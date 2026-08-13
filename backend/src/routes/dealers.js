const express = require('express');
const { body, validationResult } = require('express-validator');
const { PrismaClient } = require('@prisma/client');
const asyncHandler = require('../utils/asyncHandler');
const { authenticate, optionalAuth } = require('../middleware/auth');
const { toVehicleResponse } = require('./vehicles');

const router = express.Router();
const prisma = new PrismaClient();

// Computes each dealer's live rating (average + review count) straight
// from Review rows, batched across every dealer in a given response with
// one groupBy — same "compute fresh instead of trusting a stored number"
// pattern already used for isFeatured (getFeaturedIds) and soldCount
// (getSoldCountsBySeller) in vehicles.js. A dealer with zero reviews is
// simply absent from the returned map — callers must treat "not in the
// map" as "no rating yet", never as "rating 0", since 0 would read as a
// terrible rating rather than an honest lack of one.
async function getDealerRatings(dealerIds) {
  const uniqueIds = [...new Set(dealerIds.filter(Boolean))];
  if (uniqueIds.length === 0) return new Map();

  const agg = await prisma.review.groupBy({
    by: ['dealerId'],
    where: { dealerId: { in: uniqueIds } },
    _avg: { rating: true },
    _count: { _all: true },
  });

  return new Map(
    agg.map((a) => [a.dealerId, { rating: a._avg.rating, reviewCount: a._count._all }])
  );
}

// Shared shape for the summary fields (Home "Popular Dealers", dealer
// list, dealer profile header) — `rating` is null and `reviewCount` is 0
// for a dealer nobody has reviewed yet, rather than a fake default.
//
// `totalCars` is the count of the dealer's ACTIVE vehicles ONLY — not
// every vehicle they've ever listed. This used to come from an
// UNFILTERED _count.vehicles (every status included: SOLD, EXPIRED,
// everything), while "Available Listings" on the profile screen only
// ever showed ACTIVE ones — two different numbers, both labeled as if
// they meant the same thing, guaranteed to drift apart the moment
// anything sold. Both call sites below now pass a count filtered the
// exact same way the profile's `vehicles` list itself is filtered, so
// there's no way for the two to disagree again.
function toDealerSummary(dealer, totalCars, ratingInfo) {
  return {
    id: dealer.id,
    name: dealer.name,
    logo: dealer.logo || 'assets/images/dealers/dealer1.png',
    rating: ratingInfo?.rating ?? null,
    reviewCount: ratingInfo?.reviewCount ?? 0,
    totalCars,
    location: dealer.location,
    isVerified: dealer.isVerified,
  };
}

router.get('/', asyncHandler(async (_req, res) => {
  const dealers = await prisma.dealer.findMany({
    // Filtered relation count (Prisma's `_count.select.<relation>.where`)
    // — counts only vehicles matching status: 'ACTIVE', computed by the
    // database in the same query rather than a separate JS-side filter.
    include: { _count: { select: { vehicles: { where: { status: 'ACTIVE' } } } } },
  });

  const ratings = await getDealerRatings(dealers.map((d) => d.id));

  const withRatings = dealers.map((d) => ({
    dealer: d,
    ratingInfo: ratings.get(d.id) || null,
  }));

  // Sorted here in JS rather than via Prisma's `orderBy` on the review
  // relation: a dealer with zero reviews has no aggregate row at all (not
  // a 0), and SQL's default NULLS FIRST/LAST behavior on a DESC aggregate
  // sort is easy to get backwards by accident — sorting the already-merged
  // (rating, reviewCount) pairs here makes "no reviews yet sorts after
  // dealers who have any" explicit and easy to verify at a glance, the
  // same way _filterMock() in vehicle_service.dart sorts client-side
  // rather than trusting a fragile query-level ordering.
  withRatings.sort((a, b) => {
    const ratingA = a.ratingInfo?.rating ?? -1;
    const ratingB = b.ratingInfo?.rating ?? -1;
    if (ratingB !== ratingA) return ratingB - ratingA;
    const countA = a.ratingInfo?.reviewCount ?? 0;
    const countB = b.ratingInfo?.reviewCount ?? 0;
    if (countB !== countA) return countB - countA;
    return Number(b.dealer.isVerified) - Number(a.dealer.isVerified);
  });

  res.json({
    dealers: withRatings.map(({ dealer, ratingInfo }) =>
      // FIX: was `dealer._count.vehicles || dealer.totalCars` — besides
      // the unfiltered-count problem above, `||` on a genuine 0 falls
      // through to the stale dealer.totalCars column too (0 is falsy in
      // JS), so a dealer with zero ACTIVE vehicles would have shown
      // whatever number seed data happened to type into that column
      // instead of an honest 0. _count.vehicles is always a real number
      // here (Prisma populates it whenever requested), so there's nothing
      // to fall back to.
      toDealerSummary(dealer, dealer._count.vehicles, ratingInfo)
    ),
  });
}));

