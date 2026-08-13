const express = require('express');
const { body, query, validationResult } = require('express-validator');
const { PrismaClient } = require('@prisma/client');
const { authenticate, optionalAuth } = require('../middleware/auth');
const { emitNewNotification } = require('../socket');

const router = express.Router();
const prisma = new PrismaClient();

// Upper limit on featured slots once the catalog is large enough. Below
// that, the actual count is scaled to the catalog size (see getFeaturedIds)
// so "Featured" never degenerates into "literally everything" on a small
// catalog — with only 6 active listings, showing all 6 as "Featured" is
// meaningless; showing 3 is a genuine top slice.
const MAX_FEATURED_COUNT = 8;

function formatPrice(amount) {
  if (amount >= 100000) {
    const lakhs = amount / 100000;
    return `₹${lakhs % 1 === 0 ? lakhs.toFixed(0) : lakhs.toFixed(1)}L`;
  }
  if (amount >= 1000) {
    const thousands = amount / 1000;
    return `₹${thousands % 1 === 0 ? thousands.toFixed(0) : thousands.toFixed(1)}K`;
  }
  return `₹${amount}`;
}

// The discount badge must always be a true reflection of price vs
// originalPrice — never a separately-editable number a seller could type in
// directly, since that could drift out of sync with reality (e.g. price
// changes later but the badge doesn't, or a seller just makes up "50% off").
// Returns null (no badge) unless originalPrice is a genuine, larger number.
function computeDiscountPercent(price, originalPrice) {
  if (!originalPrice || originalPrice <= price) return null;
  return Math.round(((originalPrice - price) / originalPrice) * 100);
}

