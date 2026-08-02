const crypto = require("crypto");
require("dotenv").config();

// CardNum — ab PERMANENT/stable hai per member (kabhi rotate nahi hota, isliye
// device sync mein race-condition ka risk khatam ho gaya). Security ab yahan se
// nahi aati — actual anti-replay/anti-screenshot protection QR image ke andar
// encrypted expiry se aata hai (dekho qrEncrypted.js), jo har baar fresh generate
// hota hai jab member "Show QR" dabata hai.
const QR_SECRET = process.env.V2_QR_SECRET || "change-me-in-production-v2-qr-secret";

// Device ka "CardNum" field sirf DIGITS accept karta hai, aur company ke apne
// card-entry app mein practical limit ~10 digits nikla hai — isliye chhota rakha hai.
function computeQrToken(memberDisplayId) {
  const hmac = crypto
    .createHmac("sha256", QR_SECRET)
    .update(`${memberDisplayId}:cardnum`)
    .digest("hex")
    .slice(0, 8); // 8 hex chars = 32 bits → max 4294967295 (10 digits)
  return BigInt("0x" + hmac).toString();
}

module.exports = { computeQrToken };
