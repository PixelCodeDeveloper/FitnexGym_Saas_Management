# Gym Device Server — Installation Guide

> **Ye guide naye VPS par server fresh install karne ke liye hai.**
> Current production server: `168.144.125.102`
> Port 8080 = Biometric device (BSComm protocol)
> Port 3000 = Admin API (Flutter app calls)

---

## Architecture Overview

```
Hysson Device  ──(port 8080)──► VPS Node.js Server ──► MySQL (local)
                                        │
Flutter App ───(port 3000)────►         └──────────────► Supabase (cloud)
```

- **Device** — connects to port 8080, polls every ~60s for commands
- **Admin API** — port 3000, Flutter gym owner app calls this
- **MySQL** — local DB for commands queue, enrollment data, scan logs
- **Supabase** — cloud DB for members, attendance, subscriptions

---

## Step 1: VPS Requirements

Fresh Ubuntu/Debian VPS. Minimum 1 vCPU, 1GB RAM.

```bash
apt update && apt upgrade -y
apt install -y curl wget git ufw mysql-server
```

### Firewall setup

```bash
ufw allow 22/tcp      # SSH
ufw allow 8080/tcp    # Biometric device connects here
ufw allow 3000/tcp    # Flutter app calls here
ufw enable
```

---

## Step 2: Install Node.js (v18+)

```bash
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt install -y nodejs
node -v   # should show v18.x or higher
```

---

## Step 3: Install PM2 (process manager)

```bash
npm install -g pm2
pm2 startup   # copy-paste the command it shows and run it
```

---

## Step 4: MySQL Setup

### Secure MySQL

```bash
mysql_secure_installation
# Set root password, remove test DB, disallow remote root login
```

### Create DB and user

```bash
mysql -u root -p
```

```sql
CREATE DATABASE gym_device_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'gymuser'@'localhost' IDENTIFIED BY 'gym@1234';
GRANT ALL PRIVILEGES ON gym_device_db.* TO 'gymuser'@'localhost';
FLUSH PRIVILEGES;
EXIT;
```

### Create all tables

```bash
mysql -u gymuser -pgym@1234 gym_device_db
```

```sql
-- Device connection status
CREATE TABLE IF NOT EXISTS tbl_device_status (
  device_id     VARCHAR(24) PRIMARY KEY,
  gym_id        VARCHAR(64),
  device_name   VARCHAR(64),
  device_model  VARCHAR(32),
  firmware      VARCHAR(64),
  device_info   TEXT,
  last_seen     DATETIME,
  is_online     TINYINT(1) DEFAULT 0
);

-- Commands queue (Server → Device)
CREATE TABLE IF NOT EXISTS tbl_commands (
  id            BIGINT AUTO_INCREMENT PRIMARY KEY,
  trans_id      VARCHAR(32) UNIQUE,
  device_id     VARCHAR(24) NOT NULL,
  cmd_code      VARCHAR(32) NOT NULL,
  cmd_param     LONGBLOB,
  status        ENUM('WAIT','SENT','RESULT','CANCELLED') DEFAULT 'WAIT',
  return_code   VARCHAR(128),
  created_at    DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at    DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Enrollment mapping (member_id ↔ device_user_id)
CREATE TABLE IF NOT EXISTS tbl_device_enrollments (
  id              BIGINT AUTO_INCREMENT PRIMARY KEY,
  device_id       VARCHAR(24),
  device_user_id  VARCHAR(16),
  member_id       VARCHAR(32),
  member_name     VARCHAR(128),
  gym_id          VARCHAR(64),
  method          ENUM('FACE','PALM','FINGERPRINT','QR','PASSWORD') DEFAULT 'FINGERPRINT',
  expiry_date     DATE,
  enrolled_at     DATETIME DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uniq_device_member (device_id, member_id)
);

-- Biometric enroll data (raw binary from device)
CREATE TABLE IF NOT EXISTS tbl_enroll_data (
  id            BIGINT AUTO_INCREMENT PRIMARY KEY,
  device_id     VARCHAR(24),
  user_id       VARCHAR(64),
  method        ENUM('QR','FACE','FINGERPRINT','PALM'),
  enroll_data   LONGBLOB,
  enrolled_at   DATETIME DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uniq_device_user (device_id, user_id)
);

-- Real-time scan logs
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
CREATE INDEX idx_enrollments_device ON tbl_device_enrollments(device_id);

EXIT;
```

