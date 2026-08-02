-- V2 — Phase 3: enrollment push-back, scan/system records, remote commands
-- Sab naye/isolated tables — purani tbl_* ya v2_devices/v2_people_sync ka structure
-- change nahi hota, sirf new tables add ho rahe hain.

USE gym_device_db;

-- Device se aayi enrollment info (face/fingerprint/palm template push-back)
CREATE TABLE IF NOT EXISTS v2_enrollments (
  id                  BIGINT AUTO_INCREMENT PRIMARY KEY,
  device_sn           VARCHAR(40) NOT NULL,
  device_user_id      BIGINT,
  supabase_member_id  VARCHAR(64),
  member_display_id   VARCHAR(32),
  push_type           TINYINT,            -- 1 Add, 2 Update, 3 Delete, 4 Query
  has_face            TINYINT DEFAULT 0,
  has_fingerprint     TINYINT DEFAULT 0,
  has_palmvein        TINYINT DEFAULT 0,
  photo_path          VARCHAR(255),
  raw_detail          LONGTEXT,
  created_at          DATETIME DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_v2_enroll_member ON v2_enrollments(supabase_member_id);

-- Har QR/Face/FP/Palm scan record (gate open/deny event) device se aata hai
CREATE TABLE IF NOT EXISTS v2_scan_logs (
  id                  BIGINT AUTO_INCREMENT PRIMARY KEY,
  device_sn           VARCHAR(40) NOT NULL,
  record_id           BIGINT,
  device_user_id      VARCHAR(32),
  supabase_member_id  VARCHAR(64),
  member_display_id   VARCHAR(32),
  record_type         INT,
  method_label        VARCHAR(32),
  access_result       ENUM('GRANTED','DENIED') DEFAULT 'DENIED',
  is_entry             TINYINT,
  body_temp           INT,
  io_time             DATETIME,
  photo_path          VARCHAR(255),
  raw_detail          LONGTEXT,
  created_at          DATETIME DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_v2_scan_device ON v2_scan_logs(device_sn, io_time);
CREATE INDEX idx_v2_scan_member ON v2_scan_logs(supabase_member_id);

-- Door sensor / system events (fire alarm, tamper, power on, etc.)
CREATE TABLE IF NOT EXISTS v2_system_logs (
  id                  BIGINT AUTO_INCREMENT PRIMARY KEY,
  device_sn           VARCHAR(40) NOT NULL,
  record_id           BIGINT,
  category            TINYINT,     -- 1 Door Sensor Record, 2 System Record
  sub_type            INT,
  record_date         DATETIME,
  created_at          DATETIME DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_v2_system_device ON v2_system_logs(device_sn, record_date);

-- Server → Device remote command queue (manual gate open, restart, etc.)
CREATE TABLE IF NOT EXISTS v2_remote_commands (
  id            BIGINT AUTO_INCREMENT PRIMARY KEY,
  device_sn     VARCHAR(40) NOT NULL,
  command_type  ENUM('opendoor','closedoor','keepopen','lockdoor','unlockdoor',
                      'restart','recover','closealarm','repostrecord',
                      'pushallpeople','clearrecord') NOT NULL,
  status        ENUM('pending','delivered') DEFAULT 'pending',
  created_at    DATETIME DEFAULT CURRENT_TIMESTAMP,
  delivered_at  DATETIME
);
CREATE INDEX idx_v2_remote_device ON v2_remote_commands(device_sn, status);