// Parses the optional insuranceValidTill date the client sends (an ISO
// string from Flutter's DateTime.toIso8601String()). express-validator's
// isISO8601() check below already guarantees the format is well-formed by
// the time this runs, so this is just the parse — but still returns null
// rather than an Invalid Date on anything unparseable, since a bad date
// silently corrupting the expiry sweep's query would be far worse than
// just not tracking one.
function parseInsuranceValidTill(value) {
  if (!value) return null;
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

// "Featured" is a LIVE ranking, not a stored flag: most-favorited active
// listings first, then highest-rated, then most recently listed as a
// tiebreaker (so a brand-new listing with zero favorites yet still gets a
// fair shot while the catalog is small). Recomputed on every call — there's
// no batch job, no delay, and no seller is ever locked out of ever earning
// it.
//
// How many vehicles actually get the badge scales with catalog size: half
// the active catalog (rounded up), capped at MAX_FEATURED_COUNT, minimum 1.
// Without this, a small catalog (e.g. 6 active listings) would put all 6 in
// the "top 8" — every single vehicle badged "Featured," which is
// meaningless. This way "Featured" always stays a genuine top slice,
// however big the catalog is.
async function getFeaturedIds() {
  const totalActive = await prisma.vehicle.count({ where: { status: 'ACTIVE' } });
  if (totalActive === 0) return new Set();

  const featuredCount = Math.min(MAX_FEATURED_COUNT, Math.max(1, Math.ceil(totalActive / 2)));

  const top = await prisma.vehicle.findMany({
    where: { status: 'ACTIVE' },
    orderBy: [
      { favorites: { _count: 'desc' } },
      { createdAt: 'desc' },
    ],
    take: featuredCount,
    select: { id: true },
  });
  return new Set(top.map((v) => v.id));
}

// "N Sold" is a LIVE count of how many vehicles this SELLER has actually
// completed a sale on (status = SOLD across all their listings) — not the
// old `soldCount` column, which was just a static "0" written once at
// creation and never touched again anywhere in the codebase. A single
// listing can't be "sold" more than once, so a per-listing counter never
// made sense here in the first place; what buyers actually want to see is
// "has this seller sold vehicles before" as a trust signal, computed fresh
// every time, the same way isFeatured already is.
//
// Batched with groupBy across every seller appearing in a given response,
// instead of one query per vehicle, so listing a page of 20 vehicles from
// 15 different sellers costs one extra query, not fifteen.
async function getSoldCountsBySeller(sellerIds) {
  const uniqueIds = [...new Set(sellerIds.filter(Boolean))];
  if (uniqueIds.length === 0) return new Map();

  const counts = await prisma.vehicle.groupBy({
    by: ['sellerId'],
    where: { sellerId: { in: uniqueIds }, status: 'SOLD' },
    _count: { _all: true },
  });
  return new Map(counts.map((c) => [c.sellerId, c._count._all]));
}

function toVehicleResponse(vehicle, favoriteIds = new Set(), featuredIds = new Set(), soldCountsBySeller = new Map()) {
  return {
    id: vehicle.id,
    name: vehicle.name,
    category: vehicle.category,
    images: vehicle.images,
    price: formatPrice(vehicle.price),
    priceAmount: vehicle.price,
    originalPrice: vehicle.originalPrice ? formatPrice(vehicle.originalPrice) : null,
    // Raw integer, alongside the formatted string above (same pattern as
    // price/priceAmount). Without this, the only way to prefill the Edit
    // form's Original Price field would be parsing the rounded display
    // string ("₹13.4L") back into a number — lossy, and could silently
    // change the value on every re-save.
    originalPriceAmount: vehicle.originalPrice,
    discountPercent: vehicle.discountPercent,
    isFeatured: featuredIds.has(vehicle.id),
    // Deliberately no per-vehicle `rating` field here anymore — see the
    // comment on Dealer.reviews in schema.prisma for why a listing was
    // never a valid thing to rate in the first place. Only Dealer has a
    // rating now, computed live in dealers.js from real Review rows.
    isFavorite: favoriteIds.has(vehicle.id),
    fuelType: vehicle.fuelType,
    transmission: vehicle.transmission,
    year: vehicle.year,
    seats: vehicle.seats,
    kmDriven: vehicle.kmDriven,
    owners: vehicle.owners,
    condition: vehicle.condition,
    insurance: vehicle.insurance,
    // ISO string (or null) — the machine-checkable counterpart to the
    // `insurance` display string above. SellVehicleScreen (Flutter) reads
    // this to prefill the date picker in edit mode, rather than
    // re-parsing "Valid till 12 Dec 2027" back into a Date, which is
    // exactly the kind of lossy round-trip that quietly breaks later.
    insuranceValidTill: vehicle.insuranceValidTill,
    rcStatus: vehicle.rcStatus,
    // String, to match the existing frontend model (VehicleModel.soldCount
    // is a String) — same live-computed value, just formatted the way the
    // client already expects it, so no Dart-side changes are needed.
    soldCount: String(vehicle.sellerId ? soldCountsBySeller.get(vehicle.sellerId) || 0 : 0),
    description: vehicle.description,
    location: vehicle.location,
    dealerId: vehicle.dealerId,
    dealerName: vehicle.dealer?.name || 'Independent Seller',
    sellerId: vehicle.sellerId,
    sellerName: vehicle.sellerName,
    sellerPhone: vehicle.sellerPhone,
    sellerAvatar: vehicle.sellerAvatar || 'assets/images/avatars/profile.png',
    dealerVerified: vehicle.dealerVerified,
    status: vehicle.status,
    createdAt: vehicle.createdAt,
  };
}

router.get('/', optionalAuth, async (req, res) => {
  const { q, category, featured, sort, limit } = req.query;

  const where = { status: 'ACTIVE' };
  if (category && category !== 'All') where.category = category;
  if (q) {
    where.OR = [
      { name: { contains: q, mode: 'insensitive' } },
      { location: { contains: q, mode: 'insensitive' } },
      { description: { contains: q, mode: 'insensitive' } },
      { category: { contains: q, mode: 'insensitive' } },
    ];
  }

  const featuredIds = await getFeaturedIds();
  const isFeaturedRequest = featured === 'true';
  if (isFeaturedRequest) {
    // Scope down to exactly the current top-N ranking (still respecting
    // any category/search filter also passed in), rather than a separate
    // stored flag that could disagree with the ranking.
    where.id = { in: [...featuredIds] };
  }

  let orderBy = { createdAt: 'desc' };
  if (sort === 'price_asc') orderBy = { price: 'asc' };
  if (sort === 'price_desc') orderBy = { price: 'desc' };
  if (sort === 'year_desc') orderBy = { year: 'desc' };
  // Preserve the actual featured ranking order (most-favorited first) when
  // browsing the Featured section itself, rather than falling back to
  // newest-first for a set that's supposed to be favorite-count-ordered.
  if (isFeaturedRequest && !sort) {
    orderBy = [
      { favorites: { _count: 'desc' } },
      { createdAt: 'desc' },
    ];
  }

  const vehicles = await prisma.vehicle.findMany({
    where,
    orderBy,
    take: limit ? parseInt(limit, 10) : (isFeaturedRequest ? featuredIds.size : undefined),
    include: { dealer: true },
  });

  let favoriteIds = new Set();
  if (req.user) {
    const favs = await prisma.favorite.findMany({
      where: { userId: req.user.id },
      select: { vehicleId: true },
    });
    favoriteIds = new Set(favs.map((f) => f.vehicleId));
  }

  const soldCountsBySeller = await getSoldCountsBySeller(vehicles.map((v) => v.sellerId));

  res.json({ vehicles: vehicles.map((v) => toVehicleResponse(v, favoriteIds, featuredIds, soldCountsBySeller)) });
});

router.get('/user/my-listings', authenticate, async (req, res) => {
  const vehicles = await prisma.vehicle.findMany({
    where: { sellerId: req.user.id },
    orderBy: { createdAt: 'desc' },
    include: { dealer: true },
  });
  const featuredIds = await getFeaturedIds();
  const soldCountsBySeller = await getSoldCountsBySeller(vehicles.map((v) => v.sellerId));
  res.json({ vehicles: vehicles.map((v) => toVehicleResponse(v, new Set(), featuredIds, soldCountsBySeller)) });
});

router.get('/:id', optionalAuth, async (req, res) => {
  const vehicle = await prisma.vehicle.findUnique({
    where: { id: req.params.id },
    include: { dealer: true },
  });

  if (!vehicle) {
    return res.status(404).json({ error: 'Vehicle not found' });
  }

  let favoriteIds = new Set();
  if (req.user) {
    const fav = await prisma.favorite.findUnique({
      where: { userId_vehicleId: { userId: req.user.id, vehicleId: vehicle.id } },
    });
    if (fav) favoriteIds.add(vehicle.id);
  }

  const featuredIds = await getFeaturedIds();
  const soldCountsBySeller = await getSoldCountsBySeller([vehicle.sellerId]);
  res.json({ vehicle: toVehicleResponse(vehicle, favoriteIds, featuredIds, soldCountsBySeller) });
});

router.post(
  '/',
  authenticate,
  [
    body('name').trim().notEmpty(),
    body('category').trim().notEmpty(),
    body('price').isInt({ min: 1000 }),
    body('originalPrice').optional({ values: 'falsy' }).isInt({ min: 1000 }),
    body('fuelType').trim().notEmpty(),
    body('transmission').trim().notEmpty(),
    body('year').trim().notEmpty(),
    body('description').trim().notEmpty(),
    body('location').trim().notEmpty(),
    body('sellerPhone').trim().notEmpty(),
    body('insuranceValidTill').optional({ values: 'falsy' }).isISO8601(),
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const data = req.body;
    const price = parseInt(data.price, 10);
    const originalPrice = data.originalPrice ? parseInt(data.originalPrice, 10) : null;
    const insuranceValidTill = parseInsuranceValidTill(data.insuranceValidTill);

    if (originalPrice !== null && originalPrice <= price) {
      return res.status(400).json({
        error: 'Original price must be higher than the current price for a discount to make sense.',
      });
    }

    const vehicle = await prisma.vehicle.create({
      data: {
        name: data.name,
        category: data.category,
        images: data.images?.length ? data.images : ['assets/images/cars/placeholder.png'],
        price,
        originalPrice,
        // Never trust a client-supplied discountPercent — always derive it
        // from price/originalPrice so it can never say something untrue.
        discountPercent: computeDiscountPercent(price, originalPrice),
        fuelType: data.fuelType,
        transmission: data.transmission,
        year: data.year,
        seats: data.seats || '5',
        kmDriven: data.kmDriven || '0 km',
        owners: data.owners || '1 Owner',
        condition: data.condition || 'Good',
        insurance: data.insurance || 'Valid',
        insuranceValidTill,
        rcStatus: data.rcStatus || 'Clear',
        description: data.description,
        location: data.location,
        sellerName: req.user.name,
        sellerPhone: data.sellerPhone || req.user.phone || '',
        sellerAvatar: req.user.avatar || 'assets/images/avatars/profile.png',
        sellerId: req.user.id,
        // FIX (security): this used to be `data.dealerId || null` — taken
        // straight from client input with no check at all. Any signed-in
        // user could send any real dealer's id and have their listing show
        // up under that dealer's profile, verified badge and all, with
        // nothing to stop them. Dealer affiliation is now an account-level
        // fact (User.dealerId, set only by seed data / a future admin
        // action — never by this endpoint), so a listing can only ever be
        // attributed to the dealer the authenticated seller is actually
        // linked to. An individual seller's req.user.dealerId is null,
        // so their listings correctly get dealerId: null no matter what
        // the client sends.
        dealerId: req.user.dealerId || null,
        status: 'ACTIVE',
      },
      include: { dealer: true },
    });

    // A brand-new listing is never in the top ranking yet (zero
    // favorites), so isFeatured is correctly false here — it can earn a
    // spot the moment it gets favorited, rated, or simply as newer
    // listings push older zero-favorite ones down the recency tiebreaker.
    const soldCountsBySeller = await getSoldCountsBySeller([vehicle.sellerId]);
    res.status(201).json({
      vehicle: toVehicleResponse(vehicle, new Set(), await getFeaturedIds(), soldCountsBySeller),
    });
  }
);

router.put(
  '/:id',
  authenticate,
  [
    body('name').trim().notEmpty(),
    body('category').trim().notEmpty(),
    body('price').isInt({ min: 1000 }),
    body('originalPrice').optional({ values: 'falsy' }).isInt({ min: 1000 }),
    body('fuelType').trim().notEmpty(),
    body('transmission').trim().notEmpty(),
    body('year').trim().notEmpty(),
    body('description').trim().notEmpty(),
    body('location').trim().notEmpty(),
    body('sellerPhone').trim().notEmpty(),
    body('insuranceValidTill').optional({ values: 'falsy' }).isISO8601(),
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const existing = await prisma.vehicle.findUnique({ where: { id: req.params.id } });
    if (!existing) {
      return res.status(404).json({ error: 'Vehicle not found' });
    }
    // Only the seller who created this listing may edit it — never trust
    // the client, always check ownership against the authenticated user.
    if (existing.sellerId !== req.user.id) {
      return res.status(403).json({ error: 'You can only edit your own listings' });
    }

    const data = req.body;
    const price = parseInt(data.price, 10);
    const originalPrice = data.originalPrice ? parseInt(data.originalPrice, 10) : null;
    // Whatever the form sends replaces the old value outright, including
    // an explicit null (insurance status changed away from "Valid", or
    // the date field was cleared) — same "no partial-keep" treatment as
    // every other field on this route, rather than falling back to
    // `existing.insuranceValidTill` the way a plain omitted-field default
    // would, which could leave a stale expiry date attached to a listing
    // whose insurance status no longer says "Valid" at all.
    const insuranceValidTill = parseInsuranceValidTill(data.insuranceValidTill);

    if (originalPrice !== null && originalPrice <= price) {
      return res.status(400).json({
        error: 'Original price must be higher than the current price for a discount to make sense.',
      });
    }

    // dealerId is deliberately never touched here either — same reasoning
    // as create: it's an account-level fact, not something a listing edit
    // can change. Leaving it out of the update data means Prisma keeps
    // whatever the listing already had.
    const vehicle = await prisma.vehicle.update({
      where: { id: req.params.id },
      data: {
        name: data.name,
        category: data.category,
        images: data.images?.length ? data.images : existing.images,
        price,
        originalPrice,
        discountPercent: computeDiscountPercent(price, originalPrice),
        fuelType: data.fuelType,
        transmission: data.transmission,
        year: data.year,
        seats: data.seats || existing.seats,
        kmDriven: data.kmDriven || existing.kmDriven,
        owners: data.owners || existing.owners,
        condition: data.condition || existing.condition,
        insurance: data.insurance || existing.insurance,
        insuranceValidTill,
        rcStatus: data.rcStatus || existing.rcStatus,
        description: data.description,
        location: data.location,
        sellerPhone: data.sellerPhone || req.user.phone || existing.sellerPhone,
      },
      include: { dealer: true },
    });

    // Notify everyone who favorited this vehicle when the price actually
    // drops — the "price_drop" entries in their Notifications tab. Only
    // fires on a genuine decrease, and never notifies the seller about
    // their own listing.
    if (price < existing.price) {
      const favorites = await prisma.favorite.findMany({
        where: { vehicleId: req.params.id, userId: { not: req.user.id } },
      });
      for (const fav of favorites) {
        const notification = await prisma.notification.create({
          data: {
            userId: fav.userId,
            type: 'price_drop',
            title: 'Price drop',
            body: `${vehicle.name} is now ${formatPrice(vehicle.price)} (was ${formatPrice(existing.price)})`,
            relatedVehicleId: vehicle.id,
          },
        });
        emitNewNotification(fav.userId, notification);
      }
    }

    const favoriteRow = await prisma.favorite.findUnique({
      where: { userId_vehicleId: { userId: req.user.id, vehicleId: vehicle.id } },
    });
    const featuredIds = await getFeaturedIds();
    const soldCountsBySeller = await getSoldCountsBySeller([vehicle.sellerId]);
    res.json({
      vehicle: toVehicleResponse(
        vehicle,
        favoriteRow ? new Set([vehicle.id]) : new Set(),
        featuredIds,
        soldCountsBySeller
      ),
    });
  }
);

// Lets a seller mark their own listing as sold (or relist it back to
// active) — this is what actually makes "N Sold" move off zero. Nothing
// anywhere else in the codebase ever set status to SOLD before this route
// existed, so the count could never have changed no matter how many
// vehicles anyone "sold" through the app.
router.put(
  '/:id/status',
  authenticate,
  [body('status').isIn(['ACTIVE', 'SOLD'])],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const existing = await prisma.vehicle.findUnique({ where: { id: req.params.id } });
    if (!existing) {
      return res.status(404).json({ error: 'Vehicle not found' });
    }
    if (existing.sellerId !== req.user.id) {
      return res.status(403).json({ error: 'You can only update your own listings' });
    }

    // A relist (→ ACTIVE) is blocked while the listing's tracked
    // insurance date is still in the past — otherwise this would just
    // reactivate it for the few minutes until the next expiry sweep
    // (services/listingExpiry.js) took it straight back down again,
    // which is confusing and pointless. This applies whether the listing
    // got here via the sweep (status already EXPIRED) or was simply
    // ACTIVE the whole time with a stale date nobody noticed — either
    // way, "relist" only means something once the underlying problem
    // (an expired insurance date) is actually fixed via Edit first.
    // Listings with no tracked date at all (insuranceValidTill: null —
    // insurance status "Expired"/"Not Available", or never set) are
    // unaffected; there's nothing here to be stale.
    if (req.body.status === 'ACTIVE' && existing.insuranceValidTill && existing.insuranceValidTill < new Date()) {
      return res.status(400).json({
        error: 'This listing\'s insurance date has passed. Update it via Edit before relisting.',
      });
    }

    const vehicle = await prisma.vehicle.update({
      where: { id: req.params.id },
      data: { status: req.body.status },
      include: { dealer: true },
    });

    // Tell everyone who favorited this vehicle that it's gone, the moment
    // it actually goes — same reasoning, and the same shape, as the
    // price-drop notification below in PUT /:id: someone who bothered to
    // save a listing deserves to know why it silently vanished off their
    // Favorites tab, instead of just disappearing with no explanation.
    // Only fires on a genuine ACTIVE→SOLD transition (never on a re-save
    // that leaves status unchanged, and never on a relist back to ACTIVE —
    // that's a "welcome back," not a "sold" event, and isn't what anyone
    // favorited it hoping to hear).
    if (req.body.status === 'SOLD' && existing.status !== 'SOLD') {
      const favorites = await prisma.favorite.findMany({
        where: { vehicleId: req.params.id, userId: { not: req.user.id } },
      });
      for (const fav of favorites) {
        const notification = await prisma.notification.create({
          data: {
            userId: fav.userId,
            type: 'sold',
            title: 'Vehicle sold',
            body: `${vehicle.name}, which you saved, has been marked as sold.`,
            relatedVehicleId: vehicle.id,
          },
        });
        emitNewNotification(fav.userId, notification);
      }
    }

    const featuredIds = await getFeaturedIds();
    // This seller's own sold count just changed as a direct result of this
    // call — recompute fresh rather than reusing a value from before the
    // update.
    const soldCountsBySeller = await getSoldCountsBySeller([vehicle.sellerId]);
    res.json({ vehicle: toVehicleResponse(vehicle, new Set(), featuredIds, soldCountsBySeller) });
  }
);

