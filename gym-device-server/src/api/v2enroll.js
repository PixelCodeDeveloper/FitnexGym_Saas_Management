const express = require("express");
const router  = express.Router();
const db      = require("../db");
const axios   = require("axios");
require("dotenv").config();

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_KEY;

const sbHeaders = {
  apikey: SUPABASE_KEY,
  Authorization: `Bearer ${SUPABASE_KEY}`,
  "Content-Type": "application/json",
};

async function getGymId(deviceSn) {
  const [[row]] = await db.execute(
    `SELECT gym_id FROM v2_devices WHERE device_sn = ? LIMIT 1`,
    [deviceSn]
  );
  return row?.gym_id || null;
}

// GET /api/v2/enroll/members/:deviceSn — purane /api/enroll/members/:deviceId
// jaisa hi response shape ({members: [{..., enrolled, enroll_method, device_user_id}]}) —
// taaki app ki EXISTING enrollment-status UI (members_screen.dart) bina change kiye
// naye A3-8396 device ke liye bhi kaam kare.
router.get("/members/:deviceSn", async (req, res) => {
  try {
    const { deviceSn } = req.params;
    const gymId = await getGymId(deviceSn);
    if (!gymId) return res.status(404).json({ error: "Device kisi gym se registered nahi hai" });

    const sbRes = await axios.get(
      `${SUPABASE_URL}/rest/v1/members?gym_id=eq.${gymId}&deleted_at=is.null&select=id,member_id,name,end_date,status`,
      { headers: sbHeaders }
    );
    const members = sbRes.data || [];

    const [syncRows] = await db.execute(
      `SELECT supabase_member_id, device_user_id, status FROM v2_people_sync WHERE device_sn = ?`,
      [deviceSn]
    );
    const syncMap = {};
    syncRows.forEach(r => { syncMap[r.supabase_member_id] = r; });

    // Har member ka sabse recent enrollment push-back (agar walk-up enroll hua ho to)
    const [enrollRows] = await db.execute(
      `SELECT e1.supabase_member_id, e1.has_face, e1.has_fingerprint, e1.has_palmvein
       FROM v2_enrollments e1
       INNER JOIN (
         SELECT supabase_member_id, MAX(id) AS max_id
         FROM v2_enrollments WHERE device_sn = ? GROUP BY supabase_member_id
       ) latest ON e1.id = latest.max_id`,
      [deviceSn]
    );
    const enrollMap = {};
    enrollRows.forEach(r => { enrollMap[r.supabase_member_id] = r; });

    const result = members.map(m => {
      const sync = syncMap[m.id];
      const enroll = enrollMap[m.id];
      const methods = [];
      if (enroll?.has_face) methods.push("FACE");
      if (enroll?.has_fingerprint) methods.push("FINGERPRINT");
      if (enroll?.has_palmvein) methods.push("PALM");

      return {
        ...m,
        enrolled: methods.length > 0,
        device_user_id: sync?.device_user_id || null,
        enroll_method: methods.length > 0 ? methods.join("+") : null,
        sync_status: sync?.status || "not_synced",
      };
    });

    res.json({ members: result });
  } catch (err) {
    console.error("v2 enroll members error:", err.message);
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
