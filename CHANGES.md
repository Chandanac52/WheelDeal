# Audit & Fixes — This Pass

A full audit was done by actually running the backend (npm install, syntax-checking
every file) and tracing every screen against every API route, plus inspecting the
native Android/iOS project files — not just reading the code.

## Fixed in this pass

0. **Performance pass (indexes, image compression, debounce, optimistic UI):**
   - Added Postgres indexes on `Vehicle(status, category)`, `Vehicle(status, createdAt)`,
     and `Message(chatId, createdAt)` — these are the exact columns filtered/sorted on
     for every browse, search, and chat-open request.
   - Rewrote `backend/src/routes/upload.js` to actually resize (max width 1600px) and
     recompress (JPEG quality 78, auto-rotated by EXIF) every uploaded photo with
     `sharp` before saving — tested end-to-end with a synthetic 4000×3000 image,
     confirmed correct output dimensions. Raw phone photos (often 3-8MB) no longer
     get shipped to every user's phone at full size.
   - Upgraded `multer` 1.x → 2.x (1.x has known unpatched vulnerabilities).
   - Debounced the search box (350ms) — was firing an API call on every keystroke.
   - Made favorite toggling optimistic — the heart icon fills instantly instead of
     waiting for the network round trip, with automatic rollback if the request fails.

1. **Android release builds had no INTERNET permission** — added to
   `android/app/src/main/AndroidManifest.xml`. Without this, a real release build
   could not reach any server at all.
2. **New listings were stuck in `PENDING` forever** — no endpoint existed to ever
   approve them, so every listing a real user posted would silently never appear
   anywhere. Changed the default to `ACTIVE` (`backend/src/routes/vehicles.js`) so
   listings go live immediately. (If you want a moderation/approval step later,
   that's a deliberate feature to add back in — not a bug fix.)
3. **Photo upload was not implemented anywhere** — the Sell screen's photo box was
   a static graphic; `image_picker` wasn't even a dependency; the backend had
   `multer` installed but no route used it. Built:
   - `backend/src/routes/upload.js` — real multipart upload endpoint
   - `image_picker` wired into `sell_vehicle_screen.dart` — pick, preview, remove,
     upload
   - `ApiClient.uploadImages()` — multipart upload helper
   - iOS `Info.plist` photo/camera permission strings (would have crashed on
     first use otherwise)
4. **Release build was signed with the debug keystore** — `build.gradle.kts` now
   actually reads `android/key.properties` when present and uses it for release
   signing, falling back to debug signing only for local testing. (Previously the
   guide told you to create `key.properties` but nothing ever read it.)
5. **App ID was still `com.example.wheeldeal`** — changed to `com.wheeldeal.app`
   across Android (`build.gradle.kts`, `MainActivity.kt` package + folder) and iOS
   (`project.pbxproj`). Change this again to your own domain if you have one,
   before your first store submission — it can't be changed after publishing.
6. **Chat had no realtime refresh** — added lightweight polling (chat list every
   6s, open conversation every 4s) so messages/replies show up without leaving
   the screen. Not a websocket — good enough for an MVP; worth revisiting if
   message volume grows.
7. **Auth token stored in plain `SharedPreferences`** — switched to
   `flutter_secure_storage` (encrypted at rest).

## Found but NOT fixed — needs your decision or infra you own

- **`useMockData = true`** in `lib/core/constants/api_constants.dart` — the app
  still runs on fake local data by default. Flip this to `false` and set `baseUrl`
  once your backend is deployed. Left as-is because your production API URL isn't
  known yet.
- **Uploaded photos are stored on local disk** (`backend/uploads/`). Render/Railway
  free tiers wipe local disk on every redeploy — photos will disappear. Fine for
  testing; before real users rely on it, move `backend/src/routes/upload.js` to
  Cloudinary or S3 (details in `DEPLOYMENT_GUIDE.md`).
- **No listing moderation** — since #2 above makes listings go live immediately,
  there's nothing stopping spam/fake listings. Not built because it wasn't asked
  for and adds real scope (admin auth, review queue, reporting) — flagging so it's
  a conscious choice, not an oversight.
- **Real Android release keystore** — I wired up the Gradle config to use one, but
  generating it has to happen on your machine (`keytool`, in `DEPLOYMENT_GUIDE.md`)
  since it's a secret only you should hold.
