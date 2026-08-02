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
  Prefer: "return=representation",
};

async function getGymId(deviceId) {
  const [[row]] = await db.execute(
    `SELECT gym_id FROM tbl_device_status WHERE device_id=? LIMIT 1`,
    [deviceId]
  );
  return row?.gym_id || null;
}

// Registered devices list
router.get("/devices", async (req, res) => {
  try {
    const [rows] = await db.execute(
      `SELECT device_id, gym_id, last_seen,
        CASE WHEN last_seen > DATE_SUB(NOW(), INTERVAL 2 MINUTE) THEN 1 ELSE 0 END as is_online
       FROM tbl_device_status WHERE gym_id IS NOT NULL`
    );
    res.json({ devices: rows });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// Members list — device_id se gym auto-detect
router.get("/", async (req, res) => {
  try {
    const deviceId = req.query.device_id;
    if (!deviceId) return res.status(400).json({ error: "device_id query param required" });

    const gymId = await getGymId(deviceId);
    if (!gymId) return res.status(404).json({ error: "Device kisi gym se registered nahi hai" });

    const r = await axios.get(
      `${SUPABASE_URL}/rest/v1/members?gym_id=eq.${gymId}&deleted_at=is.null&order=member_id.asc`,
      { headers: sbHeaders }
    );
    let members = r.data || [];

    const [enrolled] = await db.execute(
      `SELECT member_id, device_user_id, method, expiry_date FROM tbl_device_enrollments WHERE device_id=?`,
      [deviceId]
    );
    const map = {};
    enrolled.forEach(e => { map[e.member_id] = e; });
    members = members.map(m => ({
      ...m,
      enrolled: !!map[m.member_id],
      device_user_id: map[m.member_id]?.device_user_id || null,
      enroll_method:  map[m.member_id]?.method || null,
    }));

    res.json({ members });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// Delete member — Supabase se + device se bhi remove
router.delete("/:id", async (req, res) => {
  try {
    const deviceId = req.query.device_id;
    const gymId = deviceId ? await getGymId(deviceId) : null;

    // UUID se member_id (BH-XXX) fetch karo
    const filter = gymId
      ? `id=eq.${req.params.id}&gym_id=eq.${gymId}`
      : `id=eq.${req.params.id}`;

    const sbRes = await axios.get(
      `${SUPABASE_URL}/rest/v1/members?${filter}&select=member_id`,
      { headers: sbHeaders }
    );
    const displayMemberId = sbRes.data?.[0]?.member_id;

    if (displayMemberId) {
      const [enrolled] = await db.execute(
        `SELECT device_id, device_user_id FROM tbl_device_enrollments WHERE member_id=?`,
        [displayMemberId]
      );
      for (const row of enrolled) {
        const T = Date.now().toString().slice(-10);
        await db.execute(
          `INSERT INTO tbl_commands (trans_id, device_id, cmd_code, cmd_param, status) VALUES (?, ?, 'DELETE_USER', ?, 'WAIT')`,
          [`del_${T}`, row.device_id, Buffer.from(JSON.stringify({ user_id: row.device_user_id }))]
        );
        await db.execute(
          `DELETE FROM tbl_device_enrollments WHERE device_id=? AND member_id=?`,
          [row.device_id, displayMemberId]
        );
      }
    }

    await axios.patch(
      `${SUPABASE_URL}/rest/v1/members?id=eq.${req.params.id}`,
      { deleted_at: new Date().toISOString(), status: "Inactive" },
      { headers: sbHeaders }
    );
    res.json({ success: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

module.exports = router;
