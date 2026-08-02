-- V2 — Dynamic QR support (Phase 2)
-- v2_people_sync mein QR tracking columns add karo. Additive migration —
-- existing rows/columns touch nahi hote.

USE gym_device_db;

ALTER TABLE v2_people_sync
  ADD COLUMN qr_code   VARCHAR(64) NULL AFTER expiration_unix,
  ADD COLUMN qr_window BIGINT      NULL AFTER qr_code;
