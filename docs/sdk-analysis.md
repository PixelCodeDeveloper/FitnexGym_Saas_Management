# Manufacturer SDK Analysis
## BS(WAN) API — ControlFK + fkwebserver_src

---

## SDK Mein Kya Hai

Manufacturer ne 2 alag tools diye hain:

```
BS(WAN) API_E/
├── fkwebserver_src/     ← Device Communication Server (ASP.NET)
├── ControlFK/           ← Admin Panel UI (ASP.NET)
└── mssql-script/        ← Database Tables (MSSQL)
```

Ye dono Windows + IIS + MSSQL pe chalte hain.  
Humne inhe Linux + Node.js + MySQL pe rebuild kiya hai (`gym-device-server/`).

---

## fkwebserver_src — Kya Karta Hai

Device hamesha is server se baat karta hai. Ye 5 types ke requests handle karta hai:

| Request Code | Direction | Kaam |
|---|---|---|
| `receive_cmd` | Device → Server → Device | Device 60sec mein command maangta hai |
| `send_cmd_result` | Device → Server | Device command ka result bhejta hai |
| `realtime_glog` | Device → Server | Scan event (QR/Face/FP/Palm) |
| `realtime_enroll_data` | Device → Server | Enrollment complete hone ka data |
| `realtime_door_status` | Device → Server | Gate open/close status |

**Ye server 24/7 chalna chahiye** — device isse constantly communicate karta hai.

---

## ControlFK — Kya Karta Hai

Admin panel UI hai. Seedha MSSQL mein commands insert karta hai.  
fkwebserver_src wahi commands device ko deta hai jab device poll kare.

**ControlFK ke Pages:**

| Page | Kaam |
|---|---|
| `UserManage.aspx` | User add/edit/delete, biometric enrollment |
| `DeviceManage.aspx` | Device settings, firmware, reset, logs |
| `LogManager.aspx` | Scan logs dekho, download karo |
| `RTLogView.aspx` | Real-time scan feed dekho |
| `RTEnrollView.aspx` | Real-time enrollment feed |
| `RTPassView.aspx` | Real-time access pass feed |
| `PassManage.aspx` | Access time rules manage karo |

---

## Sare Device Commands (Complete List)

### User Management

| Command | Kaam | Zaroorat Kab |
|---|---|---|
| `SET_USER_INFO` | User add karo device pe (naam, ID, method) | Naya member join kare |
| `DELETE_USER` | User delete karo device se | Subscription expire hone pe |
| `GET_USER_INFO` | User ki info lao | Verify / sync karne ke liye |
| `GET_USER_ID_LIST` | Sare registered users ki ID list | Audit / sync |
| `GET_ALL_USER_INFO` | Sare users ki poori info | Full device sync |
| `CLEAR_ENROLL_DATA` | Kisi user ka sirf biometric data delete karo | Re-enrollment ke liye |
| `SET_ENROLL_DATA` | Biometric data seedha device pe daalo | Server se biometric push karna ho |

### Gate Control

| Command | Kaam | Use Case |
|---|---|---|
| `SET_DOOR_STATUS` | Gate open ya close karo | QR valid → gate open; Manual control |

### Device Settings

| Command | Kaam | Parameters |
|---|---|---|
| `SET_DEVICE_SETTING` | Device settings set karo | `OpenDoor_Delay`, `Wiegand_Type`, `Volume` |
| `GET_DEVICE_SETTING` | Current settings lo | — |
| `GET_DEVICE_STATUS` | Device ki health check | Online/offline, memory, etc. |
| `SET_FK_NAME` | Device ka naam set karo | "Gym A Entry Gate" |
| `SET_WEB_SERVER_INFO` | Device ko server ka IP/port batao | Initial setup mein |

### Access Time Rules

| Command | Kaam | Use Case |
|---|---|---|
| `SET_USER_PASSTIME` | User ke liye allowed time set karo | e.g. Sirf 6am-10pm access |
| `GET_USER_PASSTIME` | User ki time rules lo | — |
| `SET_TIMEZONE` | Device ka timezone set karo | IST set karna |
| `GET_TIMEZONE` | Current timezone lo | — |

### Logs

| Command | Kaam |
|---|---|
| `GET_LOG_DATA` | Scan logs device se download karo |
| `GET_SLOG_DATA` | System logs download karo |
| `GET_LOG_IMAGE` | Scan ke waqt ली gayi photo lo |
| `CLEAR_LOG_DATA` | Device se sare logs delete karo |

### System / Maintenance

| Command | Kaam | Risk |
|---|---|---|
| `SET_TIME` | Device ka time sync karo | — |
| `SET_COMMAND` | Custom/raw command bhejo | Advanced |
| `CLEAR_MANAGER` | Admin/manager data clear karo | — |
| `RESET_FK` | Factory reset karo | ⚠️ Sab data delete |
| `UPDATE_FIRMWARE` | Firmware update karo | ⚠️ Carefully |

---

