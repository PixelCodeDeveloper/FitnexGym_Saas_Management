const zlib = require("zlib");

// Device docs mein kai jagah field "text" ki tarah bheja jaata hai lekin kabhi
// gzip Content-Encoding ke saath bina filename ke "file part" ki tarah bhi aa sakta
// hai (vendor doc ki examples mein aisa dikhaya gaya hai) — dono cases handle karo.
function getField(req, name) {
  if (req.body && req.body[name] !== undefined) return req.body[name];

  const f = (req.files || []).find(file => file.fieldname === name);
  if (f) {
    let buf = f.buffer;
    if (buf && buf.length > 2 && buf[0] === 0x1f && buf[1] === 0x8b) {
      try { buf = zlib.gunzipSync(buf); } catch { /* not actually gzip, use as-is */ }
    }
    return buf ? buf.toString("utf8") : null;
  }
  return null;
}

module.exports = { getField };
