export type TransactionType = 'Income' | 'Expense';

export type CategoryName =
  | 'Salary'
  | 'Freelance'
  | 'Investment'
  | 'Food & Drink'
  | 'Transport'
  | 'Shopping'
  | 'Study'
  | 'Bills'
  | 'Entertainment';

export interface UserAccount {
  id: string;
  email: string;
  name: string;
  role: string;
}

export interface AuthSession {
  auth_token: string;
  current_user: UserAccount;
  authenticated_at: string;
}

export interface TransactionRecord {
  id: string;
  userId: string;
  ownerEmail: string;
  type: TransactionType;
  amount: number; // Stored in VND (e.g., 12000000)
  category: CategoryName;
  date: string; // YYYY-MM-DD
  note: string;
}

export interface FinancialSummary {
  totalIncome: number;
  totalExpenses: number;
  balance: number;
  incomeRatioPercent: number;
  expenseRatioPercent: number;
  transactionCount: number;
}

export interface TransactionFilterOptions {
  searchQuery: string;
  typeFilter: 'All' | TransactionType;
  categoryFilter: 'All Categories' | CategoryName;
}

export interface ValidationResult {
  valid: boolean;
  error?: string;
  fieldErrors?: {
    email?: string;
    password?: string;
    amount?: string;
    category?: string;
    date?: string;
  };
}

export const STORAGE_KEYS = {
  AUTH_SESSION: 'prm393_auth_session',
  TRANSACTIONS_DB: 'prm393_transactions_db_vnd',
} as const;

export const ALL_CATEGORIES: CategoryName[] = [
  'Salary',
  'Freelance',
  'Investment',
  'Food & Drink',
  'Transport',
  'Shopping',
  'Study',
  'Bills',
  'Entertainment',
];

export const INCOME_CATEGORIES: CategoryName[] = [
  'Salary',
  'Freelance',
  'Investment',
];

export const EXPENSE_CATEGORIES: CategoryName[] = [
  'Food & Drink',
  'Transport',
  'Shopping',
  'Study',
  'Bills',
  'Entertainment',
];

export const CATEGORY_LABELS_VI: Record<CategoryName, string> = {
  Salary: 'Lương',
  Freelance: 'Freelance',
  Investment: 'Đầu tư',
  'Food & Drink': 'Ăn uống',
  Transport: 'Di chuyển',
  Shopping: 'Mua sắm',
  Study: 'Học tập',
  Bills: 'Hóa đơn',
  Entertainment: 'Giải trí',
};

export const TYPE_LABELS_VI: Record<TransactionType, string> = {
  Income: 'Thu nhập',
  Expense: 'Chi tiêu',
};

export function getCategoryLabelVi(category: CategoryName): string {
  return CATEGORY_LABELS_VI[category] || category;
}

interface SeedUserRecord extends UserAccount {
  passwordHashCheck: string;
}

export const SEED_USERS: SeedUserRecord[] = [
  {
    id: 'usr_01',
    email: 'user1@fpt.edu.vn',
    passwordHashCheck: '123456',
    name: 'Tạ Tuấn Kỳ',
    role: 'Tài khoản Cá nhân',
  },
  {
    id: 'usr_02',
    email: 'user2@fpt.edu.vn',
    passwordHashCheck: '123456',
    name: 'Nguyễn Văn A',
    role: 'Tài khoản Cá nhân',
  },
];

