import express from 'express';
import Database from 'better-sqlite3';
import path from 'path';
import dotenv from 'dotenv';
import { createServer as createViteServer } from 'vite';

dotenv.config();
import {
  INITIAL_TRANSACTIONS_SEED,
  SEED_USERS,
  validateLoginInput,
  validateTransactionInput,
} from './src/lib/financeEngine';

const PORT = Number(process.env.PORT) || 3000;
const DB_PATH = path.resolve(process.cwd(), process.env.SQLITE_DB_PATH || 'prm393_finance.sqlite');

// Initialize SQLite database on local disk
const db = new Database(DB_PATH);
db.pragma('journal_mode = WAL');

db.exec(`
  CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    email TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    name TEXT NOT NULL,
    role TEXT NOT NULL
  );

  CREATE TABLE IF NOT EXISTS transactions (
    id TEXT PRIMARY KEY,
    userId TEXT NOT NULL,
    ownerEmail TEXT NOT NULL,
    type TEXT NOT NULL CHECK(type IN ('Income', 'Expense')),
    amount REAL NOT NULL CHECK(amount > 0),
    category TEXT NOT NULL,
    date TEXT NOT NULL,
    note TEXT DEFAULT '',
    FOREIGN KEY (userId) REFERENCES users(id)
  );
`);

function seedInitialData(forceReset = false) {
  const upsertUser = db.prepare(
    'INSERT OR REPLACE INTO users (id, email, password_hash, name, role) VALUES (?, ?, ?, ?, ?)'
  );
  for (const u of SEED_USERS) {
    upsertUser.run(u.id, u.email, u.passwordHashCheck, u.name, u.role);
  }

  if (forceReset) {
    db.prepare('DELETE FROM transactions').run();
  }

  const txnCountRow = db
    .prepare('SELECT COUNT(*) as count FROM transactions')
    .get() as { count: number };

  // Also check if legacy USD amounts (< 10000) exist in TXN-101 and migrate to VND
  const sampleTxn = db
    .prepare('SELECT amount FROM transactions WHERE id = ?')
    .get('TXN-101') as { amount: number } | undefined;

  if (txnCountRow.count === 0 || (sampleTxn && sampleTxn.amount < 10000)) {
    const upsertTxn = db.prepare(
      'INSERT OR REPLACE INTO transactions (id, userId, ownerEmail, type, amount, category, date, note) VALUES (?, ?, ?, ?, ?, ?, ?, ?)'
    );
    const runSeed = db.transaction(() => {
      for (const t of INITIAL_TRANSACTIONS_SEED) {
        upsertTxn.run(
          t.id,
          t.userId,
          t.ownerEmail,
          t.type,
          t.amount,
          t.category,
          t.date,
          t.note
        );
      }
    });
    runSeed();
  }
}

seedInitialData(false);

