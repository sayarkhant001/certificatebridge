/**
 * CertiBridge - Google Apps Script Bridge & Email Receipt Dispatcher
 * Deployed as a Web App on the educator / institution Google Account ($0 Operational Cost).
 * Handles:
 * 1. Health check & user verification ('ping')
 * 2. Uploading Certificate PDFs directly to Google Drive ('upload_cert')
 * 3. Reading and writing student rosters in Google Sheets ('read_sheet', 'write_sheet')
 * 4. Dispatching verified email receipts via MailApp.sendEmail ('send_email')
 */

function doGet(e) {
  return ContentService.createTextOutput(
    JSON.stringify({
      success: true,
      service: "CertiBridge Google Cloud Bridge",
      status: "active",
      user: Session.getActiveUser().getEmail() || "Connected User"
    })
  ).setMimeType(ContentService.MimeType.JSON);
}

function doPost(e) {
  try {
    const requestData = JSON.parse(e.postData.contents);
    const action = requestData.action || (requestData.recipient_email ? "send_email" : "ping");

    // 1. Health Check & Account Identity
    if (action === "ping") {
      const email = Session.getActiveUser().getEmail() || "Connected Google Account";
      return jsonResponse({ success: true, email: email, message: "CertiBridge Bridge Connected" });
    }

    // 2. Upload Certificate PDF to Google Drive
    if (action === "upload_cert") {
      const fileName = requestData.file_name || "Certificate.pdf";
      const base64Data = requestData.base64_pdf;
      const folderName = requestData.folder_name || "CertiBridge Certificates";

      if (!base64Data) {
        return jsonResponse({ success: false, error: "Missing base64_pdf data" });
      }

      // Find or create target folder
      const folders = DriveApp.getFoldersByName(folderName);
      let folder;
      if (folders.hasNext()) {
        folder = folders.next();
      } else {
        folder = DriveApp.createFolder(folderName);
      }

      const decodedBytes = Utilities.base64Decode(base64Data);
      const blob = Utilities.newBlob(decodedBytes, "application/pdf", fileName);
      const file = folder.createFile(blob);
      file.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.VIEW);

      return jsonResponse({
        success: true,
        file_id: file.getId(),
        file_name: fileName,
        view_url: file.getUrl(),
        download_url: file.getDownloadUrl()
      });
    }

    // 3. List Worksheets / Pages inside a Google Sheet
    if (action === "list_sheets") {
      const spreadsheetId = requestData.spreadsheet_id;
      if (!spreadsheetId) {
        return jsonResponse({ success: false, error: "Missing spreadsheet_id" });
      }
      const ss = SpreadsheetApp.openById(spreadsheetId);
      const sheets = ss.getSheets().map(function(s) {
        return {
          name: s.getName(),
          sheet_id: s.getSheetId(),
          rows: s.getLastRow(),
          cols: s.getLastColumn()
        };
      });
      return jsonResponse({
        success: true,
        title: ss.getName(),
        sheets: sheets
      });
    }

    // 4. List Google Spreadsheets from Google Drive
    if (action === "list_drive_spreadsheets") {
      const query = requestData.query || "";
      const files = DriveApp.getFilesByType(MimeType.GOOGLE_SHEETS);
      const list = [];
      let count = 0;
      while (files.hasNext() && count < 50) {
        const file = files.next();
        if (!query || file.getName().toLowerCase().indexOf(query.toLowerCase()) !== -1) {
          list.push({
            id: file.getId(),
            name: file.getName(),
            url: file.getUrl(),
            last_updated: file.getLastUpdated().toISOString()
          });
          count++;
        }
      }
      return jsonResponse({ success: true, files: list });
    }

    // 5. Read Google Sheet Dataset
    if (action === "read_sheet") {
      const spreadsheetId = requestData.spreadsheet_id;
      const sheetName = requestData.sheet_name;

      if (!spreadsheetId) {
        return jsonResponse({ success: false, error: "Missing spreadsheet_id" });
      }

      const ss = SpreadsheetApp.openById(spreadsheetId);
      const sheet = sheetName ? ss.getSheetByName(sheetName) : ss.getSheets()[0];
      const data = sheet.getDataRange().getValues();

      if (data.length === 0) {
        return jsonResponse({ success: true, headers: [], rows: [] });
      }

      const headers = data[0];
      const rows = [];
      for (let i = 1; i < data.length; i++) {
        const rowObj = {};
        for (let j = 0; j < headers.length; j++) {
          rowObj[String(headers[j])] = data[i][j];
        }
        rows.push(rowObj);
      }

      return jsonResponse({ success: true, headers: headers, rows: rows });
    }

    // 4. Write Back to Google Sheet
    if (action === "write_sheet") {
      const spreadsheetId = requestData.spreadsheet_id;
      const sheetName = requestData.sheet_name;
      const rowIndex = requestData.row_index; // 1-indexed
      const updates = requestData.updates || {};

      if (!spreadsheetId || !rowIndex) {
        return jsonResponse({ success: false, error: "Missing spreadsheet_id or row_index" });
      }

      const ss = SpreadsheetApp.openById(spreadsheetId);
      const sheet = sheetName ? ss.getSheetByName(sheetName) : ss.getSheets()[0];
      const headers = sheet.getRange(1, 1, 1, sheet.getLastColumn()).getValues()[0];

      for (const [colName, val] of Object.entries(updates)) {
        let colIdx = headers.indexOf(colName) + 1;
        if (colIdx === 0) {
          // Append new column header
          colIdx = headers.length + 1;
          sheet.getRange(1, colIdx).setValue(colName);
          headers.push(colName);
        }
        sheet.getRange(rowIndex, colIdx).setValue(val);
      }

      return jsonResponse({ success: true });
    }

    // 5. Send Email Verification Receipt
    if (action === "send_email") {
      const recipientEmail = requestData.recipient_email;
      const certCode = requestData.cert_code || "N/A";
      const fields = requestData.fields || {};
      const pdfLink = requestData.pdf_link || null;
      const schoolName = requestData.school_name || "CertiBridge Verified Institution";

      if (!recipientEmail || recipientEmail.indexOf("@") === -1) {
        return jsonResponse({ success: false, error: "Invalid recipient email" });
      }

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

      return jsonResponse({ success: true, message: "Receipt sent successfully" });
    }

    return jsonResponse({ success: false, error: "Unrecognized action: " + action });
  } catch (error) {
    return jsonResponse({ success: false, error: error.toString() });
  }
}

function jsonResponse(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}

function escapeHtml(text) {
  return String(text)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}
