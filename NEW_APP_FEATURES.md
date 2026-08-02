# Gym Owner Management App (Standalone SaaS)

## 1. Overview
This is a standalone SaaS application designed exclusively for Gym Owners. It simplifies gym management by focusing entirely on member subscriptions and revenue tracking. It completely removes the overhead of hardware access control (biometrics, RFID), attendance tracking, and separate member apps.

## 2. Core Operational Flow
- **Target Audience:** Independent Gym Owners.
- **Usage Requirement:** Download from Play Store -> Login using Email/Google SSO -> Pay Subscription for the App -> Start managing members.
- **SaaS Model:** The Gym Owner is charged a monthly subscription fee to use this app. If their subscription expires, the app locks down immediately and prompts for payment before allowing access to gym data.

## 3. Detailed Features

### 3.1 Authentication & Gym Setup
*   **SSO Sign-in:** Hassle-free email or Google single sign-on.
*   **Onboarding:** Quick setup to add Gym Name, Currency, and Owner details. No "SuperAdmin" hierarchy—every sign-up is a completely separate tenant/gym.

### 3.2 Gym Owner's SaaS Subscription (App Billing)
*   **Strict Access Control:** The app enforces a mandatory monthly subscription.
*   **Paywall Routing:** Upon subscription expiry, the app routing forcefully redirects to a "Plan Expired - Renew Now" screen. The owner cannot bypass this.
*   **Payment Gateway Integration:** Direct payment using Razorpay/Stripe (depending on region) for the app's usage fee.

### 3.3 Member Management & Subscription Tracking
*   **Add Members:** Simple UI to add a member's Name, Phone Number, Plan Type (1 month, 3 months, etc.), and Start Date.
*   **Status Dashboard:** Clear visual categorization of members:
    *   🟢 **Active:** Subscription is valid.
    *   🟠 **Expiring Soon:** Subscription expires in the next 3-7 days.
    *   🔴 **Expired:** Subscription is over.
*   **Renewal System:** 1-click renewal flow to update a member's subscription when they pay the gym owner. 

### 3.4 Revenue & Analytics
*   **Financial Dashboard:** 
    *   Total revenue collected this month.
    *   Comparison with previous months.
*   **Payment History:** A structured ledger tracking "who paid", "how much", and "when", ensuring the owner has full visibility into cash flow.

### 3.5 Communications
*   **WhatsApp Integration:** Direct one-click button in the app to send a WhatsApp message to members whose subscriptions are expiring or expired.
*   **App Notifications:** Automated push/in-app notifications for the gym owner whenever any member's subscription is about to expire or has already expired.

### 3.6 Sales Pipeline & Inquiry Management
*   **Inquiry Logging:** Gym owner can log details of people who come for inquiries.
*   **Follow-up Reminders:** Set a return date (e.g., "Will join after 4 days"). On that specific day, the app automatically sends a notification to the gym owner reminding them to call and follow up with the lead.

### 3.7 Diet Plan Management
*   **Default Templates:** The app comes pre-loaded with standard "Veg" and "Non-Veg" diet plans.
*   **Customization:** The gym owner can easily modify the default diet plans or add new ones.
*   **1-Click Sharing:** Owner can send the diet plan directly to a member's registered WhatsApp number with one click, or copy the text to send it manually.


## 4. Technical Constraints
*   **No Access Control:** Do not integrate Biometric/Gate APIs.
*   **No Attendance:** Do not build attendance logs or check-in features.
*   **Single App:** No separate views or builds for Members.

---
*Created as the foundational requirement spec for the new Gym Management app architecture.*