// Permanently deletes one of the current user's own listings. Only the
// seller who created it may delete it — same ownership check as PUT /:id
// and PUT /:id/status above; a 404 vs 403 distinction is kept for the same
// reason those routes keep it (don't reveal whether an id exists at all to
// someone who doesn't own it... actually here it's fine either way since
// the vehicle is public, but consistency with the other two routes makes
// the ownership logic easy to audit at a glance).
//
// This is a real, permanent delete — not a status flip to some hidden
// state — because "remove this listing" is a distinct action from "mark
// as sold" (PUT /:id/status already covers the sold case, and a sold
// listing is still worth keeping around as sales history for the "N Sold"
// count). Once this returns, the row is gone from the vehicles table, so
// it can never again show up in the public feed, search, favorites, or
// this seller's own "My Listings".
//
// Nothing else needs manual cleanup for this to be safe:
//   - Favorite rows pointing at this vehicle: onDelete: Cascade (see
//     schema.prisma) — they're deleted automatically.
//   - CallbackRequest rows pointing at this vehicle: onDelete: Cascade too
//     (also see schema.prisma) — same automatic cleanup.
//   - Notification.relatedVehicleId is a plain string column, not a
//     foreign key relation, so it can't block this delete and is simply
//     left pointing at an id that no longer resolves (the same way
//     GET /vehicles/:id already tolerates "not found" elsewhere in the
//     app today).
router.delete('/:id', authenticate, async (req, res) => {
  const existing = await prisma.vehicle.findUnique({ where: { id: req.params.id } });
  if (!existing) {
    return res.status(404).json({ error: 'Vehicle not found' });
  }
  if (existing.sellerId !== req.user.id) {
    return res.status(403).json({ error: 'You can only delete your own listings' });
  }

  await prisma.vehicle.delete({ where: { id: req.params.id } });

  res.json({ message: 'Vehicle deleted' });
});

