const express = require("express");
const db      = require("../db");
const router  = express.Router();

// Scan logs — member names ke saath
router.get("/scans", async (req, res) => {
  const { device_id, limit = 100 } = req.query;
  try {
    if (!device_id) return res.status(400).json({ error: "device_id required" });
    const [rows] = await db.execute(
      `SELECT s.user_id, s.verify_mode, s.access_result, s.created_at,
              COALESCE(e.member_name, s.user_id) as member_name
       FROM tbl_scan_logs s
       LEFT JOIN tbl_device_enrollments e ON e.device_id=s.device_id AND e.member_id=s.user_id
       WHERE s.device_id=?
       ORDER BY s.created_at DESC LIMIT ?`,
      [device_id, parseInt(limit)]
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Raw scan logs
router.get("/", async (req, res) => {
  const { device_id, limit = 50 } = req.query;
  try {
    let query = `SELECT * FROM tbl_scan_logs`;
    const params = [];
    if (device_id) { query += ` WHERE device_id = ?`; params.push(device_id); }
    query += ` ORDER BY created_at DESC LIMIT ?`;
    params.push(parseInt(limit));
    const [rows] = await db.execute(query, params);
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Device status with online/offline
router.get("/devices", async (req, res) => {
  try {
    const [rows] = await db.execute(
      `SELECT *, TIMESTAMPDIFF(SECOND, last_seen, NOW()) AS seconds_ago
       FROM tbl_device_status ORDER BY last_seen DESC`
    );
    rows.forEach(r => { r.is_online = r.seconds_ago !== null && r.seconds_ago < 120 ? 1 : 0; });
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
