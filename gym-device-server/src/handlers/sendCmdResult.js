const db = require("../db");

// Device command execute karke result bhejta hai
async function handleSendCmdResult(req, res, devId, transId, body) {
  try {
    const returnCode = req.headers["cmd_return_code"] || "";

    await db.execute(
      `UPDATE tbl_commands SET status='RESULT', return_code=?, cmd_result=?, updated_at=NOW()
       WHERE trans_id=? AND device_id=?`,
      [returnCode, body.length > 0 ? body : null, transId, devId]
    );

    // Log user info if it's a GET_USER_INFO result
    if (body.length > 0) {
      try {
        const jsonStr = body.slice(4, body.readUInt32LE(0) + 4).toString("utf8").replace(/\0/g, "");
        const parsed  = JSON.parse(jsonStr);
        if (parsed.user_name) {
          console.log(`[${devId}] USER INFO → id="${parsed.user_id}" name="${parsed.user_name}" privilege="${parsed.user_privilege}"`);
        }
      } catch {}
    }

    console.log(`[${devId}] CMD RESULT → trans="${transId}" code="${returnCode}" bodyLen=${body.length}`);

    res.setHeader("response_code", "OK");
    res.setHeader("trans_id", transId);
    res.setHeader("Content-Type", "application/octet-stream");
    res.setHeader("Content-Length", "0");
    res.end();
  } catch (err) {
    console.error(`[${devId}] sendCmdResult error:`, err.message);
    res.setHeader("response_code", "ERROR");
    res.setHeader("Content-Length", "0");
    res.end();
  }
}

module.exports = handleSendCmdResult;
