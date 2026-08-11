const express = require('express');
const { PrismaClient } = require('@prisma/client');
const { authenticate } = require('../middleware/auth');
const { emitChatRead } = require('../socket');

const router = express.Router();
const prisma = new PrismaClient();

// Everything here is scoped to req.user.id (from the JWT) — a user can only
// ever see or modify their own notifications, in test accounts and real
// production accounts alike, the same way My Listings/Favorites already work.

router.get('/', authenticate, async (req, res) => {
  const notifications = await prisma.notification.findMany({
    where: { userId: req.user.id },
    orderBy: { createdAt: 'desc' },
    take: 50,
  });
  res.json({ notifications });
});

router.get('/unread-count', authenticate, async (req, res) => {
  const count = await prisma.notification.count({
    where: { userId: req.user.id, read: false },
  });
  res.json({ count });
});

// Marks the underlying chat's messages as read too, when this is a
// 'message' notification — this is the other half of the three-way sync
// (chat dot / Profile badge / Home bell). Without this, reading a message
// notification from the Notifications screen (without opening the chat
// itself first) would clear the badge and bell but leave the per-chat dot
// on the Messages list stuck on.
async function markUnderlyingChatRead(notification, userId) {
  if (notification.type !== 'message' || !notification.relatedChatId) return;
  const result = await prisma.message.updateMany({
    where: { chatId: notification.relatedChatId, senderId: { not: userId }, read: false },
    data: { read: true },
  });
  if (result.count > 0) {
    emitChatRead(notification.relatedChatId, userId);
  }
}

router.put('/:id/read', authenticate, async (req, res) => {
  const existing = await prisma.notification.findUnique({ where: { id: req.params.id } });
  if (!existing || existing.userId !== req.user.id) {
    return res.status(404).json({ error: 'Notification not found' });
  }
  const notification = await prisma.notification.update({
    where: { id: req.params.id },
    data: { read: true },
  });
  await markUnderlyingChatRead(notification, req.user.id);
  res.json({ notification });
});

router.put('/read-all', authenticate, async (req, res) => {
  // Need the actual rows (not just a count) so each linked chat's messages
  // can be marked read too — updateMany alone can't tell us which chats
  // were affected.
  const unread = await prisma.notification.findMany({
    where: { userId: req.user.id, read: false },
  });
  await prisma.notification.updateMany({
    where: { userId: req.user.id, read: false },
    data: { read: true },
  });
  for (const n of unread) {
    await markUnderlyingChatRead(n, req.user.id);
  }
  res.json({ success: true });
});

module.exports = router;