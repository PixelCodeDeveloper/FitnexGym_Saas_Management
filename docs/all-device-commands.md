# Device Commands — Full SDK Reference
## SDK ke dono apps (fkwebserver_src + ControlFK) ka complete analysis

---

## Architecture — Pehle Ye Samajhna Zaroori Hai

### Device ← → Server Communication (2 Channels)

```
CHANNEL 1: Device 60 sec me poll kare (receive_cmd)
─────────────────────────────────────────────────────
Device → HTTP POST → Server (request_code: receive_cmd)
Device body mein:
{
  "fk_name": "GymA-MainGate",
  "fk_time": "20241215143022",
  "fk_info": {
    "supported_enroll_data": ["FP","PASSWORD","IDCARD","FACE","PALMVEIN"],
    "fk_bin_data_lib":       "FKDataHS101",
    "firmware":              "FK725HS001",
    "firmware_filename":     "FK725HS001",
    "fp_data_ver":           100,
    "face_data_ver":         100,
    "pv_data_ver":           100
  }
}

Server → Response headers mein command deta hai:
  response_code: OK / ERROR_NO_CMD / RESET_FK
  trans_id:      "1234567890"
  cmd_code:      "SET_USER_INFO"
  Content body:  BSComm format mein command parameters
─────────────────────────────────────────────────────

CHANNEL 2: Scan/Event hone pe device seedha push kare
─────────────────────────────────────────────────────
Device → HTTP POST → Server (request_code: realtime_glog)
Device body mein: user_id, verify_mode, io_mode, io_time...

Server → Response: response_code: OK
─────────────────────────────────────────────────────
```

### HTTP Request Headers (Device → Server, har request mein)
| Header | Matlab |
|---|---|
| `request_code` | Kya bhej raha hai (receive_cmd / realtime_glog etc.) |
| `dev_id` | Device ka unique ID |
| `dev_model` | Naye devices mein hota hai (purane mein nahi) |
| `token_id` | Auth token — `.env` mein `DEVICE_TOKEN_ID` se match karna chahiye |
| `blk_no` | Large data transfer mein block number (1,2,3... phir 0=last) |

### Special Response Codes (Server → Device)
| Response | Matlab |
|---|---|
| `OK` | Command di ya accept ki |
| `ERROR_NO_CMD` | Koi command queue mein nahi |
| `RESET_FK` | Factory reset karo — sirf emergency |
| `ERROR_DB_CONNECT` | Server ka DB connected nahi |
| `ERROR_CANCELED` | Command cancel ho gayi |

---

## BSComm Binary Protocol (Important!)

**Purane devices** (dev_model header absent) BSComm binary format mein data bhejte hain:

```
[ 4 bytes: JSON length (LE) ] [ JSON UTF-8 string ] [ \0 null byte ]
[ 4 bytes: binary1 length ] [ binary1 data ]
[ 4 bytes: binary2 length ] [ binary2 data ] ...
```

**Naye devices** (`dev_model` header present) ke liye: sirf plain JSON UTF-8.

### fk_bin_data_lib — Device Model Detection
`realtime_glog` aur `receive_cmd` mein aata hai — server ko batata hai kaunsi decode library use karo:

| Library | Device Type |
|---|---|
| `FKDataHS100` | Sabse purana model — Integer UserID, 12-byte struct |
| `FKDataHS101` | Purana model — Integer UserID, 12-byte struct |
| `FKDataHS102` | String UserID (16 chars), 32-byte GLog, 40-byte SLog |
| `FKDataHS103` | String UserID (32 chars), 48-byte GLog (larger struct) |
| `FKDataHS104` | Integer UserID, 12-byte struct with workcode |
| `FKDataHS105` | Integer UserID, 20-byte struct |
| `FKDataHS200` | 12-byte struct, 5-bit InOut + BackupNumber embedded |

