import test from 'node:test';
import assert from 'node:assert/strict';
import {
  INITIAL_TRANSACTIONS_SEED,
  calculateFinancialSummary,
  getTransactionsForUser,
  filterTransactions,
  validateLoginInput,
  authenticateCredentials,
  validateTransactionInput,
  formatCurrency,
  formatLongDate,
  getCategoryLabelVi,
} from './financeEngine';

test('User 1 (usr_01) multi-user isolation and Balance = Total Income - Total Expenses in VND', () => {
  const user1Txns = getTransactionsForUser(INITIAL_TRANSACTIONS_SEED, 'usr_01');
  assert.equal(user1Txns.length, 5);

  const summary = calculateFinancialSummary(user1Txns);
  // Income: 12,000,000 + 4,500,000 = 16,500,000
  // Expense: 85,000 + 450,000 + 150,000 = 685,000
  // Balance: 16,500,000 - 685,000 = 15,815,000
  assert.equal(summary.totalIncome, 16500000);
  assert.equal(summary.totalExpenses, 685000);
  assert.equal(summary.balance, 15815000);
});

test('User 2 (usr_02) multi-user isolation and Balance calculation in VND', () => {
  const user2Txns = getTransactionsForUser(INITIAL_TRANSACTIONS_SEED, 'usr_02');
  assert.equal(user2Txns.length, 3);

  const summary = calculateFinancialSummary(user2Txns);
  // Income: 6,500,000
  // Expense: 1,850,000 + 520,000 = 2,370,000
  // Balance: 6,500,000 - 2,370,000 = 4,130,000
  assert.equal(summary.totalIncome, 6500000);
  assert.equal(summary.totalExpenses, 2370000);
  assert.equal(summary.balance, 4130000);
});

test('Search and Dual Filter (supports both Vietnamese category/note and English keys)', () => {
  const user1Txns = getTransactionsForUser(INITIAL_TRANSACTIONS_SEED, 'usr_01');

  const byNote = filterTransactions(user1Txns, {
    searchQuery: 'thực tập',
    typeFilter: 'All',
    categoryFilter: 'All Categories',
  });
  assert.equal(byNote.length, 1);
  assert.equal(byNote[0].id, 'TXN-101');

  const byCategoryVi = filterTransactions(user1Txns, {
    searchQuery: 'ăn uống',
    typeFilter: 'All',
    categoryFilter: 'All Categories',
  });
  assert.equal(byCategoryVi.length, 1);
  assert.equal(byCategoryVi[0].id, 'TXN-103');

  const studyExpense = filterTransactions(user1Txns, {
    searchQuery: '',
    typeFilter: 'Expense',
    categoryFilter: 'Study',
  });
  assert.equal(studyExpense.length, 1);
  assert.equal(studyExpense[0].id, 'TXN-104');
});

test('Login validation and authentication in Vietnamese', () => {
  assert.equal(validateLoginInput('', '123456').valid, false);
  assert.equal(validateLoginInput('invalid-email', '123456').valid, false);
  assert.equal(validateLoginInput('user1@fpt.edu.vn', '123').valid, false);

  const failedAuth = authenticateCredentials('user1@fpt.edu.vn', 'wrongpass');
  assert.equal(failedAuth.success, false);
  assert.equal(
    failedAuth.error,
    'Email hoặc mật khẩu không chính xác. Vui lòng thử lại.'
  );

  const validAuth = authenticateCredentials('user1@fpt.edu.vn', '123456');
  assert.equal(validAuth.success, true);
  assert.equal(validAuth.user?.id, 'usr_01');
});

test('Transaction input validation enforces amount > 0 ₫, category, and date', () => {
  const zeroAmount = validateTransactionInput({
    amountRaw: '0',
    category: 'Salary',
    date: '2026-10-28',
  });
  assert.equal(zeroAmount.valid, false);
  assert.equal(zeroAmount.fieldErrors?.amount, 'Số tiền phải lớn hơn 0 ₫.');

  const negativeAmount = validateTransactionInput({
    amountRaw: '-50000',
    category: 'Food & Drink',
    date: '2026-10-28',
  });
  assert.equal(negativeAmount.valid, false);
  assert.equal(negativeAmount.fieldErrors?.amount, 'Số tiền phải lớn hơn 0 ₫.');

  const validInput = validateTransactionInput({
    amountRaw: '150000',
    category: 'Food & Drink',
    date: '2026-10-28',
  });
  assert.equal(validInput.valid, true);
});

test('VND Currency and Vietnamese date formatting helpers', () => {
  assert.equal(formatCurrency(12000000, 'Income'), '+12.000.000 ₫');
  assert.equal(formatCurrency(85000, 'Expense'), '-85.000 ₫');
  assert.equal(formatCurrency(15815000), '15.815.000 ₫');
  assert.equal(formatLongDate('2026-10-27'), '27 tháng 10, 2026');
  assert.equal(getCategoryLabelVi('Food & Drink'), 'Ăn uống');
});
