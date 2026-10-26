const cron    = require('node-cron');
const Listing = require('../models/Listing');
const User    = require('../models/User');
const Thread  = require('../models/Thread');
const SavedSearch = require('../models/SavedSearch');
const { buildListingFilter } = require('./listingFilter');
const {
  sendListingExpiredEmail,
  sendPriceDropEmail,
  sendSavedSearchMatchesEmail,
} = require('../utils/email');

/**
 * Emails each favoriter (with alerts on) one digest of favorites whose price
 * dropped since the last run, then clears the drop markers.
 */
const sendPriceDropAlerts = async () => {
  const dropped = await Listing.find({
    priceDroppedAt: { $ne: null },
    status:         { $in: ['active', 'pending'] },
  }).select('_id title price previousPrice owner');

  if (dropped.length > 0) {
    const byId = new Map(dropped.map((l) => [String(l._id), l]));
    const users = await User.find({
      favorites:      { $in: dropped.map((l) => l._id) },
      emailPriceDrop: { $ne: false },
      isBlocked:      { $ne: true },
    }).select('name email favorites');

    for (const user of users) {
      const drops = user.favorites
        .map((id) => byId.get(String(id)))
        .filter((l) => l && String(l.owner) !== String(user._id) && l.previousPrice > l.price)
        .map((l) => ({ title: l.title, oldPrice: l.previousPrice, newPrice: l.price }));
      if (drops.length === 0) continue;
      try {
        await sendPriceDropEmail(user.email, user.name, drops);
      } catch (emailErr) {
        console.error(`[CRON] Price-drop email failed for ${user._id}:`, emailErr.message);
      }
    }
  }

  // Clear every marker (including on listings that went off market) so a
  // drop is only ever announced once
  const cleared = await Listing.updateMany(
    { priceDroppedAt: { $ne: null } },
    { priceDroppedAt: null, previousPrice: null }
  );
  console.log(`[CRON] Price-drop alerts processed for ${cleared.modifiedCount} listing(s).`);
};

/**
 * For each saved search whose owner has alerts on, emails the listings
 * created since the last run that match its filters.
 */
const sendSavedSearchAlerts = async () => {
  const runAt    = new Date();
  const searches = await SavedSearch.find().populate('user', 'name email emailPriceDrop isBlocked');

  for (const search of searches) {
    const user = search.user;
    if (user && user.emailPriceDrop !== false && !user.isBlocked) {
      const filter = {
        ...buildListingFilter(search.toObject().filters || {}),
        createdAt: { $gt: search.lastNotifiedAt, $lte: runAt },
        owner:     { $ne: user._id },
      };
      const matches = await Listing.find(filter)
        .sort({ createdAt: -1 })
        .select('title price campus')
        .lean();
      if (matches.length > 0) {
        try {
          await sendSavedSearchMatchesEmail(user.email, user.name, search.label, matches);
        } catch (emailErr) {
          console.error(`[CRON] Saved-search email failed for ${search._id}:`, emailErr.message);
          continue; // retry these matches on the next run
        }
      }
    }
    search.lastNotifiedAt = runAt;
    await search.save();
  }
  console.log(`[CRON] Saved-search alerts processed for ${searches.length} search(es).`);
};

/**
 * Runs every day at 2:00 AM.
 * Finds active/pending listings past their expiresAt date,
 * sets them to offMarket, notifies the owner, updates thread snapshots.
 */
const startCronJobs = () => {
  cron.schedule('0 2 * * *', async () => {
    console.log('[CRON] Running listing expiry check...');

    try {
      const expired = await Listing.find({
        status:    { $in: ['active', 'pending'] },
        expiresAt: { $lt: new Date() },
      }).populate('owner', 'name email');

      if (expired.length === 0) {
        console.log('[CRON] No listings to expire.');
        return;
      }

      for (const listing of expired) {
        // Set to offMarket
        listing.status = 'offMarket';
        await listing.save();

        // Update listing snapshot in all related threads
        await Thread.updateMany(
          { listing: listing._id },
          { 'listingSnapshot.status': 'offMarket' }
        );

        // Notify the owner via email
        if (listing.owner?.email) {
          try {
            await sendListingExpiredEmail(
              listing.owner.email,
              listing.owner.name,
              listing.title
            );
          } catch (emailErr) {
            console.error(`[CRON] Email failed for listing ${listing._id}:`, emailErr.message);
          }
        }

        console.log(`[CRON] Expired listing: "${listing.title}" (${listing._id})`);
      }

      console.log(`[CRON] Expired ${expired.length} listing(s).`);
    } catch (err) {
      console.error('[CRON] Expiry job failed:', err.message);
    }
  });

  /**
   * Runs hourly.
   * Boosted listings sort above everything else by boostedUntil — once a
   * boost's paid period lapses, clear the field back to null so the listing
   * falls back into normal newest-first order instead of an expired date
   * still outranking un-boosted listings.
   */
  cron.schedule('0 * * * *', async () => {
    try {
      const res = await Listing.updateMany(
        { boostedUntil: { $ne: null, $lt: new Date() } },
        { boostedUntil: null }
      );
      if (res.modifiedCount > 0) {
        console.log(`[CRON] Cleared ${res.modifiedCount} expired boost(s).`);
      }
    } catch (err) {
      console.error('[CRON] Boost cleanup failed:', err.message);
    }
  });

  /**
   * Runs every day at 9:00 AM.
   * Listing alert emails — price drops on favorites and new matches for
   * saved searches. Both respect the user's emailPriceDrop setting.
   */
  cron.schedule('0 9 * * *', async () => {
    console.log('[CRON] Sending listing alerts...');
    try {
      await sendPriceDropAlerts();
    } catch (err) {
      console.error('[CRON] Price-drop alerts failed:', err.message);
    }
    try {
      await sendSavedSearchAlerts();
    } catch (err) {
      console.error('[CRON] Saved-search alerts failed:', err.message);
    }
  });

  console.log('✅ Cron jobs started');
};

module.exports = { startCronJobs, sendPriceDropAlerts, sendSavedSearchAlerts };