export const INITIAL_TRANSACTIONS_SEED: TransactionRecord[] = [
  // User 1: Tạ Tuấn Kỳ (5 giao dịch — Đơn vị: VNĐ)
  {
    id: 'TXN-101',
    userId: 'usr_01',
    ownerEmail: 'user1@fpt.edu.vn',
    type: 'Income',
    amount: 12000000,
    category: 'Salary',
    date: '2026-10-01',
    note: 'Trợ cấp thực tập kỹ sư phần mềm tháng 10',
  },
  {
    id: 'TXN-102',
    userId: 'usr_01',
    ownerEmail: 'user1@fpt.edu.vn',
    type: 'Income',
    amount: 4500000,
    category: 'Freelance',
    date: '2026-10-10',
    note: 'Dự án thiết kế giao diện ứng dụng di động',
  },
  {
    id: 'TXN-103',
    userId: 'usr_01',
    ownerEmail: 'user1@fpt.edu.vn',
    type: 'Expense',
    amount: 85000,
    category: 'Food & Drink',
    date: '2026-10-18',
    note: 'Cà phê và ăn trưa cùng nhóm tại trường',
  },
  {
    id: 'TXN-104',
    userId: 'usr_01',
    ownerEmail: 'user1@fpt.edu.vn',
    type: 'Expense',
    amount: 450000,
    category: 'Study',
    date: '2026-10-22',
    note: 'Gia hạn máy chủ đám mây & tên miền học tập',
  },
  {
    id: 'TXN-105',
    userId: 'usr_01',
    ownerEmail: 'user1@fpt.edu.vn',
    type: 'Expense',
    amount: 150000,
    category: 'Transport',
    date: '2026-10-27',
    note: 'Vé xe buýt và di chuyển tuần này',
  },
  // User 2: Nguyễn Văn A (3 giao dịch độc lập — Đơn vị: VNĐ)
  {
    id: 'TXN-201',
    userId: 'usr_02',
    ownerEmail: 'user2@fpt.edu.vn',
    type: 'Income',
    amount: 6500000,
    category: 'Salary',
    date: '2026-10-05',
    note: 'Lương trợ giảng bán thời gian tại khoa',
  },
  {
    id: 'TXN-202',
    userId: 'usr_02',
    ownerEmail: 'user2@fpt.edu.vn',
    type: 'Expense',
    amount: 1850000,
    category: 'Shopping',
    date: '2026-10-14',
    note: 'Bàn phím cơ phục vụ lập trình',
  },
  {
    id: 'TXN-203',
    userId: 'usr_02',
    ownerEmail: 'user2@fpt.edu.vn',
    type: 'Expense',
    amount: 520000,
    category: 'Bills',
    date: '2026-10-20',
    note: 'Thanh toán tiền điện và Internet tháng 10',
  },
];

/**
 * Pure calculation of Balance = Total Income - Total Expenses for a user's transactions.
 */
export function calculateFinancialSummary(
  transactions: TransactionRecord[]
): FinancialSummary {
  let totalIncome = 0;
  let totalExpenses = 0;

  for (const txn of transactions) {
    const val = Number(txn.amount) || 0;
    if (txn.type === 'Income') {
      totalIncome += val;
    } else if (txn.type === 'Expense') {
      totalExpenses += val;
    }
  }

  totalIncome = Math.round(totalIncome);
  totalExpenses = Math.round(totalExpenses);
  const balance = totalIncome - totalExpenses;

  const grossVolume = totalIncome + totalExpenses;
  const incomeRatioPercent =
    grossVolume > 0 ? Math.round((totalIncome / grossVolume) * 1000) / 10 : 50;
  const expenseRatioPercent =
    grossVolume > 0 ? Math.round((100 - incomeRatioPercent) * 10) / 10 : 50;

  return {
    totalIncome,
    totalExpenses,
    balance,
    incomeRatioPercent,
    expenseRatioPercent,
    transactionCount: transactions.length,
  };
}

/**
 * Isolates transactions strictly by userId and sorts newest-first by date (and ID tie-breaker).
 */
export function getTransactionsForUser(
  allTransactions: TransactionRecord[],
  userId: string
): TransactionRecord[] {
  return allTransactions
    .filter((t) => t.userId === userId)
    .sort((a, b) => {
      const dateCompare = b.date.localeCompare(a.date);
      if (dateCompare !== 0) return dateCompare;
      return b.id.localeCompare(a.id);
    });
}

/**
 * Real-time search (by Note OR Category in Vietnamese/English, case-insensitive) and dual filtering.
 */
export function filterTransactions(
  userTransactions: TransactionRecord[],
  options: TransactionFilterOptions
): TransactionRecord[] {
  const query = options.searchQuery.trim().toLowerCase();

  return userTransactions.filter((txn) => {
    if (options.typeFilter !== 'All' && txn.type !== options.typeFilter) {
      return false;
    }
    if (
      options.categoryFilter !== 'All Categories' &&
      txn.category !== options.categoryFilter
    ) {
      return false;
    }
    if (query.length > 0) {
      const noteMatches = txn.note.toLowerCase().includes(query);
      const categoryMatches = txn.category.toLowerCase().includes(query);
      const categoryViMatches = getCategoryLabelVi(txn.category)
        .toLowerCase()
        .includes(query);
      const idMatches = txn.id.toLowerCase().includes(query);
      if (
        !noteMatches &&
        !categoryMatches &&
        !categoryViMatches &&
        !idMatches
      ) {
        return false;
      }
    }
    return true;
  });
}

