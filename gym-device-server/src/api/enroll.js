const express = require("express");
const router  = express.Router();
const db      = require("../db");
const axios   = require("axios");
require("dotenv").config();

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_KEY;
const METHODS = { FACE: 12, PALM: 13, FP: 0 };

async function getGymId(deviceId) {
  const [[row]] = await db.execute(
    `SELECT gym_id FROM tbl_device_status WHERE device_id=? LIMIT 1`,
    [deviceId]
  );
  return row?.gym_id || null;
}

const sbHeaders = (key) => ({
  apikey: key,
  Authorization: `Bearer ${key}`,
  "Content-Type": "application/json",
});

router.get("/members/:deviceId", async (req, res) => {
  try {
    const { deviceId } = req.params;
    const gymId = await getGymId(deviceId);
    if (!gymId) return res.status(404).json({ error: "Device kisi gym se registered nahi hai" });

    const sbRes = await axios.get(
      `${SUPABASE_URL}/rest/v1/members?gym_id=eq.${gymId}&deleted_at=is.null&select=id,member_id,name,end_date,status`,
      { headers: sbHeaders(SUPABASE_KEY) }
    );
    const members = sbRes.data || [];

    const [enrolled] = await db.execute(
      `SELECT member_id, device_user_id, method, expiry_date FROM tbl_device_enrollments WHERE device_id=?`,
      [deviceId]
    );
    const enrollMap = {};
    enrolled.forEach(e => { enrollMap[e.member_id] = e; });

    const result = members.map(m => ({
      ...m,
      enrolled: !!enrollMap[m.member_id],
      device_user_id: enrollMap[m.member_id]?.device_user_id || null,
      enroll_method: enrollMap[m.member_id]?.method || null,
      enroll_expiry: enrollMap[m.member_id]?.expiry_date || null,
    }));

    res.json({ members: result });
  } catch (err) {
    console.error("enroll members error:", err.message);
    res.status(500).json({ error: err.message });
  }
});

router.post("/start", async (req, res) => {
  try {
    const { device_id, member_id, member_name, end_date, method } = req.body;
    if (!device_id || !member_id || !method) {
      return res.status(400).json({ error: "device_id, member_id, method required" });
    }

    const gymId = await getGymId(device_id);
    if (!gymId) return res.status(404).json({ error: "Device kisi gym se registered nahi hai" });

    const backupNumber = METHODS[method.toUpperCase()];
    if (backupNumber === undefined) {
      return res.status(400).json({ error: "method must be FACE, PALM, or FP" });
    }

    const [usedRows] = await db.execute(
      `SELECT CAST(device_user_id AS UNSIGNED) as uid FROM tbl_device_enrollments WHERE device_id=? ORDER BY uid ASC`,
      [device_id]
    );
    const usedIds = new Set(usedRows.map(r => r.uid));
    let nextIdNum = 5;
    while (usedIds.has(nextIdNum)) nextIdNum++;
    const nextId = String(nextIdNum);

    const [[existing]] = await db.execute(
      `SELECT device_user_id FROM tbl_device_enrollments WHERE device_id=? AND member_id=?`,
      [device_id, member_id]
    );
    const deviceUserId = existing ? existing.device_user_id : nextId;

    const expiryDate = end_date ? new Date(end_date).toISOString().split("T")[0] : null;

    await db.execute(
      `INSERT INTO tbl_device_enrollments (device_id, device_user_id, member_id, member_name, gym_id, method, expiry_date)
       VALUES (?, ?, ?, ?, ?, ?, ?)
       ON DUPLICATE KEY UPDATE device_user_id=VALUES(device_user_id), method=VALUES(method), expiry_date=VALUES(expiry_date), member_name=VALUES(member_name)`,
      [device_id, deviceUserId, member_id, member_name || member_id, gymId, method.toUpperCase(), expiryDate]
    );

    const T = Date.now().toString().slice(-10);
    const expireStr = expiryDate ? expiryDate.replace(/-/g, "") : "";
    const userInfoParam = JSON.stringify({
      user_id: deviceUserId,
      user_name: member_name || member_id,
      user_privilege: "normal",
      expire_date: expireStr,
      enroll_data_array: []
    });
    await db.execute(
      `INSERT INTO tbl_commands (trans_id, device_id, cmd_code, cmd_param, status) VALUES (?, ?, 'SET_USER_INFO', ?, 'WAIT')`,
      [`sui_${T}`, device_id, Buffer.from(userInfoParam)]
    );

    const enrollParam = JSON.stringify({
      cmd: "enter_enroll",
      param: { user_id: deviceUserId, backup_number: backupNumber }
    });
    await db.execute(
      `INSERT INTO tbl_commands (trans_id, device_id, cmd_code, cmd_param, status) VALUES (?, ?, 'SET_COMMAND', ?, 'WAIT')`,
      [`enr_${T}`, device_id, Buffer.from(enrollParam)]
    );

    res.json({
      success: true,
      device_user_id: deviceUserId,
      message: `Device enrollment mode mein ja raha hai — member ko device ke saamne ${method} scan karne ke liye bolo`
    });
  } catch (err) {
    console.error("enroll start error:", err.message);
    res.status(500).json({ error: err.message });
  }
});

