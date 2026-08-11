# WheelDeal Backend API

REST API for the WheelDeal used-vehicle marketplace.

## Quick Start

```bash
npm install
cp .env.example .env
# Edit .env with your DATABASE_URL and JWT_SECRET
npm run db:setup
npm run dev
```

API runs at http://localhost:3000

## Scripts

| Command | Description |
|---------|-------------|
| `npm run dev` | Start with hot reload |
| `npm start` | Production start |
| `npm run db:setup` | Migrate + seed database |
| `npm run db:seed` | Seed demo data only |

See `../DEPLOYMENT_GUIDE.md` for full production deployment instructions.
