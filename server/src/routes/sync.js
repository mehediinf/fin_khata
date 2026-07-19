const express = require('express');

const { pool } = require('../db');
const { authMiddleware } = require('../middleware/auth');

const router = express.Router();

router.use(authMiddleware);

router.get('/workspaces', async (req, res, next) => {
  try {
    const result = await pool.query(
      `SELECT workspace_id AS "workspaceId", version_counter AS "versionCounter",
              server_updated_at AS "updatedAt"
       FROM workspace_snapshots WHERE user_id=$1 ORDER BY server_updated_at DESC`,
      [req.userId],
    );
    res.json(result.rows);
  } catch (err) {
    next(err);
  }
});

router.get('/workspaces/:id', async (req, res, next) => {
  try {
    const result = await pool.query(
      `SELECT workspace_id AS "workspaceId", version_counter AS "versionCounter", snapshot
       FROM workspace_snapshots WHERE user_id=$1 AND workspace_id=$2`,
      [req.userId, req.params.id],
    );
    if (!result.rows.length) return res.status(404).json({ error: 'No snapshot found for this workspace.' });
    res.json(result.rows[0]);
  } catch (err) {
    next(err);
  }
});

router.put('/workspaces/:id', async (req, res, next) => {
  const workspaceId = req.params.id;
  const { baseVersion, snapshot } = req.body || {};
  if (typeof snapshot !== 'object' || snapshot === null) {
    return res.status(400).json({ error: 'snapshot is required.' });
  }
  if (typeof snapshot.schemaVersion !== 'number' || typeof snapshot.exportedAt !== 'string') {
    return res.status(400).json({ error: 'snapshot must include schemaVersion and exportedAt.' });
  }
  const baseVersionNumber = Number.isFinite(baseVersion) ? baseVersion : 0;

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const existing = await client.query(
      'SELECT user_id, version_counter FROM workspace_snapshots WHERE workspace_id=$1 FOR UPDATE',
      [workspaceId],
    );
    if (existing.rows.length && existing.rows[0].user_id !== req.userId) {
      await client.query('ROLLBACK');
      return res.status(409).json({ error: 'This workspace id is already synced to a different account.' });
    }

    const previousVersion = existing.rows.length ? Number(existing.rows[0].version_counter) : 0;
    const newVersion = previousVersion + 1;

    await client.query(
      `INSERT INTO workspace_snapshots
         (user_id, workspace_id, snapshot, schema_version, client_exported_at, version_counter)
       VALUES ($1, $2, $3, $4, $5, $6)
       ON CONFLICT (user_id, workspace_id) DO UPDATE SET
         snapshot = EXCLUDED.snapshot,
         schema_version = EXCLUDED.schema_version,
         client_exported_at = EXCLUDED.client_exported_at,
         version_counter = EXCLUDED.version_counter,
         server_updated_at = now()`,
      [req.userId, workspaceId, snapshot, snapshot.schemaVersion, snapshot.exportedAt, newVersion],
    );
    await client.query('COMMIT');

    const conflict = baseVersionNumber < previousVersion;
    res.json({ versionCounter: newVersion, conflict });
  } catch (err) {
    await client.query('ROLLBACK');
    next(err);
  } finally {
    client.release();
  }
});

module.exports = router;
