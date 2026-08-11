// firebase-admin v14 removed the old `admin.credential.cert(...)` /
// `admin.auth()` namespaced API in favor of modular imports. If you've ever
// seen "Cannot read properties of undefined (reading 'cert')", that's why —
// admin.credential doesn't exist anymore. This file uses the current API.
const { initializeApp, cert } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const fs = require('fs');
const path = require('path');

// Firebase Admin needs a service account key to verify ID tokens server-side.
// Get this from: Firebase Console -> Project Settings -> Service Accounts ->
// "Generate new private key". That downloads a JSON file.
//
// Local dev: save it as backend/firebase-service-account.json (already
// gitignored — never commit this file) and leave FIREBASE_SERVICE_ACCOUNT_JSON
// unset; we'll load the file directly.
//
// Production (Railway/Render/etc.): you usually can't upload a file, so
// instead paste the ENTIRE JSON file's contents as a single-line string into
// an env var called FIREBASE_SERVICE_ACCOUNT_JSON.
let authInstance = null;

const SERVICE_ACCOUNT_PATH = path.join(__dirname, '..', '..', 'firebase-service-account.json');

function ensureInitialized() {
  if (authInstance) return authInstance;

  let serviceAccount;

  if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
    try {
      serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);
    } catch (e) {
      console.error('[firebase-config] FIREBASE_SERVICE_ACCOUNT_JSON is set but invalid:', e.message);
      throw new Error(
        'Firebase phone login is not configured. FIREBASE_SERVICE_ACCOUNT_JSON env var is set ' +
        'but could not be parsed as valid JSON credentials.'
      );
    }
  } else {
    if (!fs.existsSync(SERVICE_ACCOUNT_PATH)) {
      console.error(
        '[firebase-config] No firebase-service-account.json found at:', SERVICE_ACCOUNT_PATH
      );
      throw new Error(
        'Firebase phone login is not configured. Either set FIREBASE_SERVICE_ACCOUNT_JSON ' +
        'or place firebase-service-account.json in the backend/ folder. See DEPLOYMENT_GUIDE.md.'
      );
    }

    try {
      const raw = fs.readFileSync(SERVICE_ACCOUNT_PATH, 'utf8');
      serviceAccount = JSON.parse(raw);
    } catch (e) {
      console.error('[firebase-config] Failed to parse firebase-service-account.json:', e.message);
      throw new Error(
        'Firebase phone login is not configured. firebase-service-account.json exists but is not valid JSON.'
      );
    }
  }

  if (!serviceAccount.project_id || !serviceAccount.private_key || !serviceAccount.client_email) {
    console.error(
      '[firebase-config] Service account is missing required fields (project_id / private_key / client_email).'
    );
    throw new Error('Firebase phone login is not configured. Service account JSON is incomplete.');
  }

  try {
    const app = initializeApp({ credential: cert(serviceAccount) });
    authInstance = getAuth(app);
    console.log('[firebase-config] Firebase Admin initialized successfully for project:', serviceAccount.project_id);
    return authInstance;
  } catch (e) {
    console.error('[firebase-config] initializeApp/getAuth failed:', e.message);
    throw new Error('Firebase phone login is not configured. Failed to initialize Firebase Admin: ' + e.message);
  }
}

async function verifyFirebaseIdToken(idToken) {
  const auth = ensureInitialized();
  return auth.verifyIdToken(idToken);
}

module.exports = { verifyFirebaseIdToken };