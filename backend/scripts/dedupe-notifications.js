// One-time cleanup: run this BEFORE `npx prisma db push` picks up the new
// @@unique([userId, relatedChatId, type]) constraint on Notification.
//
// Your database currently has exactly the duplicate rows visible in your
// screenshot (several separate 'message' notifications for the same
// Demo User -> Rajesh conversation). Adding a unique constraint on top of
// data that already violates it would make `prisma db push` fail outright,
// so this keeps the single most recent notification per (userId,
// relatedChatId) and deletes the rest first.
//
// Usage (from the backend/ folder):
//   node scripts/dedupe-notifications.js

const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  const messageNotifications = await prisma.notification.findMany({
    where: { type: 'message', relatedChatId: { not: null } },
    orderBy: { createdAt: 'desc' },
  });

  const seen = new Set();
  const idsToDelete = [];

  for (const n of messageNotifications) {
    const key = `${n.userId}::${n.relatedChatId}`;
    if (seen.has(key)) {
      // Already kept the newest one for this (user, chat) pair — this older
      // duplicate goes.
      idsToDelete.push(n.id);
    } else {
      seen.add(key);
    }
  }

  if (idsToDelete.length === 0) {
    console.log('No duplicate message notifications found — nothing to clean up.');
    return;
  }

  const result = await prisma.notification.deleteMany({
    where: { id: { in: idsToDelete } },
  });

  console.log(`Deleted ${result.count} duplicate message notification(s).`);
  console.log('Safe to run `npx prisma db push` now.');
}

main()
  .catch((err) => {
    console.error(err);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());