/**
 * CertiBridge Permanent Edge Verifier Worker
 * Runs on Cloudflare Workers edge network ($0 cost tier)
 * Bound KV Namespace: CERT_KV
 */

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const path = url.pathname;

    // CORS preflight handling
    if (request.method === "OPTIONS") {
      return new Response(null, {
        headers: {
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
          "Access-Control-Allow-Headers": "Content-Type",
        },
      });
    }

    // Health check endpoint
    if (path === "/" || path === "/health") {
      return new Response(
        JSON.stringify({
          status: "healthy",
          engine: "CertiBridge Edge Verifier",
          version: "1.0.0",
          timestamp: new Date().toISOString(),
        }),
        {
          headers: {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
          },
        }
      );
    }

    // Edge QR shortener & certificate verification route: /c/:id
    const match = path.match(/^\/c\/([a-zA-Z0-9_-]+)/);
    if (!match) {
      return new Response("Not Found", { status: 404 });
    }

    const certCode = match[1];

    // Check bound KV namespace CERT_KV
    if (!env.CERT_KV) {
      return new Response(
        renderErrorPage("Cloudflare CERT_KV binding not configured on this Worker."),
        { status: 500, headers: { "Content-Type": "text/html; charset=utf-8" } }
      );
    }

    const certDataRaw = await env.CERT_KV.get(certCode);

    // If client asks for JSON (e.g. API client or fetch)
    const acceptsJson =
      url.searchParams.get("format") === "json" ||
      request.headers.get("accept")?.includes("application/json");

    if (!certDataRaw) {
      if (acceptsJson) {
        return new Response(
          JSON.stringify({
            verified: false,
            cert_code: certCode,
            error: "Certificate not found or revoked",
          }),
          {
            status: 404,
            headers: {
              "Content-Type": "application/json",
              "Access-Control-Allow-Origin": "*",
            },
          }
        );
      }
      return new Response(renderNotFoundPage(certCode), {
        status: 404,
        headers: { "Content-Type": "text/html; charset=utf-8" },
      });
    }

    const certData = JSON.parse(certDataRaw);

    if (acceptsJson) {
      return new Response(JSON.stringify(certData), {
        status: 200,
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*",
        },
      });
    }

    // Render HTML verification page with injected verified payload
    return new Response(renderVerificationPage(certCode, certData), {
      status: 200,
      headers: {
        "Content-Type": "text/html; charset=utf-8",
        "Cache-Control": "public, max-age=3600, s-maxage=86400",
      },
    });
  },
};

