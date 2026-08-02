const express = require("express");
const router  = express.Router();
const db      = require("../db");

const VALID_COMMANDS = [
  "opendoor", "closedoor", "keepopen", "lockdoor", "unlockdoor",
  "restart", "recover", "closealarm", "repostrecord", "pushallpeople", "clearrecord",
];

// POST /api/v2/remote-command — app/admin se gate manually open karna ho,
// device restart karna ho, etc. — agle heartbeat pe device isko utha lega.
// Body: { device_sn, command_type }
router.post("/", async (req, res) => {
  try {
    const { device_sn, command_type } = req.body || {};
    if (!device_sn || !VALID_COMMANDS.includes(command_type)) {
      return res.status(400).json({ error: `command_type must be one of: ${VALID_COMMANDS.join(", ")}` });
    }

    const [result] = await db.execute(
      `INSERT INTO v2_remote_commands (device_sn, command_type, status) VALUES (?, ?, 'pending')`,
      [device_sn, command_type]
    );

    console.log(`[V2 API] Remote command queued → device=${device_sn} type=${command_type}`);
    res.json({ success: true, id: result.insertId });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/v2/remote-command/:device_sn — status dekho (pending/delivered)
router.get("/:device_sn", async (req, res) => {
  try {
    const [rows] = await db.execute(
      `SELECT id, command_type, status, created_at, delivered_at
       FROM v2_remote_commands WHERE device_sn = ? ORDER BY created_at DESC LIMIT 20`,
      [req.params.device_sn]
    );
    res.json({ commands: rows });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
