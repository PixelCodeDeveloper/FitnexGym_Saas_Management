const express = require("express");
const router  = express.Router();
const db      = require("../db");
const { gymExists } = require("../v2/supabase");

// POST /api/v2/devices/register — SuperOwner ek A3-8396 device ko ek gym se
// link/reassign karta hai. gym_id explicitly zaroori hai (koi silent default nahi —
// production, multi-gym system hai).
// Body: { device_sn, gym_id }
router.post("/register", async (req, res) => {
  try {
    const { device_sn, gym_id } = req.body || {};
    if (!device_sn) return res.status(400).json({ error: "device_sn required" });
    if (!gym_id) return res.status(400).json({ error: "gym_id required — SuperOwner ko gym batana zaroori hai" });

    const gym = await gymExists(gym_id);
    if (!gym) return res.status(404).json({ error: "gym_id Supabase mein nahi mila" });

    const [[existing]] = await db.execute(
      `SELECT gym_id FROM v2_devices WHERE device_sn = ? LIMIT 1`,
      [device_sn]
    );
    const isReassignment = existing?.gym_id && existing.gym_id !== gym_id;

    if (isReassignment) {
      // Purane gym ke saare enrolled members ko device se hataane ke liye queue karo
      await db.execute(
        `UPDATE v2_people_sync SET status = 'pending_delete'
         WHERE device_sn = ? AND status IN ('synced','sent_add_pending_ack')`,
        [device_sn]
      );
      console.log(`[V2 API] Device "${device_sn}" reassigned ${existing.gym_id} → ${gym_id}, purane members delete queue ho gaye`);
    }

    await db.execute(
      `INSERT INTO v2_devices (device_sn, gym_id, last_seen) VALUES (?, ?, NOW())
       ON DUPLICATE KEY UPDATE gym_id = VALUES(gym_id)`,
      [device_sn, gym_id]
    );

    console.log(`[V2 API] Device "${device_sn}" registered → gym "${gym.gym_name}" (${gym_id})`);
    res.json({ success: true, device_sn, gym_id, gym_name: gym.gym_name, reassigned: !!isReassignment });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/v2/devices — sab registered v2 devices (gym assignment ke saath)
router.get("/", async (req, res) => {
  try {
    const [rows] = await db.execute(
      `SELECT device_sn, gym_id, last_seen,
        CASE WHEN last_seen > DATE_SUB(NOW(), INTERVAL 2 MINUTE) THEN 1 ELSE 0 END AS is_online
       FROM v2_devices ORDER BY last_seen DESC`
    );
    res.json({ devices: rows });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/v2/devices/:deviceSn/resync-cardnums — one-time migration utility.
// Device pe "existing user UPDATE/re-ADD" dono ke baad Face data reliably nahi
// tikta (verified — Fingerprint/Palm hamesha survive karte hain, Face nahi, chahe
// Update ho ya fresh delete+Add). Ye lagta hai device firmware ki apni limitation
// hai Face data ko DownloadPeopleList API se (re)inject karne mein.
//
// Isliye: jis bhi member ka Face enrolled hai, use resync se SKIP karo — unka
// data device pe jaise capture hua tha wahi locally rehne do, kabhi touch mat
// karo. Sirf non-Face (ya sirf Fingerprint/Palm) wale members hi resync honge.
router.post("/:deviceSn/resync-cardnums", async (req, res) => {
  try {
    const { deviceSn } = req.params;

    const [faceRows] = await db.execute(
      `SELECT e1.supabase_member_id
       FROM v2_enrollments e1
       INNER JOIN (
         SELECT supabase_member_id, MAX(id) AS max_id
         FROM v2_enrollments WHERE device_sn = ? AND supabase_member_id IS NOT NULL
         GROUP BY supabase_member_id
       ) latest ON e1.id = latest.max_id
       WHERE e1.has_face = 1`,
      [deviceSn]
    );
    const faceEnrolledIds = faceRows.map(r => r.supabase_member_id);

    const [candidates] = await db.execute(
      `SELECT id, supabase_member_id, member_display_id FROM v2_people_sync
       WHERE device_sn = ? AND status NOT IN ('pending_delete','sent_delete_pending_ack')`,
      [deviceSn]
    );

    const toSkip = candidates.filter(c => faceEnrolledIds.includes(c.supabase_member_id));
    const toResync = candidates.filter(c => !faceEnrolledIds.includes(c.supabase_member_id));

    for (const row of toResync) {
      await db.execute(`UPDATE v2_people_sync SET status = 'pending_delete' WHERE id = ?`, [row.id]);
    }

    console.log(
      `[V2 API] Resync (delete+re-add) → device "${deviceSn}": ${toResync.length} delete-queued, ` +
      `${toSkip.length} skipped (Face-enrolled: ${toSkip.map(s => s.member_display_id).join(", ") || "none"})`
    );
    res.json({
      success: true,
      deleteQueued: toResync.length,
      skippedFaceEnrolled: toSkip.map(s => s.member_display_id),
      note: "Delete complete hone ke baad agle heartbeat pe automatic fresh re-add hoga. Face-enrolled members skip kiye — unka data device pe local hi rehta hai.",
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