router.post('/:id/callback', authenticate, async (req, res) => {
  const { phone } = req.body;
  const vehicle = await prisma.vehicle.findUnique({ where: { id: req.params.id } });
  if (!vehicle) return res.status(404).json({ error: 'Vehicle not found' });

  const request = await prisma.callbackRequest.create({
    data: {
      vehicleId: vehicle.id,
      userId: req.user.id,
      phone: phone || req.user.phone || '',
    },
  });

  // Let the seller know someone wants a callback — this is the "callback"
  // entry type in their Notifications tab.
  if (vehicle.sellerId && vehicle.sellerId !== req.user.id) {
    const callbackPhone = phone || req.user.phone || '';

    // One notification row per (seller, vehicle, requester). If this SAME
    // buyer has already asked for a callback about this SAME vehicle and
    // that notification is still sitting there, this updates that row and
    // bumps `count` instead of creating a new one — otherwise the list
    // would fill up with a near-duplicate row every time an impatient
    // buyer taps "Request Callback" again. A request about a different
    // vehicle, or from a different buyer, has a different unique key
    // (relatedVehicleId / relatedUserId) so it always lands as its own
    // separate row — the seller can always tell exactly who to call back.
    // count uses Prisma's atomic increment rather than a separate
    // find-then-write, so two rapid requests from the same buyer can't
    // race each other and silently lose an increment.
    const notification = await prisma.notification.upsert({
      where: {
        userId_relatedVehicleId_relatedUserId_type: {
          userId: vehicle.sellerId,
          relatedVehicleId: vehicle.id,
          relatedUserId: req.user.id,
          type: 'callback',
        },
      },
      create: {
        userId: vehicle.sellerId,
        type: 'callback',
        title: 'Callback requested',
        body: `${req.user.name} wants a callback about your ${vehicle.name}`,
        relatedVehicleId: vehicle.id,
        relatedUserId: req.user.id,
        relatedPhone: callbackPhone,
        count: 1,
      },
      update: {
        body: `${req.user.name} wants a callback about your ${vehicle.name}`,
        // The number to call back on might change between requests (the
        // buyer can type a different one each time) — always show the
        // latest.
        relatedPhone: callbackPhone,
        count: { increment: 1 },
        // A fresh request always makes the row unread again and bumps it
        // back to the top of the list, even if the seller had already
        // read (and not yet acted on) the previous one.
        read: false,
        createdAt: new Date(),
      },
    });
    emitNewNotification(vehicle.sellerId, notification);
  }

  res.status(201).json({ message: 'Callback request submitted', request });
});

// Attached so other route files (dealers.js) can reuse the exact same
// vehicle response shape instead of hand-rolling their own — that drift is
// what caused the dealer profile's vehicle list to be malformed before.
module.exports = router;
module.exports.toVehicleResponse = toVehicleResponse;