> **IMPORTANT:** `tbl_device_enrollments` mein `gym_id` column zaroori hai — schema.sql mein nahi tha, manually add kiya tha.
> `tbl_commands` ka status ENUM `'SENT'` bhi include karo (pehle `'RUN'` tha jo galat tha).

---

## Step 5: Deploy Server Code

```bash
mkdir -p /opt/gym-device-server
cd /opt/gym-device-server
```

Source code copy karo (local machine se VPS par):

```bash
# Local machine par — node_modules ke bina copy karo
rsync -av --exclude='node_modules' --exclude='.git' \
  /path/to/gym-device-server/ root@NEW_VPS_IP:/opt/gym-device-server/
```

Ya git se clone karo agar repo hai:

```bash
git clone <repo-url> /opt/gym-device-server
```

### Install dependencies

```bash
cd /opt/gym-device-server
npm install
```

---

## Step 6: Environment Variables (.env)

```bash
nano /opt/gym-device-server/.env
```

```env
# Server Ports
DEVICE_SERVER_PORT=8080
ADMIN_API_PORT=3000

# MySQL
DB_HOST=localhost
DB_PORT=3306
DB_USER=gymuser
DB_PASSWORD=gym@1234
DB_NAME=gym_device_db

# Supabase (apna URL aur key dalo)
SUPABASE_URL=https://YOUR_PROJECT.supabase.co
SUPABASE_SERVICE_KEY=eyJhbGci...YOUR_SERVICE_ROLE_KEY...

# Admin API key (Flutter app is key ko use karta hai)
ADMIN_API_KEY=gymadmin@secret

# Device token (optional — blank rahega to koi bhi device connect ho sakta hai)
DEVICE_TOKEN_ID=

# Test mode — production par ALWAYS false
LOCAL_TEST_MODE=false
```

> **SUPABASE_SERVICE_KEY** — Supabase dashboard → Settings → API → `service_role` key copy karo (anon nahi, service_role chahiye)

---

## Step 7: Start with PM2

```bash
cd /opt/gym-device-server
pm2 start src/server.js --name gym-device-server
pm2 save
pm2 logs gym-device-server   # live logs dekhne ke liye
```

### Useful PM2 commands

```bash
pm2 status                        # process status
pm2 restart gym-device-server     # restart
pm2 stop gym-device-server        # stop
pm2 logs gym-device-server --lines 100   # last 100 lines
pm2 monit                         # real-time monitor
```

---

## Step 8: Device Configuration

Hysson biometric device ke settings mein:

| Setting | Value |
|---------|-------|
| Server IP | `VPS_IP` (e.g. `168.144.125.102`) |
| Server Port | `8080` |
| Protocol | `BSComm` (HTTP POST) |
| Token ID | blank (agar DEVICE_TOKEN_ID .env mein blank hai) |

Device should automatically connect. Logs mein ye aana chahiye:
```
[receive_cmd] dev_id=02017FC65CA2901E
```

---

## Step 9: Link Device to Gym

Pehli baar device ko gym se link karna padega:

```bash
curl -X POST http://VPS_IP:3000/api/devices/register \
  -H "Content-Type: application/json" \
  -H "x-api-key: gymadmin@secret" \
  -d '{"device_id": "DEVICE_SERIAL_HERE", "gym_id": "SUPABASE_GYM_UUID_HERE"}'
```

Ya Flutter app ke admin panel se device register karo.

> Device serial ID device ke back par hota hai ya pehle `receive_cmd` log mein dikhai deta hai.

---

## Step 10: Flutter App Settings

Gym owner app → Settings → Device Server:
- **Server URL**: `http://VPS_IP:3000`
- **API Key**: `gymadmin@secret`

---

## Supabase Setup (agar fresh project hai)

### Required tables in Supabase:

