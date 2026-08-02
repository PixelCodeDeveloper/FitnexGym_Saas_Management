const db     = require("../db");
const axios  = require("axios");
require("dotenv").config();

const VERIFY_MODES = {
  "1": "FINGERPRINT", "2": "PASSWORD",  "3": "QR",
  "4": "FP+PASS",     "5": "FP+QR",    "6": "PASS+FP",
  "7": "QR+FP",       "20": "FACE",     "21": "FACE+QR",
  "22": "FACE+PASS",  "23": "QR+FACE",  "24": "PASS+FACE",
  "40": "PALM",
};

// BSComm format mein verify_mode upper nibble (top 4 bits) mein hota hai
// e.g. 0x40000000 >> 28 = 4 = FACE
function decodeVerifyMode(raw) {
  const n = parseInt(raw, 10);
  if (isNaN(n)) return raw;
  // Simple values (1–40): direct map
  if (n <= 40 && VERIFY_MODES[String(n)]) return VERIFY_MODES[String(n)];
  // BSComm packed: upper nibble
  const kind = (n >>> 28) & 0xF;
  const VK = { 1:"FINGERPRINT", 2:"PASSWORD", 3:"QR", 4:"FACE", 5:"VEIN", 6:"IRIS", 7:"PALM" };
  return VK[kind] || `MODE_${kind}`;
}

// io_mode decode: top nibble (bits 28-31) = IN/OUT, bottom nibble (bits 0-3) = door event
function decodeIoMode(raw) {
  const n = parseInt(raw, 10);
  if (isNaN(n)) return raw;
  if (n === 0) return "OUT";
  if (n === 1) return "IN";
  const dir = (n >>> 28) === 1 ? "IN" : "OUT";
  const evt = n & 0xF;
  const DOOR = { 1:"CLOSE",2:"HAND_OPEN",3:"PROG_OPEN",4:"PROG_CLOSE",
                 5:"ILLEGAL_OPEN",6:"ILLEGAL_CLOSE",7:"COVER_OPEN",8:"COVER_CLOSE",
                 9:"OPEN",10:"THREAT_OPEN",13:"FIRE_ALARM" };
  return evt ? `${dir}_${DOOR[evt] || evt}` : dir;
}

// QR content: "member_id|gym_id|end_date|time_window"  (app format)
function parseQrContent(raw) {
  const parts = raw.split("|");
  if (parts.length < 4) return null;
  return {
    memberId:    parts[0],
    gymId:       parts[1],
    endDate:     parts[2],           // "2026-12-31"
    timeWindow:  parseInt(parts[3]), // unix_sec / 300
  };
}

function validateQrLocally(qr) {
  const now         = Date.now() / 1000;
  const curWindow   = Math.floor(now / 300);
  // Accept current window + 1 previous (gracePeriod)
  if (Math.abs(qr.timeWindow - curWindow) > 1) return "DENIED"; // QR expired
  const end = new Date(qr.endDate);
  if (isNaN(end.getTime()) || end < new Date()) return "EXPIRED";
  return "GRANTED";
}