router.get('/:id', optionalAuth, asyncHandler(async (req, res) => {
  const dealer = await prisma.dealer.findUnique({
    where: { id: req.params.id },
    include: {
      // include: { dealer: true } here is required — toVehicleResponse()
      // reads vehicle.dealer.name to fill dealerName, and without it every
      // vehicle in the profile would silently show "Independent Seller".
      vehicles: { where: { status: 'ACTIVE' }, include: { dealer: true } },
      // Same filtered count as GET / above — this is what makes the
      // "N vehicles" badge and "Available Listings (N)" below it always
      // agree, since both now come from the identical status: 'ACTIVE'
      // rule instead of two independently-drifting numbers.
      _count: { select: { vehicles: { where: { status: 'ACTIVE' } } } },
    },
  });

  if (!dealer) return res.status(404).json({ error: 'Dealer not found' });

  let favoriteIds = new Set();
  if (req.user) {
    const favs = await prisma.favorite.findMany({
      where: {
        userId: req.user.id,
        vehicleId: { in: dealer.vehicles.map((v) => v.id) },
      },
      select: { vehicleId: true },
    });
    favoriteIds = new Set(favs.map((f) => f.vehicleId));
  }

  const ratings = await getDealerRatings([dealer.id]);
  const ratingInfo = ratings.get(dealer.id) || null;

  res.json({
    dealer: {
      ...toDealerSummary(dealer, dealer._count.vehicles, ratingInfo),
      // FIX: this used to be the raw Prisma rows (`dealer.vehicles`
      // untouched) — price as a raw integer, no dealerName, no
      // priceAmount, no isFavorite. VehicleModel.fromJson on the Flutter
      // side expects the exact same shape vehicles.js produces, so this
      // was silently malformed the moment a dealer profile screen tried
      // to render it. Now reuses the identical formatter.
      vehicles: dealer.vehicles.map((v) => toVehicleResponse(v, favoriteIds)),
    },
  });
}));

// Every review this dealer has actually received, newest first — powers
// a "Reviews" list on the Dealer Profile screen. Kept as its own endpoint
// (rather than embedded in GET /:id) since the profile page needs it far
// less often than the summary rating, and a popular dealer could have far
// more reviews than anyone wants loaded on every profile visit.
router.get('/:id/reviews', asyncHandler(async (req, res) => {
  const reviews = await prisma.review.findMany({
    where: { dealerId: req.params.id },
    orderBy: { createdAt: 'desc' },
    include: { buyer: { select: { id: true, name: true, avatar: true } } },
  });

  res.json({
    reviews: reviews.map((r) => ({
      id: r.id,
      rating: r.rating,
      comment: r.comment,
      createdAt: r.createdAt,
      buyerId: r.buyer.id,
      buyerName: r.buyer.name,
      buyerAvatar: r.buyer.avatar || 'assets/images/avatars/profile.png',
    })),
  });
}));

// Lets a signed-in buyer rate a dealer. One review per (dealer, buyer) —
// submitting again UPDATES their existing review instead of adding a
// second row (see the @@unique on Review in schema.prisma), so nobody can
// inflate or tank a dealer's average by repeatedly reviewing them, and a
// buyer who changes their mind just edits their one review.
router.post(
  '/:id/reviews',
  authenticate,
  [
    body('rating').isInt({ min: 1, max: 5 }),
    body('comment').optional({ values: 'falsy' }).trim().isLength({ max: 500 }),
  ],
  asyncHandler(async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const dealer = await prisma.dealer.findUnique({ where: { id: req.params.id } });
    if (!dealer) return res.status(404).json({ error: 'Dealer not found' });

    // FIX: nothing here used to stop a seller who's LINKED to this exact
    // dealer (req.user.dealerId === dealer.id — see the comment on
    // User.dealerId in schema.prisma) from rating their own dealer. A
    // rating is supposed to be an independent buyer's signal of trust;
    // letting someone tied to the dealer pad their own average is the
    // same conflict of interest as a shop rating itself five stars.
    // Checked by dealerId, not name/ownership guesswork, since dealerId
    // is the one authoritative link between an account and a dealer
    // everywhere else in this codebase (see POST /vehicles in vehicles.js).
    if (req.user.dealerId === dealer.id) {
      return res.status(403).json({ error: "You can't rate a dealer you're affiliated with." });
    }

    const review = await prisma.review.upsert({
      where: { dealerId_buyerId: { dealerId: req.params.id, buyerId: req.user.id } },
      create: {
        dealerId: req.params.id,
        buyerId: req.user.id,
        rating: req.body.rating,
        comment: req.body.comment || null,
      },
      update: {
        rating: req.body.rating,
        comment: req.body.comment || null,
      },
      include: { buyer: { select: { id: true, name: true, avatar: true } } },
    });

    res.status(201).json({
      review: {
        id: review.id,
        rating: review.rating,
        comment: review.comment,
        createdAt: review.createdAt,
        buyerId: review.buyer.id,
        buyerName: review.buyer.name,
        buyerAvatar: review.buyer.avatar || 'assets/images/avatars/profile.png',
      },
    });
  })
);

module.exports = router;