```sql
-- Members
CREATE TABLE members (
  id         UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  member_id  TEXT,          -- e.g. "BH-001"
  name       TEXT,
  gym_id     UUID REFERENCES gyms(id),
  end_date   DATE,
  status     TEXT DEFAULT 'Active',
  deleted_at TIMESTAMPTZ
);

-- Attendance
CREATE TABLE attendance (
  id            UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  member_id     UUID REFERENCES members(id),
  gym_id        UUID,
  date          DATE,
  check_in_time TIMESTAMPTZ,
  status        TEXT DEFAULT 'Present'
);

-- Subscription plans
CREATE TABLE subscription_plans (
  id             UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  gym_id         UUID,
  name           TEXT,
  price          NUMERIC,
  duration_days  INT,          -- IMPORTANT: days mein store karo, months mein nahi
  duration_months INT
);
```

### Required RPC function (QR scan ke liye):

```sql
CREATE OR REPLACE FUNCTION verify_door_entrance(qr_content TEXT, scanner_gym_id UUID)
RETURNS JSON AS $$
DECLARE
  parts TEXT[];
  member_id_val TEXT;
  gym_id_val UUID;
  end_date_val DATE;
  time_window_val BIGINT;
  cur_window BIGINT;
  member_row RECORD;
BEGIN
  parts := string_to_array(qr_content, '|');
  IF array_length(parts, 1) < 4 THEN
    RETURN json_build_object('unlock', false, 'message', 'Invalid QR format');
  END IF;

  member_id_val  := parts[1];
  gym_id_val     := parts[2]::UUID;
  end_date_val   := parts[3]::DATE;
  time_window_val := parts[4]::BIGINT;
  cur_window     := FLOOR(EXTRACT(EPOCH FROM NOW()) / 300);

  IF ABS(time_window_val - cur_window) > 1 THEN
    RETURN json_build_object('unlock', false, 'message', 'QR expired');
  END IF;

  IF end_date_val < CURRENT_DATE THEN
    RETURN json_build_object('unlock', false, 'message', 'Subscription expired');
  END IF;

  IF gym_id_val != scanner_gym_id THEN
    RETURN json_build_object('unlock', false, 'message', 'Gym mismatch');
  END IF;

  SELECT * INTO member_row FROM members
  WHERE member_id = member_id_val AND gym_id = gym_id_val AND deleted_at IS NULL LIMIT 1;

  IF NOT FOUND THEN
    RETURN json_build_object('unlock', false, 'message', 'Member not found');
  END IF;

  RETURN json_build_object('unlock', true, 'member_id', member_row.id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

---

## API Reference

### Admin API (port 3000)

All requests need header: `x-api-key: gymadmin@secret`

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/devices/register` | Device ko gym se link karo |
| GET | `/api/devices` | Saare registered devices |
| GET | `/api/members/devices` | Gym ke devices (is_online ke saath) |
| GET | `/api/members?device_id=X` | Gym ke members + enrollment status |
| GET | `/api/enroll/members/:deviceId` | Enrolled members list |
| POST | `/api/enroll/start` | Enrollment shuru karo |
| DELETE | `/api/enroll/:deviceId/:memberId` | Member ko device se remove karo |
| PATCH | `/api/enroll/update-info` | Name/expiry device par update karo |
| PATCH | `/api/enroll/update-expiry` | Sirf expiry update karo (renewal pe) |
| POST | `/api/enroll/link` | Manually existing user ID link karo |
| GET | `/api/logs/scans?device_id=X` | Scan logs with member names |
| DELETE | `/api/members/:uuid?device_id=X` | Member delete (Supabase + device) |
| GET | `/health` | Health check |

---

## Key Behaviors (Important Notes)

### 1. Auto-restore on device restart
Device restart hone par (last_seen > 5 min gap), server automatically sare enrolled members ko device par wapas push karta hai (biometric data ke saath).

### 2. Expiry enforcement
- Enrollment ke waqt `expire_date` device par set hoti hai (YYYYMMDD format)
- Subscription renewal par `PATCH /api/enroll/update-expiry` call karo
- Device automatically EXPIRED scan ko DENY karta hai

