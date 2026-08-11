/**
 * Express 4 does not catch rejected promises thrown inside async route
 * handlers. If one of those handlers throws (e.g. Prisma can't reach the
 * database because Neon is cold-starting), the rejection goes unhandled
 * and Node's default behavior is to crash the *entire process* — not just
 * that one request. Every route, every connected user, goes down until
 * something restarts the server.
 *
 * Wrapping a handler with asyncHandler(fn) catches any rejection and hands
 * it to next(err), which routes it into Express's error-handling
 * middleware (see the app.use((err, req, res, next) => ...) in index.js)
 * instead of letting it escape. The result: that one request gets a clean
 * 500 response, and the server itself stays up for every other request.
 *
 * Usage: router.get('/', asyncHandler(async (req, res) => { ... }));
 */
function asyncHandler(fn) {
  return function wrapped(req, res, next) {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
}

module.exports = asyncHandler;