const { PrismaClient } = require('@prisma/client');
const { emitNewNotification } = require('../socket');

const prisma = new PrismaClient();

// How often to check for expired listings. An hour is frequent enough that
// nobody's listing stays wrongly ACTIVE for long after its insurance date
// passes, without hammering the database with a query that (thanks to the
// [status, insuranceValidTill] index on Vehicle in schema.prisma) is cheap
// to run this often anyway.
const SWEEP_INTERVAL_MS = 60 * 60 * 1000; // 1 hour

let sweepInFlight = false;

// Finds every ACTIVE listing whose tracked insurance date has passed,
// flips it to EXPIRED (the same soft-status pattern already used for SOLD
// — never a hard delete, since the seller should be able to fix the
// insurance date and relist rather than losing the listing entirely), and
// notifies whoever owns it. Mirrors the shape of the existing 'sold'
// notification in vehicles.js (PUT /:id/status) — same fields, same
// relatedVehicleId-based navigation on the client.
async function runExpirySweep() {
  // A sweep that's still running (slow DB, huge backlog on first run
  // after deploying this feature) should never overlap with the next
  // scheduled tick — that would mean two concurrent passes both trying to
  // update and notify about the same rows.
  if (sweepInFlight) return;
  sweepInFlight = true;

  try {
    const now = new Date();
    const expired = await prisma.vehicle.findMany({
      where: {
        status: 'ACTIVE',
        insuranceValidTill: { not: null, lt: now },
      },
      select: { id: true, name: true, sellerId: true },
    });

    if (expired.length === 0) return;

    for (const vehicle of expired) {
      await prisma.vehicle.update({
        where: { id: vehicle.id },
        data: { status: 'EXPIRED' },
      });

      // A listing can exist without a sellerId in principle (older seed
      // data) — nobody to notify in that case, and nothing to do beyond
      // the status flip above.
      if (!vehicle.sellerId) continue;

      const notification = await prisma.notification.create({
        data: {
          userId: vehicle.sellerId,
          type: 'expired',
          title: 'Listing paused',
          body: `${vehicle.name}'s insurance has expired, so it's been taken down. Update the insurance date and relist it from My Listings.`,
          relatedVehicleId: vehicle.id,
        },
      });
      emitNewNotification(vehicle.sellerId, notification);
    }

    console.log(`[listingExpiry] took down ${expired.length} listing(s) with expired insurance`);
  } catch (err) {
    // A failed sweep must never crash the server or block the next
    // scheduled attempt — log it and let the next tick try again.
    console.error('[listingExpiry] sweep failed:', err);
  } finally {
    sweepInFlight = false;
  }
}

// Starts the recurring sweep. Called once from index.js after the server
// is listening. The first run is deliberately delayed rather than firing
// at the exact moment the process boots — right at startup is also when
// the database connection pool, socket.io, and everything else is still
// settling, and a failed first attempt (transient, not a real problem)
// would otherwise log a scary-looking error on every single deploy.
function start() {
  setTimeout(runExpirySweep, 10 * 1000);
  setInterval(runExpirySweep, SWEEP_INTERVAL_MS);
}

module.exports = { start, runExpirySweep };