### Large Data Block Transfer
5KB se bada data ho (jaise biometric templates ya firmware) to device blocks mein bhejta hai:
```
Request 1: blk_no=1 → data chunk 1
Request 2: blk_no=2 → data chunk 2
...
Request N: blk_no=0 → LAST chunk (0 = done)
```
Server sab blocks combine karta hai memory mein.

---

## COMMANDS (Server → Device)

Commands device ki command queue mein jaati hain. Device 60-second poll pe command le jaata hai (`receive_cmd`). Command complete hone pe `send_cmd_result` event bhejta hai.

---

### 1. SET_USER_INFO

**Kaam:** User ko device pe register karo — naam, ID, privilege, biometric sab ek saath.

```json
{
  "user_id":        "abc123",
  "user_name":      "Rahul Sharma",
  "user_privilege": "USER",
  "user_vid":       "VID001",
  "user_photo":     "BIN_1",
  "enroll_data_array": [
    { "backup_number": 0,  "enroll_data": "BIN_2" },
    { "backup_number": 12, "enroll_data": "BIN_3" },
    { "backup_number": 13, "enroll_data": "BIN_4" },
    { "backup_number": 10, "enroll_data": "BIN_5" },
    { "backup_number": 11, "enroll_data": "BIN_6" }
  ]
}
```

#### Fields:
| Field | Required? | Matlab |
|---|---|---|
| `user_id` | Yes | Device pe store hone wali unique ID (string) |
| `user_name` | Yes | Display naam |
| `user_privilege` | Yes | Role (table neeche) |
| `user_vid` | Optional | Virtual ID — alternate identifier; khali ho to `" "` (ek space) |
| `user_photo` | Optional | Member ki photo → `"BIN_N"` pointer; actual image BSComm binary mein attach |
| `enroll_data_array` | Optional | Biometric data list (neeche) |

#### `user_privilege` Values:
| Value | Role | Gym use? |
|---|---|---|
| `USER` ya `0` | Normal member, sirf entry | ✅ Hamesha ye |
| `MANAGER` ya `1` | Device settings badal sakta hai | ❌ |
| `OPERATOR` ya `2` | Logs dekh sakta hai | ❌ |
| `REGISTOR` ya `3` | Enrollment kar sakta hai | ❌ |

#### `enroll_data_array` — Backup Numbers (Complete Table):
| `backup_number` | Type | Format |
|---|---|---|
| 0 | Fingerprint — Finger 1 | Binary template |
| 1 | Fingerprint — Finger 2 | Binary template |
| 2 | Fingerprint — Finger 3 | Binary template |
| 3 | Fingerprint — Finger 4 | Binary template |
| 4 | Fingerprint — Finger 5 | Binary template |
| 5 | Fingerprint — Finger 6 | Binary template |
| 6 | Fingerprint — Finger 7 | Binary template |
| 7 | Fingerprint — Finger 8 | Binary template |
| 8 | Fingerprint — Finger 9 | Binary template |
| 9 | Fingerprint — Finger 10 | Binary template |
| 10 | Password / PIN | BSComm string format |
| 11 | Card Number / QR | Plain text string |
| 12 | Face | Binary template |
| 13 | Palm Vein — Haath 1 | Binary template |
| 14 | Palm Vein — Haath 2 | Binary template |
| 15 | Palm Vein — Haath 3 | Binary (kuch devices pe 4 palm) |
| 16 | Palm Vein — Haath 4 | Binary (kuch devices pe) |
| 20 | Finger Vein | Binary template |
| 30 | Enrollment Photo | JPEG image binary |

> **`enroll_data` = `"BIN_1"`, `"BIN_2"` etc.** — ye BSComm binary attachment ke pointers hain. Number = kaunse binary slot mein actual data hai.

#### Biometric Version Compatibility:
Server ko pata hona chahiye device ka `fp_data_ver`, `face_data_ver`, `pv_data_ver` (receive_cmd body mein aata hai). Agar server ke paas different version ka data hai to conversion karni pad sakti hai.

