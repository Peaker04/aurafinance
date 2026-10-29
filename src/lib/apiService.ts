import {
  AuthSession,
  CategoryName,
  INITIAL_TRANSACTIONS_SEED,
  STORAGE_KEYS,
  TransactionRecord,
  TransactionType,
  UserAccount,
  authenticateCredentials,
  getTransactionsForUser,
  validateTransactionInput,
} from './financeEngine';

/**
 * Ensures local cache is initialized and synchronized with the database (in VNĐ).
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
 * Authenticates via Node.js + SQLite REST endpoint `POST /api/auth/login`.
 * Tự động fallback sang authenticateCredentials() khi chạy độc lập trong .ipa trên iPhone.
 */
export async function apiLogin(
  email: string,
  password: string
): Promise<AuthSession> {
  try {
    const response = await fetch('/api/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password }),
    });

    const contentType = response.headers.get('content-type') || '';
    if (response.ok && contentType.includes('application/json')) {
      const session = (await response.json()) as AuthSession;
      try {
        localStorage.setItem(STORAGE_KEYS.AUTH_SESSION, JSON.stringify(session));
      } catch {
        // Ignore
      }
      return session;
    }

    if (!response.ok && contentType.includes('application/json')) {
      const errBody = await response.json().catch(() => ({}));
      if (errBody.error) {
        throw new Error(errBody.error);
      }
    }
  } catch (err: unknown) {
    if (
      err instanceof Error &&
      (err.message.includes('Mật khẩu') ||
        err.message.includes('Email') ||
        err.message.includes('không chính xác'))
    ) {
      throw err;
    }
    // Lỗi mạng hoặc 404 khi chạy offline trên file .ipa -> Tự động fallback
  }

  // Fallback xác thực Offline cho iPhone
  const auth = authenticateCredentials(email, password);
  if (!auth.success || !auth.user) {
    throw new Error(
      auth.error || 'Email hoặc mật khẩu không chính xác. Vui lòng thử lại.'
    );
  }

  const session: AuthSession = {
    auth_token: `token_offline_${auth.user.id}_${Date.now()}`,
    current_user: auth.user,
    authenticated_at: new Date().toISOString(),
  };

  try {
    localStorage.setItem(STORAGE_KEYS.AUTH_SESSION, JSON.stringify(session));
  } catch {
    // Ignore
  }
  return session;
}

/**
 * Fetches isolated user transactions.
 * Khi ở cổng 3000: Đồng bộ SQLite Server.
 * Khi ở file .ipa: Đọc trực tiếp từ localStorage.
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
    const contentType = response.headers.get('content-type') || '';
    if (response.ok && contentType.includes('application/json')) {
      const rows = (await response.json()) as TransactionRecord[];
      const existing = ensureTransactionsDatabase().filter(
        (t) => t.userId !== user.id
      );
      saveTransactionsDatabase([...rows, ...existing]);
      return rows;
    }
  } catch {
    // Offline fallback uses local cache
  }

  const all = ensureTransactionsDatabase();
  return getTransactionsForUser(all, user.id);
}

/**
 * Creates a new transaction.
 * Khi ở cổng 3000: Lưu vào SQLite Server.
 * Khi ở file .ipa: Lưu trực tiếp vào localStorage thiết bị.
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

  try {
    const response = await fetch('/api/transactions', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        userId: user.id,
        ownerEmail: user.email,
        ...payload,
      }),
    });

    const contentType = response.headers.get('content-type') || '';
    if (response.ok && contentType.includes('application/json')) {
      const created = (await response.json()) as TransactionRecord;
      const all = ensureTransactionsDatabase();
      saveTransactionsDatabase([created, ...all]);
      return created;
    }
  } catch {
    // Offline fallback for iPhone .ipa
  }

  // Fallback lưu trực tiếp trên máy
  const newTxn: TransactionRecord = {
    id: `TXN-${10000 + Math.floor(Math.random() * 89999)}`,
    userId: user.id,
    ownerEmail: user.email,
    type: payload.type,
    amount: Math.round(Number(payload.amount)),
    category: payload.category,
    date: payload.date,
    note: payload.note || '',
  };

  const all = ensureTransactionsDatabase();
  saveTransactionsDatabase([newTxn, ...all]);
  return newTxn;
}

/**
 * Updates an existing transaction.
 * Khi ở cổng 3000: Cập nhật SQLite Server.
 * Khi ở file .ipa: Cập nhật trực tiếp trong localStorage thiết bị.
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

  try {
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

    const contentType = response.headers.get('content-type') || '';
    if (response.ok && contentType.includes('application/json')) {
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
  } catch {
    // Offline fallback for iPhone .ipa
  }

  // Fallback cập nhật trực tiếp trên máy
  const all = ensureTransactionsDatabase();
  const idx = all.findIndex(
    (t) => t.id === transactionId && t.userId === user.id
  );
  if (idx === -1) {
    throw new Error('Giao dịch không tồn tại hoặc không thuộc tài khoản của bạn.');
  }

  const updated: TransactionRecord = {
    ...all[idx],
    type: payload.type,
    amount: Math.round(Number(payload.amount)),
    category: payload.category,
    date: payload.date,
    note: payload.note || '',
  };

  const next = [...all];
  next[idx] = updated;
  saveTransactionsDatabase(next);
  return updated;
}

/**
 * Deletes a transaction permanently.
 * Khi ở cổng 3000: Xóa trên SQLite Server.
 * Khi ở file .ipa: Xóa trực tiếp trong localStorage thiết bị.
 */
export async function apiDeleteTransaction(
  user: UserAccount,
  transactionId: string
): Promise<void> {
  try {
    const response = await fetch(
      `/api/transactions/${encodeURIComponent(
        transactionId
      )}?userId=${encodeURIComponent(user.id)}`,
      {
        method: 'DELETE',
      }
    );
    if (response.ok) {
      const all = ensureTransactionsDatabase();
      saveTransactionsDatabase(
        all.filter((t) => !(t.id === transactionId && t.userId === user.id))
      );
      return;
    }
  } catch {
    // Offline fallback for iPhone .ipa
  }

  const all = ensureTransactionsDatabase();
  saveTransactionsDatabase(
    all.filter((t) => !(t.id === transactionId && t.userId === user.id))
  );
}

/**
 * Resets database back to initial 8 VND seed records.
 */
export async function apiResetDemoData(): Promise<TransactionRecord[]> {
  try {
    const response = await fetch('/api/demo/reset', {
      method: 'POST',
    });
    const contentType = response.headers.get('content-type') || '';
    if (response.ok && contentType.includes('application/json')) {
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
