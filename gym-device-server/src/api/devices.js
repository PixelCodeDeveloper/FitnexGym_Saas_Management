const express = require("express");
const db      = require("../db");
const router  = express.Router();

// Device ko gym se link karo — agar pehle kisi aur gym se tha to clean karo
// POST /api/devices/register
// Body: { device_id, gym_id }
router.post("/register", async (req, res) => {
  const { device_id, gym_id } = req.body;
  if (!device_id || !gym_id) {
    return res.status(400).json({ error: "device_id and gym_id required" });
  }

  try {
    // Pehla gym_id check karo
    const [[existing]] = await db.execute(
      `SELECT gym_id FROM tbl_device_status WHERE device_id=? LIMIT 1`,
      [device_id]
    );
    const oldGymId = existing?.gym_id || null;
    const gymChanged = oldGymId && oldGymId !== gym_id;

    if (gymChanged) {
      // Old enrolled members ko device se DELETE karo
      const [enrolled] = await db.execute(
        `SELECT device_user_id FROM tbl_device_enrollments WHERE device_id=?`,
        [device_id]
      );
      for (const row of enrolled) {
        const T = Date.now().toString().slice(-10) + Math.floor(Math.random() * 1000);
        await db.execute(
          `INSERT IGNORE INTO tbl_commands (trans_id, device_id, cmd_code, cmd_param, status)
           VALUES (?, ?, 'DELETE_USER', ?, 'WAIT')`,
          [`clr_${T}`, device_id, Buffer.from(JSON.stringify({ user_id: row.device_user_id }))]
        );
      }
      // Local DB clean karo
      await db.execute(`DELETE FROM tbl_device_enrollments WHERE device_id=?`, [device_id]);
      await db.execute(`DELETE FROM tbl_enroll_data WHERE device_id=?`, [device_id]);
      console.log(`[API] Device "${device_id}" reassigned — ${enrolled.length} old enrollments cleared`);
    }

    // Gym ID update/insert karo
    await db.execute(
      `INSERT INTO tbl_device_status (device_id, gym_id, device_name, last_seen, is_online)
       VALUES (?, ?, '', NOW(), 0)
       ON DUPLICATE KEY UPDATE gym_id=VALUES(gym_id)`,
      [device_id, gym_id]
    );

    console.log(`[API] Device "${device_id}" linked to gym "${gym_id}"`);
    res.json({ success: true, device_id, gym_id, cleared: gymChanged ? true : false });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Saare registered devices aur unka gym dekho
// GET /api/devices
router.get("/", async (req, res) => {
  try {
    const [rows] = await db.execute(
      `SELECT device_id, gym_id, device_name, firmware, last_seen, is_online FROM tbl_device_status ORDER BY last_seen DESC`
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