## Device se Aane Wale Events (Real-time Push)

Device in events ko **turant** server ko bhejta hai:

| Event | Kab Aata Hai | Kya Data Aata Hai |
|---|---|---|
| `realtime_glog` | Har scan pe | user_id, verify_mode, io_time, work_code |
| `realtime_enroll_data` | Enrollment complete hone pe | user_id, backup_number, biometric data |
| `realtime_door_status` | Gate khulne/bandne pe | door_status |
| `realtime_slog` | System event pe | system log entry |

---

## Verify Modes (Scan Method Codes)

| Code | Method | Local/Server |
|---|---|---|
| 1 | Fingerprint | Local |
| 2 | Password/PIN | Local |
| 3 | QR / ID Card | Server |
| 4 | FP + Password | Local |
| 5 | FP + QR | Local + Server |
| 20 | Face | Local |
| 21 | Face + QR | Local + Server |
| 22 | Face + Password | Local |
| 40 | Palm | Local |

---

## Enrollment Backup Numbers

| Backup No. | Biometric Type |
|---|---|
| 0–9 | Fingerprint (10 fingers) |
| 11 | ID Card / QR |
| 12 | Face |
| 13 | Palm (haath 1) |
| 14 | Palm (haath 2) |

---

## Communication Architecture

```
                    ┌─────────────────────────────────┐
                    │        Device (Hardware)         │
                    │  - Local biometric DB            │
                    │  - Gate relay control            │
                    │  - HTTP Client only              │
                    └────────────┬────────────────────┘
                                 │ HTTP (BSComm Protocol)
                                 │ Device hamesha connect karta hai
                                 ▼
                    ┌─────────────────────────────────┐
                    │       gym-device-server          │
                    │  (fkwebserver_src ka replacement)│
                    │  Port 8080 — device se baat      │
                    │  Port 3000 — app se baat         │
                    └────────┬────────────┬────────────┘
                             │            │
                    QR scan  │            │ User add/delete
                    validate │            │ (app se trigger)
                             ▼            ▼
                    ┌─────────────┐  ┌──────────────┐
                    │  Cloudflare │  │  Tumhara App │
                    │   Worker   │  │  (Mobile)    │
                    └─────┬───────┘  └──────────────┘
                          │
                          ▼
                    ┌─────────────┐
                    │   Supabase  │
                    │ (Gym Data)  │
                    └─────────────┘
```

---

## Kya Directly Supabase se Ho Sakta Hai?

**Nahi** — directly Supabase ya Cloudflare Worker se device control nahi ho sakta.

**Kyun:**

1. **Device ko dedicated HTTP server chahiye** jo 24/7 chale aur BSComm binary protocol samjhe
2. **Cloudflare Worker stateless hai** — device ka persistent polling connection handle nahi kar sakta
3. **Device binary format bhejta hai** (BSComm) — Supabase/Cloudflare seedha parse nahi kar sakta
4. **Dynamic IP issue** — server ko device ka IP pata nahi hota, device hamesha server ko call karta hai

**Isliye gym-device-server zaroori hai** — ye wahi kaam karta hai jo fkwebserver_src karta tha, bas Linux pe.

---

## Kya ControlFK ki Zaroorat Hai

**Pehle setup ke liye haan, roz roz ke liye nahi.**

| Kaam | ControlFK chahiye? | Humara Solution |
|---|---|---|
| User add/delete | Nahi | App → gym-device-server API |
| QR scan validate | Nahi | Device → gym-device-server → Cloudflare |
| Enrollment trigger | Nahi | App → gym-device-server API |
| Device settings set karo | Initial setup mein | gym-device-server API |
| Firmware update | Haan (rare) | DeviceManage se karo |
| Factory reset | Haan (rare) | DeviceManage se karo |
| Real-time log monitoring | Nahi | gym-device-server admin panel |

**Short answer:** Roz ke kaam ke liye `gym-device-server` kaafi hai.  
ControlFK sirf maintenance/setup ke waqt kaam aata hai.

---

## Kya Kya Apne System mein Use Hoga

### Definitely Use Hoga:
- `SET_USER_INFO` — member add karne pe
- `DELETE_USER` — subscription expire pe
- `SET_DOOR_STATUS` — QR valid hone pe gate open
- `realtime_glog` — sare scans ka log
- `realtime_enroll_data` — enrollment confirmation
- `SET_TIME` — daily time sync

### Optionally Use Hoga:
- `SET_USER_PASSTIME` — agar sirf specific hours mein access dena ho
- `GET_LOG_IMAGE` — agar entry pe photo capture chahiye
- `CLEAR_ENROLL_DATA` — re-enrollment ke liye
- `GET_DEVICE_STATUS` — device health monitoring

### Zaroorat Nahi Padegi:
- `RESET_FK` — factory reset (only emergency)
- `UPDATE_FIRMWARE` — manufacturer se update aaye tab
- `CLEAR_MANAGER` — admin clear
- `SET_COMMAND` — advanced/custom use
