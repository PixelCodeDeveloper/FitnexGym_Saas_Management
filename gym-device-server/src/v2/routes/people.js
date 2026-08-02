const express = require("express");
const router = express.Router();
const multer = require("multer");
const fs = require("fs");
const path = require("path");
const db = require("../../db");
const { getField } = require("../multipart");

const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 2 * 1024 * 1024 } });
const UPLOAD_DIR = path.join(__dirname, "../../../uploads/v2");

// POST /People/DownloadPeopleList — Keepalive ne AddPeople=1 bola tha, ab device pull kar raha hai
router.post("/DownloadPeopleList", async (req, res) => {
  try {
    const { SN, Limit } = req.body || {};
    if (!SN) return res.json({ Success: 400 });
    const limit = Math.min(parseInt(Limit, 10) || 50, 1000);

    const [rows] = await db.query(
      `SELECT id, device_user_id, supabase_member_id, name, expiration_unix, qr_code FROM v2_people_sync
       WHERE device_sn = ? AND status = 'pending_add' LIMIT ?`,
      [SN, limit]
    );

    if (rows.length > 0) {
      // id (surrogate PK) se update karo — device_user_id sirf per-device unique hai,
      // globally nahi, isliye us akele se dusre device ka row galti se touch ho sakta tha
      const ids = rows.map(r => r.id);
      await db.query(
        `UPDATE v2_people_sync SET status = 'sent_add_pending_ack' WHERE id IN (?)`,
        [ids]
      );
    }

    // CRITICAL: agar ye re-push hai (jaise QR rotation ke baad), aur member ka pehle se
    // koi Face/FP/Palm walk-up enrollment ho chuka hai, to uska data bhi isi record mein
    // wapas bhejna zaroori hai — warna device "overwrite" karte waqt purana biometric
    // data khud hi delete kar dega (ye bug real device pe reproduce hua tha).
    const memberIds = rows.map(r => r.supabase_member_id).filter(Boolean);
    const enrollMap = {};
    if (memberIds.length > 0) {
      const [enrollRows] = await db.query(
        `SELECT e1.supabase_member_id, e1.raw_detail
         FROM v2_enrollments e1
         INNER JOIN (
           SELECT supabase_member_id, MAX(id) AS max_id
           FROM v2_enrollments WHERE device_sn = ? AND supabase_member_id IN (?)
           GROUP BY supabase_member_id
         ) latest ON e1.id = latest.max_id`,
        [SN, memberIds]
      );
      for (const e of enrollRows) {
        try {
          enrollMap[e.supabase_member_id] = JSON.parse(e.raw_detail);
        } catch { /* corrupt/empty, skip */ }
      }
    }

    const PeopleList = rows.map(r => {
      const enroll = enrollMap[r.supabase_member_id];
      const entry = {
        UserID: String(r.device_user_id),
        Name: r.name || "",
        AccessType: 0,
        ExpirationDate: r.expiration_unix || 0,
        OpenTimes: 65535,
        KeepOpen: 0,
        Timegroup: 1,
        QRCode: r.qr_code || "",
        // Company ne confirm kiya — device QR ko CardNum field se match karta hai,
        // isliye same numeric token dono jagah bhej rahe hain (safe/redundant)
        CardNum: r.qr_code || "",
      };
      if (enroll?.FaceFeature) {
        entry.FaceFeature = enroll.FaceFeature;
        if (enroll.FaceFeatureMD5) entry.FaceFeatureMD5 = enroll.FaceFeatureMD5;
      }
      if (Array.isArray(enroll?.Fingerprints) && enroll.Fingerprints.length > 0) {
        entry.Fingerprints = enroll.Fingerprints;
      }
      if (Array.isArray(enroll?.Palmveins) && enroll.Palmveins.length > 0) {
        entry.Palmveins = enroll.Palmveins;
      }
      return entry;
    });

    console.log(`[V2][${SN}] DownloadPeopleList → sending ${PeopleList.length} people`);
    // Exact CardNum/QRCode per UserID log karo — taaki proof ho ki server kya bhej raha hai
    for (const p of PeopleList) {
      console.log(`[V2][${SN}]   → UserID=${p.UserID} Name="${p.Name}" CardNum=${p.CardNum} QRCode=${p.QRCode}`);
    }
    // Doc mein field ka naam "PeopleCount" bataya gaya hai lekin JSON example mein "Count" use hua hai —
    // dono bhej rahe hain jab tak real device se confirm na ho jaye ki kaunsa actually padha jaata hai
    res.json({ Success: 1, PeopleCount: PeopleList.length, Count: PeopleList.length, PeopleList });
  } catch (err) {
    console.error("[V2] DownloadPeopleList error:", err.message);
    res.json({ Success: 500 });
  }
});

