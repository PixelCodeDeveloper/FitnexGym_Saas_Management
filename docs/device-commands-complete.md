# Device Commands — Complete Analysis
## Har Command ka Kaam, Parameters, aur Firmware Behavior

---

## Ye Samajhna Zaroori Hai

```
Sab kuch firmware mein hardcoded hai.
Tum sirf JSON bhejo — device khud jaanta hai kya karna hai.
```

---

## SET_USER_INFO — Sabse Important Command

User device pe add karta hai — naam, ID, aur biometric data sab ek saath.

### JSON Structure:
```json
{
  "user_id":        "abc123",
  "user_name":      "Rahul Sharma",
  "user_privilege": "USER",
  "enroll_data_array": [
    { "backup_number": 0,  "enroll_data": "BIN_0" },
    { "backup_number": 12, "enroll_data": "BIN_1" }
  ]
}
```

### `user_privilege` ke Values:
| Value | Matlab |
|---|---|
| `USER` (0) | Normal member — sirf entry kar sakta hai |
| `MANAGER` (1) | Device settings change kar sakta hai |
| `OPERATOR` (2) | Logs dekh sakta hai |
| `REGISTOR` (3) | Enrollment kar sakta hai |

> **Gym ke liye hamesha `USER` use karo.**

---

### `enroll_data_array` — Biometric Data

`backup_number` se pata chalta hai kaunsa biometric store ho raha hai:

#### Fingerprint (10 fingers):
| backup_number | Matlab |
|---|---|
| 0 | Finger 1 |
| 1 | Finger 2 |
| 2 | Finger 3 |
| 3 | Finger 4 |
| 4 | Finger 5 |
| 5 | Finger 6 |
| 6 | Finger 7 |
| 7 | Finger 8 |
| 8 | Finger 9 |
| 9 | Finger 10 |

#### Other Methods:
| backup_number | Matlab | Data Type |
|---|---|---|
| 10 | Password / PIN | Plain text string |
| 11 | Card / QR code number | Plain text string |
| 12 | Face | Binary data |
| 13 | Palm 1 (left ya right haath) | Binary data |
| 14 | Palm 2 (doosra haath) | Binary data |
| 15 | User photo | Binary image |

> **`enroll_data` mein `"BIN_0"`, `"BIN_1"` likha hota hai** — ye BSComm format mein binary data ka pointer hota hai. Actual biometric binary data alag attach hota hai.

---

## DELETE_USER

Device se user aur uska sara biometric data delete karo.

```json
{ "user_id": "abc123" }
```

**Firmware kya karta hai:** User ki saari biometric templates local memory se delete karta hai. Ab koi bhi us ID se match nahi hoga.

---

## GET_USER_INFO

Device se kisi user ki info lo.

```json
{ "user_id": "abc123" }
```

**Response mein aata hai:** `user_name`, `user_privilege`, `enroll_data_array` (kaunka kaunsa biometric enrolled hai).

---

## GET_USER_ID_LIST

Device pe registered sare users ki list lo.

**Parameters:** Koi nahi  
**Response:** User IDs ki array

**Use case:** App aur device ka sync check karna — kaun device pe hai, kaun nahi.

---

## GET_ALL_USER_INFO

Sare users ki poori info ek saath lo.

**Parameters:** Koi nahi  
**Response:** Sare users ka `user_id`, `user_name`, `user_privilege`, `enroll_data_array`

**Use case:** Full device backup ya audit.

---

## CLEAR_ENROLL_DATA

Kisi user ka **sirf biometric data** delete karo — user ID/naam device pe rehta hai.

```json
{ "user_id": "abc123" }
```

**Use case:** Re-enrollment ke liye — pehle purana data clear karo, phir naya enroll karo.  
DELETE_USER se fark: User hata nahi, sirf biometric wipe hota hai.

---

## SET_ENROLL_DATA

Server se biometric data seedha device pe daalo (bina device pe physically jaaye).

```json
{
  "user_id": "abc123",
  "enroll_data_array": [
    { "backup_number": 12, "enroll_data": "BIN_0" }
  ]
}
```