---

### 2. DELETE_USER

**Kaam:** User + uska sara biometric data device se permanently delete karo.

```json
{
  "user_id": "abc123"
}
```

#### Firmware kya karta hai:
- Fingerprint, face, palm, vein, PIN, card — sab wipe
- User list se bhi remove
- Ab is ID ka koi match nahi hoga

#### Gym use:
- Subscription expire → DELETE_USER queue karo
- Member permanently remove karna ho

---

### 3. GET_USER_INFO

**Kaam:** Device pe registered kisi user ki poori info lo.

```json
{
  "user_id": "abc123"
}
```

#### Device ka Response:
```json
{
  "user_id":        "abc123",
  "user_name":      "Rahul Sharma",
  "user_privilege": "USER",
  "user_vid":       "VID001",
  "user_photo":     "BIN_1",
  "enroll_data_array": [
    { "backup_number": 12, "enroll_data": "BIN_2" }
  ]
}
```

---

### 4. GET_USER_ID_LIST

**Kaam:** Device pe registered sare users ki ID list lo.

**Parameters:** Koi nahi (null ya `{}`)

#### Device ka Response:
```json
{
  "user_id_list": ["abc123", "xyz456", "def789"]
}
```

---

### 5. GET_ALL_USER_INFO

**Kaam:** Sare registered users ki poori info ek saath lo.

**Parameters:** Koi nahi

#### Gym use:
- Full device backup
- Server migrate karna ho
- Complete audit

---

### 6. CLEAR_ENROLL_DATA

**Kaam:** Biometric data delete karo — 2 modes hain:

#### Mode A — Ek User ka biometric clear karo:
```json
{
  "user_id": "abc123"
}
```
User naam/ID device pe rehta hai, sirf biometric templates delete hote hain.

#### Mode B — SARE users ka biometric clear karo:
```json
{}
```
Empty ya null parameter → Device pe **sare enrolled biometric templates delete** ho jaate hain. User IDs aur names rehte hain.

> **⚠️ Mode B Caution:** Poori gym ki biometric enrollment wipe ho jaayegi. Sirf maintenance ya factory reset scenario mein use karo.

---

### 7. SET_ENROLL_DATA

**Kaam:** Server se biometric data seedha device pe push karo.

```json
{
  "user_id":       "abc123",
  "backup_number": 12,
  "enroll_data":   "BIN_1"
}
```
+ BSComm binary attachment mein actual biometric template

#### Gym use:
- Gym A pe enrolled hai → Gym B pe bhi access chahiye → `SET_ENROLL_DATA` bhejo
- Multi-device biometric sync
- Server-side stored template wapas device pe dalna

---

### 8. SET_DOOR_STATUS

**Kaam:** Gate ka relay directly control karo.

```json
{ "door_status": "open" }
```
ya
```json
{ "door_status": "close" }
```

#### Firmware kya karta hai:
- `"open"` → Hardware relay HIGH → Gate/solenoid ON → Door khulta hai
- `"close"` → Hardware relay LOW → Gate band
- `OpenDoor_Delay` setting ke baad auto-close hota hai

#### Gym use:
- QR/Face/FP scan valid → `SET_DOOR_STATUS: open` queue karo
- Staff manual gate control
- Emergency open/close

---

### 9. SET_DEVICE_SETTING

**Kaam:** Device ke hardware behavior settings change karo.

```json
{
  "OpenDoor_Delay": "3",
  "Wiegand_Type":   "0",
  "Volume":         "5"
}
```

#### Parameters:
| Parameter | Matlab | Values |
|---|---|---|
| `OpenDoor_Delay` | Gate kitne sec khula rahe scan ke baad | `"1"` to `"10"` (seconds) |
| `Wiegand_Type` | External access control output protocol | `"0"` = off, `"1"` = 26-bit, `"2"` = 34-bit |
| `Volume` | Device beep / speaker loudness | `"0"` (mute) to `"10"` (max) |