async function startServer() {
  const app = express();
  app.use(express.json());

  // 1. POST /api/auth/login — Authenticate against SQLite users table
  app.post('/api/auth/login', (req, res) => {
    const { email = '', password = '' } = req.body || {};
    const validation = validateLoginInput(String(email), String(password));
    if (!validation.valid) {
      res.status(400).json({ error: validation.error });
      return;
    }

    const row = db
      .prepare(
        'SELECT id, email, name, role FROM users WHERE LOWER(email) = LOWER(?) AND password_hash = ?'
      )
      .get(String(email).trim(), String(password)) as
      | { id: string; email: string; name: string; role: string }
      | undefined;

    if (!row) {
      res.status(401).json({
        error: 'Email hoặc mật khẩu không chính xác. Vui lòng thử lại.',
      });
      return;
    }

    const session = {
      auth_token: `jwt_sqlite_${row.id}_${Date.now().toString(36)}`,
      current_user: row,
      authenticated_at: new Date().toISOString(),
    };

    res.status(200).json(session);
  });

  // 2. GET /api/transactions — Strictly isolated by userId in SQLite
  app.get('/api/transactions', (req, res) => {
    const userId = String(req.query.userId || '').trim();
    if (!userId) {
      res.status(401).json({ error: 'Yêu cầu xác thực tài khoản.' });
      return;
    }

    const rows = db
      .prepare(
        'SELECT id, userId, ownerEmail, type, amount, category, date, note FROM transactions WHERE userId = ? ORDER BY date DESC, id DESC'
      )
      .all(userId);

    res.status(200).json(rows);
  });

  // 3. POST /api/transactions — Validate amount > 0 & insert into SQLite
  app.post('/api/transactions', (req, res) => {
    const { userId, ownerEmail, type, amount, category, date, note = '' } =
      req.body || {};

    if (!userId || !ownerEmail) {
      res.status(401).json({ error: 'Không tìm thấy thông tin người dùng.' });
      return;
    }

    const validation = validateTransactionInput({
      amountRaw: amount,
      category: String(category || ''),
      date: String(date || ''),
    });

    if (!validation.valid) {
      res.status(400).json({ error: validation.error });
      return;
    }

    const id = `TXN-${Math.floor(10000 + Math.random() * 90000)}`;
    const cleanAmount = Math.round(Number(amount));
    const cleanType = type === 'Income' ? 'Income' : 'Expense';
    const cleanNote = String(note || '').trim();

    db.prepare(
      'INSERT INTO transactions (id, userId, ownerEmail, type, amount, category, date, note) VALUES (?, ?, ?, ?, ?, ?, ?, ?)'
    ).run(
      id,
      String(userId),
      String(ownerEmail),
      cleanType,
      cleanAmount,
      String(category),
      String(date),
      cleanNote
    );

    res.status(201).json({
      id,
      userId: String(userId),
      ownerEmail: String(ownerEmail),
      type: cleanType,
      amount: cleanAmount,
      category: String(category),
      date: String(date),
      note: cleanNote,
    });
  });

  // 4. PUT /api/transactions/:id — Update transaction in SQLite
  app.put('/api/transactions/:id', (req, res) => {
    const transactionId = req.params.id;
    const { userId, type, amount, category, date, note = '' } = req.body || {};

    if (!userId) {
      res
        .status(401)
        .json({ error: 'Không có quyền cập nhật giao dịch này.' });
      return;
    }

    const validation = validateTransactionInput({
      amountRaw: amount,
      category: String(category || ''),
      date: String(date || ''),
    });

    if (!validation.valid) {
      res.status(400).json({ error: validation.error });
      return;
    }

    const cleanAmount = Math.round(Number(amount));
    const cleanType = type === 'Income' ? 'Income' : 'Expense';
    const cleanNote = String(note || '').trim();

    const result = db
      .prepare(
        'UPDATE transactions SET type = ?, amount = ?, category = ?, date = ?, note = ? WHERE id = ? AND userId = ?'
      )
      .run(
        cleanType,
        cleanAmount,
        String(category),
        String(date),
        cleanNote,
        transactionId,
        String(userId)
      );

    if (result.changes === 0) {
      res.status(404).json({
        error: 'Không tìm thấy giao dịch hoặc không có quyền truy cập.',
      });
      return;
    }

    const updated = db
      .prepare(
        'SELECT id, userId, ownerEmail, type, amount, category, date, note FROM transactions WHERE id = ? AND userId = ?'
      )
      .get(transactionId, String(userId));

    res.status(200).json(updated);
  });

  // 5. DELETE /api/transactions/:id — Delete transaction from SQLite
  app.delete('/api/transactions/:id', (req, res) => {
    const transactionId = req.params.id;
    const userId = String(req.query.userId || req.body?.userId || '').trim();

    if (!userId) {
      res.status(401).json({ error: 'Không có quyền xóa giao dịch này.' });
      return;
    }

    const result = db
      .prepare('DELETE FROM transactions WHERE id = ? AND userId = ?')
      .run(transactionId, userId);

    if (result.changes === 0) {
      res.status(404).json({ error: 'Không tìm thấy giao dịch cần xóa.' });
      return;
    }

    res.status(200).json({ deleted: true, id: transactionId });
  });

  // 6. POST /api/demo/reset — Reset SQLite database to initial 8 VND seed transactions
  app.post('/api/demo/reset', (_req, res) => {
    seedInitialData(true);
    const allRows = db
      .prepare(
        'SELECT id, userId, ownerEmail, type, amount, category, date, note FROM transactions ORDER BY date DESC, id DESC'
      )
      .all();
    res.status(200).json(allRows);
  });

  if (process.env.NODE_ENV !== 'production') {
    const vite = await createViteServer({
      server: { middlewareMode: true },
      appType: 'spa',
    });
    app.use(vite.middlewares);
  } else {
    const distPath = path.join(process.cwd(), 'dist');
    app.use(express.static(distPath));
    app.get('*', (_req, res) => {
      res.sendFile(path.join(distPath, 'index.html'));
    });
  }

  app.listen(PORT, '0.0.0.0', () => {
    console.log(
      `AuraFinance Node.js + SQLite (VNĐ) server running on http://localhost:${PORT}`
    );
  });
}

startServer();
