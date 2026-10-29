import React, { useState } from 'react';
import {
  ChevronLeft,
  Pencil,
  Trash2,
  AlertTriangle,
  Loader2,
  AlertCircle,
} from 'lucide-react';
import { motion, AnimatePresence } from 'motion/react';
import {
  TYPE_LABELS_VI,
  TransactionRecord,
  formatCurrency,
  formatLongDate,
  getCategoryLabelVi,
} from '../lib/financeEngine';
import { CategoryIconBadge, getCategoryIcon } from './CategoryIconBadge';

interface TransactionDetailScreenProps {
  transaction: TransactionRecord;
  onBack: () => void;
  onEdit: (transaction: TransactionRecord) => void;
  onDelete: (transactionId: string) => Promise<void>;
}

export const TransactionDetailScreen: React.FC<
  TransactionDetailScreenProps
> = ({ transaction, onBack, onEdit, onDelete }) => {
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
  const [isDeleting, setIsDeleting] = useState(false);
  const [deleteError, setDeleteError] = useState<string | null>(null);

  const isIncome = transaction.type === 'Income';
  const categoryVi = getCategoryLabelVi(transaction.category);
  const typeVi = TYPE_LABELS_VI[transaction.type];

  const handleConfirmDelete = async () => {
    setIsDeleting(true);
    setDeleteError(null);
    try {
      await onDelete(transaction.id);
    } catch (err) {
      setDeleteError(
        err instanceof Error ? err.message : 'Không thể xóa giao dịch này.'
      );
      setIsDeleting(false);
    }
  };

  return (
    <motion.div
      initial={{ opacity: 0, y: 8 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.15, ease: 'easeOut' }}
      className="flex flex-col justify-between px-4 pt-safe pb-safe min-h-full relative"
    >
      <div>
        {/* Top Bar */}
        <header className="flex items-center justify-between mb-4 pt-1">
          <motion.button
            whileTap={{ scale: 0.95 }}
            type="button"
            onClick={onBack}
            className="glass-tier-2 glass-tier-2-interactive px-3 h-10 flex items-center gap-1 text-[13px] font-semibold text-[#F8FAFC] cursor-pointer"
          >
            <ChevronLeft className="w-4 h-4 text-[#38BDF8]" />
            <span>Quay lại</span>
          </motion.button>
          <h1 className="text-[17px] font-bold tracking-[-0.02em] text-[#F8FAFC]">
            Chi tiết giao dịch
          </h1>
          <div className="w-[82px]" aria-hidden="true" />
        </header>

        {/* Detail Glass Card (Tier 1 Frosted Glass — Zero nested blurred cards inside) */}
        <section
          aria-label="Thông tin chi tiết giao dịch"
          className="glass-tier-1 p-5 flex flex-col"
        >
          {/* Top Hero Section inside Card */}
          <div className="flex flex-col items-center text-center pb-5 border-b border-white/[0.08]">
            <CategoryIconBadge
              category={transaction.category}
              type={transaction.type}
              size="lg"
            />
            <div className="mt-3 text-[11px] font-bold uppercase tracking-[0.08em] text-[#94A3B8]">
              {typeVi.toUpperCase()} · {categoryVi}
            </div>
            <div
              data-testid="detail-amount-display"
              className={`text-[28px] font-bold font-tabular tracking-[-0.03em] mt-1 ${
                isIncome ? 'text-[#34D399]' : 'text-[#FB7185]'
              }`}
            >
              {formatCurrency(transaction.amount, transaction.type)}
            </div>
          </div>

          {/* Structured Metadata Rows separated by rgba(255,255,255,0.07) hairlines */}
          <dl className="divide-y divide-white/[0.07] text-[13.5px]">
            <div className="py-3 flex items-center justify-between gap-4">
              <dt className="text-[#94A3B8] font-medium">Mã giao dịch</dt>
              <dd className="font-tabular font-semibold text-[#F8FAFC]">
                #{transaction.id}
              </dd>
            </div>

            <div className="py-3 flex items-center justify-between gap-4">
              <dt className="text-[#94A3B8] font-medium">Loại giao dịch</dt>
              <dd
                className={`font-semibold ${
                  isIncome ? 'text-[#34D399]' : 'text-[#FB7185]'
                }`}
              >
                {typeVi}
              </dd>
            </div>

            <div className="py-3 flex items-center justify-between gap-4">
              <dt className="text-[#94A3B8] font-medium">Danh mục</dt>
              <dd className="font-semibold text-[#F8FAFC] flex items-center gap-1.5">
                <span className="text-[#38BDF8]">
                  {getCategoryIcon(transaction.category, 'w-4 h-4')}
                </span>
                <span>{categoryVi}</span>
              </dd>
            </div>

            <div className="py-3 flex items-center justify-between gap-4">
              <dt className="text-[#94A3B8] font-medium">Ngày giao dịch</dt>
              <dd className="font-tabular font-medium text-[#F8FAFC]">
                {formatLongDate(transaction.date)}
              </dd>
            </div>

            <div className="py-3 flex items-center justify-between gap-4">
              <dt className="text-[#94A3B8] font-medium">Tài khoản</dt>
              <dd
                data-testid="detail-owner-email"
                className="font-tabular text-[12.5px] text-[#38BDF8] truncate max-w-[190px]"
              >
                {transaction.ownerEmail}
              </dd>
            </div>

            <div className="pt-3 pb-1 flex flex-col gap-1.5">
              <dt className="text-[#94A3B8] font-medium">Ghi chú</dt>
              <dd className="text-[#F8FAFC] leading-relaxed">
                {transaction.note ? (
                  transaction.note
                ) : (
                  <span className="italic text-[#64748B]">
                    Không có ghi chú bổ sung
                  </span>
                )}
              </dd>
            </div>
          </dl>
        </section>

        {deleteError && (
          <div
            role="alert"
            className="mt-3 rounded-xl bg-[#F43F5E]/15 border border-[#F43F5E]/40 px-3.5 py-2.5 flex items-start gap-2.5 text-[#FB7185] text-[12.5px]"
          >
            <AlertCircle className="w-4 h-4 text-[#F43F5E] shrink-0 mt-0.5" />
            <span>{deleteError}</span>
          </div>
        )}
      </div>

      {/* Action Buttons Bar at Bottom */}
      <div className="grid grid-cols-2 gap-3 mt-6">
        <motion.button
          whileTap={{ scale: 0.96 }}
          type="button"
          onClick={() => onEdit(transaction)}
          className="glass-tier-2 glass-tier-2-interactive h-12 px-4 flex items-center justify-center gap-2 text-[14px] font-bold text-[#F8FAFC] cursor-pointer"
        >
          <Pencil className="w-4 h-4 text-[#38BDF8]" />
          <span>Chỉnh sửa</span>
        </motion.button>

        <motion.button
          whileTap={{ scale: 0.96 }}
          type="button"
          onClick={() => {
            setDeleteError(null);
            setShowDeleteConfirm(true);
          }}
          className="h-12 px-4 rounded-2xl bg-[#FB7185]/[0.14] hover:bg-[#FB7185]/[0.24] border border-[#FB7185]/35 flex items-center justify-center gap-2 text-[14px] font-bold text-[#FB7185] transition-all cursor-pointer"
        >
          <Trash2 className="w-4 h-4" />
          <span>Xóa</span>
        </motion.button>
      </div>

      {/* Mandatory Tier 1 Glass Delete Confirmation Modal */}
      <AnimatePresence>
        {showDeleteConfirm && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.18 }}
            role="dialog"
            aria-modal="true"
            aria-labelledby="delete-dialog-title"
            className="absolute inset-0 z-50 bg-[#080C14]/80 backdrop-blur-[4px] flex items-center justify-center p-5"
          >
            <motion.div
              initial={{ scale: 0.9, opacity: 0, y: 10 }}
              animate={{ scale: 1, opacity: 1, y: 0 }}
              exit={{ scale: 0.92, opacity: 0, y: 8 }}
              transition={{ type: 'spring', stiffness: 400, damping: 28 }}
              className="glass-tier-1 p-5 w-full max-w-[335px] flex flex-col items-center text-center"
            >
              <div className="w-12 h-12 rounded-2xl bg-[#FB7185]/20 border border-[#FB7185]/40 flex items-center justify-center text-[#FB7185] mb-3">
                <AlertTriangle className="w-6 h-6" />
              </div>

              <h2
                id="delete-dialog-title"
                className="text-[18px] font-bold text-[#F8FAFC] mb-1.5"
              >
                Xóa giao dịch này?
              </h2>

              <p className="text-[13px] text-[#94A3B8] leading-relaxed mb-5">
                Bạn có chắc chắn muốn xóa vĩnh viễn giao dịch này? Số dư tài
                khoản sẽ được tính toán lại ngay lập tức.
              </p>

              {deleteError && (
                <div className="w-full mb-3 rounded-xl bg-[#F43F5E]/15 border border-[#F43F5E]/40 p-2.5 text-[12px] text-[#FB7185]">
                  {deleteError}
                </div>
              )}

              <div className="grid grid-cols-2 gap-2.5 w-full">
                <motion.button
                  whileTap={{ scale: 0.96 }}
                  type="button"
                  disabled={isDeleting}
                  onClick={() => setShowDeleteConfirm(false)}
                  className="glass-tier-2 glass-tier-2-interactive h-11 text-[13.5px] font-semibold text-[#F8FAFC] cursor-pointer"
                >
                  Hủy
                </motion.button>

                <motion.button
                  whileTap={{ scale: 0.96 }}
                  type="button"
                  disabled={isDeleting}
                  onClick={handleConfirmDelete}
                  className="h-11 rounded-2xl bg-[#F43F5E] hover:bg-[#E11D48] text-[#F8FAFC] font-bold text-[13.5px] flex items-center justify-center gap-1.5 transition-colors cursor-pointer disabled:opacity-60"
                >
                  {isDeleting ? (
                    <>
                      <Loader2 className="w-4 h-4 animate-spin" />
                      <span>Đang xóa...</span>
                    </>
                  ) : (
                    <span>Xác nhận xóa</span>
                  )}
                </motion.button>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </motion.div>
  );
};
