-- Gym Device Server — MySQL Schema

CREATE DATABASE IF NOT EXISTS gym_device_db;
USE gym_device_db;

-- Device connection status
CREATE TABLE IF NOT EXISTS tbl_device_status (
  device_id     VARCHAR(24) PRIMARY KEY,
  device_name   VARCHAR(64),
  device_model  VARCHAR(32),
  firmware      VARCHAR(64),
  device_info   TEXT,
  last_seen     DATETIME,
  is_online     TINYINT(1) DEFAULT 0
);

-- Commands queue (Server → Device)
CREATE TABLE IF NOT EXISTS tbl_commands (
  trans_id      VARCHAR(16) PRIMARY KEY,
  device_id     VARCHAR(24) NOT NULL,
  cmd_code      VARCHAR(32) NOT NULL,
  cmd_param     LONGBLOB,
  status        ENUM('WAIT','RUN','RESULT','CANCELLED') DEFAULT 'WAIT',
  return_code   VARCHAR(128),
  created_at    DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at    DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Real-time scan logs (Device → Server)
CREATE TABLE IF NOT EXISTS tbl_scan_logs (
  id            BIGINT AUTO_INCREMENT PRIMARY KEY,
  device_id     VARCHAR(24),
  user_id       VARCHAR(64),
  verify_mode   VARCHAR(32),
  io_mode       VARCHAR(32),
  io_time       DATETIME,
  work_code     VARCHAR(16) DEFAULT '0',
  log_image     LONGBLOB,
  access_result ENUM('GRANTED','DENIED','EXPIRED') DEFAULT 'DENIED',
  created_at    DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Enrollment data (Device → Server)
CREATE TABLE IF NOT EXISTS tbl_enroll_data (
  id            BIGINT AUTO_INCREMENT PRIMARY KEY,
  device_id     VARCHAR(24),
  user_id       VARCHAR(64),
  method        ENUM('QR','FACE','FINGERPRINT','PALM'),
  enroll_data   LONGBLOB,
  enrolled_at   DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Door status log
CREATE TABLE IF NOT EXISTS tbl_door_status (
  id            BIGINT AUTO_INCREMENT PRIMARY KEY,
  device_id     VARCHAR(24),
  door_status   VARCHAR(32),
  created_at    DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX idx_commands_device ON tbl_commands(device_id, status);
CREATE INDEX idx_scan_logs_device ON tbl_scan_logs(device_id, io_time);
CREATE INDEX idx_enroll_user ON tbl_enroll_data(user_id, method);
