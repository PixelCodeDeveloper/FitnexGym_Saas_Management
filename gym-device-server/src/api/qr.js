const express = require("express");
const router  = express.Router();
const axios   = require("axios");
require("dotenv").config();

const { computeQrToken } = require("../v2/qr");
const { generateEncryptedQr } = require("../v2/qrEncrypted");

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_KEY;

// Device company ke apne app jitna hi — 5 minute validity window har fresh QR ke liye
const QR_VALID_SECONDS = 5 * 60;

// GET /api/qr/:memberUuid — app isse call karke member ka CURRENT valid QR le.
// Ye ab device ke PROPRIETARY encrypted format mein hota hai (RC4 + CRC8 + packed
// expiry — reverse-engineer kiya company ke apne management app se, dekho
// v2/qrEncrypted.js). Member ka CardNum stable hai (kabhi nahi badalta), sirf QR
// image har baar fresh generate hoti hai (naya embedded expiry ke saath) — isliye
// security/anti-screenshot QR ke andar hi hai, alag se rotation-sync ki zaroorat nahi.
router.get("/:memberUuid", async (req, res) => {
  try {
    const memberUuid = req.params.memberUuid;

    const r = await axios.get(
      `${SUPABASE_URL}/rest/v1/members?id=eq.${memberUuid}&deleted_at=is.null&select=id,gym_id,status,end_date&limit=1`,
      {
        headers: {
          apikey: SUPABASE_KEY,
          Authorization: `Bearer ${SUPABASE_KEY}`,
        },
        timeout: 5000,
      }
    );

    const member = r.data?.[0];
    if (!member) return res.status(404).json({ error: "Member nahi mila" });
    if (member.status !== "Active") return res.status(403).json({ error: "Member active nahi hai" });
    if (new Date(member.end_date) < new Date()) return res.status(403).json({ error: "Subscription expired" });

    const cardNum = computeQrToken(member.id); // stable, device pe already CardNum se synced
    const expiry = new Date(Date.now() + QR_VALID_SECONDS * 1000);
    const qr = generateEncryptedQr(cardNum, expiry);

    res.json({ qr, validForSeconds: QR_VALID_SECONDS, cardNum });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
