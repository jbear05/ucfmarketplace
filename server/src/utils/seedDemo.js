/**
 * Seeds 5 demo student accounts (superhero identities) with 3 listings each,
 * for trying out the app with realistic-looking data.
 *
 * Usage: npm run seed:demo
 */
require('dotenv').config();
const mongoose = require('mongoose');
const User     = require('../models/User');
const Listing  = require('../models/Listing');
const { UCF_CAMPUS_CENTER } = require('./geocode');

const DEMO_PASSWORD = 'Hero12345'; // shared across all demo accounts — easy to hand out

// Real, freely-licensed photos (via Openverse) of generic equivalents —
// e.g. a real leather belt for "Tactical Utility Belt" — rather than official
// superhero merch photos (avoids trademark issues) or text-label placeholders.
const FALLBACK_IMAGE = 'https://live.staticflickr.com/2628/3770457870_325823e331_b.jpg'; // backpack

const AREAS = [
  'Near the Student Union, UCF Main Campus',
  'Knights Plaza, UCF',
  'Library West Entrance, UCF',
  'Recreation and Wellness Center, UCF',
  'Garage A, UCF Main Campus',
];

// Small deterministic jitter so pins don't all stack on the exact same point
const jitter = (base, i) => base + (i % 5) * 0.0025 - 0.005;

const USERS = [
  {
    name: 'Clark Kent',
    email: 'clarkkent@ucf.edu',
    listings: [
      { title: 'Vintage Press Badge — Daily Planet', description: 'Screen-accurate prop badge, great condition.', price: 15, category: 'Other', condition: 'Good', image: 'https://images.rawpixel.com/editor_1024/cHJpdmF0ZS9zdGF0aWMvZmlsZXMvd2Vic2l0ZS8yMDIyLTExL3NtaXRoc25ucG0wMDI4MDg1MzAwMS1pbWFnZS5qcGc.jpg' },
      { title: 'Blue & Red Cape (Costume, Dry-Clean Only)', description: 'Worn once for a con. No tears, freshly cleaned.', price: 40, category: 'Clothing', condition: 'Like New', image: 'https://live.staticflickr.com/3163/2944302453_6623da36cd_b.jpg' },
      { title: 'Clark Kent Signature Glasses', description: 'Classic frames, non-prescription.', price: 20, category: 'Other', condition: 'Good', image: 'https://live.staticflickr.com/3597/3369429959_b781e42399_b.jpg' },
    ],
  },
  {
    name: 'Bruce Wayne',
    email: 'brucewayne@ucf.edu',
    listings: [
      { title: 'Batarang Replica Set (6-Pack)', description: 'Display-only, rubber-tipped. Never used.', price: 35, category: 'Other', condition: 'New', image: 'https://upload.wikimedia.org/wikipedia/commons/c/c7/Ninja_Shuriken.jpg' },
      { title: 'Wayne Enterprises Desk Lamp', description: 'Sleek matte-black desk lamp, dorm-approved.', price: 25, category: 'Dorm & Home', condition: 'Good', image: 'https://live.staticflickr.com/5263/5756031128_d157bbaed7_b.jpg' },
      { title: 'Grappling Hook Prop (Non-Functional)', description: 'Heavy prop replica, great shelf piece.', price: 18, category: 'Other', condition: 'Fair', image: 'https://live.staticflickr.com/3907/15004955370_c6a8aee22f_b.jpg' },
    ],
  },
  {
    name: 'Diana Prince',
    email: 'dianaprince@ucf.edu',
    listings: [
      { title: 'Lasso of Truth (Costume Prop)', description: 'Gold braided rope prop, costume quality.', price: 22, category: 'Other', condition: 'Like New', image: 'https://live.staticflickr.com/65535/53121582314_410613fa49_b.jpg' },
      { title: 'Amazonian Bracelets (Pair)', description: 'Metallic costume bracelets, one size.', price: 16, category: 'Clothing', condition: 'Good', image: 'https://images.rawpixel.com/editor_1024/cHJpdmF0ZS9sci9pbWFnZXMvd2Vic2l0ZS8yMDIzLTA0L2JzMjExLWltYWdlLmpwZw.jpg' },
      { title: 'Themyscira Travel Poster', description: 'Large print, looks great in a dorm room.', price: 10, category: 'Dorm & Home', condition: 'New', image: 'https://live.staticflickr.com/7525/15962292426_8b9e716817_b.jpg' },
    ],
  },
  {
    name: 'Peter Parker',
    email: 'peterparker@ucf.edu',
    listings: [
      { title: 'Web-Shooter Prop (Wearable)', description: 'Wrist-mounted prop, adjustable strap.', price: 20, category: 'Electronics', condition: 'Good', image: 'https://live.staticflickr.com/2484/3602672406_99ed2321c2_b.jpg' },
      { title: 'Spider-Man Backpack', description: 'Everyday backpack, laptop sleeve included.', price: 28, category: 'Other', condition: 'Like New', image: 'https://live.staticflickr.com/2628/3770457870_325823e331_b.jpg' },
      { title: 'Camera Bag (Daily Bugle Style)', description: 'Padded camera bag, fits a DSLR + lenses.', price: 30, category: 'Electronics', condition: 'Fair', image: 'https://live.staticflickr.com/1043/748218301_a6a60f6ff0_b.jpg' },
    ],
  },
  {
    name: 'Natasha Romanoff',
    email: 'natasharomanoff@ucf.edu',
    listings: [
      { title: 'Tactical Utility Belt', description: 'Adjustable, multiple pouches. Costume/cosplay grade.', price: 24, category: 'Clothing', condition: 'Good', image: 'https://live.staticflickr.com/143/428349468_321a88eed5_b.jpg' },
      { title: "Widow's Bite Gauntlets (Prop)", description: 'LED light-up gauntlets, batteries included.', price: 32, category: 'Other', condition: 'Like New', image: 'https://live.staticflickr.com/3079/2527221233_cb86d62c73_b.jpg' },
      { title: 'Black Ops Duffel Bag', description: 'Durable canvas duffel, barely used.', price: 18, category: 'Other', condition: 'Good', image: 'https://live.staticflickr.com/7556/15480395609_2ea5d83d1b_b.jpg' },
    ],
  },
];

