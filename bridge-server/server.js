const http = require("http");

// ─── CONFIG ───────────────────────────────────────────────────────────────────
const CONFIG = {
  PORT: 8080,                          // Device isko connect karega
  CLOUDFLARE_WORKER_URL: "http://supabasegym.ro4373.workers.dev/",
  TOKEN_ID: "",                        // web.config ka token_id (khali chhodo agar nahi hai)
};
// ──────────────────────────────────────────────────────────────────────────────

// Device se aane wala BSComm binary buffer se JSON string nikalta hai
function getStringFromBSCommBuffer(buf) {
  if (buf.length < 4) return "";
  try {
    const lenText = buf.readUInt32LE(0);
    if (lenText === 0 || lenText > buf.length - 4) return "";
    const lastByte = buf[4 + lenText - 1];
    const str = buf.slice(4, lastByte === 0 ? 4 + lenText - 1 : 4 + lenText).toString("utf8");
    return str;
  } catch {
    return "";
  }
}

// HTTP response device ko bhejta hai
function sendResponse(res, responseCode, transId = "", cmdCode = "", bodyBuf = Buffer.alloc(0)) {
  res.setHeader("response_code", responseCode);
  res.setHeader("trans_id", transId);
  res.setHeader("cmd_code", cmdCode);
  res.setHeader("Content-Type", "application/octet-stream");
  res.setHeader("Content-Length", bodyBuf.length);
  res.writeHead(200);
  res.end(bodyBuf);
}

// Cloudflare Worker ko call karta hai (tumhara existing API)
async function callGymAPI(qrContent) {
  const body = JSON.stringify({
    qr_content: qrContent,
    scanner_gym_id: CONFIG.GYM_ID,
  });

  return new Promise((resolve) => {
    const url = new URL(CONFIG.CLOUDFLARE_WORKER_URL);
    const options = {
      hostname: url.hostname,
      port: url.port || 80,
      path: url.pathname,
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Content-Length": Buffer.byteLength(body),
      },
    };

    const req = http.request(options, (apiRes) => {
      let data = "";
      apiRes.on("data", (chunk) => (data += chunk));
      apiRes.on("end", () => {
        try {
          resolve({ status: apiRes.statusCode, body: JSON.parse(data) });
        } catch {
          resolve({ status: apiRes.statusCode, body: data });
        }
      });
    });

    req.on("error", (err) => {
      console.error("[API] Error:", err.message);
      resolve({ status: 500, body: null });
    });

    req.write(body);
    req.end();
  });
}

// Request body buffer mein collect karta hai
function collectBody(req) {
  return new Promise((resolve) => {
    const chunks = [];
    req.on("data", (chunk) => chunks.push(chunk));
    req.on("end", () => resolve(Buffer.concat(chunks)));
  });
}

// ─── MAIN SERVER ──────────────────────────────────────────────────────────────
const server = http.createServer(async (req, res) => {
  const headers = req.headers;

  // Token check (agar set hai toh)
  if (CONFIG.TOKEN_ID && headers["token_id"] !== CONFIG.TOKEN_ID) {
    res.writeHead(403);
    res.end();
    return;
  }

  const requestCode = headers["request_code"];
  const devId = headers["dev_id"];
  const transId = headers["trans_id"] || "";
  const devModel = headers["dev_model"] || null; // newer devices JSON bhejte hain

  if (!requestCode || !devId) {
    res.writeHead(400);
    res.end();
    return;
  }

  const bodyBuf = await collectBody(req);

  // ── 1. receive_cmd: Device poochta hai "koi command hai?" ──────────────────
  if (requestCode === "receive_cmd") {
    // Abhi koi pending command nahi hai
    console.log(`[${devId}] receive_cmd (device connected)`);
    sendResponse(res, "ERROR_NO_CMD", transId);
    return;
  }

  // ── 2. send_cmd_result: Device command ka result bhejta hai ────────────────
  if (requestCode === "send_cmd_result") {
    const returnCode = headers["cmd_return_code"] || "";
    console.log(`[${devId}] send_cmd_result: ${returnCode}`);
    sendResponse(res, "OK", transId);
    return;
  }

  // ── 3. realtime_glog: QR / Face scan event ─────────────────────────────────
  if (requestCode === "realtime_glog") {
    let jsonStr = "";

    if (devModel) {
      // Newer device model: plain UTF-8 JSON
      jsonStr = bodyBuf.toString("utf8");
    } else {
      // Purana BSComm binary format
      jsonStr = getStringFromBSCommBuffer(bodyBuf);
    }

    if (!jsonStr) {
      sendResponse(res, "ERROR_INVALID_DATA", transId);
      return;
    }

    let scanData;
    try {
      scanData = JSON.parse(jsonStr);
    } catch {
      sendResponse(res, "ERROR_INVALID_JSON", transId);
      return;
    }

    const userId = scanData["user_id"] || "";
    const ioTime = scanData["io_time"] || "";
    const verifyMode = scanData["verify_mode"] || "";

    console.log(`[${devId}] SCAN → user_id="${userId}" time="${ioTime}" mode="${verifyMode}"`);

    // Cloudflare Worker ko call karo (tumhara existing API)
    const apiResult = await callGymAPI(userId);

    if (apiResult.status === 200 && apiResult.body) {
      console.log(`[${devId}] GYM API → ACCESS GRANTED for "${userId}"`);
      // Gate open hone ka log
    } else {
      console.log(`[${devId}] GYM API → ACCESS DENIED for "${userId}" (status=${apiResult.status})`);
    }

    sendResponse(res, "OK", transId);
    return;
  }

  // ── 4. realtime_enroll_data: Naya user ka biometric data ───────────────────
  if (requestCode === "realtime_enroll_data") {
    let jsonStr = devModel
      ? bodyBuf.toString("utf8")
      : getStringFromBSCommBuffer(bodyBuf);

    let enrollData = {};
    try { enrollData = JSON.parse(jsonStr); } catch {}

    console.log(`[${devId}] ENROLL → user_id="${enrollData["user_id"] || "?"}"`);
    sendResponse(res, "OK", transId);
    return;
  }

  // ── 5. realtime_door_status: Door status update ────────────────────────────
  if (requestCode === "realtime_door_status") {
    let jsonStr = devModel
      ? bodyBuf.toString("utf8")
      : getStringFromBSCommBuffer(bodyBuf);

    let doorData = {};
    try { doorData = JSON.parse(jsonStr); } catch {}

    console.log(`[${devId}] DOOR STATUS → "${doorData["door_status"] || "?"}"`);
    sendResponse(res, "OK", transId);
    return;
  }

  // Unknown request
  console.warn(`[${devId}] Unknown request_code: "${requestCode}"`);
  sendResponse(res, "ERROR_INVALID_REQUEST_CODE", transId);
});

server.listen(CONFIG.PORT, "0.0.0.0", () => {
  console.log(`Bridge Server running on port ${CONFIG.PORT}`);
  console.log(`Cloudflare Worker: ${CONFIG.CLOUDFLARE_WORKER_URL}`);
  console.log(`Gym ID: ${CONFIG.GYM_ID}`);
  console.log("─────────────────────────────────────────");
  console.log("Device settings mein yahi IP:PORT dalo");
  console.log("─────────────────────────────────────────");
});
