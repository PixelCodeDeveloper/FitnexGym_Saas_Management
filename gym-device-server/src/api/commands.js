const express = require("express");
const db      = require("../db");
const router  = express.Router();

// App se command bhejo device ko
// POST /api/commands
// Body: { device_id, cmd_code, params }
router.post("/", async (req, res) => {
  const { device_id, cmd_code, params } = req.body;

  if (!device_id || !cmd_code) {
    return res.status(400).json({ error: "device_id and cmd_code required" });
  }

  try {
    const transId  = Date.now().toString().slice(-10);
    const paramBuf = params ? Buffer.from(JSON.stringify(params), "utf8") : null;

    await db.execute(
      `INSERT INTO tbl_commands (trans_id, device_id, cmd_code, cmd_param, status)
       VALUES (?, ?, ?, ?, 'WAIT')`,
      [transId, device_id, cmd_code, paramBuf]
    );

    console.log(`[API] Command queued: ${cmd_code} → device "${device_id}"`);
    res.json({ success: true, trans_id: transId });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Command status check karo
// GET /api/commands/:transId
router.get("/:transId", async (req, res) => {
  const [rows] = await db.execute(
    `SELECT trans_id, device_id, cmd_code, status, return_code, updated_at
     FROM tbl_commands WHERE trans_id=?`,
    [req.params.transId]
  );
  if (rows.length === 0) return res.status(404).json({ error: "Not found" });
  res.json(rows[0]);
});

module.exports = router;
