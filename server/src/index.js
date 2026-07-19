require('dotenv').config();
const express = require('express');
const cors = require('cors');
const rateLimit = require('express-rate-limit');

const authRoutes = require('./routes/auth');
const syncRoutes = require('./routes/sync');

const app = express();
app.use(cors());
app.use(express.json({ limit: '2mb' }));

app.get('/health', (req, res) => res.json({ status: 'ok' }));

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 10,
  standardHeaders: true,
  legacyHeaders: false,
});
app.use('/auth/register', authLimiter);
app.use('/auth/login', authLimiter);

app.use('/auth', authRoutes);
app.use('/sync', syncRoutes);

app.use((req, res) => {
  res.status(404).json({ error: 'Not found' });
});

// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).json({ error: 'Internal server error' });
});

const port = process.env.PORT || 3000;
app.listen(port, () => {
  console.log(`FinKhata server listening on port ${port}`);
});