**Use case:** Ek device pe enrolled user ko doosre device pe add karna — physically jaaye bina.  
Jaise: Member gym A mein enrolled hai → Gym B pe bhi access dena hai → `SET_ENROLL_DATA` bhejo.

---

## SET_DOOR_STATUS — Gate Control

Gate kholo ya band karo.

```json
{ "door_status": "open" }
```

| Value | Action |
|---|---|
| `"open"` | Relay ON — gate khulta hai |
| `"close"` | Relay OFF — gate band hota hai |

**Firmware kya karta hai:** Hardware relay pin ko HIGH/LOW karta hai. Ye directly gate/solenoid/motor control karta hai.

---

## SET_DEVICE_SETTING — Device Hardware Settings

Device ke hardware behavior change karo.

```json
{
  "OpenDoor_Delay": "3",
  "Wiegand_Type":   "0",
  "Volume":         "5"
}
```

| Parameter | Matlab | Values |
|---|---|---|
| `OpenDoor_Delay` | Gate kitne second khula rahe | Seconds (e.g. `"3"`) |
| `Wiegand_Type` | Wiegand output type | `"0"` = disabled, `"1"` = 26-bit, `"2"` = 34-bit |
| `Volume` | Device ka volume | `"0"` (mute) to `"10"` (max) |

> **Wiegand** = Third-party access control system ke saath connect karne ka protocol. Gym ke liye usually `"0"` (off) rakhna.

---

## GET_DEVICE_SETTING

Current device settings lo.

**Parameters:** Koi nahi  
**Response:** `OpenDoor_Delay`, `Wiegand_Type`, `Volume`

---

## GET_DEVICE_STATUS

Device ki health check karo.

**Parameters:** Koi nahi  
**Response:** Online status, memory usage, connected users count

---

## SET_TIME

Device ka time sync karo.

```json
{ "time": "20241215143022" }
```

Format: `YYYYMMDDHHmmss`

**Kyun zaroori:** Device ka time galat ho to scan logs mein galat timestamps aayenge. Roz ek baar sync karna chahiye.

---

## SET_TIMEZONE / GET_TIMEZONE

Device ka timezone set karo.

```json
{ "TimeZone_No": "8" }
```

> India ke liye IST = UTC+5:30 → `"5"` ya device-specific value.

---

## SET_USER_PASSTIME — Access Time Rules

Kisi user ko sirf specific time pe aane do.

```json
{
  "user_id": "abc123",
  "Week_TimeZone_No": ["1","1","1","1","1","1","1"]
}
```

Array order: `[Sun, Mon, Tue, Wed, Thu, Fri, Sat]`

| Value | Matlab |
|---|---|
| `"1"` | Is din access allowed |
| `"0"` | Is din access denied |

**Use case:** Koi member weekdays-only plan le to Sunday/Saturday `"0"` karo — device automatically deny karega.

---

## GET_USER_PASSTIME

Kisi user ki current access time rules lo.

```json
{ "user_id": "abc123" }
```

---

## SET_FK_NAME

Device ka naam set karo.

```json
{ "fk_name": "Gym A - Entry Gate" }
```

**Use case:** 50 devices hain — har ek ka naam set karo taaki logs mein identify kar sako.

---

## SET_WEB_SERVER_INFO

Device ko batao server ka IP/Port/Token — device yahan connect karega.

```json
{
  "server_ip":   "103.21.244.0",
  "server_port": "8080",
  "token_id":    "secret-token"
}
```

**Ye command sirf initial setup mein use hoti hai.** Iske baad device automatically usi server se connect karta hai.

---

## GET_LOG_DATA

Device se scan logs download karo.

```json
{ "start_time": "20241201000000", "end_time": "20241231235959" }
```

**Use case:** Device offline tha — baad mein logs sync karo.

---

## GET_LOG_IMAGE

Scan ke waqt capture ki gayi photo lo.

```json
{ "log_id": "12345" }
```

**Use case:** Security audit — kaun aaya tha us time pe photo proof ke saath.

---

## CLEAR_LOG_DATA

Device se sare scan logs delete karo.

**⚠️ Warning:** Ye data wapas nahi aayega. Pehle `GET_LOG_DATA` se backup lo.

---

## CLEAR_MANAGER

Device pe set kiye gaye Manager/Operator users delete karo.

