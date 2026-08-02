# Gym Biometric System — Architecture

## System Components

| Component | Technology | Kaam |
|---|---|---|
| Mobile App | React Native / Flutter | SuperAdmin, GymOwner, Member management |
| Supabase | PostgreSQL + Auth | Database, subscriptions, QR generation |
| Cloudflare Worker | JavaScript | API gateway, validation logic |
| fkwebserver_src | ASP.NET C# + IIS | Device se communication |
| ControlFK | ASP.NET C# + IIS | Device admin panel (setup/maintenance) |
| MSSQL | SQL Server | fkwebserver + ControlFK ka shared database |
| Device | Biometric Hardware | QR / Face / Fingerprint scanner + Gate relay |

---

## Roles

```
SuperAdmin
    └── GymOwner add kare (app se)
            └── Members add kare (app se)
                    └── Method choose kare: QR / Face / Fingerprint
```

---

## Char User Methods

### 1. QR Method
- Device ke paas enrollment ke liye **aana nahi padta**
- App se add karo → Supabase mein QR generate ho → Done
- Har scan pe **server validate** karta hai (subscription real-time check)
- Internet **zaroori** hai

### 2. Face Method
- Enrollment ke liye member **ek baar device ke paas aaye**
- App se add karo → Device enrollment mode mein aaye → Member face scan kare
- Baad mein device **locally validate** karta hai (fast)
- Subscription check ke liye server ping hota hai
- Internet nahi ho tab bhi **gate kaam karta hai** (local match)

### 3. Fingerprint Method
- Enrollment ke liye member **ek baar device ke paas aaye**
- App se add karo → Device enrollment mode mein aaye → Member finger scan kare
- Baad mein device **locally validate** karta hai (fast)
- Subscription check ke liye server ping hota hai
- Internet nahi ho tab bhi **gate kaam karta hai** (local match)

### 4. Palm Scan Method (Palm Vein)
- Enrollment ke liye member **ek baar device ke paas aaye**
- App se add karo → Device enrollment mode mein aaye → Member haath scan kare
- **2 palm scan** store ho sakti hain ek user ke liye (BACKUP_PV_0, BACKUP_PV_1)
- Baad mein device **locally validate** karta hai (fast)
- Subscription check ke liye server ping hota hai
- Internet nahi ho tab bhi **gate kaam karta hai** (local match)
- Verify mode code: **40 (VERIFY_MODE_PALM)**

---

## Poora Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                     MOBILE APP                              │
│                                                             │
│  SuperAdmin Panel    GymOwner Panel      Member App         │
│  - GymOwner add      - Member add        - QR show          │
│  - Device assign     - Method choose     - Profile          │
│  - Reports           - Subscription      - Entry history    │
└──────────────────────────┬──────────────────────────────────┘
                           │ HTTPS
                           ▼
┌─────────────────────────────────────────────────────────────┐
│              SUPABASE + CLOUDFLARE WORKER                   │
│                                                             │
│  Tables:                    Worker Actions:                 │
│  - gyms                     - Member validate               │
│  - members                  - Subscription check            │
│  - subscriptions            - QR generate                   │
│  - entry_logs               - Send command to fkwebserver   │
│  - devices                  - Receive enrollment notify     │
└──────────────────────────┬──────────────────────────────────┘
                           │ HTTP API
                           ▼
