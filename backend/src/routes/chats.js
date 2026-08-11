const express = require('express');
const { body, validationResult } = require('express-validator');
const { PrismaClient } = require('@prisma/client');
const { authenticate } = require('../middleware/auth');
const { emitNewMessage, emitMessageUpdated, emitMessageDeleted, emitNewNotification, emitChatRead } = require('../socket');

const router = express.Router();
const prisma = new PrismaClient();

const EDIT_WINDOW_MS = 15 * 60 * 1000; // 15 minutes
const DELETE_WINDOW_MS = EDIT_WINDOW_MS;

router.get('/', authenticate, async (req, res) => {
  const participations = await prisma.chatParticipant.findMany({
    where: { userId: req.user.id },
    include: {
      chat: {
        include: {
          participants: { include: { user: { select: { id: true, name: true, avatar: true } } } },
          messages: { orderBy: { createdAt: 'desc' }, take: 1 },
        },
      },
    },
  });

  const chats = participations.map(({ chat }) => {
    const other = chat.participants.find((p) => p.userId !== req.user.id);
    const lastMessage = chat.messages[0];
    return {
      id: chat.id,
      otherUser: other?.user || null,
      lastMessage: lastMessage
        ? {
            content: lastMessage.deleted ? 'This message was deleted' : lastMessage.content,
            createdAt: lastMessage.createdAt,
            senderId: lastMessage.senderId,
            // Was missing entirely before — with no `read` field reaching
            // the client, there was no way for the chat list to ever know
            // a message was unread, so the dot could never appear or clear.
            read: lastMessage.read,
          }
        : null,
      updatedAt: chat.updatedAt,
    };
  });

  chats.sort((a, b) => new Date(b.updatedAt) - new Date(a.updatedAt));
  res.json({ chats });
});

router.post(
  '/',
  authenticate,
  [body('recipientId').notEmpty(), body('vehicleId').optional()],
  async (req, res) => {
    const { recipientId } = req.body;
    if (recipientId === req.user.id) {
      return res.status(400).json({ error: 'Cannot chat with yourself' });
    }

    const recipient = await prisma.user.findUnique({ where: { id: recipientId } });
    if (!recipient) return res.status(404).json({ error: 'User not found' });

    const existing = await prisma.chat.findFirst({
      where: {
        AND: [
          { participants: { some: { userId: req.user.id } } },
          { participants: { some: { userId: recipientId } } },
        ],
      },
    });

    if (existing) {
      // FIX: this used to report isNew: false purely because the Chat row
      // already existed — but that row gets created the moment someone
      // taps "chat", even if they close the screen without ever sending
      // anything. That meant a SECOND tap on an untouched, message-less
      // chat wrongly counted as "not new" and silently dropped the draft
      // message. isNew now actually means "no messages have been sent in
      // this chat yet" — the thing the client actually cares about — so an
      // empty chat still gets the draft no matter how many times it's
      // reopened, and it stops being "new" the moment either side sends a
      // real message.
      const messageCount = await prisma.message.count({ where: { chatId: existing.id } });
      return res.json({ chatId: existing.id, isNew: messageCount === 0 });
    }

    // FIX: this used to auto-create a "Hi, I'm interested in your listing."
    // message from the buyer the instant a chat was opened from a vehicle
    // page — meaning it was sent before the buyer ever typed or saw
    // anything. The chat now starts empty; the equivalent draft text is
    // composed client-side (see chat_start_helper.dart) and only lands in
    // the text box, not sent, so the buyer can read it, edit it, or clear
    // it before it's actually sent.
    const chat = await prisma.chat.create({
      data: {
        participants: {
          create: [{ userId: req.user.id }, { userId: recipientId }],
        },
      },
    });

    res.status(201).json({ chatId: chat.id, isNew: true });
  }
);

router.get('/:chatId/messages', authenticate, async (req, res) => {
  const participant = await prisma.chatParticipant.findUnique({
    where: { chatId_userId: { chatId: req.params.chatId, userId: req.user.id } },
  });
  if (!participant) return res.status(403).json({ error: 'Access denied' });

  const messages = await prisma.message.findMany({
    where: { chatId: req.params.chatId },
    orderBy: { createdAt: 'asc' },
    include: { sender: { select: { id: true, name: true, avatar: true } } },
  });

  res.json({ messages });
});

// Marks every message from the OTHER participant in this chat as read.
// Call this when the person actually opens the chat thread — that's what
// makes the unread dot on the chats list disappear.
router.put('/:chatId/read', authenticate, async (req, res) => {
  const participant = await prisma.chatParticipant.findUnique({
    where: { chatId_userId: { chatId: req.params.chatId, userId: req.user.id } },
  });
  if (!participant) return res.status(403).json({ error: 'Access denied' });

  const result = await prisma.message.updateMany({
    where: { chatId: req.params.chatId, senderId: { not: req.user.id }, read: false },
    data: { read: true },
  });

  if (result.count > 0) {
    emitChatRead(req.params.chatId, req.user.id);
  }

  // This is the other half of the cross-screen sync: opening the chat
  // thread was only ever clearing the per-chat dot on the Messages list —
  // it never touched the matching notification, so the "N new" badge on
  // Profile and the red dot on the Home bell stayed stuck on until you
  // happened to separately open the Notifications screen. Since there's at
  // most one 'message' notification per (user, chat) now, this is a single
  // targeted update, not a guess across all notifications.
  const notifResult = await prisma.notification.updateMany({
    where: { userId: req.user.id, type: 'message', relatedChatId: req.params.chatId, read: false },
    data: { read: true },
  });
  if (notifResult.count > 0) {
    emitNewNotification(req.user.id, { chatRead: req.params.chatId });
  }

  res.json({ success: true, markedCount: result.count });
});

