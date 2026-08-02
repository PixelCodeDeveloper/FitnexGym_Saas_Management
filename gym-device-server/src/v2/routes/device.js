const express = require("express");
const router = express.Router();
const db = require("../../db");
const { getActiveMembers } = require("../supabase");
const { computeQrToken } = require("../qr");

function isExpired(endDate) {
  if (!endDate) return false;
  return new Date(endDate) < new Date();
}

// Device kis gym se registered hai. Koi hardcoded fallback NAHI hai —
// jab tak SuperOwner isko explicitly kisi gym se assign nahi karta
// (POST /api/v2/devices/register), ye null rahega aur device kuch bhi
// sync nahi karega. Multi-gym production system ka yehi safe default hai.
async function getDeviceGymId(deviceSn) {
  const [[row]] = await db.execute(
    `SELECT gym_id FROM v2_devices WHERE device_sn = ? LIMIT 1`,
    [deviceSn]
  );
  return row?.gym_id || null;
}

// Supabase (device ke assigned gym) ke members vs device ki local sync-state
// compare karo — pending_add / pending_delete decide karo. CardNum ab PERMANENT
// hai per member (kabhi rotate nahi hota) — isliye yahan sirf add/remove hi hota
// hai, koi repush/race-condition risk nahi (QR ki security ab encrypted-expiry se
// aati hai, dekho api/qr.js + v2/qrEncrypted.js).
async function reconcileDevice(deviceSn) {
  const gymId = await getDeviceGymId(deviceSn);

  await db.execute(
    `INSERT INTO v2_devices (device_sn, last_seen) VALUES (?, NOW())
     ON DUPLICATE KEY UPDATE last_seen = NOW()`,
    [deviceSn]
  );

  if (!gymId) {
    console.log(`[V2][${deviceSn}] Kisi gym se assign nahi hai — SuperOwner ko register karna hoga`);
    return null;
  }

  const members = await getActiveMembers(gymId);
  const validMembers = members.filter(m => m.status === "Active" && !isExpired(m.end_date));
  const validIds = new Set(validMembers.map(m => m.id));

  const [existingRows] = await db.execute(
    `SELECT id, device_user_id, supabase_member_id, status FROM v2_people_sync WHERE device_sn = ?`,
    [deviceSn]
  );
  const existingByMember = new Map(existingRows.map(r => [r.supabase_member_id, r]));

  // Gap-fill: 1-10 device pe manual/local entries ke liye reserved hain — app-driven
  // sync hamesha 11 se shuru hoga aur delete hue member ka khaali slot reuse karega
  // (agla naya member sabse chhota available ID paayega, sirf isi device ke andar)
  const usedIds = new Set(existingRows.map(r => r.device_user_id));
  function nextDeviceUserId() {
    let candidate = 11;
    while (usedIds.has(candidate)) candidate++;
    usedIds.add(candidate);
    return candidate;
  }

  for (const m of validMembers) {
    if (existingByMember.has(m.id)) continue;
    const deviceUserId = nextDeviceUserId();
    const expirationUnix = Math.floor(new Date(m.end_date).getTime() / 1000) || 0;
    // m.id (Supabase UUID) use karo, m.member_id (jaise "BH-002") nahi —
    // display ID sirf ek gym ke andar unique hota hai, UUID globally unique hai
    const qrCode = computeQrToken(m.id);
    await db.execute(
      `INSERT INTO v2_people_sync
         (device_sn, device_user_id, gym_id, supabase_member_id, member_display_id, name, expiration_unix, qr_code, status)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'pending_add')`,
      [deviceSn, deviceUserId, gymId, m.id, m.member_id, m.name, expirationUnix, qrCode]
    );
  }

  for (const row of existingRows) {
    const stillValid = validIds.has(row.supabase_member_id);
    const alreadyPendingDelete = ["pending_delete", "sent_delete_pending_ack"].includes(row.status);
    if (!stillValid && !alreadyPendingDelete) {
      await db.execute(
        `UPDATE v2_people_sync SET status = 'pending_delete' WHERE id = ?`,
        [row.id]
      );
    }
  }

  return gymId;
}

