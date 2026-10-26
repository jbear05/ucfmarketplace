const { Resend } = require('resend');

const resend = new Resend(process.env.RESEND_API_KEY);
const FROM   = process.env.EMAIL_FROM || 'KnightMarket <onboarding@resend.dev>';

// Verify/reset links point at the API itself, which renders a small HTML page —
// there's no separate web client in this project.
const SERVER_URL = process.env.SERVER_URL || 'http://localhost:5000';

// Brand — black & gold
const GOLD  = '#D4AF37';
const BLACK = '#0A0A0B';

const sendVerificationEmail = async (to, name, token) => {
  const link = `${SERVER_URL}/api/auth/verify/${token}`;
  await resend.emails.send({
    from:    FROM,
    to,
    subject: 'Verify your KnightMarket account',
    html: `
      <div style="font-family:sans-serif;max-width:520px;margin:auto;padding:32px;background:${BLACK};">
        <h2 style="color:${GOLD};">Welcome to KnightMarket, ${name}! 🛍️</h2>
        <p style="color:#ccc;line-height:1.6;">
          You're one step away from buying and selling with fellow students near campus.
          Click the button below to verify your email address.
        </p>
        <a href="${link}"
           style="display:inline-block;margin:24px 0;padding:14px 32px;
                  background:${GOLD};color:#000;border-radius:8px;
                  text-decoration:none;font-weight:600;">
          Verify My Email
        </a>
        <p style="color:#888;font-size:13px;">
          This link expires in 24 hours. If you didn't create an account, ignore this email.
        </p>
        <hr style="border:none;border-top:1px solid #333;margin:24px 0;">
        <p style="color:#777;font-size:12px;">KnightMarket — Buy & Sell Near Campus</p>
      </div>
    `,
  });
};

const sendPasswordResetEmail = async (to, name, token) => {
  const link = `${SERVER_URL}/api/auth/reset-password/${token}`;
  await resend.emails.send({
    from:    FROM,
    to,
    subject: 'Reset your KnightMarket password',
    html: `
      <div style="font-family:sans-serif;max-width:520px;margin:auto;padding:32px;background:${BLACK};">
        <h2 style="color:${GOLD};">Password Reset Request</h2>
        <p style="color:#ccc;line-height:1.6;">
          Hi ${name}, we received a request to reset your password.
          Click below to set a new one. This link expires in <strong>1 hour</strong>.
        </p>
        <a href="${link}"
           style="display:inline-block;margin:24px 0;padding:14px 32px;
                  background:${GOLD};color:#000;border-radius:8px;
                  text-decoration:none;font-weight:600;">
          Reset My Password
        </a>
        <p style="color:#888;font-size:13px;">
          If you didn't request this, your account is safe — just ignore this email.
        </p>
      </div>
    `,
  });
};

const sendListingExpiredEmail = async (to, name, listingTitle) => {
  const link = `${process.env.CLIENT_URL}/my-listings`;
  await resend.emails.send({
    from:    FROM,
    to,
    subject: `Your listing "${listingTitle}" has expired`,
    html: `
      <div style="font-family:sans-serif;max-width:520px;margin:auto;padding:32px;background:${BLACK};">
        <h2 style="color:${GOLD};">Your listing has gone off market</h2>
        <p style="color:#ccc;line-height:1.6;">
          Hi ${name}, your listing <strong>"${listingTitle}"</strong> has been active for 90 days
          and has automatically moved to <em>Off Market</em> status.
        </p>
        <p style="color:#ccc;line-height:1.6;">
          It's no longer visible in search results. Contact us if you'd like to reactivate it.
        </p>
        <a href="${link}"
           style="display:inline-block;margin:24px 0;padding:14px 32px;
                  background:${GOLD};color:#000;border-radius:8px;
                  text-decoration:none;font-weight:600;">
          View My Listings
        </a>
      </div>
    `,
  });
};

// Listing titles and search names are user-written — escape before putting them in HTML
const escapeHtml = (s) => String(s)
  .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
  .replace(/"/g, '&quot;').replace(/'/g, '&#39;');

const formatPrice = (n) => `$${Number(n).toFixed(2).replace(/\.00$/, '')}`;

// drops: [{ title, oldPrice, newPrice }]
const sendPriceDropEmail = async (to, name, drops) => {
  const rows = drops.map((d) => `
    <li style="margin:8px 0;color:#ccc;">
      <strong style="color:#F5F1E6;">${escapeHtml(d.title)}</strong>:
      <span style="text-decoration:line-through;color:#888;">${formatPrice(d.oldPrice)}</span>
      → <strong style="color:${GOLD};">${formatPrice(d.newPrice)}</strong>
    </li>`).join('');
  await resend.emails.send({
    from:    FROM,
    to,
    subject: drops.length === 1
      ? `Price drop: "${drops[0].title}" is now ${formatPrice(drops[0].newPrice)}`
      : `${drops.length} of your favorites dropped in price`,
    html: `
      <div style="font-family:sans-serif;max-width:520px;margin:auto;padding:32px;background:${BLACK};">
        <h2 style="color:${GOLD};">Price drop on your favorites</h2>
        <p style="color:#ccc;line-height:1.6;">Hi ${escapeHtml(name)}, these listings you favorited just got cheaper:</p>
        <ul style="padding-left:18px;">${rows}</ul>
        <p style="color:#ccc;line-height:1.6;">Open KnightMarket to message the seller.</p>
        <hr style="border:none;border-top:1px solid #333;margin:24px 0;">
        <p style="color:#777;font-size:12px;">
          You're getting this because listing alerts are on. Turn them off in Settings in the app.
        </p>
      </div>
    `,
  });
};

// listings: [{ title, price, campus }]
const sendSavedSearchMatchesEmail = async (to, name, searchLabel, listings) => {
  const rows = listings.slice(0, 10).map((l) => `
    <li style="margin:8px 0;color:#ccc;">
      <strong style="color:#F5F1E6;">${escapeHtml(l.title)}</strong>
      · <span style="color:${GOLD};">${formatPrice(l.price)}</span>
      ${l.campus ? `· ${escapeHtml(l.campus)}` : ''}
    </li>`).join('');
  const more = listings.length > 10 ? `<p style="color:#888;">…and ${listings.length - 10} more.</p>` : '';
  await resend.emails.send({
    from:    FROM,
    to,
    subject: `${listings.length} new match${listings.length === 1 ? '' : 'es'} for "${searchLabel}"`,
    html: `
      <div style="font-family:sans-serif;max-width:520px;margin:auto;padding:32px;background:${BLACK};">
        <h2 style="color:${GOLD};">New listings for "${escapeHtml(searchLabel)}"</h2>
        <p style="color:#ccc;line-height:1.6;">Hi ${escapeHtml(name)}, these just went up and match your saved search:</p>
        <ul style="padding-left:18px;">${rows}</ul>
        ${more}
        <p style="color:#ccc;line-height:1.6;">Open KnightMarket to take a look.</p>
        <hr style="border:none;border-top:1px solid #333;margin:24px 0;">
        <p style="color:#777;font-size:12px;">
          You're getting this because listing alerts are on. Turn them off in Settings in the app,
          or delete the saved search.
        </p>
      </div>
    `,
  });
};

module.exports = {
  sendVerificationEmail,
  sendPasswordResetEmail,
  sendListingExpiredEmail,
  sendPriceDropEmail,
  sendSavedSearchMatchesEmail,
};
