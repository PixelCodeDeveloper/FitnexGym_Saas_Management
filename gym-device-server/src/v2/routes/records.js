const express = require("express");
const router = express.Router();
const multer = require("multer");
const fs = require("fs");
const path = require("path");
const db = require("../../db");
const { getField } = require("../multipart");
const { markAttendance, TEST_GYM_ID } = require("../supabase");

const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 2 * 1024 * 1024 } });
const UPLOAD_DIR = path.join(__dirname, "../../../uploads/v2");

// RecordType → human label + whether it means access was actually granted.
// Reference: HTTP protocol doc, "Record Management" section.
const GRANTED_TYPES = new Set([
  1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 25, 29, 31, 32, 33, 34,
  36, 37, 38, 39, 40, 41, 42, 43, 46, 47,
]);
const RECORD_TYPE_LABEL = {
  1: "CARD", 2: "FINGERPRINT", 3: "FACE", 4: "CARD+FP", 5: "FACE+FP", 6: "CARD+FACE",
  7: "CARD+PASSWORD", 8: "FACE+PASSWORD", 9: "FP+PASSWORD", 10: "PASSWORD",
  11: "CARD+FP+PASSWORD", 12: "CARD+FACE+PASSWORD", 13: "FP+FACE+PASSWORD",
  14: "CARD+FP+FACE", 15: "REPEATED", 16: "EXPIRED", 17: "TIMEZONE_EXPIRED",
  18: "HOLIDAY_DENIED", 19: "UNREGISTERED", 20: "LOCKED", 21: "TIMES_EXHAUSTED",
  22: "LOCKED_VERIFY", 23: "LOST_CARD", 24: "BLACKLIST", 25: "NO_VERIFY_OPEN",
  26: "CARD_DISABLED", 27: "FP_DISABLED", 28: "CONTROLLER_EXPIRED", 29: "EXPIRING_SOON",
  30: "TEMP_ABNORMAL", 31: "VISITOR_PASSWORD", 32: "QR", 33: "MENU_ADD", 34: "MENU_MODIFY",
  35: "MENU_DELETE", 36: "PALM", 37: "CARD+PALM+FACE", 38: "PALM+PASSWORD", 39: "CARD+PALM",
  40: "FACE+PALM", 41: "CARD+PALM+PASSWORD", 42: "PALM+FACE+PASSWORD", 43: "FP+PALM+FACE",
  44: "COMBO_WAITING", 45: "COMBO_FAILED", 46: "COMBO_SUCCESS", 47: "PEOPLE_ID_COMPARE",
  48: "CARD_NOT_REGISTERED", 49: "UNREGISTERED_QR",
};

// POST /Record/UploadIdentifyRecord — QR/Face/FP/Palm scan hote hi device bhejta hai
// (gate ka faisla device pehle hi le chuka hota hai — ye sirf INFORM karta hai)
router.post("/UploadIdentifyRecord", upload.any(), async (req, res) => {
  try {
    const SN = getField(req, "SN");
    // Doc ke text mein field "RecordDetail" hai, examples mein "recordJson" — dono accept karo
    const detailRaw = getField(req, "RecordDetail") || getField(req, "recordJson");
    if (!SN || !detailRaw) return res.json({ Success: 400 });

    let detail;
    try {
      detail = JSON.parse(detailRaw);
    } catch {
      return res.json({ Success: 400 });
    }

    const photoFile = (req.files || []).find(f => ["Photo", "pic"].includes(f.fieldname));
    let photoPath = null;
    if (photoFile) {
      fs.mkdirSync(UPLOAD_DIR, { recursive: true });
      const filename = `scan_${SN}_${Date.now()}.jpg`;
      fs.writeFileSync(path.join(UPLOAD_DIR, filename), photoFile.buffer);
      photoPath = `uploads/v2/${filename}`;
    }

    const rawUserId = String(detail.UserID || "");
    const [[mapping]] = await db.execute(
      `SELECT supabase_member_id, member_display_id, gym_id FROM v2_people_sync
       WHERE device_sn = ? AND device_user_id = ? LIMIT 1`,
      [SN, rawUserId]
    );

    const recordType = parseInt(detail.RecordType, 10) || 0;
    const methodLabel = RECORD_TYPE_LABEL[recordType] || `TYPE_${recordType}`;
    const accessResult = GRANTED_TYPES.has(recordType) ? "GRANTED" : "DENIED";
    const ioTime = detail.RecordDate ? new Date(detail.RecordDate * 1000) : new Date();

    await db.execute(
      `INSERT INTO v2_scan_logs
         (device_sn, record_id, device_user_id, supabase_member_id, member_display_id,
          record_type, method_label, access_result, is_entry, body_temp, io_time, photo_path, raw_detail)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        SN, detail.RecordID || null, rawUserId, mapping?.supabase_member_id || null,
        mapping?.member_display_id || detail.Name || null, recordType, methodLabel,
        accessResult, detail.IsEntry ?? null, detail.BodyTemp ?? null, ioTime, photoPath,
        JSON.stringify(detail),
      ]
    );

    console.log(
      `[V2][${SN}] Scan → user=${mapping?.member_display_id || rawUserId} ` +
      `method=${methodLabel} result=${accessResult}`
    );

    if (accessResult === "GRANTED" && mapping?.supabase_member_id) {
      try {
        await markAttendance(mapping.supabase_member_id, mapping.gym_id || TEST_GYM_ID);
      } catch (e) {
        console.warn(`[V2][${SN}] markAttendance failed:`, e.message);
      }
    }

    res.json({ Success: 1 });
  } catch (err) {
    console.error("[V2] UploadIdentifyRecord error:", err.message);
    res.json({ Success: 500 });
  }
});

// POST /Record/UploadSystemRecord — door sensor / system / alarm events (batch, JSON)
router.post("/UploadSystemRecord", async (req, res) => {
  try {
    const { SN, RecordType, Records } = req.body || {};
    if (!SN || !Array.isArray(Records)) return res.json({ Success: 400 });

    for (const r of Records) {
      await db.execute(
        `INSERT INTO v2_system_logs (device_sn, record_id, category, sub_type, record_date)
         VALUES (?, ?, ?, ?, ?)`,
        [
          SN, r.RecordID || null, RecordType || null, r.RecordType || null,
          r.RecordDate ? new Date(r.RecordDate * 1000) : new Date(),
        ]
      );
    }

    console.log(`[V2][${SN}] UploadSystemRecord → ${Records.length} events logged`);
    res.json({ Success: 1 });
  } catch (err) {
    console.error("[V2] UploadSystemRecord error:", err.message);
    res.json({ Success: 500 });
  }
});

module.exports = router;
