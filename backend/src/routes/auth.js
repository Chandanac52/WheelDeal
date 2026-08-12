const express = require('express');
const { body, validationResult } = require('express-validator');
const { PrismaClient } = require('@prisma/client');
const { signToken } = require('../utils/jwt');
const { authenticate } = require('../middleware/auth');
const { verifyFirebaseIdToken } = require('../config/firebase');
const { normalizePhone } = require('../utils/normalizePhone');

const router = express.Router();
const prisma = new PrismaClient();

router.get('/me', authenticate, async (req, res) => {
  res.json({ user: req.user });
});

router.post(
  '/firebase-login',
  [body('idToken').notEmpty(), body('name').optional().trim()],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { idToken, name } = req.body;

    let decoded;
    try {
      decoded = await verifyFirebaseIdToken(idToken);
    } catch (e) {
      const isServerConfigError = e.message?.includes('Firebase phone login is not configured');
      if (isServerConfigError) {
        console.error('[firebase-login] server misconfigured:', e.message);
        return res.status(503).json({
          error: 'Phone login is not set up on the server yet (missing Firebase Admin credentials).',
        });
      }
      console.error('[firebase-login] token verification failed:', e.message);
      return res.status(401).json({ error: 'Invalid or expired code. Please try again.' });
    }

    // Firebase always gives us E.164 format ("+919876543210", no spaces).
    // Normalizing here too is defense-in-depth: even if something upstream
    // ever changes, this lookup/create can never diverge from what's
    // actually stored, so a user can never get silently duplicated again.
    const phone = normalizePhone(decoded.phone_number);
    if (!phone) {
      return res.status(400).json({ error: 'Token has no verified phone number' });
    }

    let user = await prisma.user.findUnique({ where: { phone } });
    if (!user) {
      user = await prisma.user.create({
        data: {
          phone,
          name: name && name.trim() ? name.trim() : 'WheelDeal User',
          role: 'BUYER',
        },
      });
    }

    const token = signToken({ userId: user.id });
    res.json({
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        phone: user.phone,
        avatar: user.avatar,
        role: user.role,
        // FIX: this object is hand-built rather than returned straight
        // from Prisma, and dealerId was missing from the list — meaning
        // the very first user object the Flutter app ever sees, right at
        // sign-in, never carried it. UserModel.fromJson would parse this
        // as dealerId: null even for a real dealer-linked seller, and
        // nothing corrected it until (if ever) something else re-fetched
        // GET /me, which DOES return it (it forwards req.user wholesale,
        // and the authenticate middleware's select already includes
        // dealerId). Every field returned here needs to actually match
        // what authenticate's select produces, or exactly this kind of
        // silent, field-by-field drift is how one login path quietly
        // disagrees with another.
        dealerId: user.dealerId,
      },
      token,
    });
  }
);

router.put(
  '/me',
  authenticate,
  [body('name').optional().trim().notEmpty()],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      // FIX: this route declared the `name` validator above but never
      // actually checked its result — an empty-after-trim name (e.g. " ")
      // would silently pass straight through to the update instead of
      // being rejected here like every other validated route in this API.
      return res.status(400).json({ errors: errors.array() });
    }

    // FIX (security): `phone` used to be accepted and applied here —
    // `...(phone !== undefined && { phone: normalizePhone(phone) })` —
    // taken straight from client input with nothing to stop it. Phone is
    // the verified sign-in identity (proven via a real Firebase OTP at
    // login, not by typing a number into a text field), so this endpoint
    // must never be able to change it — not because the Flutter screen no
    // longer sends it (that's not a real fix, same lesson as the dealerId
    // issue earlier), but because the backend itself now ignores `phone`
    // entirely on this route regardless of what any client sends.
    const { name, avatar } = req.body;

    const user = await prisma.user.update({
      where: { id: req.user.id },
      data: {
        ...(name && { name }),
        ...(avatar !== undefined && { avatar }),
      },
      // FIX: dealerId was missing from this select too — same bug as
      // firebase-login above, different route. A dealer-linked seller who
      // simply edited their display name here would have their LOCAL
      // client state (AuthNotifier.updateProfile sets state.user straight
      // from this response — see auth_provider.dart) silently lose
      // dealerId until the app was fully restarted and GET /me ran again.
      // In the meantime the "Rate this dealer" hide-button check
      // (dealer_profile_screen.dart) would wrongly show the button again
      // for someone the backend would still correctly 403 — a confusing,
      // hard-to-reproduce inconsistency for exactly the reason this
      // comment exists: it only happens after an edit, not at login.
      select: { id: true, email: true, name: true, phone: true, avatar: true, role: true, dealerId: true },
    });

    // Vehicle.sellerName is a denormalized COPY of the seller's name taken
    // at listing-creation time (kept that way so a listing can still show
    // a seller name even if that account were ever deleted) — it does NOT
    // automatically follow later changes to User.name. Without this,
    // changing your display name here would only ever be visible on your
    // own Profile screen; every one of your existing listings would keep
    // showing the old name to buyers on Home, Search, and the vehicle
    // detail page indefinitely. sellerAvatar has this exact same
    // denormalization pattern, not touched here since only name editing
    // was asked for — worth the same fix later if avatar changes need to
    // propagate to existing listings too.
    if (name) {
      await prisma.vehicle.updateMany({
        where: { sellerId: req.user.id },
        data: { sellerName: name },
      });
    }

    res.json({ user });
  }
);

module.exports = router;