> **Wiegand:** Third-party access control panels ke saath connect karne ka electrical protocol. Gym ke liye usually `"0"` (disabled).

---

### 10. GET_DEVICE_SETTING

**Kaam:** Current device settings lo.

**Parameters:** Koi nahi

#### Device ka Response:
```json
{
  "OpenDoor_Delay": "3",
  "Wiegand_Type":   "0",
  "Volume":         "5"
}
```

---

### 11. GET_DEVICE_STATUS

**Kaam:** Device ki health check karo — memory, users, connectivity.

**Parameters:** Koi nahi

---

### 12. SET_TIME

**Kaam:** Device ka internal clock server ke time se sync karo.

```json
{
  "time": "20241215143022"
}
```

Format: `YYYYMMDDHHmmss`

> **Server auto-fill karta hai:** `SET_TIME` command queue hone pe parameter khali chhod sakte ho — receive_cmd handler automatically current server time inject karta hai.

#### Gym use:
- Power cut ke baad device ka time reset ho sakta hai
- **Daily ek baar automatic cron** se queue karo

---

### 13. SET_TIMEZONE

**Kaam:** Device pe access time rules define karo (T1–T6 time slots). Ye rules SET_USER_PASSTIME mein assign kiye jaate hain.

```json
{
  "TimeZone_No": "1",
  "T1": { "start": "0600", "end": "2200" },
  "T2": { "start": "0000", "end": "0000" },
  "T3": { "start": "0000", "end": "0000" },
  "T4": { "start": "0000", "end": "0000" },
  "T5": { "start": "0000", "end": "0000" },
  "T6": { "start": "0000", "end": "0000" }
}
```

#### Parameters:
| Field | Matlab |
|---|---|
| `TimeZone_No` | Rule number `"1"`, `"2"`, `"3"`... |
| `T1`–`T6` | 6 allowed time windows (use sirf jo chahiye, baaki `"0000"` to `"0000"`) |
| `start` / `end` | Format `HHMM` → `"0600"` = 6:00 AM |

#### Gym mein typical setup:
```
TimeZone 1: T1={0600–2200}  → Regular members (6am–10pm)
TimeZone 2: T1={0600–1400}  → Morning plan only
TimeZone 3: T1={0000–2359}  → 24/7 plan
```

---

### 14. GET_TIMEZONE

**Kaam:** Stored timezone rules lo.

```json
{ "TimeZone_No": "1" }
```

---

### 15. SET_USER_PASSTIME

**Kaam:** User ko week ke har din kaun si TimeZone rule apply hogi.

```json
{
  "user_id":           "abc123",
  "Week_TimeZone_No":  ["1","1","1","1","1","0","0"]
}
```

#### Array Order:
```
Index: [0=Sun, 1=Mon, 2=Tue, 3=Wed, 4=Thu, 5=Fri, 6=Sat]
```

| Value | Matlab |
|---|---|
| `"1"` | TimeZone 1 ke hours mein access allowed |
| `"2"` | TimeZone 2 ke hours mein access |
| `"0"` | Is din koi access nahi (device khud deny karega) |

#### Common Patterns:
```
Mon–Fri:       ["0","1","1","1","1","1","0"]
Mon–Sat:       ["0","1","1","1","1","1","1"]
24/7:          ["1","1","1","1","1","1","1"]
Weekends only: ["1","0","0","0","0","0","1"]
```

---

### 16. GET_USER_PASSTIME

**Kaam:** User ki current access schedule lo.

```json
{ "user_id": "abc123" }
```

#### Device ka Response:
```json
{
  "user_id":          "abc123",
  "Week_TimeZone_No": ["1","1","1","1","1","0","0"]
}
```

---

### 17. SET_FK_NAME

**Kaam:** Device ka naam set karo.

```json
{
  "fk_name": "GymA-MainGate"
}
```

