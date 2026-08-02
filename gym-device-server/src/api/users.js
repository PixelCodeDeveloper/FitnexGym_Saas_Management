const express = require("express");
const db      = require("../db");
const router  = express.Router();

// Member add karo device pe (App se trigger)
// POST /api/users/add
// Body: { device_id, user_id, user_name, method: "QR"|"FACE"|"FINGERPRINT"|"PALM" }
router.post("/add", async (req, res) => {
  const { device_id, user_id, user_name, method } = req.body;

  if (!device_id || !user_id || !user_name || !method) {
    return res.status(400).json({ error: "device_id, user_id, user_name, method required" });
  }

  try {
    const transId = Date.now().toString().slice(-10);
    const params  = {
      user_id,
      user_name,
      user_privilege: "normal",
      enroll_data_array: [],
    };
    const paramBuf = Buffer.from(JSON.stringify(params), "utf8");

    await db.execute(
      `INSERT INTO tbl_commands (trans_id, device_id, cmd_code, cmd_param, status)
       VALUES (?, ?, 'SET_USER_INFO', ?, 'WAIT')`,
      [transId, device_id, paramBuf]
    );

    console.log(`[API] User add queued: "${user_name}" (${method}) → device "${device_id}"`);
    res.json({
      success: true,
      trans_id: transId,
      message: method === "QR"
        ? "User added. QR ready to use."
        : `User added. Member ko device ke paas le jao enrollment ke liye.`,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Member delete karo device se (Subscription expire pe)
// POST /api/users/delete
// Body: { device_id, user_id }
router.post("/delete", async (req, res) => {
  const { device_id, user_id } = req.body;

  if (!device_id || !user_id) {
    return res.status(400).json({ error: "device_id and user_id required" });
  }

  try {
    const transId  = Date.now().toString().slice(-10);
    const paramBuf = Buffer.from(JSON.stringify({ user_id }), "utf8");

    await db.execute(
      `INSERT INTO tbl_commands (trans_id, device_id, cmd_code, cmd_param, status)
       VALUES (?, ?, 'DELETE_USER', ?, 'WAIT')`,
      [transId, device_id, paramBuf]
    );

    console.log(`[API] User delete queued: "${user_id}" → device "${device_id}"`);
    res.json({ success: true, trans_id: transId });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Gate manually open/close karo
// POST /api/users/door
// Body: { device_id, status: "open"|"close" }
router.post("/door", async (req, res) => {
  const { device_id, status } = req.body;

  if (!device_id || !status) {
    return res.status(400).json({ error: "device_id and status required" });
  }

  try {
    const transId  = Date.now().toString().slice(-10);
    const paramBuf = Buffer.from(JSON.stringify({ door_status: status }), "utf8");

    await db.execute(
      `INSERT INTO tbl_commands (trans_id, device_id, cmd_code, cmd_param, status)
       VALUES (?, ?, 'SET_DOOR_STATUS', ?, 'WAIT')`,
      [transId, device_id, paramBuf]
    );

    res.json({ success: true, trans_id: transId });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