### 3. Attendance deduplication
Ek member ka ek din mein sirf ek attendance log hota hai. Duplicate scan ignore ho jaata hai.

### 4. Multi-gym support
Koi bhi `gym_id` hardcode nahi hai. Device `tbl_device_status.gym_id` se auto-detect hota hai. Multiple gyms ek hi server par chal sakte hain.

### 5. Device user ID assignment
Enrollment par device_user_id 5 se shuru hota hai (1-4 reserved for admin). Gaps fill karta hai (koi delete ho to uska ID reuse karta hai).

### 6. Biometric method detection
`enroll_data_array[0].backup_number` se method detect karta hai:
- 0-9 → FINGERPRINT
- 12 → FACE
- 13-16 → PALM

---

## Troubleshooting

### Device connect nahi ho raha
```bash
pm2 logs gym-device-server
# Check karo [RAW] log aa raha hai ya nahi
# Firewall check karo: ufw status
# Port check: netstat -tlnp | grep 8080
```

### MySQL connection error
```bash
# Test karo
mysql -u gymuser -pgym@1234 gym_device_db -e "SELECT 1"
# .env file mein DB credentials check karo
```

### Supabase error
```bash
# .env mein SUPABASE_URL aur SUPABASE_SERVICE_KEY check karo
# service_role key chahiye, anon key nahi
curl https://YOUR_PROJECT.supabase.co/rest/v1/members \
  -H "apikey: YOUR_SERVICE_KEY" \
  -H "Authorization: Bearer YOUR_SERVICE_KEY"
```

### Commands execute nahi ho rahe
```bash
# tbl_commands check karo
mysql -u gymuser -pgym@1234 gym_device_db -e "SELECT trans_id, cmd_code, status FROM tbl_commands ORDER BY id DESC LIMIT 10;"
# status 'WAIT' hona chahiye — agar 'SENT' hai to device ne receive kiya
```

### Device online/offline wrong dikhna
- `last_seen` column `tbl_device_status` mein update ho raha hai?
- 2 minute gap = offline (server side calculation)
- Flutter: `['is_online'].toString() == '1'` se compare karo (type safety)

---

## File Structure

```
/opt/gym-device-server/
├── .env                      # credentials (git mein mat dalo)
├── package.json
├── src/
│   ├── server.js             # main entry point
│   ├── db.js                 # MySQL connection pool
│   ├── handlers/
│   │   ├── receiveCmd.js     # device polling + auto-restore
│   │   ├── sendCmdResult.js  # command response from device
│   │   ├── realtimeGlog.js   # scan events (QR/Face/FP/Palm)
│   │   └── realtimeEnroll.js # biometric enrollment data
│   └── api/
│       ├── devices.js        # /api/devices
│       ├── enroll.js         # /api/enroll
│       ├── members.js        # /api/members
│       ├── logs.js           # /api/logs
│       ├── commands.js       # /api/commands
│       └── users.js          # /api/users
└── sql/
    └── schema.sql            # base schema (enrollment table manually added)
```

---

## Checklist — New Server Setup

- [ ] Node.js v18+ installed
- [ ] PM2 installed and startup configured
- [ ] MySQL installed, `gym_device_db` created, `gymuser` created
- [ ] All tables created (especially `tbl_device_enrollments` with `gym_id` column)
- [ ] `/opt/gym-device-server` code deployed
- [ ] `.env` file configured (Supabase URL + service key)
- [ ] `npm install` done
- [ ] `pm2 start` done, `pm2 save` done
- [ ] Firewall: ports 22, 8080, 3000 open
- [ ] Device IP/port updated to new VPS
- [ ] Device registered to gym via `/api/devices/register`
- [ ] Flutter app Settings updated with new server URL
- [ ] Test: device connects (check pm2 logs)
- [ ] Test: enrollment works
- [ ] Test: scan → attendance in member app

---

*Current device serial: `02017FC65CA2901E`*
*Current Supabase project: `crikbwuzdplcwogelgvb`*
*Test gym ID: `d18a6227-a175-4666-b7a0-894f888c9d9e` (NEVER touch real gym `a314a735-4a8f-487c-bdf6-8dcc538b0fe7`)*