const seed = async () => {
  await mongoose.connect(process.env.MONGODB_URI);
  console.log('Connected — seeding demo data...\n');

  let areaIdx = 0;

  for (const u of USERS) {
    let user = await User.findOne({ email: u.email });
    if (!user) {
      user = await User.create({
        name: u.name,
        email: u.email,
        passwordHash: DEMO_PASSWORD,
        isEmailConfirmed: true,
        isVerifiedStudent: true,
      });
      console.log(`Created user: ${u.name} <${u.email}>`);
    } else {
      console.log(`User already exists: ${u.name} <${u.email}> — reusing`);
    }

    for (const l of u.listings) {
      const exists = await Listing.findOne({ owner: user._id, title: l.title });
      if (exists) {
        console.log(`  Listing already exists: "${l.title}" — skipping`);
        continue;
      }

      const area = AREAS[areaIdx % AREAS.length];
      const [lng, lat] = UCF_CAMPUS_CENTER;

      await Listing.create({
        owner: user._id,
        title: l.title,
        description: l.description,
        price: l.price,
        category: l.category,
        condition: l.condition,
        meetupArea: area,
        coordinates: { type: 'Point', coordinates: [jitter(lng, areaIdx), jitter(lat, areaIdx)] },
        images: [l.image || FALLBACK_IMAGE],
      });
      console.log(`  Created listing: "${l.title}" ($${l.price})`);
      areaIdx++;
    }
  }

  console.log('\nDone. Shared demo login for all 5 accounts:');
  console.log(`  password: ${DEMO_PASSWORD}`);
  USERS.forEach((u) => console.log(`  ${u.name.padEnd(20)} ${u.email}`));

  await mongoose.disconnect();
};

seed().catch((err) => {
  console.error('Seed failed:', err);
  process.exit(1);
});
