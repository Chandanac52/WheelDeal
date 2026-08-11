const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();

async function main() {
  console.log('Seeding WheelDeal database...');

  // Dealers are created before the users below, because three of those
  // users now get linked to one via dealerId — see the note on each user.
  const dealers = await Promise.all([
    prisma.dealer.upsert({
      where: { id: 'dealer-1' },
      update: {},
      create: {
        id: 'dealer-1',
        name: 'AutoPrime Motors',
        logo: 'assets/images/dealers/dealer1.png',
        rating: 4.8,
        totalCars: 47,
        location: 'Banjara Hills, Hyderabad',
        isVerified: true,
      },
    }),
    prisma.dealer.upsert({
      where: { id: 'dealer-2' },
      update: {},
      create: {
        id: 'dealer-2',
        name: 'Prestige Auto Hub',
        logo: 'assets/images/dealers/dealer2.png',
        rating: 4.6,
        totalCars: 63,
        location: 'Kondapur, Hyderabad',
        isVerified: true,
      },
    }),
    prisma.dealer.upsert({
      where: { id: 'dealer-3' },
      update: {},
      create: {
        id: 'dealer-3',
        name: 'Elite Cars',
        logo: 'assets/images/dealers/dealer3.png',
        rating: 4.7,
        totalCars: 35,
        location: 'Madhapur, Hyderabad',
        isVerified: false,
      },
    }),
  ]);

  // Login is phone-OTP only now (via Firebase), so seeded users don't need
  // a password. Add these numbers as Firebase test phone numbers (Console ->
  // Authentication -> Sign-in method -> Phone -> Phone numbers for testing)
  // with a fixed code like 123456 so you can log in as them without sending
  // a real SMS. See DEPLOYMENT_GUIDE.md "Phone OTP Login".
  //
  // IMPORTANT: these must be in strict E.164 format (no spaces) because
  // that's exactly what Firebase reports back after verifying an OTP.
  // A stored phone like "+91 98765 43210" (with spaces) will NEVER match
  // what Firebase sends, and the backend will silently create a brand-new,
  // disconnected user on every login instead of finding this seeded one.

  // A plain buyer — no dealer link, same as any real individual buyer.
  const demoUser = await prisma.user.upsert({
    where: { phone: '+919876543210' },
    update: {},
    create: {
      email: 'demo@wheeldeal.com',
      name: 'Demo User',
      phone: '+919876543210',
      avatar: 'assets/images/avatars/profile.png',
      role: 'BUYER',
    },
  });

  // dealerId lives on the ACCOUNT, not stamped onto individual vehicles at
  // seed time — every vehicle a seller creates through the actual Sell
  // form (not just these seeded ones) shows up under their dealer profile
  // automatically, because it's the account that's linked, not the listing.
  const sellerUser = await prisma.user.upsert({
    where: { phone: '+919876500001' },
    update: { dealerId: dealers[0].id },
    create: {
      email: 'seller@wheeldeal.com',
      name: 'Rajesh Nair',
      phone: '+919876500001',
      avatar: 'assets/images/avatars/profile.png',
      role: 'SELLER',
      dealerId: dealers[0].id,
    },
  });

  // Every seller shown in the app needs a real User row, or "Contact seller"
  // has no valid recipientId to open a chat with.
  const priyaUser = await prisma.user.upsert({
    where: { phone: '+919123456780' },
    update: { dealerId: dealers[1].id },
    create: {
      email: 'priya@wheeldeal.com',
      name: 'Priya Menon',
      phone: '+919123456780',
      avatar: 'assets/images/avatars/profile.png',
      role: 'SELLER',
      dealerId: dealers[1].id,
    },
  });

  const arjunUser = await prisma.user.upsert({
    where: { phone: '+919000011122' },
    update: { dealerId: dealers[2].id },
    create: {
      email: 'arjun@wheeldeal.com',
      name: 'Arjun Rao',
      phone: '+919000011122',
      avatar: 'assets/images/avatars/profile.png',
      role: 'SELLER',
      dealerId: dealers[2].id,
    },
  });

  // Explicit cleanup order, not relying solely on the database's cascade
  // behavior to do the right thing: CallbackRequest and Favorite both
  // reference Vehicle by foreign key, so they must be cleared BEFORE
  // vehicles are deleted, or Postgres will refuse the deletion with a
  // foreign-key-constraint error — this is exactly what happened before
  // (CallbackRequest_vehicleId_fkey violated RESTRICT). Doing it explicitly
  // here means this seed script can never hit that error again, regardless
  // of whether onDelete: Cascade in schema.prisma has actually been pushed
  // to the real database yet.
  await prisma.callbackRequest.deleteMany({});
  await prisma.favorite.deleteMany({});
  await prisma.vehicle.deleteMany({});

  const vehicles = [
    {
      name: 'Maruti Swift VXI',
      category: 'Cars',
      images: ['assets/images/cars/car1.png', 'assets/images/cars/car2.png'],
      price: 480000,
      originalPrice: 550000,
      discountPercent: 12,
      isFeatured: true,
      rating: 4.3,
      fuelType: 'Petrol',
      transmission: 'Manual',
      year: '2021',
      seats: '5',
      kmDriven: '28.4k km',
      owners: '1 Owner',
      condition: 'Good',
      insurance: 'Valid',
      rcStatus: 'Clear',
      soldCount: '1.2k+',
      description:
        'The Maruti Swift VXI is a 2021 model in excellent condition with only 28.4k km driven. Features include Petrol engine, Manual transmission, and comes with a clear RC and valid insurance.',
      location: 'Banjara Hills, Hyderabad',
      sellerName: 'Rajesh Nair',
      sellerPhone: '+919876500001',
      sellerAvatar: 'assets/images/avatars/profile.png',
      dealerVerified: true,
      dealerId: dealers[0].id,
      sellerId: sellerUser.id,
    },
    {
      name: 'Honda Activa 6G',
      category: 'Scooters',
      images: ['assets/images/cars/scooter1.png'],
      price: 72000,
      originalPrice: 85000,
      discountPercent: 15,
      rating: 4.5,
      fuelType: 'Petrol',
      transmission: 'Automatic',
      year: '2022',
      seats: '2',
      kmDriven: '11.2k km',
      owners: '1 Owner',
      condition: 'Excellent',
      insurance: 'Valid',
      rcStatus: 'Clear',
      soldCount: '640+',
      description:
        'Honda Activa 6G, well maintained with single owner. Ideal daily commuter with excellent mileage.',
      location: 'Kondapur, Hyderabad',
      sellerName: 'Priya Menon',
      sellerPhone: '+919123456780',
      sellerAvatar: 'assets/images/avatars/profile.png',
      dealerVerified: true,
      dealerId: dealers[1].id,
      sellerId: priyaUser.id,
    },
    {
      name: 'Tata Nexon EV Max',
      category: 'Cars',
      images: ['assets/images/cars/car3.png'],
      price: 1450000,
      originalPrice: 1680000,
      discountPercent: 13,
      isFeatured: true,
      rating: 4.6,
      fuelType: 'Electric',
      transmission: 'Automatic',
      year: '2023',
      seats: '5',
      kmDriven: '9.8k km',
      owners: '1 Owner',
      condition: 'Excellent',
      insurance: 'Valid',
      rcStatus: 'Clear',
      soldCount: '310+',
      description:
        'Tata Nexon EV Max with long range battery, barely used, comes with home charger.',
      location: 'Gachibowli, Hyderabad',
      sellerName: 'Rajesh Nair',
      sellerPhone: '+919876500001',
      sellerAvatar: 'assets/images/avatars/profile.png',
      dealerVerified: true,
      dealerId: dealers[0].id,
      sellerId: sellerUser.id,
    },
    {
      name: 'Royal Enfield Meteor 350',
      category: 'Bikes',
      images: ['assets/images/cars/bike1.png'],
      price: 170000,
      originalPrice: 190000,
      discountPercent: 14,
      rating: 4.4,
      fuelType: 'Petrol',
      transmission: 'Manual',
      year: '2021',
      seats: '2',
      kmDriven: '18.7k km',
      owners: '1 Owner',
      condition: 'Good',
      insurance: 'Valid',
      rcStatus: 'Clear',
      soldCount: '420+',
      description:
        'Royal Enfield Meteor 350 in great shape, recently serviced, single owner.',
      location: 'Madhapur, Hyderabad',
      sellerName: 'Arjun Rao',
      sellerPhone: '+919000011122',
      sellerAvatar: 'assets/images/avatars/profile.png',
      dealerVerified: false,
      dealerId: dealers[2].id,
      sellerId: arjunUser.id,
    },
    {
      name: 'Hyundai Creta SX',
      category: 'Cars',
      images: ['assets/images/cars/car4.png'],
      price: 1180000,
      originalPrice: 1340000,
      discountPercent: 12,
      isFeatured: true,
      rating: 4.5,
      fuelType: 'Diesel',
      transmission: 'Automatic',
      year: '2022',
      seats: '5',
      kmDriven: '22.1k km',
      owners: '1 Owner',
      condition: 'Excellent',
      insurance: 'Valid',
      rcStatus: 'Clear',
      soldCount: '560+',
      description:
        'Hyundai Creta SX top variant, sunroof, well maintained with complete service history.',
      location: 'Jubilee Hills, Hyderabad',
      sellerName: 'Priya Menon',
      sellerPhone: '+919123456780',
      sellerAvatar: 'assets/images/avatars/profile.png',
      dealerVerified: true,
      dealerId: dealers[1].id,
      sellerId: priyaUser.id,
    },
    {
      name: 'Bajaj Pulsar NS200',
      category: 'Bikes',
      images: ['assets/images/cars/bike2.png'],
      price: 98000,
      originalPrice: 110000,
      discountPercent: 15,
      rating: 4.2,
      fuelType: 'Petrol',
      transmission: 'Manual',
      year: '2020',
      seats: '2',
      kmDriven: '31.5k km',
      owners: '2 Owners',
      condition: 'Good',
      insurance: 'Expired',
      rcStatus: 'Clear',
      soldCount: '280+',
      description:
        'Bajaj Pulsar NS200, sporty and fun to ride, minor cosmetic wear, mechanically sound.',
      location: 'Kukatpally, Hyderabad',
      sellerName: 'Arjun Rao',
      sellerPhone: '+919000011122',
      sellerAvatar: 'assets/images/avatars/profile.png',
      dealerVerified: false,
      dealerId: dealers[2].id,
      sellerId: arjunUser.id,
    },
  ];

  for (const v of vehicles) {
    await prisma.vehicle.create({ data: v });
  }

  const allVehicles = await prisma.vehicle.findMany({ take: 2 });
  for (const v of allVehicles) {
    await prisma.favorite.create({
      data: { userId: demoUser.id, vehicleId: v.id },
    });
  }

  console.log('Seed complete!');
  console.log('Login is phone OTP only now. Seeded phone numbers:');
  console.log('  Demo User (buyer):    +919876543210');
  console.log('  Rajesh Nair (seller, linked to AutoPrime Motors):    +919876500001');
  console.log('  Priya Menon (seller, linked to Prestige Auto Hub):   +919123456780');
  console.log('  Arjun Rao (seller, linked to Elite Cars):            +919000011122');
  console.log('Add these as Firebase test phone numbers to log in without real SMS.');
  console.log('');
  console.log('Try it: log in as Priya Menon, go to Sell, add a vehicle — it will now');
  console.log('show up under Prestige Auto Hub\'s dealer profile automatically, because');
  console.log('the dealer link now lives on her account, not on individual listings.');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });