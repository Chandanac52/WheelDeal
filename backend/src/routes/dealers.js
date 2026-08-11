const express = require('express');
const { PrismaClient } = require('@prisma/client');
const asyncHandler = require('../utils/asyncHandler');
const { optionalAuth } = require('../middleware/auth');
const { toVehicleResponse } = require('./vehicles');

const router = express.Router();
const prisma = new PrismaClient();

router.get('/', asyncHandler(async (_req, res) => {
  const dealers = await prisma.dealer.findMany({
    orderBy: { rating: 'desc' },
    include: { _count: { select: { vehicles: true } } },
  });

  res.json({
    dealers: dealers.map((d) => ({
      id: d.id,
      name: d.name,
      logo: d.logo || 'assets/images/dealers/dealer1.png',
      rating: d.rating,
      totalCars: d._count.vehicles || d.totalCars,
      location: d.location,
      isVerified: d.isVerified,
    })),
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
      _count: { select: { vehicles: true } },
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

  res.json({
    dealer: {
      id: dealer.id,
      name: dealer.name,
      logo: dealer.logo || 'assets/images/dealers/dealer1.png',
      rating: dealer.rating,
      totalCars: dealer._count.vehicles,
      location: dealer.location,
      isVerified: dealer.isVerified,
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

module.exports = router;