require('dotenv').config();
const express     = require('express');
const http        = require('http');
const { Server }  = require('socket.io');
const cors        = require('cors');
const helmet      = require('helmet');
const morgan      = require('morgan');
const rateLimit   = require('express-rate-limit');

const connectDB             = require('./config/db');
const { errorHandler, notFound } = require('./middleware/errorHandler');
const { startCronJobs }     = require('./utils/cron');

// Route imports
const authRoutes         = require('./routes/auth');
const listingRoutes      = require('./routes/listings');
const chatRoutes         = require('./routes/chat');
const adminRoutes        = require('./routes/admin');
const ratingRoutes       = require('./routes/ratings');

// ── App setup ─────────────────────────────────────────────────────────────────
const app    = express();
const server = http.createServer(app); // needed for Socket.io

// ── Socket.io ─────────────────────────────────────────────────────────────────
// Allow web client and mobile app (mobile has no origin)
const allowedOrigins = [
  process.env.CLIENT_URL || 'http://localhost:5173',
  'http://localhost:5173',
  'http://localhost:3000',
  'http://localhost:8080',
  'http://localhost:9090',
  'http://localhost:9091',
  'https://knightmarket.com',
  'https://www.knightmarket.com',
];

const corsOptions = {
  origin: (origin, callback) => {
    // Allow requests with no origin (mobile apps, Postman, curl)
    if (!origin) return callback(null, true);
    if (allowedOrigins.includes(origin)) return callback(null, true);
    // Allow any localhost port (Flutter web dev)
    if (/^http:\/\/localhost(:\d+)?$/.test(origin)) return callback(null, true);
    callback(new Error('Not allowed by CORS'));
  },
  credentials: true,
};

const io = new Server(server, {
  cors: {
    origin: (origin, callback) => {
      if (!origin) return callback(null, true);
      if (allowedOrigins.includes(origin)) return callback(null, true);
      if (/^http:\/\/localhost(:\d+)?$/.test(origin)) return callback(null, true);
      callback(new Error('Not allowed by CORS'));
    },
    methods: ['GET', 'POST'],
    credentials: true,
  },
});

// Make io accessible in route controllers via req.app.get('io')
app.set('io', io);

io.on('connection', (socket) => {
  // Client sends their userId on connect — we use it to route events
  const userId = socket.handshake.auth?.userId;
  if (userId) {
    socket.join(`user:${userId}`);
    console.log(`Socket connected: user ${userId}`);
  }

  // Client joins a specific thread room to receive messages
  socket.on('joinThread', (threadId) => {
    socket.join(`thread:${threadId}`);
  });

  socket.on('leaveThread', (threadId) => {
    socket.leave(`thread:${threadId}`);
  });

  socket.on('disconnect', () => {
    if (userId) console.log(`Socket disconnected: user ${userId}`);
  });
});

// ── Middleware ────────────────────────────────────────────────────────────────
app.use(helmet());
app.use(cors(corsOptions));
app.use(morgan(process.env.NODE_ENV === 'production' ? 'combined' : 'dev'));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Rate limiting — 100 requests per 15 minutes per IP
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max:      100,
  message:  { success: false, message: 'Too many requests — please slow down' },
});
app.use('/api/', limiter);

// Stricter rate limit for auth routes
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max:      200,
  message:  { success: false, message: 'Too many auth attempts — try again later' },
});
app.use('/api/auth/', authLimiter);

// ── Routes ────────────────────────────────────────────────────────────────────
app.use('/api/auth',         authRoutes);
app.use('/api/listings',     listingRoutes);
app.use('/api/threads',      chatRoutes);
app.use('/api/admin',        adminRoutes);
app.use('/api/ratings',      ratingRoutes);

// Health check — for Railway deployment monitoring
app.get('/health', (_req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// ── Error handling (must come last) ──────────────────────────────────────────
app.use(notFound);
app.use(errorHandler);

// ── Start ─────────────────────────────────────────────────────────────────────
const PORT = process.env.PORT || 5000;

const start = async () => {
  await connectDB();
  startCronJobs();
  server.listen(PORT, () => {
    console.log(`🚀 KnightMarket API running on port ${PORT}`);
    console.log(`   Environment: ${process.env.NODE_ENV || 'development'}`);
    console.log(`   Client URL:  ${process.env.CLIENT_URL || 'http://localhost:5173'}`);
  });
};

start();
