const cron    = require('node-cron');
const Listing = require('../models/Listing');
const User    = require('../models/User');
const Thread  = require('../models/Thread');
const { sendListingExpiredEmail } = require('../utils/email');

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

  console.log('✅ Cron jobs started');
};

module.exports = { startCronJobs };