┌─────────────────────────────────────────────────────────────┐
│           WINDOWS SERVER / VPS                              │
│                                                             │
│  ┌─────────────────────┐    ┌──────────────────────────┐   │
│  │   fkwebserver_src   │    │       ControlFK          │   │
│  │   (Port: 80/8080)   │    │   (Admin Panel UI)       │   │
│  │                     │    │                          │   │
│  │ - Device se baat    │    │ - Device setup           │   │
│  │ - Commands bheje    │    │ - Firmware update        │   │
│  │ - Logs receive      │    │ - Emergency control      │   │
│  │ - Supabase bridge   │    │                          │   │
│  └──────────┬──────────┘    └──────────────────────────┘   │
│             │                           │                   │
│             └──────────┬────────────────┘                   │
│                        ▼                                    │
│              ┌─────────────────┐                            │
│              │   MSSQL DB      │                            │
│              │   (AttDB)       │                            │
│              │                 │                            │
│              │ - Commands      │                            │
│              │ - Scan logs     │                            │
│              │ - Device status │                            │
│              │ - Enroll data   │                            │
│              └─────────────────┘                            │
└──────────────────────────┬──────────────────────────────────┘
                           │ SDK Protocol (HTTP)
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                    BIOMETRIC DEVICE                         │
│              (Local Network / WiFi)                         │
│                                                             │
│   QR Scanner + Face Camera + Fingerprint Sensor            │
│   Gate Relay (open/close)                                   │
└─────────────────────────────────────────────────────────────┘
```

---

## Flow 1 — QR User Add + Use

```
[ADD]
GymOwner → App mein member add kare + QR method select
    → Supabase mein member save + QR generate
    → Done (device pe kuch nahi bheja)

[USE]
Member → Device pe QR dikhaye
    → Device → fkwebserver_src (realtime_glog)
    → fkwebserver_src → Cloudflare Worker
        Body: { qr_content: "QR-ABC123", scanner_gym_id: "device_id" }
    → Cloudflare Worker → Supabase check kare
        - Member exist karta hai?
        - Subscription active hai?
    → Valid → fkwebserver_src → MSSQL → SET_DOOR_STATUS (open)
    → Device → Gate OPEN ✅
    → Invalid/Expired → Gate BAND ❌
```

---

## Flow 2 — Face User Add + Enroll + Use

```
[ADD + ENROLL]
GymOwner → App mein member add kare + Face method select
    → Supabase mein member save
    → Cloudflare Worker → fkwebserver_src API
    → MSSQL → SET_USER_INFO command (sirf naam/ID, no biometric)
    → Device command receive kare (next poll pe)
    → App bole: "Member ko device ke paas le jao"

Member device ke aage aaye
    → Device enrollment mode mein ho us user ke liye
    → Member face scan kare
    → Device → fkwebserver_src (realtime_enroll_data)
    → fkwebserver_src → Supabase notify kare
    → App pe: "Face Enrolled ✅"

[USE - Daily]
Member → Face dikhaye
    → Device locally match kare
    → Match hua → fkwebserver_src → Supabase subscription check
    → Active → Gate OPEN ✅
    → Expired → fkwebserver_src → MSSQL → DELETE_USER → Device se user hatao
               → Gate BAND ❌

[SUBSCRIPTION EXPIRE]
Supabase detect kare expiry
    → Cloudflare Worker → fkwebserver_src API
    → MSSQL → DELETE_USER command
    → Device → User ka face data delete
    → Ab scan kare → No match → Gate BAND ❌
```

---

## Flow 3 — Fingerprint User Add + Enroll + Use

```
[ADD + ENROLL]
GymOwner → App mein member add kare + Fingerprint method select
    → Supabase mein member save
    → Cloudflare Worker → fkwebserver_src API
    → MSSQL → SET_USER_INFO command (sirf naam/ID)
    → Device command receive kare
    → App bole: "Member ko device ke paas le jao"

Member device ke aage aaye
    → Device enrollment mode mein ho
    → Member finger rakhe
    → Device → fkwebserver_src (realtime_enroll_data)
    → fkwebserver_src → Supabase notify
    → App pe: "Fingerprint Enrolled ✅"

[USE - Daily]
Member → Finger rakhe
    → Device locally match kare
    → Match hua → fkwebserver_src → Supabase subscription check
    → Active → Gate OPEN ✅
    → Expired → DELETE_USER → Gate BAND ❌
```

---

## Flow 4 — Palm User Add + Enroll + Use

```
[ADD + ENROLL]
GymOwner → App mein member add kare + Palm method select
    → Supabase mein member save
    → Cloudflare Worker → fkwebserver_src API
    → MSSQL → SET_USER_INFO command (sirf naam/ID)
    → Device command receive kare
    → App bole: "Member ko device ke paas le jao"

Member device ke aage aaye
    → Device enrollment mode mein ho
    → Member haath device pe rakhe (left ya right)
    → Device → fkwebserver_src (realtime_enroll_data)
    → fkwebserver_src → Supabase notify
    → App pe: "Palm Enrolled ✅"
    (Optional: doosra haath bhi enroll ho sakta hai)

