-- Gym Device Server — V2 Schema (A3-8396 / FC-8200H HTTPv2 protocol)
-- Isolated tables (v2_ prefix) — purani tbl_* tables se koi relation/touch nahi.
-- Phase 1 scope: sirf heartbeat + people add/delete sync.

USE gym_device_db;

CREATE TABLE IF NOT EXISTS v2_devices (
  device_sn   VARCHAR(40) PRIMARY KEY,
  gym_id      VARCHAR(64) NOT NULL,
  last_seen   DATETIME,
  created_at  DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS v2_people_sync (
  device_user_id      BIGINT AUTO_INCREMENT PRIMARY KEY,
  device_sn           VARCHAR(40) NOT NULL,
  gym_id              VARCHAR(64) NOT NULL,
  supabase_member_id  VARCHAR(64) NOT NULL,   -- members.id (uuid)
  member_display_id   VARCHAR(32),            -- members.member_id, e.g. BH-002
  name                VARCHAR(128),
  expiration_unix     BIGINT DEFAULT 0,
  status              ENUM('pending_add','sent_add_pending_ack','synced','pending_delete','sent_delete_pending_ack')
                        DEFAULT 'pending_add',
  last_error          VARCHAR(255),
  created_at          DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at          DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_device_member (device_sn, supabase_member_id)
);

CREATE INDEX idx_v2_people_status ON v2_people_sync(device_sn, status);
