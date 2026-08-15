# WheelDeal - Used Vehicle Marketplace

**WheelDeal** is a Flutter mobile app for buying and selling used cars, bikes, and scooters in India. It includes a full Node.js REST API backend with PostgreSQL.

## What's Included

| Component | Description |
|-----------|-------------|
| **Flutter App** | Home, Search, Sell, Chats, Profile, Vehicle Details |
| **Backend API** | Auth, Vehicles, Dealers, Favorites, Chat |
| **Database** | PostgreSQL schema via Prisma ORM |
| **Dummy Images** | Placeholder photos in `assets/images/` (replace before launch) |

## Quick Start 

The app runs **offline with mock data** by default:

```bash
flutter pub get
flutter run
```

## Connect to Backend

1. Set up backend (see `DEPLOYMENT_GUIDE.md`)
2. Edit `lib/core/constants/api_constants.dart`:
   - Set `baseUrl` to your API URL
   - Set `useMockData = false`
3. Rebuild the app

## Project Structure

```
WheelDeal/
├── lib/                  # Flutter app
├── backend/              # Node.js API
├── assets/images/        # Dummy images (replace before launch)
├── DEPLOYMENT_GUIDE.md   # Full setup & deployment steps
└── README.md
```

## Tech Stack

- **Frontend:** Flutter 3, Riverpod, GoRouter
- **Backend:** Node.js, Express, Prisma, PostgreSQL
- **Auth:** JWT tokens

See **DEPLOYMENT_GUIDE.md** for database setup, API keys, and Play Store / App Store deployment.
