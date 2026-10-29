import React, { useState, useEffect, useCallback, useMemo } from 'react';
import {
  Home,
  ListFilter,
  Plus,
  CheckCircle2,
  AlertTriangle,
} from 'lucide-react';
import { motion, AnimatePresence } from 'motion/react';
import {
  AuthSession,
  CategoryName,
  TransactionFilterOptions,
  TransactionRecord,
  TransactionType,
  calculateFinancialSummary,
  getTransactionsForUser,
} from './lib/financeEngine';
import {
  apiCreateTransaction,
  apiDeleteTransaction,
  apiGetTransactions,
  apiLogin,
  apiResetDemoData,
  apiUpdateTransaction,
  clearPersistedAuthSession,
  ensureTransactionsDatabase,
  getPersistedAuthSession,
} from './lib/apiService';
import { LoginScreen } from './components/LoginScreen';
import { HomeDashboardScreen } from './components/HomeDashboardScreen';
import { TransactionListScreen } from './components/TransactionListScreen';
import { AddEditTransactionScreen } from './components/AddEditTransactionScreen';
import { TransactionDetailScreen } from './components/TransactionDetailScreen';

type ActiveScreen =
  | 'LOGIN'
  | 'HOME_DASHBOARD'
  | 'TRANSACTION_LIST'
  | 'ADD_EDIT_MODAL'
  | 'TRANSACTION_DETAIL';

export default function App() {
  const [session, setSession] = useState<AuthSession | null>(null);
  const [allTransactions, setAllTransactions] = useState<TransactionRecord[]>(
    []
  );
  const [activeScreen, setActiveScreen] = useState<ActiveScreen>('LOGIN');
  const [previousTabScreen, setPreviousTabScreen] = useState<
    'HOME_DASHBOARD' | 'TRANSACTION_LIST'
  >('HOME_DASHBOARD');
  const [selectedTransactionId, setSelectedTransactionId] = useState<
    string | null
  >(null);
  const [editingTransaction, setEditingTransaction] =
    useState<TransactionRecord | null>(null);

  const [filterOptions, setFilterOptions] = useState<TransactionFilterOptions>({
    searchQuery: '',
    typeFilter: 'All',
    categoryFilter: 'All Categories',
  });

  const [toastMessage, setToastMessage] = useState<string | null>(null);
  const [apiErrorBanner, setApiErrorBanner] = useState<string | null>(null);

  const triggerToast = useCallback((msg: string) => {
    setToastMessage(msg);
  }, []);

  useEffect(() => {
    if (!toastMessage) return;
    const timer = setTimeout(() => setToastMessage(null), 2400);
    return () => clearTimeout(timer);
  }, [toastMessage]);

  const runStartupLifecycle = useCallback(async () => {
    const dbRecords = ensureTransactionsDatabase();
    setAllTransactions(dbRecords);

    const persistedSession = getPersistedAuthSession();
    if (persistedSession && persistedSession.auth_token) {
      setSession(persistedSession);
      setActiveScreen('HOME_DASHBOARD');
      setPreviousTabScreen('HOME_DASHBOARD');
      try {
        const synced = await apiGetTransactions(persistedSession.current_user);
        if (synced.length > 0) {
          setAllTransactions(ensureTransactionsDatabase());
        }
      } catch {
        // Offline fallback uses local SQLite/storage cache
      }
    } else {
      setSession(null);
      setActiveScreen('LOGIN');
    }
  }, []);

  useEffect(() => {
    runStartupLifecycle();
  }, [runStartupLifecycle]);

  const userTransactions = useMemo(() => {
    if (!session?.current_user) return [];
    return getTransactionsForUser(allTransactions, session.current_user.id);
  }, [allTransactions, session]);

  const financialSummary = useMemo(
    () => calculateFinancialSummary(userTransactions),
    [userTransactions]
  );

  const selectedTransaction = useMemo(() => {
    if (!selectedTransactionId) return null;
    return (
      userTransactions.find((t) => t.id === selectedTransactionId) || null
    );
  }, [userTransactions, selectedTransactionId]);

  const handleLogin = async (email: string, password: string) => {
    setApiErrorBanner(null);
    const newSession = await apiLogin(email, password);
    setSession(newSession);
    const userTxns = await apiGetTransactions(newSession.current_user);
    const dbRecords = ensureTransactionsDatabase();
    setAllTransactions(dbRecords.length > 0 ? dbRecords : userTxns);
    setFilterOptions({
      searchQuery: '',
      typeFilter: 'All',
      categoryFilter: 'All Categories',
    });
    setActiveScreen('HOME_DASHBOARD');
    setPreviousTabScreen('HOME_DASHBOARD');
    triggerToast(`Chào mừng trở lại, ${newSession.current_user.name}`);
  };

  const handleLogout = () => {
    clearPersistedAuthSession();
    setSession(null);
    setSelectedTransactionId(null);
    setEditingTransaction(null);
    setActiveScreen('LOGIN');
    triggerToast('Đã đăng xuất khỏi tài khoản');
  };

  const handleQuickSwitchUser = async (email: string) => {
    const newSession = await apiLogin(email, '123456');
    setSession(newSession);
    await apiGetTransactions(newSession.current_user);
    setAllTransactions(ensureTransactionsDatabase());
    setFilterOptions({
      searchQuery: '',
      typeFilter: 'All',
      categoryFilter: 'All Categories',
    });
    setActiveScreen('HOME_DASHBOARD');
    setPreviousTabScreen('HOME_DASHBOARD');
    triggerToast(`Đã chuyển sang tài khoản: ${newSession.current_user.name}`);
  };

  const handleResetDemo = async () => {
    const resetRows = await apiResetDemoData();
    setAllTransactions(resetRows);
    if (session?.current_user) {
      await apiGetTransactions(session.current_user);
      setAllTransactions(ensureTransactionsDatabase());
    }
    triggerToast('Đã khôi phục dữ liệu mẫu (VNĐ)');
  };

  const handleOpenAddModal = () => {
    if (
      activeScreen === 'HOME_DASHBOARD' ||
      activeScreen === 'TRANSACTION_LIST'
    ) {
      setPreviousTabScreen(activeScreen);
    }
    setEditingTransaction(null);
    setActiveScreen('ADD_EDIT_MODAL');
  };

  const handleOpenEditModal = (txn: TransactionRecord) => {
    setEditingTransaction(txn);
    setActiveScreen('ADD_EDIT_MODAL');
  };

  const handleSaveTransaction = async (payload: {
    type: TransactionType;
    amount: number;
    category: CategoryName;
    date: string;
    note: string;
  }) => {
    if (!session?.current_user) return;
    setApiErrorBanner(null);

    if (editingTransaction) {
      const updated = await apiUpdateTransaction(
        session.current_user,
        editingTransaction.id,
        payload
      );
      setAllTransactions(ensureTransactionsDatabase());
      setSelectedTransactionId(updated.id);
      setEditingTransaction(null);
      setActiveScreen('TRANSACTION_DETAIL');
      triggerToast('Đã cập nhật giao dịch thành công');
    } else {
      await apiCreateTransaction(session.current_user, payload);
      setAllTransactions(ensureTransactionsDatabase());
      setEditingTransaction(null);
      setActiveScreen(previousTabScreen);
      triggerToast('Đã lưu giao dịch thành công');
    }
  };

  const handleDeleteTransaction = async (transactionId: string) => {
    if (!session?.current_user) return;
    setApiErrorBanner(null);

    await apiDeleteTransaction(session.current_user, transactionId);
    setAllTransactions(ensureTransactionsDatabase());
    setSelectedTransactionId(null);
    setActiveScreen(previousTabScreen);
    triggerToast('Đã xóa giao dịch — Số dư đã cập nhật');
  };

  const handleSelectTransaction = (txn: TransactionRecord) => {
    if (
      activeScreen === 'HOME_DASHBOARD' ||
      activeScreen === 'TRANSACTION_LIST'
    ) {
      setPreviousTabScreen(activeScreen);
    }
    setSelectedTransactionId(txn.id);
    setActiveScreen('TRANSACTION_DETAIL');
  };

  const showBottomNavigation =
    session !== null &&
    (activeScreen === 'HOME_DASHBOARD' || activeScreen === 'TRANSACTION_LIST');

  return (
    <div className="min-h-[100dvh] w-full bg-[#080C14] text-[#F8FAFC] flex justify-center select-none overflow-hidden">
      {/* Native Mobile App Shell with full iOS SafeArea support */}
      <div
        data-testid="mobile-app-shell"
        className="relative w-full max-w-[430px] h-[100dvh] bg-[#080C14] sm:border-x sm:border-white/[0.08] sm:shadow-[0_0_80px_rgba(0,0,0,0.85)] overflow-hidden flex flex-col"
      >
        {/* Ambient Lighting Orbs (Fixed behind the glass layer) */}
        <div
          aria-hidden="true"
          className="pointer-events-none absolute inset-0 overflow-hidden z-0"
        >
          <div
            className="absolute -top-12 -left-12 w-[260px] h-[260px] rounded-full"
            style={{
              background:
                'radial-gradient(circle, rgba(16, 185, 129, 0.18) 0%, rgba(16, 185, 129, 0) 70%)',
              filter: 'blur(90px)',
            }}
          />
          <div
            className="absolute top-[280px] -right-16 w-[280px] h-[280px] rounded-full"
            style={{
              background:
                'radial-gradient(circle, rgba(99, 102, 241, 0.16) 0%, rgba(99, 102, 241, 0) 70%)',
              filter: 'blur(110px)',
            }}
          />
          <div
            className="absolute bottom-8 -left-10 w-[240px] h-[240px] rounded-full"
            style={{
              background:
                'radial-gradient(circle, rgba(14, 165, 233, 0.12) 0%, rgba(14, 165, 233, 0) 70%)',
              filter: 'blur(100px)',
            }}
          />
        </div>

        {/* Global Error Banner */}
        <AnimatePresence>
          {apiErrorBanner && (
            <motion.div
              initial={{ opacity: 0, y: -8 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -8 }}
              role="alert"
              className="relative z-30 mx-4 mt-3 px-3 py-2 rounded-xl bg-[#F43F5E]/20 border border-[#F43F5E]/50 flex items-center justify-between gap-2 text-[12px] text-[#FB7185]"
            >
              <div className="flex items-center gap-2 min-w-0">
                <AlertTriangle className="w-4 h-4 text-[#F43F5E] shrink-0" />
                <span className="truncate">{apiErrorBanner}</span>
              </div>
              <button
                type="button"
                onClick={() => setApiErrorBanner(null)}
                className="text-[11px] font-bold underline shrink-0 cursor-pointer"
              >
                Đóng
              </button>
            </motion.div>
          )}
        </AnimatePresence>

        {/* Animated Glass Toast Notification */}
        <AnimatePresence>
          {toastMessage && (
            <motion.div
              key={toastMessage}
              initial={{ opacity: 0, y: 14, scale: 0.96 }}
              animate={{ opacity: 1, y: 0, scale: 1 }}
              exit={{ opacity: 0, y: 10, scale: 0.96 }}
              transition={{ type: 'spring', stiffness: 420, damping: 28 }}
              role="status"
              data-testid="glass-toast"
              className="absolute bottom-safe-toast left-5 right-5 z-40 glass-tier-1 px-4 py-2.5 flex items-center gap-2 text-[12.5px] font-semibold text-[#F8FAFC] shadow-lg pointer-events-none"
            >
              <CheckCircle2 className="w-4 h-4 text-[#34D399] shrink-0" />
              <span className="truncate">{toastMessage}</span>
            </motion.div>
          )}
        </AnimatePresence>

        {/* Main Scrollable Screen Viewport */}
        <main className="relative z-10 flex-1 overflow-y-auto no-scrollbar">
          {activeScreen === 'LOGIN' || !session ? (
            <LoginScreen
              key="screen-login"
              onLogin={handleLogin}
              apiError={apiErrorBanner}
              onClearError={() => setApiErrorBanner(null)}
            />
          ) : activeScreen === 'HOME_DASHBOARD' ? (
            <HomeDashboardScreen
              key="screen-dashboard"
              user={session.current_user}
              summary={financialSummary}
              recentTransactions={userTransactions}
              onLogout={handleLogout}
              onSwitchUser={handleQuickSwitchUser}
              onResetDemoData={handleResetDemo}
              onSeeAllTransactions={() => setActiveScreen('TRANSACTION_LIST')}
              onSelectTransaction={handleSelectTransaction}
              onOpenAddModal={handleOpenAddModal}
            />
          ) : activeScreen === 'TRANSACTION_LIST' ? (
            <TransactionListScreen
              key="screen-list"
              transactions={userTransactions}
              filterOptions={filterOptions}
              onChangeFilter={setFilterOptions}
              onSelectTransaction={handleSelectTransaction}
            />
          ) : activeScreen === 'ADD_EDIT_MODAL' ? (
            <AddEditTransactionScreen
              key="screen-add-edit"
              initialTransaction={editingTransaction}
              onCancel={() => {
                if (editingTransaction && selectedTransactionId) {
                  setEditingTransaction(null);
                  setActiveScreen('TRANSACTION_DETAIL');
                } else {
                  setEditingTransaction(null);
                  setActiveScreen(previousTabScreen);
                }
              }}
              onSave={handleSaveTransaction}
            />
          ) : activeScreen === 'TRANSACTION_DETAIL' && selectedTransaction ? (
            <TransactionDetailScreen
              key={`screen-detail-${selectedTransaction.id}`}
              transaction={selectedTransaction}
              onBack={() => setActiveScreen(previousTabScreen)}
              onEdit={handleOpenEditModal}
              onDelete={handleDeleteTransaction}
            />
          ) : (
            <HomeDashboardScreen
              key="screen-dashboard-fallback"
              user={session.current_user}
              summary={financialSummary}
              recentTransactions={userTransactions}
              onLogout={handleLogout}
              onSwitchUser={handleQuickSwitchUser}
              onResetDemoData={handleResetDemo}
              onSeeAllTransactions={() => setActiveScreen('TRANSACTION_LIST')}
              onSelectTransaction={handleSelectTransaction}
              onOpenAddModal={handleOpenAddModal}
            />
          )}
        </main>

        {/* Tier 1 Floating Bottom Tab Bar + Center FAB (`+`) with iOS SafeArea bottom offset */}
        <AnimatePresence>
          {showBottomNavigation && (
            <motion.nav
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: 20 }}
              transition={{ duration: 0.2 }}
              aria-label="Điều hướng chính"
              className="absolute bottom-safe-nav left-4 right-4 z-30 glass-tier-1 h-[64px] px-5 flex items-center justify-between"
            >
              <motion.button
                whileTap={{ scale: 0.93 }}
                type="button"
                onClick={() => setActiveScreen('HOME_DASHBOARD')}
                aria-current={
                  activeScreen === 'HOME_DASHBOARD' ? 'page' : undefined
                }
                className={`flex flex-col items-center justify-center min-w-[88px] min-h-[44px] cursor-pointer transition-colors ${
                  activeScreen === 'HOME_DASHBOARD'
                    ? 'text-[#38BDF8]'
                    : 'text-[#94A3B8] hover:text-[#F8FAFC]'
                }`}
              >
                <Home className="w-5 h-5" />
                <span className="text-[11px] font-semibold mt-0.5">
                  Tổng quan
                </span>
              </motion.button>

              {/* Floating Action Button (`+`) */}
              <motion.button
                whileHover={{ scale: 1.04 }}
                whileTap={{ scale: 0.92 }}
                type="button"
                onClick={handleOpenAddModal}
                aria-label="Thêm giao dịch"
                className="btn-primary-gradient w-12 h-12 rounded-2xl -mt-5 flex items-center justify-center text-[#080C14] shadow-xl border-2 border-[#080C14] cursor-pointer"
              >
                <Plus className="w-6 h-6 stroke-[2.5]" />
              </motion.button>

              <motion.button
                whileTap={{ scale: 0.93 }}
                type="button"
                onClick={() => setActiveScreen('TRANSACTION_LIST')}
                aria-current={
                  activeScreen === 'TRANSACTION_LIST' ? 'page' : undefined
                }
                className={`flex flex-col items-center justify-center min-w-[88px] min-h-[44px] cursor-pointer transition-colors ${
                  activeScreen === 'TRANSACTION_LIST'
                    ? 'text-[#38BDF8]'
                    : 'text-[#94A3B8] hover:text-[#F8FAFC]'
                }`}
              >
                <ListFilter className="w-5 h-5" />
                <span className="text-[11px] font-semibold mt-0.5">
                  Sổ giao dịch
                </span>
              </motion.button>
            </motion.nav>
          )}
        </AnimatePresence>
      </div>
    </div>
  );
}