#### Gym use:
- Multiple devices hain — har ek ka unique naam zaroori
- Naam `receive_cmd` body mein wapas aata hai — server ko pata rehta hai kaun connect kiya

---

### 18. SET_WEB_SERVER_INFO

**Kaam:** Device ko batao kis server se connect karna hai.

```json
{
  "ip_address": "103.21.244.0",
  "port":       "8080",
  "token_id":   "gymadmin@secret"
}
```

> **⚠️ Field names zaroori:** `ip_address` aur `port` — ye exact names SDK mein defined hain. `server_ip` ya `server_port` kaam NAHI karenge.

#### Firmware kya karta hai:
- Device is IP:Port pe permanently connect karne lagta hai
- `token_id` har request ke `token_id` header mein jaata hai
- Reboot ke baad bhi same settings retain hoti hain

#### Gym use:
- **Sirf ek baar — initial device setup mein**
- VPS ka public IP aur port 8080 dalo
- Token ID `.env` mein `DEVICE_TOKEN_ID` wali value

---

### 19. GET_LOG_DATA

**Kaam:** Device se historical scan logs download karo.

```json
{
  "start_time": "20241201000000",
  "end_time":   "20241231235959"
}
```

Format: `YYYYMMDDHHmmss`

#### Gym use:
- Device offline tha → server se disconnect tha → baad mein sync karo
- Historical attendance audit

---

### 20. GET_SLOG_DATA

**Kaam:** Device ke system/admin action logs lo.

```json
{
  "start_time": "20241201000000",
  "end_time":   "20241231235959"
}
```

---

### 21. GET_LOG_IMAGE

**Kaam:** Specific scan ke waqt camera se capture ki gayi photo lo.

```json
{
  "log_id": "12345"
}
```

#### Device ka Response:
Binary JPEG image data

---

### 22. CLEAR_LOG_DATA

**Kaam:** Device se sare scan logs permanently delete karo.

**Parameters:** Koi nahi (null)

**⚠️ Warning:** Irreversible. Pehle `GET_LOG_DATA` se backup lo.

---

### 23. CLEAR_MANAGER

**Kaam:** Device pe MANAGER aur OPERATOR privilege wale users delete karo.

**Parameters:** Koi nahi (null)

Normal `USER` privilege wale safe rehte hain.

---

### 24. SET_COMMAND — Sub-Commands

**Kaam:** Device ko special internal operations karne ke liye.

#### 24a. `enter_enroll` — Enrollment Mode Shuru Karo

```json
{
  "cmd":   "enter_enroll",
  "param": {
    "user_id":       "abc123",
    "backup_number": 12
  }
}
```

Device screen pe enrollment prompt aata hai. Member aake apna biometric scan kare. Complete hone pe `realtime_enroll_data` event server ko push hota hai.

**`backup_number` values:**
| Value | Enrollment Type |
|---|---|
| 0–9 | Fingerprint (Finger 1–10) |
| 12 | Face |
| 13 | Palm Haath 1 |
| 14 | Palm Haath 2 |

---

### 25. RESET_FK

**Kaam:** Device factory reset karo.

**Parameters:** Koi nahi (null)

**⚠️ EXTREME CAUTION — YE SAB DELETE KARTA HAI:**
- Sare registered users + biometric templates
- Sare scan logs
- Server connection info (IP/port/token)
- Device naam
- Door settings
- Sari timezone rules

> **Server response se bhi trigger hota hai:** Normal `receive_cmd` response mein server `response_code: RESET_FK` de sakta hai — device turant reset kar leta hai (command queue se nahi, seedha response header se).

---

### 26. UPDATE_FIRMWARE

**Kaam:** Device ka firmware update karo.

```json
{
  "firmware_file_name": "FK725HS001_v2.0.bin",
  "firmware_bin_data":  "BIN_1"
}
```
+ BSComm binary attachment mein actual `.bin` firmware file

