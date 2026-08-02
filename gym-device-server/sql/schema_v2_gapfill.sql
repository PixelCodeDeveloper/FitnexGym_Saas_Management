-- V2 — Gap-fill device_user_id assignment (purane device jaisa: delete hone
-- par khaali ID slot dobara reuse hota hai) + cross-device safety fix.
--
-- Ab tak device_user_id GLOBALLY unique tha (poore system mein, sab devices
-- milake) — matlab do alag devices kabhi bhi same number use nahi kar sakte the.
-- Isse ek chhupa hua bug tha: kai jagah code sirf `device_user_id` se row
-- update/delete karta tha (bina device_sn check kiye) — jab dusra device aata,
-- to ID clash hone par GALAT device ka row update ho sakta tha.
--
-- Fix: naya surrogate `id` column PRIMARY KEY banaya, `device_user_id` ab sirf
-- (device_sn, device_user_id) combination mein unique hai — har device ki apni
-- alag ID series hai (dono ki 11 se shuru ho sakti hai, koi conflict nahi).

USE gym_device_db;

ALTER TABLE v2_people_sync MODIFY device_user_id BIGINT NOT NULL;
ALTER TABLE v2_people_sync DROP PRIMARY KEY;
ALTER TABLE v2_people_sync ADD COLUMN id BIGINT AUTO_INCREMENT PRIMARY KEY FIRST;
ALTER TABLE v2_people_sync ADD UNIQUE KEY uq_device_userid (device_sn, device_user_id);