**Use case:** Security — purane admin access hatana.

---

## RESET_FK

**⚠️ Factory Reset — Sab kuch delete ho jaayega.**

Device wapas factory settings pe aa jaayega:
- Sare users delete
- Sare logs delete
- Server settings reset
- Biometric data wipe

---

## UPDATE_FIRMWARE

Device ka firmware update karo.

**Manufacturer se update file leni hogi.** Galat firmware brick kar sakta hai device.

---

## SET_COMMAND

Custom/raw command bhejo device ko.

```json
{ "command": "custom_cmd_string" }
```

**Advanced use only** — manufacturer se documentation maango.

---

## Verify Modes — Sabhi Authentication Methods

Ye codes `realtime_glog` event mein aate hain — kaise authenticate hua pata chalta hai.

### Single Methods:
| Code | Method | Local/Server | Gym Use? |
|---|---|---|---|
| 1 | Fingerprint only | Local | ✅ |
| 2 | Password/PIN only | Local | ✅ |
| 3 | QR Code / ID Card | Server | ✅ |
| 20 | Face only | Local | ✅ |
| 40 | Palm only | Local | ✅ |

### Combination Methods (2 factors):
| Code | Method | Matlab |
|---|---|---|
| 4 | FP + Password | Pehle finger, phir PIN |
| 5 | FP + QR | Pehle finger, phir QR scan |
| 6 | Password + FP | Pehle PIN, phir finger |
| 7 | QR + FP | Pehle QR, phir finger |
| 21 | Face + QR | Pehle face, phir QR |
| 22 | Face + Password | Pehle face, phir PIN |
| 23 | QR + Face | Pehle QR, phir face |
| 24 | Password + Face | Pehle PIN, phir face |

> **2-factor combinations** = Extra security. Gym ke premium members ke liye use kar sakte ho.

---

## IO Modes — Entry/Exit Track Karo

`realtime_glog` mein `io_mode` field aata hai:

| Code | Matlab |
|---|---|
| 0 | OUT — Bahar jaana |
| 1 | IN — Andar aana |

**Use case:** Gym mein kitne log abhi hain — IN count minus OUT count.

---

## Device se Aane Wale Events (Push)

### realtime_glog — Scan Event
```json
{
  "user_id":     "abc123",
  "verify_mode": "20",
  "io_mode":     "1",
  "io_time":     "20241215143022",
  "work_code":   "0"
}
```

### realtime_enroll_data — Enrollment Complete
```json
{
  "user_id":       "abc123",
  "backup_number": "12",
  "enroll_data":   "BIN_0"
}
```

### realtime_door_status — Gate Status
```json
{ "door_status": "open" }
```

### realtime_slog — System Log
Device ka internal system event.

---

## Gym Ke Liye Kya Use Karna Hai

### Roz ka kaam:
| Command / Event | Kab |
|---|---|
| `SET_USER_INFO` | Member join kare |
| `DELETE_USER` | Subscription expire |
| `SET_DOOR_STATUS` | QR valid hone pe |
| `realtime_glog` | Har scan pe log |
| `realtime_enroll_data` | Enrollment confirm |
| `SET_TIME` | Daily time sync |

### Kabhi kabhi:
| Command / Event | Kab |
|---|---|
| `SET_USER_PASSTIME` | Time-limited plan members |
| `CLEAR_ENROLL_DATA` | Re-enrollment |
| `SET_ENROLL_DATA` | Multi-device access |
| `GET_LOG_IMAGE` | Security audit |
| `GET_USER_ID_LIST` | Device sync check |

### Setup mein ek baar:
| Command | Kab |
|---|---|
| `SET_WEB_SERVER_INFO` | Device pehli baar configure |
| `SET_FK_NAME` | Device ka naam |
| `SET_DEVICE_SETTING` | Gate delay, volume |
| `SET_TIMEZONE` | IST set karo |

### Zaroorat nahi:
| Command | Kyun |
|---|---|
| `RESET_FK` | Emergency only |
| `UPDATE_FIRMWARE` | Manufacturer ke saath |
| `CLEAR_MANAGER` | Rare |
| `SET_COMMAND` | Advanced only |
