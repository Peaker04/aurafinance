import {
  AuthSession,
  CategoryName,
  INITIAL_TRANSACTIONS_SEED,
  STORAGE_KEYS,
  TransactionRecord,
  TransactionType,
  UserAccount,
  getTransactionsForUser,
  validateTransactionInput,
} from './financeEngine';

/**
 * Ensures local cache is initialized and synchronized with the Node.js SQLite backend (in VNĐ).
 */
export function ensureTransactionsDatabase(): TransactionRecord[] {
  try {
    const raw = localStorage.getItem(STORAGE_KEYS.TRANSACTIONS_DB);
    if (!raw) {
      localStorage.setItem(
        STORAGE_KEYS.TRANSACTIONS_DB,
        JSON.stringify(INITIAL_TRANSACTIONS_SEED)
      );
      return [...INITIAL_TRANSACTIONS_SEED];
    }
    const parsed = JSON.parse(raw) as TransactionRecord[];
    if (Array.isArray(parsed) && parsed.length > 0) {
      return parsed;
    }
    localStorage.setItem(
      STORAGE_KEYS.TRANSACTIONS_DB,
      JSON.stringify(INITIAL_TRANSACTIONS_SEED)
    );
    return [...INITIAL_TRANSACTIONS_SEED];
  } catch {
    return [...INITIAL_TRANSACTIONS_SEED];
  }
}

export function saveTransactionsDatabase(records: TransactionRecord[]): void {
  try {
    localStorage.setItem(STORAGE_KEYS.TRANSACTIONS_DB, JSON.stringify(records));
  } catch {
    // Ignore storage quota errors
  }
}

/**
 * Restores persistent auth session (`prm393_auth_session`) on startup.
 */
export function getPersistedAuthSession(): AuthSession | null {
  try {
    const raw = localStorage.getItem(STORAGE_KEYS.AUTH_SESSION);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as AuthSession;
    if (
      parsed &&
      parsed.auth_token &&
      parsed.current_user?.id &&
      parsed.current_user?.email
    ) {
      return parsed;
    }
    return null;
  } catch {
    return null;
  }
}

export function clearPersistedAuthSession(): void {
  try {
    localStorage.removeItem(STORAGE_KEYS.AUTH_SESSION);
  } catch {
    // Ignore
  }
}

/**
 * Authenticates via Node.js + SQLite REST endpoint `POST /api/auth/login`
 */
export async function apiLogin(
  email: string,
  password: string
): Promise<AuthSession> {
  const response = await fetch('/api/auth/login', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password }),
  });

  if (!response.ok) {
    const errBody = await response.json().catch(() => ({}));
    throw new Error(
      errBody.error || 'Email hoặc mật khẩu không chính xác. Vui lòng thử lại.'
    );
  }

  const session = (await response.json()) as AuthSession;
  try {
    localStorage.setItem(STORAGE_KEYS.AUTH_SESSION, JSON.stringify(session));
  } catch {
    // Ignore
  }
  return session;
}

/**
 * Fetches isolated user transactions from Node.js + SQLite `GET /api/transactions`
 */
export async function apiGetTransactions(
  user: UserAccount
): Promise<TransactionRecord[]> {
  try {
    const response = await fetch(
      `/api/transactions?userId=${encodeURIComponent(user.id)}`,
      {
        headers: { Accept: 'application/json' },
      }
    );
    if (response.ok) {
      const rows = (await response.json()) as TransactionRecord[];
      const existing = ensureTransactionsDatabase().filter(
        (t) => t.userId !== user.id
      );
      saveTransactionsDatabase([...rows, ...existing]);
      return rows;
    }
  } catch {
    // Fallback to local cache if offline
  }

  const all = ensureTransactionsDatabase();
  return getTransactionsForUser(all, user.id);
}

/**
 * Creates a new transaction in SQLite via `POST /api/transactions`
 */
export async function apiCreateTransaction(
  user: UserAccount,
  payload: {
    type: TransactionType;
    amount: number;
    category: CategoryName;
    date: string;
    note: string;
  }
): Promise<TransactionRecord> {
  const validation = validateTransactionInput({
    amountRaw: payload.amount,
    category: payload.category,
    date: payload.date,
  });

  if (!validation.valid) {
    throw new Error(validation.error || 'Dữ liệu giao dịch không hợp lệ.');
  }

  const response = await fetch('/api/transactions', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      userId: user.id,
      ownerEmail: user.email,
      ...payload,
    }),
  });

  if (!response.ok) {
    const errBody = await response.json().catch(() => ({}));
    throw new Error(errBody.error || 'Không thể lưu giao dịch.');
  }

  const created = (await response.json()) as TransactionRecord;
  const all = ensureTransactionsDatabase();
  saveTransactionsDatabase([created, ...all]);
  return created;
}

/**
 * Updates an existing transaction in SQLite via `PUT /api/transactions/:id`
 */
export async function apiUpdateTransaction(
  user: UserAccount,
  transactionId: string,
  payload: {
    type: TransactionType;
    amount: number;
    category: CategoryName;
    date: string;
    note: string;
  }
): Promise<TransactionRecord> {
  const validation = validateTransactionInput({
    amountRaw: payload.amount,
    category: payload.category,
    date: payload.date,
  });

  if (!validation.valid) {
    throw new Error(validation.error || 'Dữ liệu giao dịch không hợp lệ.');
  }

  const response = await fetch(
    `/api/transactions/${encodeURIComponent(transactionId)}`,
    {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        userId: user.id,
        ...payload,
      }),
    }
  );

  if (!response.ok) {
    const errBody = await response.json().catch(() => ({}));
    throw new Error(errBody.error || 'Không thể cập nhật giao dịch.');
  }

  const updated = (await response.json()) as TransactionRecord;
  const all = ensureTransactionsDatabase();
  const idx = all.findIndex(
    (t) => t.id === transactionId && t.userId === user.id
  );
  if (idx !== -1) {
    const next = [...all];
    next[idx] = updated;
    saveTransactionsDatabase(next);
  }
  return updated;
}

/**
 * Deletes a transaction permanently in SQLite via `DELETE /api/transactions/:id`
 */
export async function apiDeleteTransaction(
  user: UserAccount,
  transactionId: string
): Promise<void> {
  const response = await fetch(
    `/api/transactions/${encodeURIComponent(
      transactionId
    )}?userId=${encodeURIComponent(user.id)}`,
    {
      method: 'DELETE',
    }
  );

  if (!response.ok) {
    const errBody = await response.json().catch(() => ({}));
    throw new Error(errBody.error || 'Không thể xóa giao dịch.');
  }

  const all = ensureTransactionsDatabase();
  saveTransactionsDatabase(
    all.filter((t) => !(t.id === transactionId && t.userId === user.id))
  );
}

/**
 * Resets SQLite and localStorage database back to initial 8 VND seed records
 */
export async function apiResetDemoData(): Promise<TransactionRecord[]> {
  try {
    const response = await fetch('/api/demo/reset', {
      method: 'POST',
    });
    if (response.ok) {
      const rows = (await response.json()) as TransactionRecord[];
      saveTransactionsDatabase(rows);
      return rows;
    }
  } catch {
    // Fallback
  }
  saveTransactionsDatabase([...INITIAL_TRANSACTIONS_SEED]);
  return [...INITIAL_TRANSACTIONS_SEED];
}