function renderVerificationPage(certCode, data) {
  const schoolName = data.school_name || "CertiBridge Verified Institution";
  const verifiedDate = data.verified_at ? new Date(data.verified_at).toLocaleDateString() : new Date().toLocaleDateString();
  const fields = data.fields || {};
  const pdfLink = data.drive_pdf_link || null;

  const rowsHtml = Object.entries(fields)
    .map(
      ([k, v]) => `
      <tr class="border-b border-slate-700/60">
        <td class="py-3 px-4 text-xs font-semibold uppercase tracking-wider text-slate-400">${escapeHtml(k.replace(/_/g, ' '))}</td>
        <td class="py-3 px-4 text-sm font-medium text-slate-100">${escapeHtml(String(v))}</td>
      </tr>`
    )
    .join("");

  return `<!DOCTYPE html>
<html lang="en" class="dark">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Verified Certificate: ${escapeHtml(certCode)} | ${escapeHtml(schoolName)}</title>
  <script src="https://cdn.tailwindcss.com"></script>
  <style>
    @keyframes pulse-glow {
      0%, 100% { box-shadow: 0 0 25px -5px rgba(16, 185, 129, 0.4); }
      50% { box-shadow: 0 0 35px 5px rgba(16, 185, 129, 0.6); }
    }
    .verified-glow { animation: pulse-glow 3s infinite ease-in-out; }
  </style>
</head>
<body class="bg-slate-950 text-slate-100 min-h-screen flex flex-col items-center justify-center p-4 selection:bg-emerald-500 selection:text-white">
  <div class="max-w-xl w-full bg-slate-900 border border-slate-800 rounded-2xl shadow-2xl overflow-hidden verified-glow">
    <!-- Header Authenticity Banner -->
    <div class="bg-gradient-to-r from-emerald-600 via-teal-600 to-emerald-700 p-6 text-center text-white relative">
      <div class="w-16 h-16 bg-white/20 backdrop-blur-md rounded-full flex items-center justify-center mx-auto mb-3 shadow-inner">
        <svg class="w-10 h-10 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M5 13l4 4L19 7"></path>
        </svg>
      </div>
      <span class="inline-block px-3 py-1 bg-emerald-950/40 rounded-full text-xs font-bold uppercase tracking-widest text-emerald-200 border border-emerald-400/30 mb-1">
        Official Edge Verified
      </span>
      <h1 class="text-2xl font-black tracking-tight">${escapeHtml(schoolName)}</h1>
      <p class="text-emerald-100/90 text-sm mt-1">Permanent Cryptographic Record Verified</p>
    </div>

    <!-- Body Information -->
    <div class="p-6 space-y-6">
      <div class="flex items-center justify-between p-4 bg-slate-800/80 rounded-xl border border-slate-700/80">
        <div>
          <span class="text-xs text-slate-400 block font-semibold uppercase">Certificate ID</span>
          <span class="text-lg font-mono font-bold text-emerald-400 tracking-wider">${escapeHtml(certCode)}</span>
        </div>
        <div class="text-right">
          <span class="text-xs text-slate-400 block font-semibold uppercase">Status</span>
          <span class="inline-flex items-center text-emerald-400 font-bold text-sm">
            <span class="w-2 h-2 rounded-full bg-emerald-400 inline-block mr-1.5 animate-ping"></span>
            AUTHENTIC
          </span>
        </div>
      </div>

      <!-- Public Attribute Table -->
      <div class="overflow-hidden rounded-xl border border-slate-800 bg-slate-900/50">
        <table class="w-full text-left border-collapse">
          <tbody>
            ${rowsHtml}
          </tbody>
        </table>
      </div>

      <!-- Action Buttons -->
      <div class="pt-2 flex flex-col sm:flex-row gap-3">
        ${
          pdfLink
            ? `<a href="${escapeHtml(pdfLink)}" target="_blank" rel="noopener noreferrer" class="flex-1 inline-flex items-center justify-center gap-2 bg-blue-600 hover:bg-blue-500 text-white font-semibold py-3 px-5 rounded-xl transition duration-200 shadow-lg shadow-blue-900/40">
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path></svg>
                View Official PDF
               </a>`
            : ""
        }
        <button onclick="window.print()" class="inline-flex items-center justify-center gap-2 bg-slate-800 hover:bg-slate-700 text-slate-200 font-semibold py-3 px-5 rounded-xl border border-slate-700 transition duration-200">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 17h2a2 2 0 002-2v-4a2 2 0 00-2-2H5a2 2 0 00-2 2v4a2 2 0 002 2h2m2 4h6a2 2 0 002-2v-4a2 2 0 00-2-2H9a2 2 0 00-2 2v4a2 2 0 002 2zm8-12V5a2 2 0 00-2-2H9a2 2 0 00-2 2v4h10z"></path></svg>
          Print Record
        </button>
      </div>

      <div class="text-center text-xs text-slate-500 pt-4 border-t border-slate-800/80">
        Secured by CertiBridge Zero-Cost Local-First Architecture &bull; Powered by Cloudflare KV Edge
      </div>
    </div>
  </div>
</body>
</html>`;
}

function renderNotFoundPage(certCode) {
  return `<!DOCTYPE html>
<html lang="en" class="dark">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Certificate Not Found or Revoked</title>
  <script src="https://cdn.tailwindcss.com"></script>
</head>
<body class="bg-slate-950 text-slate-100 min-h-screen flex items-center justify-center p-4">
  <div class="max-w-md w-full bg-slate-900 border border-red-900/60 rounded-2xl shadow-2xl p-8 text-center">
    <div class="w-16 h-16 bg-red-950/60 text-red-500 border border-red-800/60 rounded-full flex items-center justify-center mx-auto mb-4">
      <svg class="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path></svg>
    </div>
    <h1 class="text-xl font-bold text-white mb-2">Certificate Not Found</h1>
    <p class="text-slate-400 text-sm mb-6">The certificate record for <span class="font-mono text-red-400 font-bold">${escapeHtml(certCode)}</span> could not be verified. It may be revoked, invalid, or expired.</p>
    <a href="/" class="inline-block bg-slate-800 hover:bg-slate-700 text-slate-300 px-5 py-2.5 rounded-lg text-sm font-semibold transition">Back to Home</a>
  </div>
</body>
</html>`;
}

function renderErrorPage(msg) {
  return `<!DOCTYPE html><html><body style="background:#0f172a;color:#f8fafc;font-family:sans-serif;padding:40px;"><h2>Edge Verifier Notice</h2><p>${escapeHtml(msg)}</p></body></html>`;
}

function escapeHtml(str) {
  return String(str)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}