// POST /People/DownloadPeopleListResult — device batata hai kaun import hua, kaun fail
router.post("/DownloadPeopleListResult", async (req, res) => {
  try {
    const { SN, SuccessCount, FailCount, FailList } = req.body || {};
    const failIds = new Set((Array.isArray(FailList) ? FailList : []).map(f => String(f.UserID)));

    const [pending] = await db.execute(
      `SELECT id, device_user_id FROM v2_people_sync WHERE device_sn = ? AND status = 'sent_add_pending_ack'`,
      [SN]
    );

    for (const row of pending) {
      const idStr = String(row.device_user_id);
      if (failIds.has(idStr)) {
        await db.execute(
          `UPDATE v2_people_sync SET status = 'pending_add', last_error = ? WHERE id = ?`,
          ["device reported import failure", row.id]
        );
      } else {
        await db.execute(
          `UPDATE v2_people_sync SET status = 'synced', last_error = NULL WHERE id = ?`,
          [row.id]
        );
      }
    }

    console.log(`[V2][${SN}] DownloadPeopleListResult → success=${SuccessCount ?? "?"} fail=${FailCount ?? "?"}`);
    res.json({ Success: 1 });
  } catch (err) {
    console.error("[V2] DownloadPeopleListResult error:", err.message);
    res.json({ Success: 500 });
  }
});

// POST /People/DeletePeopleList — Keepalive ne DeletePeople=1 bola tha
router.post("/DeletePeopleList", async (req, res) => {
  try {
    const { SN, Limit } = req.body || {};
    if (!SN) return res.json({ Success: 400 });
    const limit = Math.min(parseInt(Limit, 10) || 50, 1000);

    const [rows] = await db.query(
      `SELECT id, device_user_id FROM v2_people_sync WHERE device_sn = ? AND status = 'pending_delete' LIMIT ?`,
      [SN, limit]
    );

    if (rows.length > 0) {
      const ids = rows.map(r => r.id);
      await db.query(
        `UPDATE v2_people_sync SET status = 'sent_delete_pending_ack' WHERE id IN (?)`,
        [ids]
      );
    }

    console.log(`[V2][${SN}] DeletePeopleList → sending ${rows.length} deletes`);
    res.json({
      Success: 1,
      DeleteAll: 0,
      DeleteCount: rows.length,
      DeleteList: rows.map(r => r.device_user_id),
    });
  } catch (err) {
    console.error("[V2] DeletePeopleList error:", err.message);
    res.json({ Success: 500 });
  }
});

// POST /People/DeletePeopleListResult — device confirm karta hai ki delete ho gaya
router.post("/DeletePeopleListResult", async (req, res) => {
  try {
    const { SN, DeleteList } = req.body || {};
    const ids = Array.isArray(DeleteList) ? DeleteList : [];

    if (ids.length > 0) {
      await db.query(
        `DELETE FROM v2_people_sync WHERE device_sn = ? AND device_user_id IN (?)`,
        [SN, ids]
      );
    }

    console.log(`[V2][${SN}] DeletePeopleListResult → removed ${ids.length} local mappings`);
    res.json({ Success: 1 });
  } catch (err) {
    console.error("[V2] DeletePeopleListResult error:", err.message);
    res.json({ Success: 500 });
  }
});

// POST /People/PushPeople — device se enrollment push-back (Face/FP/Palm walk-up
// enrollment, ya device menu se manual add/update/delete). multipart/form-data.
router.post("/PushPeople", upload.any(), async (req, res) => {
  try {
    const SN = getField(req, "SN");
    const UserID = getField(req, "UserID");
    const PushType = parseInt(getField(req, "PushType"), 10) || 0;
    const detailRaw = getField(req, "Detail");
    if (!SN || !UserID) return res.json({ Success: 400 });

    let detail = null;
    if (detailRaw) {
      try { detail = JSON.parse(detailRaw); } catch { detail = null; }
    }

    const [[mapping]] = await db.execute(
      `SELECT supabase_member_id, member_display_id FROM v2_people_sync
       WHERE device_sn = ? AND device_user_id = ? LIMIT 1`,
      [SN, UserID]
    );

    const photoFile = (req.files || []).find(f => f.fieldname === "Photo");
    let photoPath = null;
    if (photoFile) {
      fs.mkdirSync(UPLOAD_DIR, { recursive: true });
      const filename = `enroll_${SN}_${UserID}_${Date.now()}.jpg`;
      fs.writeFileSync(path.join(UPLOAD_DIR, filename), photoFile.buffer);
      photoPath = `uploads/v2/${filename}`;
    }

    const hasFace = !!(detail && detail.FaceFeature);
    const hasFingerprint = !!(detail && Array.isArray(detail.Fingerprints) && detail.Fingerprints.length > 0);
    const hasPalmvein = !!(detail && Array.isArray(detail.Palmveins) && detail.Palmveins.length > 0);

    await db.execute(
      `INSERT INTO v2_enrollments
         (device_sn, device_user_id, supabase_member_id, member_display_id, push_type,
          has_face, has_fingerprint, has_palmvein, photo_path, raw_detail)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        SN, UserID, mapping?.supabase_member_id || null, mapping?.member_display_id || null,
        PushType, hasFace ? 1 : 0, hasFingerprint ? 1 : 0, hasPalmvein ? 1 : 0,
        photoPath, JSON.stringify(detail || {}),
      ]
    );

    console.log(
      `[V2][${SN}] PushPeople → UserID=${UserID} member=${mapping?.member_display_id || "?"} ` +
      `type=${PushType} face=${hasFace} fp=${hasFingerprint} palm=${hasPalmvein}`
    );

    res.json({ Success: 1 });
  } catch (err) {
    console.error("[V2] PushPeople error:", err.message);
    res.json({ Success: 500 });
  }
});

module.exports = router;
