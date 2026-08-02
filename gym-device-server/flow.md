# Device Communication Flow

## Do Alag Channels Hain

```
Server ──(receive_cmd 60sec poll)──► Device   [Management Commands]
Device ──(realtime_glog instant)───► Server   [Scan Events]
```

---

## Channel 1 — receive_cmd (60 Second Poll)

**Direction:** Server → Device  
**Kab:** Device har 60 second mein server se puchta hai  
**Kaam:** Sirf management commands ke liye

```
Device:  "Koi naya command hai?"
Server:  "Haan → SET_USER_INFO / DELETE_USER / SET_TIME"
       ya "Nahi → ERROR_NO_CMD"
```

**Ye commands is channel se jaate hain:**
- `SET_USER_INFO` — naya user add karo device pe
- `DELETE_USER`   — user hatao device se
- `SET_DOOR_STATUS` — gate manually open/close karo
- `SET_TIME`      — device ka time sync karo

**60 second delay — acceptable kyun:**  
User add/delete real-time nahi hona chahiye. 1 minute max wait theek hai.

---

## Channel 2 — realtime_glog (Instant Push)

**Direction:** Device → Server  
**Kab:** Scan hote hi turant — 60 sec ka koi relation nahi  
**Kaam:** Scan event server ko batana + QR validation

```
User scan kare → Device TURANT server ko bheje → Server respond kare
```

**Ye events is channel se aate hain:**
- `realtime_glog`        — QR / Face / FP / Palm scan hua
- `realtime_enroll_data` — enrollment complete hua
- `realtime_door_status` — door status change hua

---

## Gate Opening — Method-wise

| Method | Validation | Gate Speed |
|---|---|---|
| Face | Device pe LOCAL | Instant (milliseconds) |
| Fingerprint | Device pe LOCAL | Instant (milliseconds) |
| Palm | Device pe LOCAL | Instant (milliseconds) |
| QR | Server pe | ~1-2 second (network round trip) |

---

## Face / FP / Palm Flow (Local Validation)

```
User chehra / haath / ungli rakhe
        │
        ▼
Device khud match kare (offline biometric database)
        │
   ┌────┴────┐
Match?      No Match?
   │              │
Gate OPEN ✅   Gate BAND ❌
(milliseconds)
        │
        ▼ (background, async)
Device → realtime_glog → Server
Server → log save karo → subscription check
Agar expired → DELETE_USER queue karo
```

---

## QR Flow (Server Validation)

```
User QR scan kare
        │
        ▼
Device → realtime_glog → Server (INSTANT push)
        │
        ▼
Server → Cloudflare Worker → Supabase check
        │
   ┌────┴────┐
Valid?      Expired / Invalid?
   │              │
Server → OK    Server → DENIED
   │              │
Gate OPEN ✅   Gate BAND ❌
(~1-2 sec)
```

---

## Subscription Expire Flow

### QR User ka Subscription Expire

```
Supabase detect kare expiry (cron job ya webhook)
        │
        ▼
Cloudflare Worker mein mark karo as EXPIRED
        │
        ▼
Next QR scan pe → Server validate kare → DENIED return kare
        │
        ▼
Gate BAND ❌

[DELETE_USER ki zaroorat NAHI — QR user ka koi biometric data
 device pe store nahi hota. Bas server pe block karo.]
```

---

### Face / FP / Palm User ka Subscription Expire

```
Supabase detect kare expiry (cron job ya webhook)
        │
        ▼
Cloudflare Worker → gym-device-server API call kare
POST /api/users/delete  { device_id, user_id }
        │
        ▼
MySQL mein DELETE_USER command queue ho (status: WAIT)
        │
        ▼
~60 second ke andar device poll kare (receive_cmd)
        │
        ▼
Device ko DELETE_USER command mile
        │
        ▼
Device apne local database se user ka
Face / FP / Palm data DELETE kare
        │
        ▼
Ab user scan kare → No local match → Gate BAND ❌

[DELETE_USER zaroori hai — kyunki Face/FP/Palm device pe
 locally validate hota hai. Agar delete nahi kiya to
 subscription expire hone ke baad bhi gate khulta rahega.]
```

---

## Subscription Expiry — Kya Kab Hoga

| User Type | Server Block | Device Delete | Max Delay |
|---|---|---|---|
| QR | Haan (instant) | Nahi chahiye | 0 sec |
| Face | Nahi (local) | Zaroori | Max 60 sec |
| Fingerprint | Nahi (local) | Zaroori | Max 60 sec |
| Palm | Nahi (local) | Zaroori | Max 60 sec |

---

## Background Subscription Check (Recommended)

Supabase mein ek daily cron job banao:

```
Har din raat 12 baje:
  1. Supabase mein expired members dhundo
  2. Unka method check karo
  3. QR → sirf mark as expired (DB update)
  4. Face/FP/Palm → gym-device-server ko API call karo
                    → DELETE_USER queue ho
  5. Device next poll pe user delete kar le
```

Ya real-time trigger:
```
Subscription expire hote hi → Supabase webhook fire ho
→ Cloudflare Worker → gym-device-server API
→ DELETE_USER queue
```
