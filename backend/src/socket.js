const { Server } = require('socket.io');
const { verifyToken } = require('./utils/jwt');

let io;

function initSocket(httpServer) {
  io = new Server(httpServer, {
    cors: { origin: process.env.CORS_ORIGIN || '*' },
  });

  io.use((socket, next) => {
    const token = socket.handshake.auth?.token;
    if (!token) return next(new Error('Authentication required'));
    try {
      const decoded = verifyToken(token);
      socket.userId = decoded.userId;
      next();
    } catch {
      next(new Error('Invalid or expired token'));
    }
  });

  io.on('connection', (socket) => {
    socket.join(`user:${socket.userId}`);

    socket.on('joinChat', (chatId) => {
      if (typeof chatId === 'string') socket.join(`chat:${chatId}`);
    });

    socket.on('leaveChat', (chatId) => {
      if (typeof chatId === 'string') socket.leave(`chat:${chatId}`);
    });
  });

  return io;
}

function emitNewMessage(chatId, message) {
  if (!io) return;
  io.to(`chat:${chatId}`).emit('newMessage', { chatId, message });
}

function emitMessageUpdated(chatId, message) {
  if (!io) return;
  io.to(`chat:${chatId}`).emit('messageUpdated', { chatId, message });
}

function emitMessageDeleted(chatId, messageId) {
  if (!io) return;
  io.to(`chat:${chatId}`).emit('messageDeleted', { chatId, messageId });
}

/** Call this right after marking messages read, so the sender's own other
 * open devices/tabs know their messages were seen (read receipts), and so
 * the sender's chats list unread state stays correct everywhere at once. */
function emitChatRead(chatId, readerUserId) {
  if (!io) return;
  io.to(`chat:${chatId}`).emit('chatRead', { chatId, readerUserId });
}

function emitNewNotification(userId, notification) {
  if (!io) return;
  io.to(`user:${userId}`).emit('newNotification', { notification });
}

module.exports = {
  initSocket,
  emitNewMessage,
  emitMessageUpdated,
  emitMessageDeleted,
  emitChatRead,
  emitNewNotification,
};
