# WheelDeal — Complete Deployment Guide

This guide walks you through everything needed to take WheelDeal from development to production with real users.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Backend Setup (Step by Step)](#backend-setup-step-by-step)
3. [Database Setup](#database-setup)
4. [Environment Variables & Secrets](#environment-variables--secrets)
5. [Running Locally](#running-locally)
6. [Connecting the Flutter App](#connecting-the-flutter-app)
7. [Phone OTP Login (Firebase)](#phone-otp-login-firebase)
8. [Replacing Dummy Images](#replacing-dummy-images)
9. [Deploy Backend to Production](#deploy-backend-to-production)
10. [Deploy Flutter App](#deploy-flutter-app)
11. [Post-Launch Checklist](#post-launch-checklist)

---

## Architecture Overview

```
┌─────────────────┐         HTTPS/REST          ┌──────────────────┐
│  Flutter App    │  ◄──────────────────────►  │  Node.js API     │
│  (Android/iOS)  │         JWT Auth            │  (Express)       │
└─────────────────┘                             └────────┬─────────┘
                                                         │
                                                         ▼
                                                ┌──────────────────┐
                                                │  PostgreSQL DB   │
                                                │  (Neon/Supabase) │
                                                └──────────────────┘
```

**Recommended stack for a startup:**
- **Database:** [Neon](https://neon.tech) or [Supabase](https://supabase.com) — free PostgreSQL tier
- **Backend hosting:** [Railway](https://railway.app), [Render](https://render.com), or [Fly.io](https://fly.io)
- **Image storage (later):** [Cloudinary](https://cloudinary.com) or AWS S3
- **App stores:** Google Play Console + Apple App Store Connect

---

## Backend Setup (Step by Step)

### Prerequisites

Install on your computer:
- [Node.js 20+](https://nodejs.org) — `node --version`
- [Git](https://git-scm.com)

### Step 1: Install backend dependencies

```bash
cd backend
npm install
```

### Step 2: Create your `.env` file

```bash
cp .env.example .env
```

Edit `.env` with your values (see [Environment Variables](#environment-variables--secrets) below).

### Step 3: Set up the database

```bash
npm run db:setup
```

This runs Prisma migrations and seeds demo data.

### Step 4: Start the API

```bash
npm run dev
```

Verify: open http://localhost:3000/health — you should see `{"status":"ok"}`.

---

## Database Setup

### Option A: Neon (Recommended — Free)

1. Go to https://neon.tech and create a free account
2. Click **New Project** → name it `wheeldeal`
3. Copy the **Connection string** (PostgreSQL format)
4. Paste into `backend/.env`:
   ```
   DATABASE_URL="postgresql://user:password@ep-xxx.region.aws.neon.tech/wheeldeal?sslmode=require"
   ```
5. Run `npm run db:setup` in the `backend` folder

### Option B: Supabase (Free)

1. Go to https://supabase.com → New Project
2. Settings → Database → Connection string → URI
3. Replace `[YOUR-PASSWORD]` with your database password
4. Paste into `DATABASE_URL` in `.env`
5. Run `npm run db:setup`

### What gets created in the database

| Table | Purpose |
|-------|---------|
| `User` | Buyers, sellers, dealers |
| `Vehicle` | Car/bike/scooter listings |
| `Dealer` | Verified dealer profiles |
| `Favorite` | User saved vehicles |
| `Chat` / `Message` | In-app messaging |
| `CallbackRequest` | "Call me back" requests |

### Demo accounts (after seed)

Login is phone-OTP only (see "Phone OTP Login" below) — there's no email/password anymore. These four users are pre-seeded so listings, favorites, and chats have real accounts behind them:

| Name | Phone | Role |
|------|-------|------|
| Demo User | +91 98765 43210 | Buyer |
| Rajesh Nair | +91 98765 00001 | Seller |
| Priya Menon | +91 91234 56780 | Seller |
| Arjun Rao | +91 90000 11122 | Seller |

Add these as **Firebase test phone numbers** (Console → Authentication → Sign-in method → Phone → Phone numbers for testing, with a fixed code like `123456`) so you can log in as any of them without receiving a real SMS. Using your own real phone number instead just creates a new buyer account on first login.

---

## Environment Variables & Secrets

Edit `backend/.env`:

```env
PORT=3000
NODE_ENV=production

# From Neon/Supabase — NEVER commit this to Git
DATABASE_URL="postgresql://..."

# Generate a strong secret (run once, save safely):
# node -e "console.log(require('crypto').randomBytes(64).toString('hex'))"
JWT_SECRET=paste_your_64_char_random_string_here
JWT_EXPIRES_IN=7d

CORS_ORIGIN=*
UPLOAD_DIR=uploads
MAX_FILE_SIZE_MB=5
```

### How to generate JWT_SECRET

```bash
node -e "console.log(require('crypto').randomBytes(64).toString('hex'))"
```

Copy the output and paste it as `JWT_SECRET`. **Keep this secret** — anyone with it can forge login tokens.

### Password rules for users

- Minimum 6 characters (enforced by API)
- Passwords are hashed with bcrypt (12 rounds) — never stored in plain text

---

## Running Locally

### Terminal 1 — Backend

```bash
cd backend
npm run dev
```

### Terminal 2 — Flutter App

```bash
flutter pub get
flutter run
```

### API URL for different devices

Edit `lib/core/constants/api_constants.dart`:

| Device | baseUrl |
|--------|---------|
| Windows/Web desktop | `http://localhost:3000` |
| Android Emulator | `http://10.0.2.2:3000` |
| iOS Simulator | `http://localhost:3000` |
| Physical phone (same WiFi) | `http://YOUR_PC_IP:3000` |

Find your PC IP: `ipconfig` (Windows) → look for IPv4 Address.

---

## Connecting the Flutter App

1. Open `lib/core/constants/api_constants.dart`
2. Change:
   ```dart
   static const String baseUrl = 'http://YOUR_API_URL';
   static const bool useMockData = false;
   ```
3. Run `flutter pub get && flutter run`

When `useMockData = true` (default), the app works without any backend — great for UI testing.

---

## Phone OTP Login (Firebase)

Login is phone number + SMS OTP only, using Firebase Phone Auth — there is no email/password login anymore. This section is **required**, not optional: until you complete it, nobody can sign into the app at all (browsing as a guest still works without it). Nothing below is code you need to write; it's console clicking + dropping two files in place.

### 1. Create a Firebase project
Go to [console.firebase.google.com](https://console.firebase.google.com) → **Add project** → name it (e.g. "WheelDeal") → finish the wizard. The free "Spark" plan is enough.

### 2. Enable Phone sign-in
In the Firebase console: **Build → Authentication → Sign-in method** → enable **Phone**.

### 3. Register your Android app
**Project settings → Your apps → Add app → Android**.
- Package name must be **exactly** `com.wheeldeal.app` (matches `android/app/build.gradle.kts`)
- You'll also be asked for a **debug SHA-1 fingerprint** — get it with:
  ```bash
  cd android
  ./gradlew signingReport
  ```
  Copy the `SHA1` value listed under the `debug` variant and paste it into Firebase.

### 4. Download `google-services.json`
Firebase gives you this file after registering the app. Place it at:
```
android/app/google-services.json
```
That exact path. The Gradle plugin is already wired up in `android/app/build.gradle.kts` — it only activates once this file exists. Until you add it, the app still launches (so you can keep testing everything else), but the phone-login screen won't work.

### 5. Generate a backend service account key
**Project settings → Service accounts → Generate new private key.** This downloads a JSON file the *backend* uses to verify OTP tokens server-side.
- **Local dev:** save it as `backend/firebase-service-account.json` (already gitignored — never commit it)
- **Production (Railway/Render/etc.):** you usually can't upload a file, so instead paste the *entire* JSON file's contents as one line into an env var called `FIREBASE_SERVICE_ACCOUNT_JSON`

### 6. Add test phone numbers (recommended for development)
**Authentication → Sign-in method → Phone → Phone numbers for testing.** Add the four seeded numbers (see "Demo accounts" above) each with a fixed code like `123456`. This lets you log in as any of them instantly, without Firebase sending a real SMS or it costing anything.

### 7. Install and run
```bash
flutter pub get
cd backend && npm install && npx prisma db push   # schema changed: email/password removed, phone is unique
npm run db:seed
npm start
flutter run
```
On the login prompt, enter one of your test phone numbers (or your own real number, which creates a new account) and the code Firebase sends (or your fixed test code).

### iOS (optional, if you're also shipping iOS)
1. Register an iOS app in the same Firebase project (bundle ID must match `ios/Runner.xcodeproj`)
2. Download `GoogleService-Info.plist` and drag it into `ios/Runner/` in Xcode (make sure "Copy items if needed" is checked)
3. No code changes needed beyond that — the Dart side is already platform-agnostic

### Troubleshooting
| Symptom | Cause |
|---|---|
| "Could not send OTP" / `verificationFailed` fires immediately | SHA-1 not added to Firebase, or `google-services.json` missing/wrong package name |
| OTP screen never gets an SMS | Real device only — Firebase phone auth SMS doesn't reach emulators without a test phone number configured in Firebase console |
| Backend returns "Firebase phone login is not configured" | You skipped step 5 — no service account key found |
| Backend returns "Invalid or expired Firebase token" | Service account key belongs to a *different* Firebase project than the one your Android app is registered in |

---

## Replacing Dummy Images

The Sell screen now uploads real photos through the app (`POST /api/upload`, saved to the backend's `uploads/` folder and served at `/uploads/<filename>`). You no longer need to manually replace files to get real listing photos — sellers add their own photos when posting.

**⚠️ Important limitation:** Render, Railway, and most free-tier hosts use an **ephemeral filesystem** — anything saved to disk (including `backend/uploads/`) is wiped every time the service restarts or redeploys. That means uploaded vehicle photos will randomly disappear in production unless you either:
- Pay for a host with a persistent volume/disk (Render and Railway both offer this on paid plans), or
- Swap local disk storage for **Cloudinary** or **AWS S3** (recommended — free tiers exist on both, and images survive redeploys). This just means changing `backend/src/routes/upload.js` to upload to Cloudinary/S3 instead of `multer.diskStorage`, and returning the Cloudinary/S3 URL instead of a local path.

For the bundled placeholder assets that still ship in `assets/images/` (used only as fallback avatars/dealer logos, not for real listings), replace them if you want your own branding:

```
assets/images/cars/       ← fallback vehicle photos (rarely shown now — real uploads replace these)
assets/images/dealers/      ← dealer logos
assets/images/avatars/      ← default profile picture
assets/images/banners/      ← promo banners
```

**Recommended sizes:**
- Cars: 800×600 px, JPG/WebP
- Dealers: 200×200 px
- Avatars: 200×200 px
- Banners: 1200×400 px

---

## Deploy Backend to Production

### Railway (Easiest)

1. Push code to GitHub
2. Go to https://railway.app → New Project → Deploy from GitHub
3. Select the `backend` folder (or whole repo with root set to `backend`)
4. Add environment variables in Railway dashboard:
   - `DATABASE_URL`
   - `JWT_SECRET`
   - `NODE_ENV=production`
   - `CORS_ORIGIN=*`
5. Set start command: `npm start`
6. Railway gives you a URL like `https://wheeldeal-api.up.railway.app`

### Render

1. https://render.com → New Web Service
2. Connect GitHub repo, root: `backend`
3. Build: `npm install && npx prisma generate && npx prisma db push`
4. Start: `npm start`
5. Add env vars same as above

### After deploy — run seed once

In Railway/Render shell:
```bash
node prisma/seed.js
```

---

## Deploy Flutter App

### Android (Google Play)

1. **Create signing key** (one time):
   ```bash
   keytool -genkey -v -keystore wheeldeal-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias wheeldeal
   ```
   Save the keystore file and passwords securely!

2. **Configure signing** — create `android/key.properties` (already wired up in `build.gradle.kts` — it'll be picked up automatically once this file exists):
   ```properties
   storePassword=YOUR_STORE_PASSWORD
   keyPassword=YOUR_KEY_PASSWORD
   keyAlias=wheeldeal
   storeFile=../wheeldeal-release.jks
   ```
   Run the `keytool` command from inside the `android/` folder so the `.jks` file ends up there, matching the relative path above.

3. **App ID** — already set to `com.wheeldeal.app` in `android/app/build.gradle.kts`. Change it to your own reverse-domain (e.g. `com.yourcompany.wheeldeal`) if you have a company domain, by editing `applicationId` and `namespace` in that file AND updating the package folder at `android/app/src/main/kotlin/com/wheeldeal/app/MainActivity.kt` to match.

4. **Set production API URL** in `api_constants.dart`

5. **Build release APK/AAB:**
   ```bash
   flutter build appbundle --release
   ```
   Output: `build/app/outputs/bundle/release/app-release.aab`

6. **Google Play Console:**
   - Create developer account ($25 one-time)
   - New App → Upload AAB → Fill store listing → Submit for review

### iOS (App Store)

1. Apple Developer account ($99/year)
2. Open `ios/Runner.xcworkspace` in Xcode
3. Set Bundle Identifier and signing team
4. Set production API URL
5. `flutter build ios --release`
6. Archive and upload via Xcode → App Store Connect

### Web (Optional)

```bash
flutter build web --release
```
Deploy `build/web/` to Firebase Hosting, Vercel, or Netlify.

---

## Post-Launch Checklist

- [ ] Set `useMockData = false` and a real `baseUrl` in `lib/core/constants/api_constants.dart`
- [ ] Set a strong, random `JWT_SECRET` on your backend host (not the example value)
- [ ] Set `CORS_ORIGIN` to your real app domain (not `*`) once you have one
- [ ] Enable HTTPS on backend (Railway/Render do this automatically)
- [ ] **Move photo storage off local disk to Cloudinary/S3** — otherwise uploaded photos vanish on every backend redeploy (see "Replacing Dummy Images" above)
- [ ] Generate a real Android release keystore and create `android/key.properties` (steps above) — do NOT ship the debug-signed build
- [ ] Decide on your real `applicationId`/bundle ID (currently `com.wheeldeal.app`) before your first Play Store / App Store upload — it can't be changed after publishing
- [ ] Add a privacy policy URL (required for Play Store — you're collecting phone numbers and photos)
- [ ] Add terms of service
- [ ] Decide if you want listing moderation (currently every new listing goes live immediately with no review step)
- [ ] Test the full flow on a real Android + iOS device, not just an emulator/simulator
- [ ] Set up error monitoring (Sentry — free tier available)
- [ ] Consider rate-limiting `/api/auth/login` and `/api/auth/register` to slow down brute-force/spam signups

---

## API Endpoints Reference

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| GET | `/health` | No | Health check |
| POST | `/api/auth/register` | No | Create account |
| POST | `/api/auth/login` | No | Login |
| GET | `/api/auth/me` | Yes | Current user |
| GET | `/api/vehicles` | No | List vehicles |
| GET | `/api/vehicles/:id` | No | Vehicle details |
| POST | `/api/vehicles` | Yes | Create listing |
| POST | `/api/upload` | Yes | Upload vehicle photos (multipart, field `images`, max 8) |
| GET | `/api/dealers` | No | List dealers |
| GET | `/api/favorites` | Yes | User favorites |
| POST | `/api/favorites/:vehicleId` | Yes | Add favorite |
| GET | `/api/chats` | Yes | Chat list |
| POST | `/api/chats/:chatId/messages` | Yes | Send message |

---

## Need Help?

Common issues:

**"Connection refused" on phone:** Use your PC's LAN IP, not `localhost`. Ensure phone and PC are on same WiFi. Allow port 3000 in Windows Firewall.

**"Invalid token":** Log out and log in again. Check `JWT_SECRET` matches between deploys.

**Database connection failed:** Verify `DATABASE_URL` includes `?sslmode=require` for Neon/Supabase.

**Images not showing:** Run `flutter pub get` and ensure asset paths in `pubspec.yaml` match your files.

---

*Built for WheelDeal startup — replace placeholders before going live with real users.*
