# CertiBridge Deployment & Operation Guide

## 1. Local Application Setup & Execution

### Running the App
Run the application on Windows desktop, Chrome, or Android:
```bash
# Run on Windows Desktop
flutter run -d windows

# Run on Chrome / Web
flutter run -d chrome

# Run on connected Android device
flutter run -d android
```

### Building Release Bundles
```bash
# Build Web SPA
flutter build web --release

# Build Windows Executable
flutter build windows --release

# Build Android APK
flutter build apk --release
```

---

## 2. Bring-Your-Own-Account (BYOA) Cloud Setup

CertiBridge incurs **$0 operational infrastructure cost** for the vendor. Customers connect their own personal accounts:

### A. Google Drive & Google Sheets (1-Click OAuth PKCE Loopback)
1. In CertiBridge, open **BYOA Cloud Setup** from the top bar.
2. Click **1-Click Connect Google**.
3. The app starts a secure loopback server on `127.0.0.1:54321/callback` and opens your default browser.
4. Grant access to Drive File and Spreadsheets.
5. Tokens are cryptographically stored in **Windows Credential Manager** / **Android Keystore**.

### B. Cloudflare Edge Verifier (Worker + KV)
1. Create a free Cloudflare account at [cloudflare.com](https://cloudflare.com).
2. Go to **My Profile > API Tokens > Create Token** and select the **Edit Cloudflare Workers** template.
3. In CertiBridge BYOA Setup, paste your **Account ID** and **API Token**.
4. Click **Provision KV & Verify Token**:
   - The app automatically creates the `CERT_VERIFIER_KV` namespace.
   - Binds `CERT_KV` to the edge redirector worker (`web_verifier/worker.js`).
   - QR codes on certificates permanently route through `verify.school.edu/c/{cert_code}`.

### C. Google Apps Script Email Receipt Dispatcher ($0 Cost)
1. Go to [script.google.com](https://script.google.com) and create a **New Project**.
2. Paste the contents of [`apps_script/code.gs`](file:///c:/Users/localhost/Downloads/certibri/apps_script/code.gs).
3. Click **Deploy > New Deployment**:
   - Select type: **Web app**
   - Execute as: **Me**
   - Who has access: **Anyone**
4. Copy the Web App URL (ends with `/exec`) and paste it into **BYOA Cloud Setup > Apps Script Web App Exec URL**.

---

## 3. High-Scale 10,000+ Batch Generation Workflow

1. **Create or Open Project**: Name your project (e.g. "Graduation 2026").
2. **Import Underlay**: Choose a multi-page PDF or image from [`assets/templates/sample_certificate_template.png`](file:///c:/Users/localhost/Downloads/certibri/assets/templates/sample_certificate_template.png).
3. **Import Data**: Click **Import Excel / Sheets** and select [`assets/sample_students.xlsx`](file:///c:/Users/localhost/Downloads/certibri/assets/sample_students.xlsx) or [`assets/sample_students.csv`](file:///c:/Users/localhost/Downloads/certibri/assets/sample_students.csv).
4. **Interactive Designer**:
   - Right-click (Windows) or long-press (Android) any element to link to spreadsheet columns.
   - Choose from **269 fonts** (Myanmar Unicode, Myanmar Win fonts, English typography).
   - Use the live preview bar `[Prev] Row X of N [Next]` to inspect live data rendering.
5. **Privacy Configuration**: Open **Privacy Rules & Verifier Visibility** to select which columns are public vs private.
6. **Execute Batch Pipeline**:
   - Click **10k+ Batch Generator**.
   - Watch real-time SQLite checkpointing and stream processing (RAM guaranteed `< 500 MB`).
   - Click **Upload to Drive** (resumable 4-worker pool).
   - Click **Sync to Cloudflare KV** (chunked bulk write).
   - Click **Write-Back Tracking Data** to record certificate codes and verification URLs back into the source spreadsheet.
