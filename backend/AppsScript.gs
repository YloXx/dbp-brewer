/**
 * Grntly Brewer — inventory ingest Web App (Google Apps Script)
 * ---------------------------------------------------------------------------
 * Receives signed JSON reports from each Mac's report.sh and upserts one row
 * per serial number into a Google Sheet. Admins read the sheet directly.
 *
 * SETUP
 *  1. Create a Google Sheet, note its ID.
 *  2. Extensions > Apps Script, paste this file.
 *  3. Project Settings > Script properties, add:
 *       SHEET_ID        = <the sheet id>
 *       SHARED_SECRET   = <same long random string as agent.conf>
 *  4. Deploy > New deployment > type "Web app":
 *       Execute as: Me
 *       Who has access: Anyone  (auth is enforced by the HMAC signature)
 *  5. Copy the /exec URL into agent.conf as GRNTLY_ENDPOINT.
 *
 * SECURITY: requests are authenticated by verifying the X-Grntly-Signature
 * header (HMAC-SHA256 of the raw body) against SHARED_SECRET. Unsigned or
 * mismatched requests are rejected with 401. "Anyone" access is safe because
 * without the secret no valid signature can be produced.
 */

var HEADERS = [
  'serial', 'hostname', 'user', 'model', 'os_version', 'os_build',
  'filevault', 'firewall', 'gatekeeper', 'free_gb', 'uptime',
  'brew_outdated_count', 'brew_outdated', 'reported_at'
];

function doPost(e) {
  try {
    var props = PropertiesService.getScriptProperties();
    var secret = props.getProperty('SHARED_SECRET');
    var sheetId = props.getProperty('SHEET_ID');
    if (!secret || !sheetId) {
      return _json(500, { error: 'Server not configured' });
    }

    var body = e.postData ? e.postData.contents : '';
    // Apps Script cannot read custom headers, so the signature arrives as the
    // "sig" query parameter: sig=sha256=<hex>.
    var provided = (e.parameter && e.parameter.sig) ? e.parameter.sig : '';
    if (!_verify(body, provided, secret)) {
      return _json(401, { error: 'Invalid signature' });
    }

    var data = JSON.parse(body);
    if (!data.serial) {
      return _json(400, { error: 'Missing serial' });
    }

    _upsert(sheetId, data);
    return _json(200, { ok: true, serial: data.serial });
  } catch (err) {
    return _json(500, { error: String(err) });
  }
}

/** Constant-time-ish HMAC verification. */
function _verify(body, providedHeader, secret) {
  if (!providedHeader) return false;
  var expected = _hmacHex(body, secret);
  var provided = providedHeader.replace(/^sha256=/, '');
  if (provided.length !== expected.length) return false;
  var diff = 0;
  for (var i = 0; i < expected.length; i++) {
    diff |= provided.charCodeAt(i) ^ expected.charCodeAt(i);
  }
  return diff === 0;
}

function _hmacHex(message, secret) {
  var raw = Utilities.computeHmacSha256Signature(message, secret);
  return raw.map(function (b) {
    var v = (b < 0 ? b + 256 : b).toString(16);
    return v.length === 1 ? '0' + v : v;
  }).join('');
}

/** Insert a new row or update the existing row for this serial. */
function _upsert(sheetId, data) {
  var lock = LockService.getScriptLock();
  lock.waitLock(20000);
  try {
    var ss = SpreadsheetApp.openById(sheetId);
    var sheet = ss.getSheetByName('devices') || ss.insertSheet('devices');
    if (sheet.getLastRow() === 0) {
      sheet.appendRow(HEADERS);
    }
    var row = HEADERS.map(function (h) {
      return data[h] !== undefined && data[h] !== null ? data[h] : '';
    });

    var serials = sheet.getRange(2, 1, Math.max(sheet.getLastRow() - 1, 1), 1).getValues();
    var found = -1;
    for (var i = 0; i < serials.length; i++) {
      if (serials[i][0] === data.serial) { found = i + 2; break; }
    }
    if (found > 0) {
      sheet.getRange(found, 1, 1, HEADERS.length).setValues([row]);
    } else {
      sheet.appendRow(row);
    }
  } finally {
    lock.releaseLock();
  }
}

function _json(code, obj) {
  return ContentService
    .createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}