#### Firmware kya karta hai:
- Naya firmware flash karta hai
- Device restart hota hai automatically
- ⚠️ Galat firmware brick kar sakta hai device

> **Auto-select option:** Null parameter bhejne pe SDK server automatically firmware folder se latest file pick karta hai.

---

## DEVICE EVENTS (Device → Server)

Ye commands nahi hain — device khud in events ko server ko push karta hai.

---

### EVENT 1: realtime_glog — Scan Hua

**Kab:** Koi bhi scan kare — QR, Face, FP, Palm, PIN, Card.
**request_code header:** `realtime_glog`

#### Body JSON:
```json
{
  "user_id":         "abc123",
  "verify_mode":     "20",
  "io_mode":         "17",
  "io_time":         "20241215143022",
  "work_code":       "0",
  "fk_bin_data_lib": "FKDataHS101",
  "log_image":       ""
}
```

#### Fields:
| Field | Matlab |
|---|---|
| `user_id` | Kisne scan kiya |
| `verify_mode` | Kaise scan kiya — code (poori table neeche) |
| `io_mode` | Entry/Exit + door event info — complex encoding (neeche) |
| `io_time` | Kab scan hua — `YYYYMMDDHHmmss` |
| `work_code` | `"0"` = normal; aur numbers = job/shift classification |
| `fk_bin_data_lib` | Device model ka naam — binary decode ke liye |
| `log_image` | Camera photo: Naye devices mein Base64 string; purane mein BSComm binary attachment |

#### `io_mode` Field — IoMode Encoding

**Simple devices (HS100/HS101):**
| `io_mode` | Matlab |
|---|---|
| `"0"` | OUT — Bahar jaana |
| `"1"` | IN — Andar aana |

**Newer devices (HS102/HS103/HS105):**
`io_mode` integer ke bits mein multiple fields embedded hain:
- **Lower nibble (bits 0–3):** Door event code
- **Upper nibble (bits 4–7):** Direction — `1` = IN, aur = OUT

**Door Event Codes (lower nibble):**
| Code | Event | Matlab |
|---|---|---|
| 1 | LOG_CLOSE_DOOR | Door band hua |
| 2 | LOG_OPEN_HAND | Manually door push kiya |
| 3 | LOG_PROG_OPEN | Server command se khula |
| 4 | LOG_PROG_CLOSE | Server command se band |
| 5 | LOG_OPEN_IREGAL | **Forced/illegal open** |
| 6 | LOG_CLOSE_IREGAL | Illegal close |
| 7 | LOG_OPEN_COVER | **Device ka cover/casing khola (tamper)** |
| 8 | LOG_CLOSE_COVER | Cover wapas band |
| 9 | LOG_OPEN_DOOR | Normal door open |
| 10 | **LOG_OPEN_DOOR_THREAT** | **⚠️ Duress — Coercion ke andar scan** |
| 13 | LOG_FIRE_ALARM | Fire alarm se door khula |

> **⚠️ Duress (code 10):** Member ko koi force kar raha ho to woh special "threat finger" scan kare — device gate kholta hai (takki attacker na maare) lekin server ko alert bhejta hai ki forced entry ho rahi hai. Security alert trigger karni chahiye.

**HS200 devices:** `io_mode` mein `BackupNumber` bhi encode hota hai (additional bits).

#### Server kya kare:
1. Supabase se member validate karo
2. Valid → `SET_DOOR_STATUS: open` queue karo
3. Expired → `DELETE_USER` queue karo
4. Scan log DB mein save karo
5. Duress (io_mode code 10) → Security alert trigger karo

---

### EVENT 2: realtime_enroll_data — Enrollment Complete Hua

**Kab:** Member device pe biometric scan kare aur enrollment complete ho.
**request_code header:** `realtime_enroll_data`

#### Body (BSComm format):
```
JSON part:
{
  "user_id": "abc123"
}
Binary part: actual biometric template data
```

---

### EVENT 3: realtime_door_status — Gate Status Change

