// A3-8396 device ka PROPRIETARY encrypted QR format — reverse-engineer kiya gaya
// company ke apne management app (3_base.apk) se. Device camera se QR scan karte
// waqt ISI format ko expect karta hai — plain number wala QR wo local-store
// (CardNum field) se to match karta hai, lekin scan-time QR decode isi encryption
// scheme se hota hai. Isliye member-app ka QR ab isi format mein banega.
//
// Format: "2E" + RC4(cardNumber(9 bytes) + packedExpiry(4 bytes), SECRET_KEY) + CRC8(same 13 bytes)
// Sab hex, uppercase, total 30 characters.

const RC4_KEY_HEX = "3165333062336563306636333438373439353665323736323764666332633436";
const IST_OFFSET_MIN = 5 * 60 + 30; // Asia/Kolkata, UTC+5:30 — device isi timezone mein chalta hai

function hexToBytes(hex) {
  if (hex.length % 2 === 1) hex = "0" + hex;
  const bytes = [];
  for (let i = 0; i < hex.length; i += 2) bytes.push(parseInt(hex.substr(i, 2), 16));
  return bytes;
}

function bytesToHex(bytes) {
  return bytes.map(b => b.toString(16).padStart(2, "0")).join("");
}

function rc4(dataBytes, keyBytes) {
  const S = new Array(256);
  for (let i = 0; i < 256; i++) S[i] = i;
  let j = 0;
  for (let i = 0; i < 256; i++) {
    j = (j + S[i] + keyBytes[i % keyBytes.length]) % 256;
    [S[i], S[j]] = [S[j], S[i]];
  }
  let i = 0;
  j = 0;
  const out = new Array(dataBytes.length);
  for (let k = 0; k < dataBytes.length; k++) {
    i = (i + 1) % 256;
    j = (j + S[i]) % 256;
    [S[i], S[j]] = [S[j], S[i]];
    out[k] = S[(S[i] + S[j]) % 256] ^ dataBytes[k];
  }
  return out;
}

// CRC-8/MAXIM-DOW (poly 0x8C reflected, init 0x00) — company ke app mein bhi yehi hai
function crc8(bytes) {
  let t = 0;
  for (const b of bytes) {
    t ^= b;
    t &= 0xff;
    for (let bit = 0; bit < 8; bit++) {
      if (t & 1) {
        t = (t >> 1) ^ 0x8c;
        t &= 0xff;
      } else t >>= 1;
    }
  }
  return t & 0xff;
}

// IST ke hisaab se date components nikalo — VPS ka system timezone chahe kuch bhi ho,
// device hamesha IST mein sochta hai
function istComponents(date) {
  const istMs = date.getTime() + IST_OFFSET_MIN * 60 * 1000;
  const ist = new Date(istMs);
  return {
    year: ist.getUTCFullYear(),
    month: ist.getUTCMonth() + 1,
    day: ist.getUTCDate(),
    hours: ist.getUTCHours(),
    minutes: ist.getUTCMinutes(),
    seconds: ist.getUTCSeconds(),
  };
}

function packTimestamp(date) {
  const { year, month, day, hours, minutes, seconds } = istComponents(date);
  const bin =
    seconds.toString(2).padStart(6, "0") +
    minutes.toString(2).padStart(6, "0") +
    hours.toString(2).padStart(5, "0") +
    day.toString(2).padStart(5, "0") +
    month.toString(2).padStart(4, "0") +
    (year - 2018).toString(2).padStart(6, "0");
  const d = parseInt(bin, 2);
  let hex = d.toString(16);
  const bytes = hexToBytes(hex);
  while (bytes.length < 4) bytes.unshift(0);
  return bytes;
}

function cardNumberToBytes(cardNumStr, minBytes) {
  let hex = BigInt(cardNumStr).toString(16);
  const bytes = hexToBytes(hex);
  while (bytes.length < minBytes) bytes.unshift(0);
  return bytes;
}

// cardNumStr: stable numeric CardNum (jo device pe already CardNum field se synced hai)
// expiryDate: JS Date — kitni der ye QR valid rahega (device isko decrypt karke khud check karega)
function generateEncryptedQr(cardNumStr, expiryDate) {
  const cardBytes = cardNumberToBytes(cardNumStr, 9);
  const timeBytes = packTimestamp(expiryDate);
  const combined = [...cardBytes, ...timeBytes]; // 13 bytes
  const checksum = crc8(combined);
  const keyBytes = hexToBytes(RC4_KEY_HEX);
  const encrypted = rc4(combined, keyBytes);
  return ("2E" + bytesToHex(encrypted) + checksum.toString(16).padStart(2, "0")).toUpperCase();
}

module.exports = { generateEncryptedQr };
