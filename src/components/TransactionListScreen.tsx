import React, { useMemo } from 'react';
import {
  Search,
  X,
  ChevronRight,
  RotateCcw,
  Filter,
} from 'lucide-react';
import { motion, AnimatePresence } from 'motion/react';
import {
  ALL_CATEGORIES,
  CategoryName,
  TransactionFilterOptions,
  TransactionRecord,
  TransactionType,
  calculateFinancialSummary,
  filterTransactions,
  formatCurrency,
  getCategoryLabelVi,
} from '../lib/financeEngine';
import { CategoryIconBadge } from './CategoryIconBadge';

interface TransactionListScreenProps {
  transactions: TransactionRecord[];
  filterOptions: TransactionFilterOptions;
  onChangeFilter: (next: TransactionFilterOptions) => void;
  onSelectTransaction: (transaction: TransactionRecord) => void;
}

const CATEGORY_CHIPS: ('All Categories' | CategoryName)[] = [
  'All Categories',
  ...ALL_CATEGORIES,
];

const TYPE_OPTIONS: { value: 'All' | TransactionType; label: string }[] = [
  { value: 'All', label: 'Tất cả' },
  { value: 'Income', label: 'Thu nhập' },
  { value: 'Expense', label: 'Chi tiêu' },
];

export const TransactionListScreen: React.FC<TransactionListScreenProps> = ({
  transactions,
  filterOptions,
  onChangeFilter,
  onSelectTransaction,
}) => {
  const filteredTransactions = useMemo(
    () => filterTransactions(transactions, filterOptions),
    [transactions, filterOptions]
  );

  const filteredSummary = useMemo(
    () => calculateFinancialSummary(filteredTransactions),
    [filteredTransactions]
  );

  const handleResetFilters = () => {
    onChangeFilter({
      searchQuery: '',
      typeFilter: 'All',
      categoryFilter: 'All Categories',
    });
  };

  const hasActiveFilters =
    filterOptions.searchQuery.trim().length > 0 ||
    filterOptions.typeFilter !== 'All' ||
    filterOptions.categoryFilter !== 'All Categories';

  return (
    <motion.div
      initial={{ opacity: 0, y: 8 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.16, ease: 'easeOut' }}
      className="flex flex-col px-4 pt-safe pb-safe-scroll"
    >
      {/* iOS Large Header */}
      <div className="flex items-center justify-between mb-3.5 pt-1">
        <h1 className="text-[22px] font-bold tracking-[-0.02em] text-[#F8FAFC]">
          Sổ giao dịch
        </h1>
        {hasActiveFilters && (
          <motion.button
            initial={{ opacity: 0, scale: 0.9 }}
            animate={{ opacity: 1, scale: 1 }}
            whileTap={{ scale: 0.95 }}
            type="button"
            onClick={handleResetFilters}
            className="text-[12px] font-semibold text-[#38BDF8] hover:text-[#818CF8] flex items-center gap-1 cursor-pointer min-h-[36px] px-2"
          >
            <RotateCcw className="w-3.5 h-3.5" />
            <span>Đặt lại</span>
          </motion.button>
        )}
      </div>

      {/* Search Bar (Mandatory Tier 2 surface) */}
      <div className="glass-tier-2 glass-tier-2-interactive flex items-center px-3.5 h-11 mb-3">
        <Search className="w-4 h-4 text-[#94A3B8] shrink-0 mr-2.5" />
        <input
          type="search"
          aria-label="Tìm kiếm theo ghi chú hoặc danh mục"
          value={filterOptions.searchQuery}
          onChange={(e) =>
            onChangeFilter({ ...filterOptions, searchQuery: e.target.value })
          }
          placeholder="Tìm theo ghi chú hoặc danh mục..."
          className="w-full bg-transparent text-[14px] text-[#F8FAFC] placeholder-[#64748B] focus:outline-none"
        />
        {filterOptions.searchQuery.length > 0 && (
          <button
            type="button"
            onClick={() => onChangeFilter({ ...filterOptions, searchQuery: '' })}
            aria-label="Xóa từ khóa tìm kiếm"
            className="min-w-[36px] min-h-[36px] -mr-1.5 flex items-center justify-center text-[#94A3B8] hover:text-[#F8FAFC] cursor-pointer"
          >
            <X className="w-4 h-4" />
          </button>
        )}
      </div>

      {/* Type Filter Segmented Control: Tất cả | Thu nhập | Chi tiêu */}
      <div
        role="group"
        aria-label="Lọc theo loại giao dịch"
        className="glass-tier-2 p-1 grid grid-cols-3 gap-1 mb-2.5 relative"
      >
        {TYPE_OPTIONS.map(({ value: typeOption, label }) => {
          const isActive = filterOptions.typeFilter === typeOption;
          let activeStyle = 'bg-white/15 text-[#F8FAFC] border border-white/20';
          if (isActive && typeOption === 'Income') {
            activeStyle =
              'bg-[#34D399]/20 text-[#34D399] border border-[#34D399]/40';
          } else if (isActive && typeOption === 'Expense') {
            activeStyle =
              'bg-[#FB7185]/20 text-[#FB7185] border border-[#FB7185]/40';
          }

          return (
            <motion.button
              whileTap={{ scale: 0.96 }}
              key={typeOption}
              type="button"
              onClick={() =>
                onChangeFilter({ ...filterOptions, typeFilter: typeOption })
              }
              aria-pressed={isActive}
              className={`h-9 rounded-xl text-[13px] font-semibold transition-all cursor-pointer whitespace-nowrap ${
                isActive
                  ? activeStyle
                  : 'text-[#94A3B8] hover:text-[#F8FAFC] border border-transparent'
              }`}
            >
              {label}
            </motion.button>
          );
        })}
      </div>

      {/* Category Horizontal Scrollable Glass Chips */}
      <div
        role="group"
        aria-label="Lọc theo danh mục"
        className="flex items-center gap-1.5 overflow-x-auto no-scrollbar pb-2 mb-2.5"
      >
        {CATEGORY_CHIPS.map((cat) => {
          const isActive = filterOptions.categoryFilter === cat;
          const chipLabel =
            cat === 'All Categories'
              ? 'Tất cả danh mục'
              : getCategoryLabelVi(cat);
          return (
            <motion.button
              whileTap={{ scale: 0.95 }}
              key={cat}
              type="button"
              onClick={() =>
                onChangeFilter({ ...filterOptions, categoryFilter: cat })
              }
              aria-pressed={isActive}
              className={`h-8 px-3 rounded-xl text-[12px] font-semibold whitespace-nowrap shrink-0 transition-all cursor-pointer ${
                isActive
                  ? 'bg-[#38BDF8]/20 text-[#38BDF8] border border-[#38BDF8]/45'
                  : 'glass-tier-2 glass-tier-2-interactive text-[#94A3B8] hover:text-[#F8FAFC]'
              }`}
            >
              {chipLabel}
            </motion.button>
          );
        })}
      </div>

      {/* Result Summary Strip */}
      <div className="flex items-center justify-between px-1 py-2 mb-2 border-b border-white/10 text-[12px]">
        <span
          data-testid="filtered-count-label"
          className="text-[#94A3B8] font-medium"
        >
          Hiển thị{' '}
          <strong className="text-[#F8FAFC] font-tabular">
            {filteredTransactions.length}
          </strong>{' '}
          giao dịch
        </span>
        <span className="text-[#94A3B8]">
          Tổng ròng:{' '}
          <strong
            data-testid="filtered-net-total"
            className={`font-tabular font-bold ${
              filteredSummary.balance >= 0 ? 'text-[#34D399]' : 'text-[#FB7185]'
            }`}
          >
            {filteredSummary.balance >= 0
              ? formatCurrency(filteredSummary.balance, 'Income')
              : formatCurrency(filteredSummary.balance)}
          </strong>
        </span>
      </div>

      {/* Transaction List View */}
      {filteredTransactions.length === 0 ? (
        <motion.div
          initial={{ opacity: 0, scale: 0.96 }}
          animate={{ opacity: 1, scale: 1 }}
          className="glass-tier-2 p-7 text-center my-4 flex flex-col items-center"
        >
          <div className="w-12 h-12 rounded-2xl bg-white/5 border border-white/10 flex items-center justify-center text-[#94A3B8] mb-3">
            <Filter className="w-5 h-5" />
          </div>
          <h2 className="text-[15px] font-semibold text-[#F8FAFC] mb-1">
            Không tìm thấy giao dịch
          </h2>
          <p className="text-[13px] text-[#94A3B8] mb-4 max-w-[240px]">
            Không có khoản thu chi nào khớp với từ khóa hoặc bộ lọc hiện tại.
          </p>
          <motion.button
            whileTap={{ scale: 0.96 }}
            type="button"
            onClick={handleResetFilters}
            className="btn-primary-gradient px-4 h-10 rounded-xl text-[13px] font-bold text-[#080C14] flex items-center gap-1.5 cursor-pointer"
          >
            <RotateCcw className="w-4 h-4" />
            <span>Đặt lại bộ lọc</span>
          </motion.button>
        </motion.div>
      ) : (
        <div className="flex flex-col">
          {filteredTransactions.map((txn) => {
            const isIncome = txn.type === 'Income';
            const categoryVi = getCategoryLabelVi(txn.category);
            return (
              <motion.button
                layout
                whileTap={{ scale: 0.985 }}
                key={txn.id}
                type="button"
                onClick={() => onSelectTransaction(txn)}
                aria-label={`${categoryVi} ${
                  txn.note || ''
                } ${formatCurrency(txn.amount, txn.type)}`}
                className="glass-tier-2 glass-tier-2-interactive w-full text-left px-4 py-[14px] mb-[10px] flex items-center justify-between gap-3 cursor-pointer"
              >
                <div className="flex items-center gap-3 min-w-0">
                  <CategoryIconBadge
                    category={txn.category}
                    type={txn.type}
                    size="md"
                  />
                  <div className="min-w-0">
                    <div className="text-[15px] font-semibold text-[#F8FAFC] truncate">
                      {categoryVi}
                    </div>
                    <div className="text-[13px] text-[#94A3B8] truncate">
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
    </motion.div>
  );
};