// QR/Face/FP/Palm scan aaya — validate karo aur gate control karo
async function handleRealtimeGlog(req, res, devId, body, devModel) {
  try {
    let scanData;
    if (devModel) {
      scanData = JSON.parse(body.toString("utf8"));
    } else {
      const jsonStr = getStringFromBSCommBuffer(body);
      scanData = JSON.parse(jsonStr);
    }

    const rawUserId  = scanData["user_id"]     || "";
    const verifyMode = scanData["verify_mode"] || "";
    const ioMode     = scanData["io_mode"]     || "";
    const ioTime     = scanData["io_time"]     || "";
    const workCode   = scanData["work_code"]   || "0";
    const method     = decodeVerifyMode(verifyMode);
    const direction  = decodeIoMode(ioMode);

    // QR scan: user_id = full QR content "member_id|gym_id|end_date|window"
    const qrParsed = method === "QR" ? parseQrContent(rawUserId) : null;
    const userId   = qrParsed ? qrParsed.memberId : rawUserId;

    console.log(`[${devId}] SCAN → user="${userId}" method="${method}" dir="${direction}" time="${ioTime}"`);

    // Device ka registered gym_id lo
    const [[deviceRow]] = await db.execute(
      `SELECT gym_id FROM tbl_device_status WHERE device_id=? LIMIT 1`, [devId]
    );
    const deviceGymId = deviceRow?.gym_id || "";

    // Biometric scan ke liye member_id mapping lo (device_user_id → member_id)
    const [[enrollRow]] = await db.execute(
      `SELECT member_id, expiry_date FROM tbl_device_enrollments WHERE device_id=? AND device_user_id=? LIMIT 1`,
      [devId, rawUserId]
    );
    const mappedMemberId = enrollRow?.member_id || null;
    const enrollExpiry  = enrollRow?.expiry_date || null;

    // Display userId: mapped member_id ya raw
    const displayUserId = mappedMemberId || userId;

    console.log(`[${devId}] SCAN → user="${displayUserId}" method="${method}" dir="${direction}" time="${ioTime}"`);

    // Validate
    let accessResult = "DENIED";

    // Enrolled member ka expiry check (subscription)
    if (enrollRow && enrollExpiry) {
      const expiry = new Date(enrollExpiry);
      if (expiry < new Date()) {
        console.log(`[${devId}] Subscription expired → ${displayUserId} (expired: ${enrollExpiry})`);
        accessResult = "EXPIRED";
      }
    }

    if (accessResult !== "EXPIRED") {
      if (process.env.LOCAL_TEST_MODE === "true") {
        if (qrParsed) {
          accessResult = validateQrLocally(qrParsed);
          if (accessResult === "GRANTED" && deviceGymId && qrParsed.gymId !== deviceGymId) {
            console.log(`[${devId}] QR gym_id mismatch`);
            accessResult = "DENIED";
          }
        } else {
          accessResult = "GRANTED";
          console.log(`[${devId}] LOCAL_TEST_MODE → auto GRANTED`);
        }
      } else {
        try {
          if (qrParsed) {
            const scannerGymId = deviceGymId || qrParsed.gymId;
            accessResult = await validateWithSupabase(rawUserId, scannerGymId);
          } else if (!mappedMemberId) {
            // No enrollment mapping = admin/physical device user → trust device, GRANT
            accessResult = "GRANTED";
            console.log(`[${devId}] No mapping → admin user, GRANTED`);
          } else {
            // Biometric: directly Supabase members table check + attendance log
            accessResult = await validateBiometric(mappedMemberId, deviceGymId);
          }
        } catch (apiErr) {
          console.warn(`[${devId}] Supabase error: ${apiErr.message}`);
          accessResult = "GRANTED"; // Supabase down ho to block mat karo
        }
      }
    }

    console.log(`[${devId}] ACCESS ${accessResult} → "${userId}"`);

    console.log(`[${devId}] ACCESS ${accessResult} → "${displayUserId}"`);

    // Log database mein save karo
    await db.execute(
      `INSERT INTO tbl_scan_logs (device_id, user_id, verify_mode, io_mode, io_time, work_code, access_result)
       VALUES (?, ?, ?, ?, NOW(), ?, ?)`,
      [devId, displayUserId, method, direction, workCode, accessResult]
    );

    // Gate control
    if (accessResult === "GRANTED") {
      await insertCommand(devId, "SET_DOOR_STATUS", { door_status: "open" });
    } else if (accessResult === "EXPIRED" && enrollRow && enrollExpiry) {
      // Sirf tab delete karo jab LOCAL expiry confirm ho — Supabase error pe nahi
      const localExpired = new Date(enrollExpiry) < new Date();
      if (localExpired) {
        console.log(`[${devId}] Local expiry confirmed → removing ${displayUserId} from device`);
        await insertCommand(devId, "DELETE_USER", { user_id: rawUserId });
        await db.execute(
          `DELETE FROM tbl_device_enrollments WHERE device_id=? AND device_user_id=?`,
          [devId, rawUserId]
        );
      }
    }

    res.setHeader("response_code", "OK");
    res.setHeader("Content-Type", "application/octet-stream");
    res.setHeader("Content-Length", "0");
    res.end();
  } catch (err) {
    console.error(`[${devId}] realtimeGlog error:`, err.message);
    res.setHeader("response_code", "ERROR");
    res.setHeader("Content-Length", "0");
    res.end();
  }
}

