const path = require("path");
// PM2 kabhi kabhi process ko alag cwd (e.g. /root) se start kar deta hai —
// isliye .env ka absolute path denа zaroori hai, warna dotenv silently kuch
// load nahi karta (DB_HOST, SUPABASE_URL, sab undefined ho jaate hain)
require("dotenv").config({ path: path.join(__dirname, "..", ".env") });
const http    = require("http");
const express = require("express");
const cors    = require("cors");

const handleReceiveCmd    = require("./handlers/receiveCmd");
const handleRealtimeGlog  = require("./handlers/realtimeGlog");
const handleRealtimeEnroll= require("./handlers/realtimeEnroll");
const handleSendCmdResult = require("./handlers/sendCmdResult");

const commandsRouter = require("./api/commands");
const usersRouter    = require("./api/users");
const logsRouter     = require("./api/logs");
const devicesRouter  = require("./api/devices");
const enrollRouter   = require("./api/enroll");
const membersRouter  = require("./api/members");
const qrRouter       = require("./api/qr");
const v2DevicesRouter = require("./api/v2devices");
const v2RemoteRouter  = require("./api/v2remote");
const v2EnrollRouter  = require("./api/v2enroll");

// V2 — naye A3-8396 device ka HTTPv2 protocol (isolated app, alag port, alag DB tables)
const v2Server = require("./v2/server");

const DEVICE_PORT = process.env.DEVICE_SERVER_PORT || 8080;
const ADMIN_PORT  = process.env.ADMIN_API_PORT     || 3000;
const V2_DEVICE_PORT = process.env.V2_DEVICE_PORT  || 8181;

// ─── 1. DEVICE SERVER (SDK Protocol) ─────────────────────────────────────────
// Device is server ko connect karta hai
const deviceServer = http.createServer(async (req, res) => {
  // Log every request from device
  console.log(`\n[RAW] ${req.method} ${req.url} from ${req.socket.remoteAddress}`);
  console.log(`[HDR] ${JSON.stringify(req.headers)}`);

  if (req.method !== "POST") {
    console.log(`[REJECT] Not a POST request`);
    res.writeHead(405); res.end(); return;
  }

  const headers    = req.headers;
  const tokenId    = process.env.DEVICE_TOKEN_ID;
  const requestCode= headers["request_code"];
  const devId      = headers["dev_id"];
  const transId    = headers["trans_id"] || "";
  const devModel   = headers["dev_model"] || null;

  // Token check
  if (tokenId && headers["token_id"] !== tokenId) {
    console.log(`[REJECT] Token mismatch — got: ${headers["token_id"]}, expected: ${tokenId}`);
    res.writeHead(403); res.end(); return;
  }

  if (!requestCode || !devId) {
    console.log(`[REJECT] Missing headers — request_code="${requestCode}" dev_id="${devId}"`);
    res.writeHead(400); res.end(); return;
  }

  // Body collect karo
  const chunks = [];
  req.on("data", c => chunks.push(c));
  req.on("end", async () => {
    const body = Buffer.concat(chunks);

    // Parse device info (receive_cmd ke liye)
    let devInfo = null;
    if (requestCode === "receive_cmd" && body.length > 0) {
      try {
        const jsonStr = devModel
          ? body.toString("utf8")
          : getStringFromBuffer(body);
        devInfo = JSON.parse(jsonStr);
      } catch {}
    }

    switch (requestCode) {
      case "receive_cmd":
        await handleReceiveCmd(req, res, devId, devInfo);
        break;
      case "send_cmd_result":
        await handleSendCmdResult(req, res, devId, transId, body);
        break;
      case "realtime_glog":
        await handleRealtimeGlog(req, res, devId, body, devModel);
        break;
      case "realtime_enroll_data":
        await handleRealtimeEnroll(req, res, devId, body, devModel);
        break;
      case "realtime_door_status": {
        const status = devModel
          ? JSON.parse(body.toString("utf8"))
          : JSON.parse(getStringFromBuffer(body));
        console.log(`[${devId}] DOOR STATUS → "${status.door_status}"`);
        res.setHeader("response_code", "OK");
        res.setHeader("Content-Length", "0");
        res.end();
        break;
      }
      default:
        res.setHeader("response_code", "ERROR_INVALID_REQUEST_CODE");
        res.setHeader("Content-Length", "0");
        res.end();
    }
  });
});

// ─── 2. ADMIN API SERVER (App se commands aate hain) ─────────────────────────
const adminApp = express();
adminApp.use(cors({ origin: "*", allowedHeaders: ["Content-Type", "x-api-key"] }));
adminApp.use(express.json());

// Health check only — no web UI
adminApp.get("/health", (req, res) => res.json({ status: "ok" }));

// Member-facing route — x-api-key middleware se PEHLE mount kiya hai jaanbujh kar.
// Ye Members app (public-facing) mein embed hota hai — usme admin key kabhi
// nahi honi chahiye (wo key member/device delete jaisa sab kuch kar sakti hai).
adminApp.use("/api/qr", qrRouter);

// API Key middleware (baaki sab /api routes ke liye — admin/gym-owner app hi use karega)
adminApp.use("/api", (req, res, next) => {
  const key = req.headers["x-api-key"];
  if (process.env.ADMIN_API_KEY && key !== process.env.ADMIN_API_KEY) {
    return res.status(401).json({ error: "Unauthorized" });
  }
  next();
});

adminApp.use("/api/commands", commandsRouter);
adminApp.use("/api/users",    usersRouter);
adminApp.use("/api/logs",     logsRouter);
adminApp.use("/api/devices",  devicesRouter);
adminApp.use("/api/enroll",   enrollRouter);
adminApp.use("/api/members",  membersRouter);
adminApp.use("/api/v2/devices", v2DevicesRouter);
adminApp.use("/api/v2/remote-command", v2RemoteRouter);
adminApp.use("/api/v2/enroll", v2EnrollRouter);

// Catch malformed HTTP from device
deviceServer.on("clientError", (err, socket) => {
  console.log(`[CLIENT_ERROR] ${err.message}`);
  socket.end("HTTP/1.1 400 Bad Request\r\n\r\n");
});

// ─── START ────────────────────────────────────────────────────────────────────
deviceServer.listen(DEVICE_PORT, "0.0.0.0", () => {
  console.log("════════════════════════════════════════");
  console.log(" Gym Device Server");
  console.log("════════════════════════════════════════");
  console.log(` Device Port : ${DEVICE_PORT}  ← Device isko connect kare`);
  console.log(` Admin Port  : ${ADMIN_PORT}   ← App API calls kare`);
  console.log(` DB          : ${process.env.DB_HOST}/${process.env.DB_NAME}`);
  console.log("════════════════════════════════════════");
});

adminApp.listen(ADMIN_PORT, "0.0.0.0", () => {
  console.log(` Admin API running on port ${ADMIN_PORT}`);
});

v2Server.start(V2_DEVICE_PORT);

function getStringFromBuffer(buf) {
  if (buf.length < 4) return "";
  const lenText = buf.readUInt32LE(0);
  if (lenText === 0 || lenText > buf.length - 4) return "";
  const lastByte = buf[4 + lenText - 1];
  return buf.slice(4, lastByte === 0 ? 4 + lenText - 1 : 4 + lenText).toString("utf8");
}
