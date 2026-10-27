/**
 * CertiBridge - Google Apps Script Email Receipt Dispatcher
 * Deployed as a Web App on the educator / institution Google Account ($0 Operational Cost).
 * Executes MailApp.sendEmail for verified certificate summaries.
 */

function doPost(e) {
  try {
    const requestData = JSON.parse(e.postData.contents);
    const recipientEmail = requestData.recipient_email;
    const certCode = requestData.cert_code || "N/A";
    const fields = requestData.fields || {};
    const pdfLink = requestData.pdf_link || null;
    const schoolName = requestData.school_name || "CertiBridge Verified Institution";

    if (!recipientEmail || recipientEmail.indexOf("@") === -1) {
      return ContentService.createTextOutput(
        JSON.stringify({ success: false, error: "Invalid recipient email" })
      ).setMimeType(ContentService.MimeType.JSON);
    }

    // Build HTML email template
    let attributesHtml = "";
    for (const [key, val] of Object.entries(fields)) {
      attributesHtml += `
        <tr>
          <td style="padding: 8px 12px; font-weight: 600; color: #475569; border-bottom: 1px solid #e2e8f0; font-size: 13px; text-transform: uppercase;">
            ${escapeHtml(key.replace(/_/g, ' '))}
          </td>
          <td style="padding: 8px 12px; color: #0f172a; border-bottom: 1px solid #e2e8f0; font-size: 14px; font-weight: 500;">
            ${escapeHtml(String(val))}
          </td>
        </tr>`;
    }

    const htmlBody = `
      <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; max-width: 580px; margin: 0 auto; background: #ffffff; border: 1px solid #cbd5e1; border-radius: 12px; overflow: hidden;">
        <div style="background: linear-gradient(135deg, #1e3a8a, #0f172a); padding: 28px 24px; text-align: center; color: #ffffff;">
          <h1 style="margin: 0; font-size: 22px; font-weight: 800; letter-spacing: -0.5px;">${escapeHtml(schoolName)}</h1>
          <p style="margin: 6px 0 0; font-size: 13px; color: #93c5fd;">Official Certificate Verification Receipt</p>
        </div>
        
        <div style="padding: 24px;">
          <div style="background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 8px; padding: 14px; margin-bottom: 20px; text-align: center;">
            <span style="font-size: 11px; font-weight: 700; color: #64748b; text-transform: uppercase; letter-spacing: 1px; display: block;">Verification Status</span>
            <span style="color: #059669; font-weight: 800; font-size: 16px;">✓ AUTHENTIC & VERIFIED</span>
            <div style="margin-top: 6px; font-family: monospace; font-size: 14px; color: #1e293b; font-weight: 600;">ID: ${escapeHtml(certCode)}</div>
          </div>

          <table style="width: 100%; border-collapse: collapse; margin-bottom: 24px;">
            <tbody>
              ${attributesHtml}
            </tbody>
          </table>

          ${
            pdfLink
              ? `<div style="text-align: center; margin-bottom: 24px;">
                  <a href="${escapeHtml(pdfLink)}" style="background: #2563eb; color: #ffffff; text-decoration: none; padding: 12px 24px; font-size: 14px; font-weight: 600; border-radius: 8px; display: inline-block;">
                    View Official Certificate PDF
                  </a>
                </div>`
              : ""
          }

          <div style="border-top: 1px solid #e2e8f0; padding-top: 16px; font-size: 11px; color: #94a3b8; text-align: center; line-height: 1.5;">
            This email was automatically dispatched by the issuing institution via CertiBridge.<br>
            Timestamp: ${new Date().toUTCString()}
          </div>
        </div>
      </div>
    `;

    MailApp.sendEmail({
      to: recipientEmail,
      subject: `Official Verification Record: ${certCode} - ${schoolName}`,
      htmlBody: htmlBody,
    });

    return ContentService.createTextOutput(
      JSON.stringify({ success: true, message: "Receipt sent successfully" })
    ).setMimeType(ContentService.MimeType.JSON);
  } catch (error) {
    return ContentService.createTextOutput(
      JSON.stringify({ success: false, error: error.toString() })
    ).setMimeType(ContentService.MimeType.JSON);
  }
}

function escapeHtml(text) {
  return String(text)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}
