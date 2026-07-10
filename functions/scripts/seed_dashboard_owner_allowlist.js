/**
 * Writes `_internal_rule_config/app_dashboard_owners` for Firestore rules
 * (dashboard owner reads). Uses the Firebase Admin SDK.
 *
 * Auth (pick one):
 *   1) Service account JSON (no gcloud): download from Firebase Console →
 *      Project settings → Service accounts → Generate new private key, then:
 *        export GOOGLE_APPLICATION_CREDENTIALS="/absolute/path/to/key.json"
 *   2) Application Default Credentials: install Google Cloud SDK, then:
 *        gcloud auth application-default login
 *
 * Optional: GCP_PROJECT=family-super-app-3bf1c
 * Optional: DASHBOARD_OWNER_EMAILS=you@a.com,other@b.com (comma-separated, merged with existing)
 *
 * If you already created this document manually in Firestore, you do not need to run this script.
 */
const admin = require("firebase-admin");

const PROJECT_ID =
  process.env.GCP_PROJECT ||
  process.env.GCLOUD_PROJECT ||
  process.env.GOOGLE_CLOUD_PROJECT ||
  "family-super-app-3bf1c";

const NEW_EMAILS = (process.env.DASHBOARD_OWNER_EMAILS || "manideepbiswas@gmail.com")
  .split(",")
  .map((e) => e.trim().toLowerCase())
  .filter(Boolean);

function printCredentialHelp() {
  const hasKey = Boolean(process.env.GOOGLE_APPLICATION_CREDENTIALS);
  console.error(`
Could not authenticate to Google Cloud (Admin SDK).

You do NOT need this script if you already added the Firestore document manually:
  Collection: _internal_rule_config
  Document:   app_dashboard_owners
  Field:      emails (array), lowercase addresses

To run this script anyway, use ONE of:

  A) Service account key (works without gcloud):
     Firebase Console → Project settings → Service accounts → Generate new private key
     Then in your terminal:
       export GOOGLE_APPLICATION_CREDENTIALS="/full/path/to/the-downloaded.json"
       cd functions && npm run seed:dashboard-owner

  B) Install gcloud and use ADC:
       brew install --cask google-cloud-sdk
       gcloud auth application-default login
       cd functions && npm run seed:dashboard-owner

GOOGLE_APPLICATION_CREDENTIALS is ${hasKey ? "set" : "not set"}.
`);
}

async function main() {
  if (!admin.apps.length) {
    admin.initializeApp({ projectId: PROJECT_ID });
  }
  const db = admin.firestore();
  const ref = db.collection("_internal_rule_config").doc("app_dashboard_owners");
  const snap = await ref.get();
  const existing =
    snap.exists && Array.isArray(snap.data()?.emails)
      ? snap.data().emails.map((e) => String(e).trim().toLowerCase())
      : [];
  const merged = [...new Set([...existing, ...NEW_EMAILS])];
  await ref.set({ emails: merged }, { merge: true });
  console.log(`OK: ${ref.path} -> emails:`, merged);
}

main().catch((e) => {
  const msg = e && e.message ? String(e.message) : String(e);
  if (msg.includes("Could not load the default credentials")) {
    printCredentialHelp();
  } else {
    console.error(e);
  }
  process.exit(1);
});