// POST /Device/Keepalive — device heartbeat, har ~15-30 sec
router.post("/Keepalive", async (req, res) => {
  try {
    const { SN } = req.body || {};
    if (!SN) return res.json({ Success: 400 });

    await reconcileDevice(SN);

    const [[addCount]] = await db.execute(
      `SELECT COUNT(*) AS c FROM v2_people_sync WHERE device_sn = ? AND status = 'pending_add'`,
      [SN]
    );
    const [[delCount]] = await db.execute(
      `SELECT COUNT(*) AS c FROM v2_people_sync WHERE device_sn = ? AND status = 'pending_delete'`,
      [SN]
    );
    const [[remoteCount]] = await db.execute(
      `SELECT COUNT(*) AS c FROM v2_remote_commands WHERE device_sn = ? AND status = 'pending'`,
      [SN]
    );

    console.log(
      `[V2][${SN}] Keepalive → pendingAdd=${addCount.c} pendingDelete=${delCount.c} remote=${remoteCount.c}`
    );

    res.json({
      Success: 1,
      AddPeople: addCount.c > 0 ? 1 : 0,
      DeletePeople: delCount.c > 0 ? 1 : 0,
      Remote: remoteCount.c > 0 ? 1 : 0,
    });
  } catch (err) {
    console.error("[V2] Keepalive error:", err.message);
    res.json({ Success: 500 });
  }
});

// POST /Device/UploadWorkSetting — device apni current settings bhejta hai
// Phase 1: sirf acknowledge karo, kuch store/process nahi karna abhi
router.post("/UploadWorkSetting", async (req, res) => {
  const sn = req.body?.DeviceSN || "?";
  console.log(`[V2][${sn}] UploadWorkSetting received (phase 1 — no-op)`);
  res.json({ Success: 1 });
});

// POST /Device/DownloadWorkSetting — device settings pull karta hai jab SyncParameter=1 ho
// Hum abhi SyncParameter kabhi 1 nahi bhejte, isliye ye call aayegi hi nahi.
// Route future-proofing ke liye rakha hai taaki heartbeat 400/404 na de agar device khud try kare.
router.post("/DownloadWorkSetting", async (req, res) => {
  const sn = req.body?.SN || "?";
  console.log(`[V2][${sn}] DownloadWorkSetting requested — abhi tak koi config push nahi hoti`);
  res.json({ Success: 1 });
});

// POST /Device/RemoteCommand — Remote=1 hone par device call karta hai
// Ek pending command uthao (oldest first), respond karo, delivered mark karo.
router.post("/RemoteCommand", async (req, res) => {
  try {
    const { SN } = req.body || {};
    if (!SN) return res.json({ Success: 400 });

    const [[cmd]] = await db.execute(
      `SELECT id, command_type FROM v2_remote_commands
       WHERE device_sn = ? AND status = 'pending' ORDER BY created_at ASC LIMIT 1`,
      [SN]
    );

    if (!cmd) {
      return res.json({ Success: 1 });
    }

    await db.execute(
      `UPDATE v2_remote_commands SET status = 'delivered', delivered_at = NOW() WHERE id = ?`,
      [cmd.id]
    );

    const OPEN_DOOR_ACTIONS = { opendoor: 1, keepopen: 2, closedoor: 3, lockdoor: 4, unlockdoor: 5 };
    const response = { Success: 1 };

    if (cmd.command_type === "restart") response.Restart = 1;
    else if (cmd.command_type === "recover") response.Recover = 1;
    else if (cmd.command_type === "closealarm") response.Closealarm = 1;
    else if (cmd.command_type === "repostrecord") response.RepostRecord = 1;
    else if (cmd.command_type === "pushallpeople") response.PushAllPeople = 1;
    else if (cmd.command_type === "clearrecord") response.ClearRecord = 1;
    else if (OPEN_DOOR_ACTIONS[cmd.command_type]) response.Opendoor = OPEN_DOOR_ACTIONS[cmd.command_type];

    console.log(`[V2][${SN}] RemoteCommand delivered → ${cmd.command_type}`);
    res.json(response);
  } catch (err) {
    console.error("[V2] RemoteCommand error:", err.message);
    res.json({ Success: 500 });
  }
});

module.exports = router;
