# CertiBridge (cbproj)

**Local-First, Zero-Cost Bulk Certificate Engine, Portable Project Bundles & Permanent Edge Verifier**

CertiBridge is a cross-platform desktop and mobile application (Windows prioritized, Android compatible) engineered for non-technical educators, academies, and institutions.

## Core Features & Guarantees

- **$0 Operational Infrastructure Cost**: Developer incurs $0 recurring hosting, database, or server costs.
- **BYOA (Bring Your Own Account)**: Customers authenticate directly with their own Google Drive, Google Sheets, and Cloudflare accounts via 1-click OAuth PKCE loopback wizard.
- **Project-Based Workspace & Portability (`.cbproj`)**: Projects are packaged as standalone, portable ZIP archives containing templates, normalized layouts, color schemes, privacy rules, and embedded TrueType fonts.
- **Universal Multi-Page Template Engine**: Multi-page PDF, PNG, JPG templates rasterized at 300 DPI or vector overlays using normalized coordinates (`0.0` to `1.0`).
- **Dynamic Multi-Script Typography**: Native support for English, Myanmar Unicode (Pyidaungsu, Padauk), and Myanmar Win legacy fonts (WinInnwa) with font subset embedding.
- **10,000+ High-Scale Batch Generator**: Low-memory stream processing (<500MB RAM) with SQLite checkpointing and resumable execution.
- **Permanent Edge Verifier**: Printed QR codes point to a customer-owned Cloudflare Worker edge redirector backed by Cloudflare KV.
- **Dual-Source Data Write-Back**: Automatically syncs tracking columns back to Google Sheets or local Excel files (`.xlsx`/`.csv`).
- **Zero-Cost Email Dispatcher**: Google Apps Script web app deploying `MailApp.sendEmail` for free branded verification receipts.

## System Architecture

```
certibridge/
├── assets/
│   ├── fonts/
│   │   ├── English/
│   │   ├── Myanmar_Unicode/
│   │   └── Myanmar_WinFonts/
│   └── templates/
├── lib/
│   ├── main.dart
│   ├── core/
│   │   ├── constants/
│   │   ├── network/
│   │   ├── storage/
│   │   └── theme/
│   ├── models/
│   │   ├── project_model.dart
│   │   ├── certificate_record.dart
│   │   ├── canvas_element.dart
│   │   ├── template_config.dart
│   │   └── display_config.dart
│   ├── services/
│   │   ├── auth/
│   │   ├── database/
│   │   ├── project/
│   │   ├── engine/
│   │   ├── google/
│   │   ├── cloudflare/
│   │   └── excel/
│   └── views/
│       ├── setup/
│       ├── projects/
│       ├── designer/
│       ├── privacy/
│       └── batch/
├── web_verifier/
│   ├── index.html
│   └── worker.js
└── apps_script/
    └── code.gs
```
