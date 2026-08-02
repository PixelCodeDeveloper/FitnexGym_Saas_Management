# Gym Device Server

Biometric device (QR + Face + Fingerprint + Palm) ke liye Linux-based server.  
Windows + MSSQL ki jagah **Node.js + MySQL** pe kaam karta hai.

---

## Kya Karta Hai

- Biometric device se directly baat karta hai (SDK protocol)
- QR scan ko Cloudflare Worker (Supabase) se validate karta hai
- Face / Fingerprint / Palm locally device pe validate hota hai
- Subscription expire hone pe device se user delete karta hai
- App ko REST API deta hai (user add/delete/door control)

---

## Folder Structure

```
gym-device-server/
├── src/
│   ├── server.js              ← Main entry point (2 servers)
│   ├── db.js                  ← MySQL connection
│   ├── handlers/
│   │   ├── receiveCmd.js      ← Device 60sec poll handle
│   │   ├── realtimeGlog.js    ← Scan event → validate → gate
│   │   ├── realtimeEnroll.js  ← Enrollment data save
│   │   └── sendCmdResult.js   ← Command result receive
│   └── api/
│       ├── users.js           ← User add / delete / door
│       ├── commands.js        ← Custom command queue
│       └── logs.js            ← Scan logs + device status
├── sql/
│   └── schema.sql             ← MySQL tables
├── .env                       ← Config file
└── package.json
```

---

## Requirements

- Node.js 18+
- MySQL 8+

---

## Setup

### 1. MySQL Database Banao

```bash
mysql -u root -p < sql/schema.sql
```

### 2. .env File Configure Karo

```env
DEVICE_SERVER_PORT=8080
ADMIN_API_PORT=3000

DB_HOST=localhost
DB_PORT=3306
DB_USER=root
DB_PASSWORD=yourpassword
DB_NAME=gym_device_db

CLOUDFLARE_WORKER_URL=http://supabasegym.ro4373.workers.dev/

ADMIN_API_KEY=your-secret-key
DEVICE_TOKEN_ID=
```

### 3. Dependencies Install Karo

```bash
npm install
```

### 4. Server Start Karo

```bash
npm start
```

---

## Do Ports

| Port | Kaam | Kaun Connect Kare |
|------|------|-------------------|
| **8080** | Device SDK Server | Biometric device |
| **3000** | Admin REST API | Tumhari App / Cloudflare Worker |

---

## Device Configuration

Device ke admin panel mein ye setting karo:

```
Server IP    → is server ka IP
Server Port  → 8080
Device ID    → scanner_gym_id (Supabase mein jo value hai)
Token ID     → .env ka DEVICE_TOKEN_ID (agar set kiya ho)
```

---

## App se API Calls

### Member Add Karo (App se trigger)

```bash
POST http://your-server:3000/api/users/add
Header: x-api-key: your-secret-key
Body:
{
  "device_id": "d18a6227-a175-4666-b7a0-894f888c9d9e",
  "user_id": "member-uuid",
  "user_name": "Rahul Sharma",
  "method": "FACE"
}
```

Response:
```json
{
  "success": true,
  "message": "User added. Member ko device ke paas le jao enrollment ke liye."
}
```

---

### Member Delete Karo (Subscription expire pe)

```bash
POST http://your-server:3000/api/users/delete
Header: x-api-key: your-secret-key
Body:
{
  "device_id": "d18a6227-a175-4666-b7a0-894f888c9d9e",
  "user_id": "member-uuid"
}
```

---

### Gate Manually Open/Close Karo

```bash
POST http://your-server:3000/api/users/door
Header: x-api-key: your-secret-key
Body:
{
  "device_id": "d18a6227-a175-4666-b7a0-894f888c9d9e",
  "status": "open"
}
```

---

### Scan Logs Dekho

```bash
GET http://your-server:3000/api/logs?device_id=d18a6227&limit=50
Header: x-api-key: your-secret-key
```

---

### Connected Devices Status

```bash
GET http://your-server:3000/api/logs/devices
Header: x-api-key: your-secret-key
```

---

## Subscription Expire Flow

### QR User
```
Supabase mein expired mark karo
→ Next QR scan pe server DENIED return karega
→ Gate nahi khulega
(Device pe kuch delete karne ki zaroorat nahi)
```

### Face / Fingerprint / Palm User
```
POST /api/users/delete call karo
→ DELETE_USER command queue hogi
→ 60 second ke andar device poll karega
→ Device local biometric data delete karega
→ Ab scan kare → No match → Gate BAND
```

---

## Supported Methods

| Method | Verify Code | Validation | Offline |
|--------|------------|------------|---------|
| QR | 3 | Server | No |
| Face | 20 | Device (local) | Yes |
| Fingerprint | 1 | Device (local) | Yes |
| Palm | 40 | Device (local) | Yes |