// Biometric ke liye: directly members table check karo + attendance log karo
async function validateBiometric(memberId, gymId) {
  const SUPABASE_URL = process.env.SUPABASE_URL;
  const SUPABASE_KEY = process.env.SUPABASE_SERVICE_KEY;
  if (!SUPABASE_URL || !SUPABASE_KEY) return "GRANTED";

  const hdrs = {
    apikey: SUPABASE_KEY,
    Authorization: `Bearer ${SUPABASE_KEY}`,
    "Content-Type": "application/json",
  };

  try {
    // Member ka status aur end_date check karo
    const res = await axios.get(
      `${SUPABASE_URL}/rest/v1/members?member_id=eq.${memberId}&gym_id=eq.${gymId}&deleted_at=is.null&select=id,end_date,status&limit=1`,
      { headers: hdrs, timeout: 5000 }
    );
    const member = res.data?.[0];
    if (!member) {
      console.warn(`Biometric: member ${memberId} not found in Supabase`);
      return "DENIED";
    }
    if (member.status !== "Active" && member.status !== "active") {
      console.log(`Biometric: ${memberId} inactive`);
      return "DENIED";
    }
    const endDate = new Date(member.end_date);
    if (isNaN(endDate.getTime()) || endDate < new Date()) {
      console.log(`Biometric: ${memberId} subscription expired (${member.end_date})`);
      return "EXPIRED";
    }

    // Attendance log karo — sirf ek baar per day
    const today = new Date().toISOString().split("T")[0];
    const existing = await axios.get(
      `${SUPABASE_URL}/rest/v1/attendance?member_id=eq.${member.id}&gym_id=eq.${gymId}&date=eq.${today}&limit=1`,
      { headers: hdrs, timeout: 5000 }
    );
    if (existing.data?.length > 0) {
      console.log(`Biometric: ${memberId} already checked in today — skipping duplicate`);
    } else {
      await axios.post(
        `${SUPABASE_URL}/rest/v1/attendance`,
        { member_id: member.id, gym_id: gymId, date: today, check_in_time: new Date().toISOString(), status: "Present" },
        { headers: hdrs, timeout: 5000 }
      );
      console.log(`Biometric: ${memberId} GRANTED + attendance logged`);
    }
    return "GRANTED";
  } catch (e) {
    console.warn(`Biometric Supabase error: ${e.message}`);
    return "GRANTED"; // Supabase down ho to block mat karo
  }
}

// Supabase verify_door_entrance RPC call karo
// QR ke liye: rawQrContent = full QR string, scannerGymId = qr.gymId
// Biometric ke liye: rawQrContent = fake QR built from memberId+gymId, scannerGymId = gymId
async function validateWithSupabase(rawQrContent, scannerGymId) {
  const SUPABASE_URL = process.env.SUPABASE_URL;
  const SUPABASE_KEY = process.env.SUPABASE_SERVICE_KEY;

  if (!SUPABASE_URL || !SUPABASE_KEY) return "DENIED";

  const apiRes = await axios.post(
    `${SUPABASE_URL}/rest/v1/rpc/verify_door_entrance`,
    { qr_content: rawQrContent, scanner_gym_id: scannerGymId },
    {
      headers: {
        "apikey": SUPABASE_KEY,
        "Authorization": `Bearer ${SUPABASE_KEY}`,
        "Content-Type": "application/json",
      },
      timeout: 5000,
    }
  );

  const result = apiRes.data;
  if (!result || !result.unlock) {
    const msg = result?.message || "";
    if (msg.includes("expired") || msg.includes("Expired")) return "EXPIRED";
    return "DENIED";
  }
  return "GRANTED";
}

async function insertCommand(devId, cmdCode, paramObj) {
  const transId  = Date.now().toString().slice(-10);
  const paramBuf = Buffer.from(JSON.stringify(paramObj), "utf8");
  await db.execute(
    `INSERT INTO tbl_commands (trans_id, device_id, cmd_code, cmd_param, status)
     VALUES (?, ?, ?, ?, 'WAIT')`,
    [transId, devId, cmdCode, paramBuf]
  );
  console.log(`[${devId}] ← Command queued: ${cmdCode}`);
}

function getStringFromBSCommBuffer(buf) {
  if (buf.length < 4) return "";
  const lenText = buf.readUInt32LE(0);
  if (lenText === 0 || lenText > buf.length - 4) return "";
  const lastByte = buf[4 + lenText - 1];
  return buf.slice(4, lastByte === 0 ? 4 + lenText - 1 : 4 + lenText).toString("utf8");
}

module.exports = handleRealtimeGlog;