router.post(
  '/:chatId/messages',
  authenticate,
  [body('content').trim().notEmpty()],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const participant = await prisma.chatParticipant.findUnique({
      where: { chatId_userId: { chatId: req.params.chatId, userId: req.user.id } },
    });
    if (!participant) return res.status(403).json({ error: 'Access denied' });

    const message = await prisma.message.create({
      data: {
        chatId: req.params.chatId,
        senderId: req.user.id,
        content: req.body.content,
      },
      include: { sender: { select: { id: true, name: true, avatar: true } } },
    });

    await prisma.chat.update({
      where: { id: req.params.chatId },
      data: { updatedAt: new Date() },
    });

    emitNewMessage(req.params.chatId, message);

    const otherParticipants = await prisma.chatParticipant.findMany({
      where: { chatId: req.params.chatId, userId: { not: req.user.id } },
    });
    for (const other of otherParticipants) {
      // Exactly one 'message' notification per (recipient, chat), always —
      // not just while the previous one is still unread. This is the fix
      // for seeing separate "Demo User" rows piling up over time: every
      // real chat app collapses all activity in one conversation into a
      // single notification entry that keeps updating and reappears as
      // unread, rather than logging a new entry per message ever sent.
      // The @@unique([userId, relatedChatId, type]) constraint on
      // Notification makes this a single atomic upsert instead of a
      // separate find-then-create/update (which had a race: two messages
      // sent milliseconds apart could both miss each other's row and
      // create two anyway).
      const notification = await prisma.notification.upsert({
        where: {
          userId_relatedChatId_type: {
            userId: other.userId,
            relatedChatId: req.params.chatId,
            type: 'message',
          },
        },
        create: {
          userId: other.userId,
          type: 'message',
          title: message.sender.name,
          body: message.content,
          relatedChatId: req.params.chatId,
          messageId: message.id,
        },
        update: {
          title: message.sender.name,
          body: message.content,
          messageId: message.id,
          // A new message always makes the conversation unread again, even
          // if the previous notification for it had already been read.
          read: false,
          createdAt: new Date(),
        },
      });
      emitNewNotification(other.userId, notification);
    }

    res.status(201).json({ message });
  }
);

router.put(
  '/:chatId/messages/:messageId',
  authenticate,
  [body('content').trim().notEmpty()],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const participant = await prisma.chatParticipant.findUnique({
      where: { chatId_userId: { chatId: req.params.chatId, userId: req.user.id } },
    });
    if (!participant) return res.status(403).json({ error: 'Access denied' });

    const existing = await prisma.message.findUnique({ where: { id: req.params.messageId } });
    if (!existing || existing.chatId !== req.params.chatId) {
      return res.status(404).json({ error: 'Message not found' });
    }
    if (existing.senderId !== req.user.id) {
      return res.status(403).json({ error: 'You can only edit your own messages' });
    }
    if (existing.deleted) {
      return res.status(400).json({ error: 'Cannot edit a deleted message' });
    }
    if (Date.now() - new Date(existing.createdAt).getTime() > EDIT_WINDOW_MS) {
      return res.status(400).json({ error: 'This message is too old to edit' });
    }

    const message = await prisma.message.update({
      where: { id: req.params.messageId },
      data: { content: req.body.content, edited: true },
      include: { sender: { select: { id: true, name: true, avatar: true } } },
    });

    // Keep any notification that was generated from this exact message in
    // sync — otherwise the Notifications screen keeps showing the old text
    // forever, completely disconnected from the message it's supposedly
    // reporting.
    const linkedNotifications = await prisma.notification.findMany({
      where: { messageId: req.params.messageId },
    });
    for (const n of linkedNotifications) {
      const updated = await prisma.notification.update({
        where: { id: n.id },
        data: { body: message.content },
      });
      emitNewNotification(updated.userId, updated);
    }

    emitMessageUpdated(req.params.chatId, message);
    res.json({ message });
  }
);

router.delete('/:chatId/messages/:messageId', authenticate, async (req, res) => {
  const participant = await prisma.chatParticipant.findUnique({
    where: { chatId_userId: { chatId: req.params.chatId, userId: req.user.id } },
  });
  if (!participant) return res.status(403).json({ error: 'Access denied' });

  const existing = await prisma.message.findUnique({ where: { id: req.params.messageId } });
  if (!existing || existing.chatId !== req.params.chatId) {
    return res.status(404).json({ error: 'Message not found' });
  }
  if (existing.senderId !== req.user.id) {
    return res.status(403).json({ error: 'You can only delete your own messages' });
  }
  if (existing.deleted) {
    return res.status(400).json({ error: 'Message is already deleted' });
  }
  if (Date.now() - new Date(existing.createdAt).getTime() > DELETE_WINDOW_MS) {
    return res.status(400).json({ error: 'This message is too old to delete' });
  }

  await prisma.message.update({
    where: { id: req.params.messageId },
    data: { deleted: true },
  });

  // Same reasoning as the edit route above — this is the actual fix for
  // "I deleted the message but the notification still shows the old text".
  const linkedNotifications = await prisma.notification.findMany({
    where: { messageId: req.params.messageId },
  });
  for (const n of linkedNotifications) {
    const updated = await prisma.notification.update({
      where: { id: n.id },
      data: { body: 'This message was deleted' },
    });
    emitNewNotification(updated.userId, updated);
  }

  emitMessageDeleted(req.params.chatId, req.params.messageId);
  res.json({ success: true });
});

module.exports = router;