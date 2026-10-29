import React, { useState } from 'react';
import {
  LogOut,
  ArrowDownLeft,
  ArrowUpRight,
  ChevronRight,
  Plus,
  Users,
  RotateCcw,
  Check,
} from 'lucide-react';
import { motion, AnimatePresence } from 'motion/react';
import {
  FinancialSummary,
  TransactionRecord,
  UserAccount,
  formatCurrency,
  getCategoryLabelVi,
} from '../lib/financeEngine';
import { CategoryIconBadge } from './CategoryIconBadge';

interface HomeDashboardScreenProps {
  user: UserAccount;
  summary: FinancialSummary;
  recentTransactions: TransactionRecord[];
  onLogout: () => void;
  onSwitchUser: (email: string) => void;
  onResetDemoData: () => void;
  onSeeAllTransactions: () => void;
  onSelectTransaction: (transaction: TransactionRecord) => void;
  onOpenAddModal: () => void;
}

export const HomeDashboardScreen: React.FC<HomeDashboardScreenProps> = ({
  user,
  summary,
  recentTransactions,
  onLogout,
  onSwitchUser,
  onResetDemoData,
  onSeeAllTransactions,
  onSelectTransaction,
  onOpenAddModal,
}) => {
  const [showAccountMenu, setShowAccountMenu] = useState(false);

  const initials = user.name
    .split(' ')
    .map((part) => part[0])
    .slice(-2)
    .join('')
    .toUpperCase();

  return (
    <motion.div
      initial={{ opacity: 0, y: 8 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.16, ease: 'easeOut' }}
      className="flex flex-col px-4 pt-safe pb-safe-scroll"
    >
      {/* Top App Bar */}
      <header className="flex items-center justify-between gap-2 mb-4">
        <button
          type="button"
          onClick={() => setShowAccountMenu((prev) => !prev)}
          aria-expanded={showAccountMenu}
          aria-label="Mở menu chuyển tài khoản"
          className="flex items-center gap-2.5 min-w-0 text-left cursor-pointer"
        >
          <div
            className="w-10 h-10 rounded-2xl flex items-center justify-center font-bold text-[13.5px] text-[#F8FAFC] shrink-0 border border-white/15"
            style={{
              background:
                'linear-gradient(135deg, rgba(56, 189, 248, 0.25) 0%, rgba(129, 140, 248, 0.25) 100%)',
            }}
            aria-hidden="true"
          >
            {initials}
          </div>
          <div className="min-w-0">
            <h1 className="text-[15.5px] font-bold tracking-[-0.02em] text-[#F8FAFC] truncate">
              Xin chào, {user.name}
            </h1>
            <p className="text-[11.5px] text-[#94A3B8] font-tabular truncate">
              {user.email}
            </p>
          </div>
        </button>

        <div className="flex items-center gap-1.5 shrink-0">
          <motion.button
            whileTap={{ scale: 0.95 }}
            type="button"
            onClick={() => setShowAccountMenu((prev) => !prev)}
            aria-label="Chuyển tài khoản"
            title="Chuyển tài khoản"
            className={`glass-tier-2 glass-tier-2-interactive w-9 h-9 flex items-center justify-center cursor-pointer ${
              showAccountMenu ? 'text-[#38BDF8] border-[#38BDF8]/50' : 'text-[#94A3B8]'
            }`}
          >
            <Users className="w-4 h-4" />
          </motion.button>

          <motion.button
            whileTap={{ scale: 0.95 }}
            type="button"
            onClick={onLogout}
            aria-label="Đăng xuất"
            title="Đăng xuất"
            className="glass-tier-2 glass-tier-2-interactive h-9 px-2.5 flex items-center justify-center gap-1 text-[11.5px] font-semibold text-[#FB7185] cursor-pointer"
          >
            <LogOut className="w-3.5 h-3.5" />
            <span>Thoát</span>
          </motion.button>
        </div>
      </header>

      {/* Collapsible Mobile Account Switcher & Demo Reset Drawer */}
      <AnimatePresence>
        {showAccountMenu && (
          <motion.div
            initial={{ opacity: 0, height: 0 }}
            animate={{ opacity: 1, height: 'auto' }}
            exit={{ opacity: 0, height: 0 }}
            transition={{ duration: 0.18 }}
            className="overflow-hidden mb-4"
          >
            <div className="glass-tier-2 p-3.5 flex flex-col gap-2.5">
              <div className="flex items-center justify-between text-[11.5px]">
                <span className="font-semibold text-[#94A3B8]">
                  Chuyển nhanh Tài khoản (Cô lập dữ liệu)
                </span>
                <button
                  type="button"
                  onClick={() => {
                    onResetDemoData();
                    setShowAccountMenu(false);
                  }}
                  className="text-[#38BDF8] font-semibold flex items-center gap-1 cursor-pointer"
                >
                  <RotateCcw className="w-3 h-3" />
                  <span>Khôi phục mẫu</span>
                </button>
              </div>

              <div className="grid grid-cols-2 gap-2">
                <button
                  type="button"
                  onClick={() => {
                    onSwitchUser('user1@fpt.edu.vn');
                    setShowAccountMenu(false);
                  }}
                  className={`p-2.5 rounded-xl border text-left transition-all cursor-pointer ${
                    user.email === 'user1@fpt.edu.vn'
                      ? 'bg-[#34D399]/15 border-[#34D399]/50 text-[#F8FAFC]'
                      : 'bg-[#080C14]/50 border-white/10 text-[#94A3B8]'
                  }`}
                >
                  <div className="flex items-center justify-between">
                    <span className="text-[12px] font-bold">Tạ Tuấn Kỳ</span>
                    {user.email === 'user1@fpt.edu.vn' && (
                      <Check className="w-3.5 h-3.5 text-[#34D399]" />
                    )}
                  </div>
                  <div className="text-[10.5px] font-tabular text-[#94A3B8] truncate">
                    user1@fpt.edu.vn
                  </div>
                </button>

                <button
                  type="button"
                  onClick={() => {
                    onSwitchUser('user2@fpt.edu.vn');
                    setShowAccountMenu(false);
                  }}
                  className={`p-2.5 rounded-xl border text-left transition-all cursor-pointer ${
                    user.email === 'user2@fpt.edu.vn'
                      ? 'bg-[#38BDF8]/15 border-[#38BDF8]/50 text-[#F8FAFC]'
                      : 'bg-[#080C14]/50 border-white/10 text-[#94A3B8]'
                  }`}
                >
                  <div className="flex items-center justify-between">
                    <span className="text-[12px] font-bold">Nguyễn Văn A</span>
                    {user.email === 'user2@fpt.edu.vn' && (
                      <Check className="w-3.5 h-3.5 text-[#38BDF8]" />
                    )}
                  </div>
                  <div className="text-[10.5px] font-tabular text-[#94A3B8] truncate">
                    user2@fpt.edu.vn
                  </div>
                </button>
              </div>
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Hero Summary Glass Card (Tier 1 Frosted Glass — Mandatory Formula: Số dư = Tổng thu - Tổng chi) */}
      <motion.section
        layout
        aria-label="Tổng quan số dư"
        className="glass-tier-1 p-5 mb-4 relative overflow-hidden"
      >
        <div className="flex items-center justify-between mb-1">
          <span className="text-[11px] font-semibold uppercase tracking-[0.06em] text-[#94A3B8]">
            SỐ DƯ HIỆN TẠI (VNĐ)
          </span>
          <span className="text-[11px] font-tabular text-[#94A3B8]">
            {summary.transactionCount} giao dịch
          </span>
        </div>

        <motion.div
          key={summary.balance}
          initial={{ opacity: 0.6, scale: 0.98 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ type: 'spring', stiffness: 400, damping: 28 }}
          data-testid="hero-balance-amount"
          className={`text-[28px] font-bold tracking-[-0.03em] font-tabular leading-tight my-1 ${
            summary.balance < 0 ? 'text-[#FB7185]' : 'text-[#F8FAFC]'
          }`}
        >
          {formatCurrency(summary.balance)}
        </motion.div>

        {/* Formula Sub-caption */}
        <p className="text-[11.5px] text-[#64748B] mb-4">
          Số dư = Tổng thu nhập − Tổng chi tiêu
        </p>

        {/* 2-Column Horizontal Split Divider inside the Tier 1 Glass Card */}
        <div className="pt-3.5 border-t border-white/12 grid grid-cols-2 gap-2.5">
          {/* Left Column: Tổng thu nhập */}
          <div className="flex items-center gap-2 min-w-0">
            <div className="w-8 h-8 rounded-xl bg-[#34D399]/[0.14] border border-[#34D399]/30 flex items-center justify-center text-[#34D399] shrink-0">
              <ArrowDownLeft className="w-4 h-4" />
            </div>
            <div className="min-w-0">
              <div className="text-[11px] font-medium text-[#94A3B8] truncate">
                Tổng thu nhập
              </div>
              <div
                data-testid="hero-total-income"
                className="text-[13px] font-bold font-tabular text-[#34D399] truncate"
              >
                {formatCurrency(summary.totalIncome, 'Income')}
              </div>
            </div>
          </div>

          {/* Right Column: Tổng chi tiêu */}
          <div className="flex items-center gap-2 min-w-0 pl-2.5 border-l border-white/10">
            <div className="w-8 h-8 rounded-xl bg-[#FB7185]/[0.14] border border-[#FB7185]/30 flex items-center justify-center text-[#FB7185] shrink-0">
              <ArrowUpRight className="w-4 h-4" />
            </div>
            <div className="min-w-0">
              <div className="text-[11px] font-medium text-[#94A3B8] truncate">
                Tổng chi tiêu
              </div>
              <div
                data-testid="hero-total-expenses"
                className="text-[13px] font-bold font-tabular text-[#FB7185] truncate"
              >
                {formatCurrency(summary.totalExpenses, 'Expense')}
              </div>
            </div>
          </div>
        </div>
      </motion.section>

      {/* Cashflow Ratio Mini-Bar */}
      <section
        aria-label="Tỷ lệ Thu Chi"
        className="glass-tier-2 px-4 py-3 mb-5"
      >
        <div className="flex items-center justify-between text-[12px] mb-2">
          <span className="font-medium text-[#94A3B8]">
            Tỷ lệ dòng tiền{' '}
            <span className="font-tabular text-[#34D399] font-semibold ml-1">
              {summary.incomeRatioPercent}% Thu
            </span>
          </span>
          <span className="font-tabular text-[#FB7185] font-semibold">
            {summary.expenseRatioPercent}% Chi
          </span>
        </div>
        <div className="w-full h-2 rounded-full bg-[#080C14]/80 overflow-hidden flex gap-0.5">
          <motion.div
            initial={{ width: 0 }}
            animate={{ width: `${summary.incomeRatioPercent}%` }}
            transition={{ duration: 0.4, ease: 'easeOut' }}
            className="h-full bg-[#34D399] rounded-l-full"
          />
          <motion.div
            initial={{ width: 0 }}
            animate={{ width: `${summary.expenseRatioPercent}%` }}
            transition={{ duration: 0.4, ease: 'easeOut' }}
            className="h-full bg-[#FB7185] rounded-r-full"
          />
        </div>
      </section>

      {/* Recent Transactions Section */}
      <section aria-label="Giao dịch gần đây">
        <div className="flex items-center justify-between mb-3 px-0.5">
          <h2 className="text-[14px] font-semibold uppercase tracking-[0.04em] text-[#94A3B8]">
            Giao dịch gần đây
          </h2>
          <button
            type="button"
            onClick={onSeeAllTransactions}
            className="min-h-[36px] px-2 text-[13px] font-semibold text-[#38BDF8] hover:text-[#818CF8] transition-colors flex items-center gap-0.5 cursor-pointer"
          >
            <span>Xem tất cả</span>
            <ChevronRight className="w-4 h-4" />
          </button>
        </div>

        {recentTransactions.length === 0 ? (
          <div className="glass-tier-2 p-6 text-center">
            <p className="text-[14px] font-medium text-[#94A3B8] mb-3">
              Chưa có giao dịch nào được ghi nhận cho {user.name}.
            </p>
            <motion.button
              whileTap={{ scale: 0.97 }}
              type="button"
              onClick={onOpenAddModal}
              className="btn-primary-gradient px-4 py-2.5 rounded-xl text-[13px] font-bold text-[#080C14] inline-flex items-center gap-1.5 cursor-pointer"
            >
              <Plus className="w-4 h-4" />
              <span>Thêm giao dịch đầu tiên</span>
            </motion.button>
          </div>
        ) : (
          <div className="flex flex-col">
            {recentTransactions.slice(0, 5).map((txn) => {
              const isIncome = txn.type === 'Income';
              const categoryVi = getCategoryLabelVi(txn.category);
              return (
                <motion.button
                  key={txn.id}
                  whileTap={{ scale: 0.985 }}
                  type="button"
                  onClick={() => onSelectTransaction(txn)}
                  aria-label={`${categoryVi} ${txn.note || ''} ${formatCurrency(
                    txn.amount,
                    txn.type
                  )}`}
                  className="glass-tier-2 glass-tier-2-interactive w-full text-left px-4 py-3.5 mb-2.5 flex items-center justify-between gap-2.5 cursor-pointer"
                >
                  <div className="flex items-center gap-3 min-w-0">
                    <CategoryIconBadge
                      category={txn.category}
                      type={txn.type}
                      size="md"
                    />
                    <div className="min-w-0">
                      <div className="text-[14.5px] font-semibold text-[#F8FAFC] truncate">
                        {categoryVi}
                      </div>
                      <div className="text-[12.5px] text-[#94A3B8] truncate">
                        {txn.note || 'Không có ghi chú'}
                      </div>
                      <div className="text-[11px] font-tabular text-[#64748B] mt-0.5">
                        {txn.date}
                      </div>
                    </div>
                  </div>

                  <div className="flex items-center gap-1 shrink-0">
                    <span
                      className={`text-[13.5px] font-bold font-tabular ${
                        isIncome ? 'text-[#34D399]' : 'text-[#FB7185]'
                      }`}
                    >
                      {formatCurrency(txn.amount, txn.type)}
                    </span>
                    <ChevronRight className="w-4 h-4 text-[#64748B]" />
                  </div>
                </motion.button>
              );
            })}
          </div>
        )}
      </section>
    </motion.div>
  );
};
