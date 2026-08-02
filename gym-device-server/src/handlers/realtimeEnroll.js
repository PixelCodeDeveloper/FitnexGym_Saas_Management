const db = require("../db");

const BACKUP_METHODS = {
  0:"FINGERPRINT",1:"FINGERPRINT",2:"FINGERPRINT",3:"FINGERPRINT",
  4:"FINGERPRINT",5:"FINGERPRINT",6:"FINGERPRINT",7:"FINGERPRINT",
  8:"FINGERPRINT",9:"FINGERPRINT",
  10:"PASSWORD", 11:"QR",
  12:"FACE",
  13:"PALM",14:"PALM",15:"PALM",16:"PALM",
  20:"VEIN", 30:"PHOTO",
};

// Device se enrollment data aaya — save karo aur app ko notify karo
async function handleRealtimeEnroll(req, res, devId, body, devModel) {
  try {
    let jsonStr;
    if (devModel) {
      jsonStr = body.toString("utf8");
    } else {
      jsonStr = getStringFromBSCommBuffer(body);
    }

    const enrollData = JSON.parse(jsonStr);
    const userId     = enrollData["user_id"] || "";
    // backup_number field — different keys possible in different firmware
    const backupNum  = parseInt(
      enrollData["backup_number"] ?? enrollData["backup_no"] ?? enrollData["backupNumber"] ?? "-1"
    );
    const method     = BACKUP_METHODS[backupNum] || `BACKUP_${backupNum}`;

    console.log(`[${devId}] ENROLL → user="${userId}" method="${method}" backup=${backupNum}`);

    // Enroll data save karo
    await db.execute(
      `INSERT INTO tbl_enroll_data (device_id, user_id, method, enroll_data)
       VALUES (?, ?, ?, ?)
       ON DUPLICATE KEY UPDATE enroll_data=VALUES(enroll_data), enrolled_at=NOW()`,
      [devId, userId, method, body]
    );

    // App ko notify karo (Cloudflare Worker webhook)
    // Ye optional hai — app chahiye to uncomment karo
    /*
    await axios.post(process.env.CLOUDFLARE_WORKER_URL + "/enrolled", {
      device_id: devId,
      user_id: userId,
      method: method,
    });
    */

    console.log(`[${devId}] Enrollment saved: user="${userId}" method="${method}"`);

    res.setHeader("response_code", "OK");
    res.setHeader("Content-Type", "application/octet-stream");
    res.setHeader("Content-Length", "0");
    res.end();
  } catch (err) {
    console.error(`[${devId}] realtimeEnroll error:`, err.message);
    res.setHeader("response_code", "ERROR");
    res.setHeader("Content-Length", "0");
    res.end();
  }
}

function getStringFromBSCommBuffer(buf) {
  if (buf.length < 4) return "";
  const lenText = buf.readUInt32LE(0);
  if (lenText === 0 || lenText > buf.length - 4) return "";
  const lastByte = buf[4 + lenText - 1];
  return buf.slice(4, lastByte === 0 ? 4 + lenText - 1 : 4 + lenText).toString("utf8");
}

module.exports = handleRealtimeEnroll;