[USE - Daily]
Member → Haath device ke aage rakhe
    → Device locally match kare
    → Match hua → fkwebserver_src → Supabase subscription check
    → Active → Gate OPEN ✅
    → Expired → DELETE_USER → Gate BAND ❌

[SUBSCRIPTION EXPIRE]
Supabase detect kare expiry
    → Cloudflare Worker → fkwebserver_src API
    → MSSQL → DELETE_USER command
    → Device → User ka palm data delete
    → Ab scan kare → No match → Gate BAND ❌
```

---

## MSSQL Commands Table

| Command | Kab Use Hoga | Kaun Bhejega |
|---|---|---|
| SET_USER_INFO | Member add hone pe | App → Supabase → fkwebserver |
| DELETE_USER | Subscription expire pe | Supabase → fkwebserver |
| SET_DOOR_STATUS | QR validate hone pe | fkwebserver (scan ke baad) |
| SET_TIME | Time sync | Automatic |
| RESET_FK | Emergency | ControlFK |
| UPDATE_FIRMWARE | Update | ControlFK |

---

## fkwebserver_src Mein Changes (C# Code)

### Change 1 — OnRealtimeGLog (Scan Event)
```
QR/Face/FP scan aaya
    → Cloudflare Worker call karo
    → Valid → SET_DOOR_STATUS (open) MSSQL mein daalo
    → Invalid → Kuch nahi
    → Expired → DELETE_USER command MSSQL mein daalo
```

### Change 2 — Naya API Endpoint
```
POST /api/command
    → Supabase/App se commands accept karo
    → SET_USER_INFO (member add)
    → DELETE_USER (member remove)
    → Body mein device_id, user info
    → MSSQL mein insert karo
```

### Change 3 — OnRealtimeEnrollData
```
Enrollment data aaya
    → Supabase ko notify karo
    → Member ka status "enrolled" karo
```

---

## Supabase/App Mein Changes

### Member Add Hone Pe
```
Member save hone ke baad:
    → fkwebserver_src /api/command call karo
    → SET_USER_INFO bhejo (naam, user_id, method)
    → Member status: "pending_enrollment" (face/fp ke liye)
    → QR ke liye: "active"
```

### Subscription Expire Pe
```
Cron job ya trigger:
    → fkwebserver_src /api/command call karo
    → DELETE_USER bhejo
    → Member status: "expired"
```

### Enrollment Complete Hone Pe
```
fkwebserver_src se callback aaye:
    → Member status: "enrolled + active"
    → App pe notification
```

---

## Device Settings (Ek Baar Karna Hai)

```
Device ka local admin panel kholo (browser mein device IP)
    → Server IP: [Windows Server / VPS IP]
    → Server Port: 80 (ya jo bhi IIS pe set kiya)
    → Device ID: [scanner_gym_id jo Supabase mein hai]
    → Save → Done
```

---

## Method Comparison Summary

| Feature | QR | Face | Fingerprint | Palm |
|---|---|---|---|---|
| Enrollment device pe | ❌ | ✅ Ek baar | ✅ Ek baar | ✅ Ek baar |
| App se trigger | ✅ | ✅ | ✅ | ✅ |
| Server validate (daily) | ✅ Hamesha | Subscription check | Subscription check | Subscription check |
| Offline kaam kare | ❌ | ✅ | ✅ | ✅ |
| Subscription auto-expire | ✅ | ✅ (delete) | ✅ (delete) | ✅ (delete) |
| Speed | Fast | Fastest | Fast | Fast |
| Security | Medium | High | High | Very High |
| Verify Mode Code | 3 (IDCARD) | 20 (FACE) | 1 (FP) | 40 (PALM) |
| Max enrollments/user | 1 QR | 1 face | 10 fingers | 2 palms |

---

## Server Requirements

| Software | Version |
|---|---|
| Windows Server | 2012 R2 ya upar |
| IIS | 7.5 ya upar |
| .NET Framework | 4.0 |
| SQL Server | 2005 ya upar |
| Ports Open | 80 (ya 8080) device ke liye |