**Kab:** Gate physically khule ya band ho.
**request_code header:** `realtime_door_status`

#### Body JSON:
```json
{
  "door_status": "open"
}
```
ya `"close"`

---

### ~~EVENT 4: realtime_slog~~ — DISABLED

> **⚠️ Important:** `realtime_slog` event SDK mein **commented out hai** — yani completely disabled hai. Device ye event nahi bhejta. System/admin action logs `GET_SLOG_DATA` command se manually download karni padegi.

```
// Source: Default.aspx.cs mein yahi tha:
// private const string REQ_CODE_REALTIME_SLOG = "realtime_slog"; // COMMENTED OUT
```

---

### EVENT 5: send_cmd_result — Command Result

**Kab:** Device kisi command ke baad result report kare.
**request_code header:** `send_cmd_result`

Server ko confirm hota hai command succeed ya fail hua.

---

## VERIFY MODES — Complete Table

`realtime_glog` mein `verify_mode` field ke codes:

### All Modes:
| Code | Method | Local/Server | Notes |
|---|---|---|---|
| `1` | Fingerprint | Local | |
| `2` | Password / PIN | Local | |
| `3` | QR Code / ID Card | Server required | |
| `4` | FP + Password | Local | |
| `5` | FP + QR Card | Local + Server | |
| `6` | Password + FP | Local | |
| `7` | QR + FP | Server + Local | |
| `8` | Job Number verify | Local | Older devices |
| `9` | Card + Password | Server + Local | Older devices |
| `0x89` (137) | Password + Card | Local + Server | Older devices |
| `20` | Face | Local | |
| `21` | Face + QR Card | Local + Server | |
| `22` | Face + Password | Local | |
| `23` | QR + Face | Server + Local | |
| `24` | Password + Face | Local | |
| `40` | Palm Vein | Local | |

### Verify Kind Nibble Encoding (HS102/103/105 complex devices):
| Nibble Value | Biometric Type |
|---|---|
| 1 | FP (Fingerprint) |
| 2 | PASS (Password) |
| 3 | CARD (QR/Card) |
| 4 | FACE |
| 5 | VEIN (Finger Vein) |
| 6 | IRIS |
| 7 | PV (Palm Vein) |

Combination = Upper nibble primary + Lower nibble secondary method.

---

## SYSTEM LOG EVENTS (realtime_slog / GET_SLOG_DATA)

`kind` field ke codes:

| Code | Event |
|---|---|
| 3 | User enrolled |
| 4 | Manager enrolled |
| 5 | Fingerprint deleted |
| 6 | Password deleted |
| 7 | Card deleted |
| 8 | All logs deleted |
| 9 | System settings changed |
| 10 | System time changed |
| 11 | Log settings changed |
| 12 | Communication settings changed |
| 13 | Access time (passtime) set |
| 14 | Door settings changed |
| 15 | Face deleted |
| 16 | Palm deleted |
| 17 | Photo deleted |
| 18 | User info modified |
| 19 | User deleted |

---

## receive_cmd — Device ki Request Body (Detail)

Jab device 60 sec mein server se command maangne aata hai, ye body bhejta hai:

```json
{
  "fk_name": "GymA-MainGate",
  "fk_time": "20241215143022",
  "fk_info": {
    "supported_enroll_data": ["FP", "PASSWORD", "IDCARD", "FACE", "PALMVEIN"],
    "fk_bin_data_lib":       "FKDataHS101",
    "firmware":              "FK725HS001_v1.0.bin",
    "firmware_filename":     "FK725HS001",
    "fp_data_ver":           100,
    "face_data_ver":         100,
    "pv_data_ver":           100
  }
}
```

