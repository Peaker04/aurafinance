import React, { useState, useEffect } from 'react';
import {
  AlertCircle,
  Calendar,
  Check,
  Loader2,
  FileText,
} from 'lucide-react';
import { motion, AnimatePresence } from 'motion/react';
import {
  ALL_CATEGORIES,
  CategoryName,
  EXPENSE_CATEGORIES,
  INCOME_CATEGORIES,
  TransactionRecord,
  TransactionType,
  getCategoryLabelVi,
  validateTransactionInput,
} from '../lib/financeEngine';
import { getCategoryIcon } from './CategoryIconBadge';

interface AddEditTransactionScreenProps {
  initialTransaction?: TransactionRecord | null;
  onCancel: () => void;
  onSave: (payload: {
    type: TransactionType;
    amount: number;
    category: CategoryName;
    date: string;
    note: string;
  }) => Promise<void>;
}

const QUICK_VND_PRESETS = [
  { label: '50k', value: 50000 },
  { label: '100k', value: 100000 },
  { label: '200k', value: 200000 },
  { label: '500k', value: 500000 },
  { label: '2Tr', value: 2000000 },
  { label: '10Tr', value: 10000000 },
];

export const AddEditTransactionScreen: React.FC<
  AddEditTransactionScreenProps
> = ({ initialTransaction, onCancel, onSave }) => {
  const isEditMode = Boolean(initialTransaction);

  const [type, setType] = useState<TransactionType>(
    initialTransaction?.type || 'Expense'
  );
  const [amountRaw, setAmountRaw] = useState<string>(
    initialTransaction ? String(initialTransaction.amount) : ''
  );
  const [category, setCategory] = useState<CategoryName>(
    initialTransaction?.category || 'Food & Drink'
  );
  const [date, setDate] = useState<string>(
    initialTransaction?.date || '2026-10-28'
  );
  const [note, setNote] = useState<string>(initialTransaction?.note || '');
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [isSaving, setIsSaving] = useState(false);

  useEffect(() => {
    if (initialTransaction) {
      setType(initialTransaction.type);
      setAmountRaw(String(initialTransaction.amount));
      setCategory(initialTransaction.category);
      setDate(initialTransaction.date);
      setNote(initialTransaction.note);
    }
  }, [initialTransaction]);

  const handleTypeSwitch = (nextType: TransactionType) => {
    setType(nextType);
    if (nextType === 'Income' && !INCOME_CATEGORIES.includes(category)) {
      setCategory('Salary');
    } else if (
      nextType === 'Expense' &&
      !EXPENSE_CATEGORIES.includes(category)
    ) {
      setCategory('Food & Drink');
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setErrorMessage(null);

    const validation = validateTransactionInput({
      amountRaw,
      category,
      date,
    });

    if (!validation.valid) {
      setErrorMessage(validation.error || 'Số tiền phải lớn hơn 0 ₫.');
      return;
    }

    setIsSaving(true);
    try {
      await onSave({
        type,
        amount: Math.round(Number(amountRaw)),
        category,
        date,
        note,
      });
    } catch (err) {
      setErrorMessage(
        err instanceof Error ? err.message : 'Không thể lưu giao dịch.'
      );
    } finally {
      setIsSaving(false);
    }
  };

  return (
    <motion.div
      initial={{ opacity: 0, y: 8 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.15, ease: 'easeOut' }}
      className="flex flex-col px-4 pt-safe pb-safe min-h-full"
    >
      {/* Header */}
      <header className="flex items-center justify-between mb-2.5 pt-1">
        <div>
          <h1 className="text-[19px] font-bold tracking-[-0.02em] text-[#F8FAFC]">
            {isEditMode ? 'Chỉnh sửa giao dịch' : 'Thêm giao dịch'}
          </h1>
          {isEditMode && initialTransaction && (
            <p className="text-[11px] font-tabular text-[#94A3B8]">
              Mã #{initialTransaction.id}
            </p>
          )}
        </div>
        <motion.button
          whileTap={{ scale: 0.95 }}
          type="button"
          onClick={onCancel}
          className="glass-tier-2 glass-tier-2-interactive px-3.5 h-9 text-[13px] font-semibold text-[#94A3B8] hover:text-[#F8FAFC] cursor-pointer"
        >
          Hủy
        </motion.button>
      </header>

      <form onSubmit={handleSubmit} noValidate className="flex flex-col gap-2.5">
        {/* High-Contrast 2-Segment Glass Toggle: Thu nhập | Chi tiêu */}
        <div
          role="group"
          aria-label="Loại giao dịch"
          className="glass-tier-2 p-1 grid grid-cols-2 gap-1.5"
        >
          <motion.button
            whileTap={{ scale: 0.97 }}
            type="button"
            onClick={() => handleTypeSwitch('Income')}
            aria-pressed={type === 'Income'}
            className={`h-9 rounded-xl text-[13.5px] font-bold transition-all cursor-pointer flex items-center justify-center gap-2 ${
              type === 'Income'
                ? 'bg-[#34D399]/20 text-[#34D399] border border-[#34D399]/50 shadow-[0_0_20px_rgba(52,211,153,0.22)]'
                : 'text-[#94A3B8] hover:text-[#F8FAFC] border border-transparent'
            }`}
          >
            <span>Thu nhập</span>
          </motion.button>

          <motion.button
            whileTap={{ scale: 0.97 }}
            type="button"
            onClick={() => handleTypeSwitch('Expense')}
            aria-pressed={type === 'Expense'}
            className={`h-9 rounded-xl text-[13.5px] font-bold transition-all cursor-pointer flex items-center justify-center gap-2 ${
              type === 'Expense'
                ? 'bg-[#FB7185]/20 text-[#FB7185] border border-[#FB7185]/50 shadow-[0_0_20px_rgba(251,113,133,0.22)]'
                : 'text-[#94A3B8] hover:text-[#F8FAFC] border border-transparent'
            }`}
          >
            <span>Chi tiêu</span>
          </motion.button>
        </div>

        {/* Amount Input Field (Mandatory Validation > 0 ₫) */}
        <div>
          <label
            htmlFor="txn-amount-input"
            className="block text-[11px] font-semibold uppercase tracking-[0.04em] text-[#94A3B8] mb-1"
          >
            Số tiền (VNĐ) *
          </label>
          <div
            className={`glass-tier-2 glass-tier-2-interactive px-3.5 py-1.5 flex items-center justify-between ${
              errorMessage?.includes('Số tiền') ? 'border-[#F43F5E]/60' : ''
            }`}
          >
            <input
              id="txn-amount-input"
              type="number"
              step="1000"
              min="0"
              inputMode="numeric"
              value={amountRaw}
              onChange={(e) => {
                setAmountRaw(e.target.value);
                if (errorMessage) setErrorMessage(null);
              }}
              placeholder="0"
              className="w-full bg-transparent text-[24px] font-bold font-tabular text-[#F8FAFC] placeholder-[#64748B]/60 focus:outline-none"
            />
            <span
              className={`text-[20px] font-bold font-tabular ml-2 shrink-0 ${
                type === 'Income' ? 'text-[#34D399]' : 'text-[#FB7185]'
              }`}
            >
              ₫
            </span>
          </div>

          {/* Quick VNĐ Denomination Chips */}
          <div className="flex items-center gap-1.5 mt-1.5 overflow-x-auto no-scrollbar">
            {QUICK_VND_PRESETS.map((preset) => (
              <button
                key={preset.value}
                type="button"
                onClick={() => {
                  setAmountRaw(String(preset.value));
                  if (errorMessage) setErrorMessage(null);
                }}
                className="h-6 px-2 rounded-lg bg-white/[0.06] hover:bg-white/[0.14] border border-white/10 text-[11px] font-tabular font-semibold text-[#94A3B8] hover:text-[#F8FAFC] transition-colors cursor-pointer shrink-0"
              >
                +{preset.label}
              </button>
            ))}
          </div>
        </div>

        {/* Category Selector Grid */}
        <div>
          <div className="flex items-center justify-between mb-1">
            <span className="text-[11px] font-semibold uppercase tracking-[0.04em] text-[#94A3B8]">
              Danh mục *
            </span>
            <span className="text-[10.5px] text-[#64748B]">
              {type === 'Income' ? 'Gợi ý thu nhập' : 'Gợi ý chi tiêu'}
            </span>
          </div>
          <div
            role="radiogroup"
            aria-label="Chọn danh mục"
            className="grid grid-cols-3 gap-1.5"
          >
            {ALL_CATEGORIES.map((cat) => {
              const isSelected = category === cat;
              const isRecommendedForType =
                type === 'Income'
                  ? INCOME_CATEGORIES.includes(cat)
                  : EXPENSE_CATEGORIES.includes(cat);

              let selectedClasses = '';
              if (isSelected) {
                selectedClasses =
                  type === 'Income'
                    ? 'bg-[#34D399]/20 border-[#34D399]/60 text-[#34D399]'
                    : 'bg-[#FB7185]/20 border-[#FB7185]/60 text-[#FB7185]';
              } else if (isRecommendedForType) {
                selectedClasses = 'text-[#F8FAFC]';
              } else {
                selectedClasses = 'text-[#94A3B8]';
              }

              return (
                <motion.button
                  whileTap={{ scale: 0.95 }}
                  key={cat}
                  type="button"
                  role="radio"
                  aria-checked={isSelected}
                  onClick={() => setCategory(cat)}
                  className={`glass-tier-2 glass-tier-2-interactive p-1.5 flex flex-col items-center justify-center gap-1 text-center cursor-pointer min-h-[50px] ${selectedClasses}`}
                >
                  {getCategoryIcon(cat, 'w-4 h-4')}
                  <span className="text-[11px] font-semibold leading-tight truncate w-full">
                    {getCategoryLabelVi(cat)}
                  </span>
                </motion.button>
              );
            })}
          </div>
        </div>

        {/* Transaction Date Picker */}
        <div>
          <label
            htmlFor="txn-date-input"
            className="block text-[11px] font-semibold uppercase tracking-[0.04em] text-[#94A3B8] mb-1"
          >
            Ngày giao dịch *
          </label>
          <div className="glass-tier-2 glass-tier-2-interactive px-3.5 h-9.5 flex items-center">
            <Calendar className="w-4 h-4 text-[#94A3B8] shrink-0 mr-2.5" />
            <input
              id="txn-date-input"
              type="date"
              value={date}
              onChange={(e) => {
                setDate(e.target.value);
                if (errorMessage) setErrorMessage(null);
              }}
              className="w-full bg-transparent text-[13px] font-tabular text-[#F8FAFC] focus:outline-none"
            />
          </div>
        </div>

        {/* Note Input Field (Optional) */}
        <div>
          <label
            htmlFor="txn-note-input"
            className="block text-[11px] font-semibold uppercase tracking-[0.04em] text-[#94A3B8] mb-1"
          >
            Ghi chú (Tùy chọn)
          </label>
          <div className="glass-tier-2 glass-tier-2-interactive px-3 py-1.5 flex items-start">
            <FileText className="w-4 h-4 text-[#94A3B8] shrink-0 mr-2.5 mt-0.5" />
            <textarea
              id="txn-note-input"
              rows={2}
              value={note}
              onChange={(e) => setNote(e.target.value)}
              placeholder="Nhập ghi chú (ví dụ: Ăn trưa tại căng tin trường)..."
              className="w-full bg-transparent text-[12.5px] text-[#F8FAFC] placeholder-[#64748B] focus:outline-none resize-none"
            />
          </div>
        </div>

        {/* Validation & API Error Alert */}
        <AnimatePresence mode="wait">
          {errorMessage && (
            <motion.div
              key={errorMessage}
              initial={{ opacity: 0, y: -4 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0 }}
              role="alert"
              data-testid="transaction-validation-error"
              className="rounded-xl bg-[#F43F5E]/15 border border-[#F43F5E]/40 px-3.5 py-2 flex items-start gap-2 text-[#FB7185] text-[12px]"
            >
              <AlertCircle className="w-4 h-4 text-[#F43F5E] shrink-0 mt-0.5" />
              <span>{errorMessage}</span>
            </motion.div>
          )}
        </AnimatePresence>

        {/* Save / Update CTA Button */}
        <motion.button
          whileTap={{ scale: 0.97 }}
          type="submit"
          disabled={isSaving}
          className="btn-primary-gradient w-full h-11 rounded-2xl text-[#080C14] font-bold text-[14.5px] flex items-center justify-center gap-2 cursor-pointer disabled:opacity-60 mt-0.5"
        >
          {isSaving ? (
            <>
              <Loader2 className="w-4 h-4 animate-spin" />
              <span>Đang lưu...</span>
            </>
          ) : (
            <>
              <Check className="w-4 h-4" />
              <span>
                {isEditMode ? 'Cập nhật giao dịch' : 'Lưu giao dịch'}
              </span>
            </>
          )}
        </motion.button>
      </form>
    </motion.div>
  );
};
