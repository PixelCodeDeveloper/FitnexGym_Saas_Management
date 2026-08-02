const db = require("../db");

const OFFLINE_THRESHOLD_MS = 5 * 60 * 1000; // 5 minutes

// Device har 60 sec mein ping karta hai — pending command hai to do
async function handleReceiveCmd(req, res, devId, devInfo) {
  try {
    // Pehle last_seen check karo — reconnect detect karne ke liye
    const [[prevRow]] = await db.execute(
      `SELECT last_seen FROM tbl_device_status WHERE device_id=? LIMIT 1`,
      [devId]
    );
    const wasOffline = !prevRow || !prevRow.last_seen ||
      (Date.now() - new Date(prevRow.last_seen).getTime()) > OFFLINE_THRESHOLD_MS;

    // Device status update karo
    await db.execute(
      `INSERT INTO tbl_device_status (device_id, device_name, device_model, firmware, device_info, last_seen, is_online)
       VALUES (?, ?, ?, ?, ?, NOW(), 1)
       ON DUPLICATE KEY UPDATE
         device_name=VALUES(device_name), device_model=VALUES(device_model),
         firmware=VALUES(firmware), device_info=VALUES(device_info),
         last_seen=NOW(), is_online=1`,
      [
        devId,
        devInfo?.fk_name || "",
        req.headers["dev_model"] || "",
        devInfo?.fk_info?.firmware || "",
        JSON.stringify(devInfo?.fk_info || {}),
      ]
    );

    // Auto-restore: device reconnect ke baad enrolled members push karo
    if (wasOffline) {
      await autoRestoreEnrollments(devId);
    }

    // Pending command check karo
    const [rows] = await db.execute(
      `SELECT trans_id, cmd_code, cmd_param FROM tbl_commands
       WHERE device_id = ? AND status = 'WAIT'
       ORDER BY id ASC LIMIT 1`,
      [devId]
    );

    if (rows.length === 0) {
      res.setHeader("response_code", "ERROR_NO_CMD");
      res.setHeader("trans_id", "");
      res.setHeader("cmd_code", "");
      res.setHeader("Content-Type", "application/octet-stream");
      res.setHeader("Content-Length", "0");
      res.end();
      return;
    }

    const cmd = rows[0];

    await db.execute(
      `UPDATE tbl_commands SET status='SENT', updated_at=NOW() WHERE trans_id=?`,
      [cmd.trans_id]
    );

    // SET_TIME: server time inject karo
    let rawParamBuf = cmd.cmd_param || Buffer.alloc(0);
    if (cmd.cmd_code === "SET_TIME") {
      const now = new Date();
      const timeStr = now.getFullYear().toString() +
        String(now.getMonth() + 1).padStart(2, "0") +
        String(now.getDate()).padStart(2, "0") +
        String(now.getHours()).padStart(2, "0") +
        String(now.getMinutes()).padStart(2, "0") +
        String(now.getSeconds()).padStart(2, "0");
      rawParamBuf = Buffer.from(JSON.stringify({ time: timeStr }), "utf8");
    }

    // BSComm device (no dev_model header): wrap params as [4-byte LE len][JSON]\0
    const isBSComm = !req.headers["dev_model"];
    let cmdParam = rawParamBuf;
    if (isBSComm && rawParamBuf.length > 0) {
      const potentialLen = rawParamBuf.readUInt32LE(0);
      const alreadyWrapped = potentialLen > 0 && potentialLen <= rawParamBuf.length - 4;
      if (!alreadyWrapped) {
        const jsonLen = rawParamBuf.length + 1;
        const hdr = Buffer.alloc(4);
        hdr.writeUInt32LE(jsonLen, 0);
        cmdParam = Buffer.concat([hdr, rawParamBuf, Buffer.alloc(1)]);
      }
    }

    res.setHeader("response_code", "OK");
    res.setHeader("trans_id", cmd.trans_id);
    res.setHeader("cmd_code", cmd.cmd_code);
    res.setHeader("Content-Type", "application/octet-stream");
    res.setHeader("Content-Length", cmdParam.length);
    res.end(cmdParam);

    console.log(`[${devId}] → Command sent: ${cmd.cmd_code} (trans: ${cmd.trans_id})`);
  } catch (err) {
    console.error(`[${devId}] receiveCmd error:`, err.message);
    res.setHeader("response_code", "ERROR");
    res.setHeader("Content-Length", "0");
    res.end();
  }
}

// Device restart/reconnect pe enrolled members wapas push karo
async function autoRestoreEnrollments(devId) {
  try {
    const [enrollments] = await db.execute(
      `SELECT e.device_user_id, e.member_id, e.member_name, e.expiry_date,
              d.enroll_data
       FROM tbl_device_enrollments e
       LEFT JOIN tbl_enroll_data d ON d.device_id=e.device_id AND d.user_id=e.device_user_id
       WHERE e.device_id=?`,
      [devId]
    );

    if (enrollments.length === 0) return;

    console.log(`[${devId}] Device reconnected — restoring ${enrollments.length} enrolled members`);

    for (const enroll of enrollments) {
      const T = Date.now().toString().slice(-10) + Math.floor(Math.random() * 1000);
      const expireStr = enroll.expiry_date
        ? enroll.expiry_date.toString().split("T")[0].replace(/-/g, "")
        : "";

      // Biometric enroll data available hai to include karo
      let enrollDataArray = [];
      if (enroll.enroll_data) {
        try {
          const raw = Buffer.isBuffer(enroll.enroll_data)
            ? enroll.enroll_data
            : Buffer.from(enroll.enroll_data);
          // BSComm buffer se JSON extract karo
          if (raw.length > 4) {
            const lenText = raw.readUInt32LE(0);
            if (lenText > 0 && lenText <= raw.length - 4) {
              const jsonStr = raw.slice(4, 4 + lenText).toString("utf8").replace(/\0+$/, "");
              const parsed = JSON.parse(jsonStr);
              if (parsed.enroll_data_array) enrollDataArray = parsed.enroll_data_array;
            }
          }
        } catch (_) {}
      }

      const userInfoParam = JSON.stringify({
        user_id: enroll.device_user_id,
        user_name: enroll.member_name || enroll.member_id,
        user_privilege: "normal",
        expire_date: expireStr,
        enroll_data_array: enrollDataArray,
      });

      await db.execute(
        `INSERT IGNORE INTO tbl_commands (trans_id, device_id, cmd_code, cmd_param, status)
         VALUES (?, ?, 'SET_USER_INFO', ?, 'WAIT')`,
        [`rst_${T}`, devId, Buffer.from(userInfoParam)]
      );
    }
  } catch (err) {
    console.error(`[${devId}] autoRestore error:`, err.message);
  }
}

module.exports = handleReceiveCmd;
