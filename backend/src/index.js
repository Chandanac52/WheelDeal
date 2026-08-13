require('dotenv').config();
const express = require('express');
// Express 4 does NOT forward errors thrown inside `async` route handlers to
// the error-handling middleware below — the request just hangs until the
// client's own timeout fires. Every route in this app (vehicles, auth,
// dealers, ...) is an async handler that can throw (e.g. if the database
// isn't configured/reachable), so without this, a DB problem shows up in the
// app as a generic "Could not load vehicles" after a long stall instead of a
// real error. This one require patches Express to forward those errors
// correctly. Must be required before the route files below.
require('express-async-errors');
const cors = require('cors');
const path = require('path');
const fs = require('fs');
const http = require('http');

const authRoutes = require('./routes/auth');
const vehicleRoutes = require('./routes/vehicles');
const dealerRoutes = require('./routes/dealers');
const favoriteRoutes = require('./routes/favorites');
const chatRoutes = require('./routes/chats');
const uploadRoutes = require('./routes/upload');
const notificationRoutes = require('./routes/notifications');
const { initSocket } = require('./socket');
const listingExpiry = require('./services/listingExpiry');

const app = express();
const httpServer = http.createServer(app);
const PORT = process.env.PORT || 3000;

const uploadDir = process.env.UPLOAD_DIR || 'uploads';
if (!fs.existsSync(uploadDir)) fs.mkdirSync(uploadDir, { recursive: true });

app.use(cors({ origin: process.env.CORS_ORIGIN || '*' }));
app.use(express.json({ limit: '10mb' }));
app.use('/uploads', express.static(path.join(__dirname, '..', uploadDir)));

app.get('/health', (_req, res) => {
  res.json({ status: 'ok', service: 'WheelDeal API', version: '1.0.0' });
});

app.use('/api/auth', authRoutes);
app.use('/api/vehicles', vehicleRoutes);
app.use('/api/dealers', dealerRoutes);
app.use('/api/favorites', favoriteRoutes);
app.use('/api/chats', chatRoutes);
app.use('/api/upload', uploadRoutes);
app.use('/api/notifications', notificationRoutes);

app.use((err, _req, res, _next) => {
  console.error(err);
  // In dev, surface the real message (e.g. a Prisma "can't reach database
  // server" error) instead of a generic string, so failures like the
  // vehicles list not loading are actually debuggable from the app/logs.
  const message =
    process.env.NODE_ENV === 'production'
      ? 'Internal server error'
      : err.message || 'Internal server error';
  res.status(500).json({ error: message });
});

initSocket(httpServer);

httpServer.listen(PORT, '0.0.0.0', () => {
  console.log(`WheelDeal API running on http://localhost:${PORT}`);
  console.log(`Health check: http://localhost:${PORT}/health`);
  console.log(`WebSocket (chat) ready on the same port`);

  // Starts the recurring "take down listings with expired insurance"
  // sweep (services/listingExpiry.js) — placed inside the listen()
  // callback, after the server and socket.io are actually up, so the
  // first sweep's notifications have somewhere real to emit to instead of
  // racing server startup.
  listingExpiry.start();
});