| Field | Use |
|---|---|
| `fk_name` | Device ka naam — `SET_FK_NAME` se set hua |
| `fk_time` | Device ki current time — check karo zyada drift na ho |
| `supported_enroll_data` | Ye device kaunse enrollment support karta hai |
| `fk_bin_data_lib` | Binary decode library — device model pata chalta hai |
| `fp_data_ver` | Fingerprint algorithm version — convert karni pad sakti hai |
| `face_data_ver` | Face algorithm version |
| `pv_data_ver` | Palm vein algorithm version |

---

## Commands Quick Reference

| Command | Direction | Frequency |
|---|---|---|
| `SET_USER_INFO` | Server → Device | Member join pe |
| `DELETE_USER` | Server → Device | Subscription expire pe |
| `SET_DOOR_STATUS` | Server → Device | Har valid scan pe |
| `SET_COMMAND (enter_enroll)` | Server → Device | Enrollment trigger |
| `SET_TIME` | Server → Device | Daily |
| `SET_USER_PASSTIME` | Server → Device | Plan type change pe |
| `SET_ENROLL_DATA` | Server → Device | Multi-device sync |
| `CLEAR_ENROLL_DATA` | Server → Device | Re-enrollment pe |
| `GET_USER_INFO` | Server → Device | Verify/sync |
| `GET_USER_ID_LIST` | Server → Device | Audit |
| `GET_ALL_USER_INFO` | Server → Device | Full backup |
| `GET_LOG_DATA` | Server → Device | Offline sync |
| `GET_SLOG_DATA` | Server → Device | Admin audit |
| `GET_LOG_IMAGE` | Server → Device | Security verify |
| `CLEAR_LOG_DATA` | Server → Device | Memory management |
| `CLEAR_MANAGER` | Server → Device | Staff change |
| `SET_DEVICE_SETTING` | Server → Device | Setup (ek baar) |
| `SET_WEB_SERVER_INFO` | Server → Device | Setup (ek baar) |
| `SET_FK_NAME` | Server → Device | Setup (ek baar) |
| `SET_TIMEZONE` | Server → Device | Plan rules define |
| `GET_DEVICE_SETTING` | Server → Device | Admin check |
| `GET_DEVICE_STATUS` | Server → Device | Health monitor |
| `RESET_FK` | Server → Device | ⚠️ Emergency |
| `UPDATE_FIRMWARE` | Server → Device | ⚠️ Rare |
| `realtime_glog` | Device → Server | Har scan |
| `realtime_enroll_data` | Device → Server | Enrollment complete |
| `realtime_door_status` | Device → Server | Gate event |
| `send_cmd_result` | Device → Server | Command complete |
| ~~`realtime_slog`~~ | — | **DISABLED in SDK** |

---

## Gym Setup Checklist

### Sirf initial device setup mein (ek baar):
```
1. SET_WEB_SERVER_INFO  → ip_address, port, token_id
2. SET_FK_NAME          → "GymA-MainGate"
3. SET_DEVICE_SETTING   → OpenDoor_Delay=3, Volume=5, Wiegand_Type=0
4. SET_TIMEZONE         → TimeZone 1: 6am-10pm (regular hours)
5. SET_TIME             → Current time
```

### Roz automatically:
```
- SET_TIME              → Daily cron se time sync
- SET_USER_INFO         → Naye member ko add karo
- DELETE_USER           → Expire member remove karo
- SET_DOOR_STATUS       → Scan valid hone pe open
```

### Kabhi kabhi:
```
- SET_USER_PASSTIME     → Time-limited plan members
- CLEAR_ENROLL_DATA     → Re-enrollment chahiye ho
- SET_ENROLL_DATA       → Multi-device sync
- GET_USER_ID_LIST      → Device sync audit
- GET_LOG_DATA          → Offline period sync
- GET_SLOG_DATA         → Security audit
- GET_LOG_IMAGE         → Suspicious access investigate
```

### Almost kabhi nahi:
```
- RESET_FK              → ⚠️ Emergency/device transfer
- UPDATE_FIRMWARE       → ⚠️ Manufacturer update
- CLEAR_LOG_DATA        → ⚠️ Device memory full
```
