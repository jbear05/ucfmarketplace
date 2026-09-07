/**
 * Tiny server-rendered HTML pages for links that go out in emails
 * (verify email, reset password). There's no separate web client in this
 * project, so the API itself serves these — kept intentionally minimal.
 */

const GOLD  = '#D4AF37';
const BLACK = '#0A0A0B';
const CARD  = '#16151A';

const shell = (bodyHtml) => `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>KnightMarket</title>
  <style>
    body { margin:0; background:${BLACK}; color:#F5F1E6; font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;
           display:flex; align-items:center; justify-content:center; min-height:100vh; padding:24px; box-sizing:border-box; }
    .card { max-width:420px; width:100%; background:${CARD}; border:1px solid #2C2A26; border-radius:16px; padding:32px; text-align:center; }
    h1 { color:${GOLD}; font-size:22px; margin:0 0 12px; }
    p { color:#A8A29E; font-size:14px; line-height:1.6; margin:0 0 8px; }
    input { width:100%; box-sizing:border-box; padding:12px 14px; margin-top:14px; border-radius:10px;
            border:1px solid #2C2A26; background:#1D1B1F; color:#F5F1E6; font-size:15px; }
    button { width:100%; margin-top:18px; padding:14px; border-radius:10px; border:none;
             background:${GOLD}; color:#000; font-weight:600; font-size:15px; cursor:pointer; }
    .error { color:#FF6B6B; font-size:13px; margin-top:10px; }
  </style>
</head>
<body>
  <div class="card">${bodyHtml}</div>
</body>
</html>`;

const renderMessagePage = ({ heading, message, isError = false }) => shell(`
  <h1 style="${isError ? 'color:#FF6B6B;' : ''}">${heading}</h1>
  <p>${message}</p>
`);

const renderResetPasswordForm = ({ token, error }) => shell(`
  <h1>Reset your password</h1>
  <p>Enter a new password for your KnightMarket account.</p>
  <form method="POST" action="/api/auth/reset-password/${token}">
    <input type="password" name="password" placeholder="New password (min 8 characters, 1 number)"
           required minlength="8" pattern=".*\d.*" title="At least 8 characters, with a number">
    <button type="submit">Reset Password</button>
  </form>
  ${error ? `<p class="error">${error}</p>` : ''}
`);

module.exports = { renderMessagePage, renderResetPasswordForm };
