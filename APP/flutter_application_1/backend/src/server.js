require('dotenv').config();

const express = require('express');
const cors = require('cors');

const { testConnection } = require('./db');
const authRoutes = require('./routes/auth');
const speciesRoutes = require('./routes/species');
const submissionsRoutes = require('./routes/submissions');
const sightingsRoutes = require('./routes/sightings');
const draftRoutes = require('./routes/drafts');

const app = express();
const port = Number(process.env.PORT || 4000);

app.use(
  cors({
    origin: process.env.CORS_ORIGIN || '*',
  })
);
app.use(express.json({ limit: '50mb' }));

app.get('/health', async (req, res, next) => {
  try {
    const connection = await testConnection();
    res.json({
      status: 'ok',
      dbTime: connection.now,
      postgisEnabled: connection.postgisEnabled,
    });
  } catch (error) {
    next(error);
  }
});

app.use('/api/auth', authRoutes);
app.use('/api/species', speciesRoutes);
app.use('/api/submissions', submissionsRoutes);
app.use('/api/sightings', sightingsRoutes);
app.use('/api/drafts', draftRoutes);

app.use((req, res) => {
  res.status(404).json({ error: 'Route not found.' });
});

app.use((error, req, res, next) => {
  console.error(error);

  if (res.headersSent) {
    return next(error);
  }

  return res.status(500).json({ error: 'Internal server error.' });
});

const server = app.listen(port, () => {
  console.log(`Bloom API listening on port ${port}`);
});

server.on('error', (error) => {
  if (error && error.code === 'EADDRINUSE') {
    console.error(`Port ${port} is already in use.`);
    console.error(
      'If Docker API is running, stop it with "docker compose stop api", or set a different PORT in backend/.env.'
    );
    process.exit(1);
  }

  throw error;
});
