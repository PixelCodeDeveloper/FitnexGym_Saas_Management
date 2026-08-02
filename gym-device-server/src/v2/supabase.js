const axios = require("axios");
require("dotenv").config();

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_KEY;

// Reference/test gym ID — sirf convenience ke liye (curl examples, manual testing).
// Ab ye kahin bhi silent fallback ki tarah use NAHI hota — har device ko
// SuperOwner ko explicitly ek gym se register karna hoga (POST /api/v2/devices/register).
const TEST_GYM_ID = process.env.V2_TEST_GYM_ID || "d18a6227-a175-4666-b7a0-894f888c9d9e";

const headers = {
  apikey: SUPABASE_KEY,
  Authorization: `Bearer ${SUPABASE_KEY}`,
  "Content-Type": "application/json",
};

// Diye gaye gym_id ke active, non-deleted members
async function getActiveMembers(gymId) {
  const res = await axios.get(
    `${SUPABASE_URL}/rest/v1/members?gym_id=eq.${gymId}&deleted_at=is.null&select=id,member_id,name,end_date,status`,
    { headers, timeout: 8000 }
  );
  return res.data || [];
}

// Device registration se pehle confirm karo ki gym_id sach mein exist karta hai
// (SuperOwner se typo/galat UUID aane se bachne ke liye)
async function gymExists(gymId) {
  const res = await axios.get(
    `${SUPABASE_URL}/rest/v1/gym_owners?id=eq.${gymId}&deleted_at=is.null&select=id,gym_name`,
    { headers, timeout: 5000 }
  );
  return res.data?.[0] || null;
}

// Attendance mark karo — duplicate-per-day guard ke saath (jaisa purane
// realtimeGlog handler mein hota tha)
async function markAttendance(memberUuid, gymId) {
  const today = new Date().toISOString().split("T")[0];
  const existing = await axios.get(
    `${SUPABASE_URL}/rest/v1/attendance?member_id=eq.${memberUuid}&gym_id=eq.${gymId}&date=eq.${today}&limit=1`,
    { headers, timeout: 5000 }
  );
  if (existing.data?.length > 0) return { skipped: true };

  await axios.post(
    `${SUPABASE_URL}/rest/v1/attendance`,
    { member_id: memberUuid, gym_id: gymId, date: today, check_in_time: new Date().toISOString(), status: "Present" },
    { headers, timeout: 5000 }
  );
  return { inserted: true };
}

module.exports = { getActiveMembers, markAttendance, gymExists, TEST_GYM_ID };