router.delete("/:deviceId/:memberId", async (req, res) => {
  try {
    const { deviceId, memberId } = req.params;
    const [[row]] = await db.execute(
      `SELECT device_user_id FROM tbl_device_enrollments WHERE device_id=? AND member_id=?`,
      [deviceId, memberId]
    );
    if (!row) return res.status(404).json({ error: "Member enrolled nahi hai is device pe" });

    const T = Date.now().toString().slice(-10);
    await db.execute(
      `INSERT INTO tbl_commands (trans_id, device_id, cmd_code, cmd_param, status) VALUES (?, ?, 'DELETE_USER', ?, 'WAIT')`,
      [`del_${T}`, deviceId, Buffer.from(JSON.stringify({ user_id: row.device_user_id }))]
    );
    await db.execute(
      `DELETE FROM tbl_device_enrollments WHERE device_id=? AND member_id=?`,
      [deviceId, memberId]
    );

    res.json({ success: true, message: `Member ${memberId} device se remove ho raha hai` });
  } catch (err) {
    console.error("enroll delete error:", err.message);
    res.status(500).json({ error: err.message });
  }
});

router.post("/cleanup/:deviceId", async (req, res) => {
  try {
    const { deviceId } = req.params;
    const [expired] = await db.execute(
      `SELECT device_user_id, member_id FROM tbl_device_enrollments WHERE device_id=? AND expiry_date < CURDATE()`,
      [deviceId]
    );
    for (const row of expired) {
      const T = Date.now().toString().slice(-10);
      await db.execute(
        `INSERT INTO tbl_commands (trans_id, device_id, cmd_code, cmd_param, status) VALUES (?, ?, 'DELETE_USER', ?, 'WAIT')`,
        [`exp_${T}`, deviceId, Buffer.from(JSON.stringify({ user_id: row.device_user_id }))]
      );
      await db.execute(
        `DELETE FROM tbl_device_enrollments WHERE device_id=? AND member_id=?`,
        [deviceId, row.member_id]
      );
    }
    res.json({ success: true, removed: expired.length, members: expired.map(r => r.member_id) });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Name ya expiry kuch bhi change ho — device pe update karo
router.patch("/update-info", async (req, res) => {
  try {
    const { device_id, member_id, member_name, end_date } = req.body;
    if (!device_id || !member_id) {
      return res.status(400).json({ error: "device_id, member_id required" });
    }
    const [[row]] = await db.execute(
      `SELECT device_user_id FROM tbl_device_enrollments WHERE device_id=? AND member_id=?`,
      [device_id, member_id]
    );
    if (!row) return res.status(404).json({ error: "Member enrolled nahi hai is device pe" });

    const expiryDate = end_date ? new Date(end_date).toISOString().split("T")[0] : null;
    const expireStr = expiryDate ? expiryDate.replace(/-/g, "") : "";
    const T = Date.now().toString().slice(-10);

    await db.execute(
      `INSERT INTO tbl_commands (trans_id, device_id, cmd_code, cmd_param, status) VALUES (?, ?, 'SET_USER_INFO', ?, 'WAIT')`,
      [`inf_${T}`, device_id, Buffer.from(JSON.stringify({
        user_id: row.device_user_id,
        user_name: member_name || member_id,
        user_privilege: "normal",
        expire_date: expireStr,
        enroll_data_array: []
      }))]
    );

    const updates = {};
    if (member_name) updates.member_name = member_name;
    if (expiryDate) updates.expiry_date = expiryDate;
    if (Object.keys(updates).length > 0) {
      const setClauses = Object.keys(updates).map(k => `${k}=?`).join(", ");
      await db.execute(
        `UPDATE tbl_device_enrollments SET ${setClauses} WHERE device_id=? AND member_id=?`,
        [...Object.values(updates), device_id, member_id]
      );
    }

    res.json({ success: true, message: `${member_id} info device pe update ho rahi hai` });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.patch("/update-expiry", async (req, res) => {
  try {
    const { device_id, member_id, member_name, end_date } = req.body;
    if (!device_id || !member_id || !end_date) {
      return res.status(400).json({ error: "device_id, member_id, end_date required" });
    }
    const [[row]] = await db.execute(
      `SELECT device_user_id FROM tbl_device_enrollments WHERE device_id=? AND member_id=?`,
      [device_id, member_id]
    );
    if (!row) return res.status(404).json({ error: "Member enrolled nahi hai is device pe" });

    const expiryDate = new Date(end_date).toISOString().split("T")[0];
    const expireStr = expiryDate.replace(/-/g, "");
    const T = Date.now().toString().slice(-10);
    const userInfoParam = JSON.stringify({
      user_id: row.device_user_id,
      user_name: member_name || member_id,
      user_privilege: "normal",
      expire_date: expireStr,
      enroll_data_array: []
    });
    await db.execute(
      `INSERT INTO tbl_commands (trans_id, device_id, cmd_code, cmd_param, status) VALUES (?, ?, 'SET_USER_INFO', ?, 'WAIT')`,
      [`upd_${T}`, device_id, Buffer.from(userInfoParam)]
    );
    await db.execute(
      `UPDATE tbl_device_enrollments SET expiry_date=? WHERE device_id=? AND member_id=?`,
      [expiryDate, device_id, member_id]
    );

    res.json({ success: true, message: `${member_id} ki expiry device pe ${expiryDate} set ho rahi hai` });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post("/link", async (req, res) => {
  try {
    const { device_id, member_id, member_name, end_date, device_user_id, method } = req.body;
    if (!device_id || !member_id || !device_user_id) {
      return res.status(400).json({ error: "device_id, member_id, device_user_id required" });
    }
    const gymId = await getGymId(device_id);
    if (!gymId) return res.status(404).json({ error: "Device kisi gym se registered nahi hai" });

    const expiryDate = end_date ? new Date(end_date).toISOString().split("T")[0] : null;
    await db.execute(
      `INSERT INTO tbl_device_enrollments (device_id, device_user_id, member_id, member_name, gym_id, method, expiry_date)
       VALUES (?, ?, ?, ?, ?, ?, ?)
       ON DUPLICATE KEY UPDATE device_user_id=VALUES(device_user_id), method=VALUES(method), expiry_date=VALUES(expiry_date), member_name=VALUES(member_name)`,
      [device_id, device_user_id, member_id, member_name || member_id, gymId, method || "FACE", expiryDate]
    );
    res.json({ success: true, message: `${member_id} → device user "${device_user_id}" se link ho gaya` });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

module.exports = router;
