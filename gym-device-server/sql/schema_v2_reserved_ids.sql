-- V2 — Device UserID 1-10 reserved for manual/local entries (device screen se
-- add kiye gaye users). App-driven sync ab sirf ID 11 se shuru hoga.
--
-- IMPORTANT: Isse chalane se PEHLE, agar koi existing v2_people_sync row already
-- ID 1-10 range mein hai, unhe pehle 'pending_delete' karke device se saaf karwao
-- (2 heartbeat cycles wait karo), TABHI ye ALTER chalao — warna device pe duplicate
-- ban jayenge (purana low-ID entry + naya 11+ wala entry, dono same insaan ke liye).

USE gym_device_db;

ALTER TABLE v2_people_sync AUTO_INCREMENT = 11;
