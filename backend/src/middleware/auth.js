const { verifyToken } = require('../utils/jwt');
const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();

async function authenticate(req, res, next) {
  const header = req.headers.authorization;
  if (!header?.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Authentication required' });
  }

  try {
    const token = header.slice(7);
    const decoded = verifyToken(token);
    const user = await prisma.user.findUnique({
      where: { id: decoded.userId },
      // dealerId added: this is what lets POST /vehicles derive a new
      // listing's dealer affiliation from the authenticated account
      // itself, instead of trusting a client-supplied dealerId — without
      // it here, req.user.dealerId would always be undefined and every
      // listing would silently fall back to "no dealer" regardless of who
      // the seller actually is.
      select: { id: true, email: true, name: true, phone: true, avatar: true, role: true, dealerId: true },
    });

    if (!user) {
      return res.status(401).json({ error: 'User not found' });
    }

    req.user = user;
    next();
  } catch {
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
}

function optionalAuth(req, res, next) {
  const header = req.headers.authorization;
  if (!header?.startsWith('Bearer ')) {
    return next();
  }
  return authenticate(req, res, next);
}

module.exports = { authenticate, optionalAuth };