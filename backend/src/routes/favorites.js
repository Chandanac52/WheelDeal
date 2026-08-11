const express = require('express');
const { PrismaClient } = require('@prisma/client');
const { authenticate } = require('../middleware/auth');
const asyncHandler = require('../utils/asyncHandler');

const router = express.Router();
const prisma = new PrismaClient();

router.get('/', authenticate, asyncHandler(async (req, res) => {
  const favorites = await prisma.favorite.findMany({
    where: { userId: req.user.id },
    include: { vehicle: { include: { dealer: true } } },
    orderBy: { createdAt: 'desc' },
  });

  res.json({ favorites: favorites.map((f) => f.vehicleId) });
}));

router.post('/:vehicleId', authenticate, asyncHandler(async (req, res) => {
  const { vehicleId } = req.params;
  const vehicle = await prisma.vehicle.findUnique({ where: { id: vehicleId } });
  if (!vehicle) return res.status(404).json({ error: 'Vehicle not found' });

  await prisma.favorite.upsert({
    where: { userId_vehicleId: { userId: req.user.id, vehicleId } },
    create: { userId: req.user.id, vehicleId },
    update: {},
  });

  res.json({ message: 'Added to favorites', vehicleId });
}));

router.delete('/:vehicleId', authenticate, asyncHandler(async (req, res) => {
  await prisma.favorite.deleteMany({
    where: { userId: req.user.id, vehicleId: req.params.vehicleId },
  });
  res.json({ message: 'Removed from favorites', vehicleId: req.params.vehicleId });
}));

module.exports = router;