/**
 * Validates login input fields before authenticating.
 */
export function validateLoginInput(
  email: string,
  password: string
): ValidationResult {
  const trimmedEmail = email.trim();
  const fieldErrors: NonNullable<ValidationResult['fieldErrors']> = {};

  if (!trimmedEmail) {
    fieldErrors.email = 'Vui lòng nhập địa chỉ email.';
  } else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(trimmedEmail)) {
    fieldErrors.email =
      'Định dạng email không hợp lệ (ví dụ: user1@fpt.edu.vn).';
  }

  if (!password) {
    fieldErrors.password = 'Vui lòng nhập mật khẩu.';
  } else if (password.length < 6) {
    fieldErrors.password = 'Mật khẩu phải có ít nhất 6 ký tự.';
  }

  if (fieldErrors.email || fieldErrors.password) {
    return {
      valid: false,
      error: fieldErrors.email || fieldErrors.password,
      fieldErrors,
    };
  }

  return { valid: true };
}

/**
 * Authenticates credentials against seed users and returns sanitized user account (never stores plaintext password).
 */
export function authenticateCredentials(
  email: string,
  password: string
): { success: boolean; user?: UserAccount; error?: string } {
  const validation = validateLoginInput(email, password);
  if (!validation.valid) {
    return { success: false, error: validation.error };
  }

  const normalizedEmail = email.trim().toLowerCase();
  const matched = SEED_USERS.find(
    (u) =>
      u.email.toLowerCase() === normalizedEmail &&
      u.passwordHashCheck === password
  );

  if (!matched) {
    return {
      success: false,
      error: 'Email hoặc mật khẩu không chính xác. Vui lòng thử lại.',
    };
  }

  const { passwordHashCheck: _, ...safeUser } = matched;
  return {
    success: true,
    user: safeUser,
  };
}

/**
 * Validates Add/Edit Transaction fields (Mandatory: amount > 0, category required, date required).
 */
export function validateTransactionInput(input: {
  amountRaw: string | number;
  category: string;
  date: string;
}): ValidationResult {
  const fieldErrors: NonNullable<ValidationResult['fieldErrors']> = {};
  const rawStr = String(input.amountRaw ?? '')
    .replace(/\./g, '')
    .replace(/,/g, '')
    .trim();
  const parsedAmount = Number(rawStr);

  if (
    rawStr === '' ||
    Number.isNaN(parsedAmount) ||
    !Number.isFinite(parsedAmount) ||
    parsedAmount <= 0
  ) {
    fieldErrors.amount = 'Số tiền phải lớn hơn 0 ₫.';
  }

  if (
    !input.category ||
    !ALL_CATEGORIES.includes(input.category as CategoryName)
  ) {
    fieldErrors.category = 'Vui lòng chọn danh mục giao dịch.';
  }

  if (!input.date || !/^\d{4}-\d{2}-\d{2}$/.test(input.date.trim())) {
    fieldErrors.date = 'Vui lòng chọn ngày giao dịch hợp lệ (YYYY-MM-DD).';
  }

  if (fieldErrors.amount || fieldErrors.category || fieldErrors.date) {
    return {
      valid: false,
      error: fieldErrors.amount || fieldErrors.category || fieldErrors.date,
      fieldErrors,
    };
  }

  return { valid: true };
}

/**
 * Formats currency amounts consistently in tabular Vietnamese Dong format (e.g., 15.815.000 ₫).
 */
export function formatCurrency(
  amount: number,
  includeSignForType?: TransactionType
): string {
  const abs = Math.round(Math.abs(Number(amount) || 0));
  const formattedNumber = abs.toString().replace(/\B(?=(\d{3})+(?!\d))/g, '.');
  const formatted = `${formattedNumber} ₫`;

  if (includeSignForType === 'Income') {
    return `+${formatted}`;
  }
  if (includeSignForType === 'Expense') {
    return `-${formatted}`;
  }
  if (amount < 0) {
    return `-${formatted}`;
  }
  return formatted;
}

/**
 * Formats YYYY-MM-DD into a Vietnamese readable date (e.g., "27 tháng 10, 2026") for Detail View.
 */
export function formatLongDate(dateStr: string): string {
  const parts = dateStr.split('-').map(Number);
  if (parts.length !== 3 || parts.some(Number.isNaN)) return dateStr;
  const [year, month, day] = parts;
  return `${day} tháng ${month}, ${year}`;
}
