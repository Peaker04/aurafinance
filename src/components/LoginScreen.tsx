import React, { useState } from 'react';
import {
  Mail,
  Lock,
  Eye,
  EyeOff,
  AlertCircle,
  Loader2,
  Sparkles,
  UserCheck,
  ArrowRight,
} from 'lucide-react';
import { motion, AnimatePresence } from 'motion/react';
import { validateLoginInput } from '../lib/financeEngine';

interface LoginScreenProps {
  onLogin: (email: string, password: string) => Promise<void>;
  apiError: string | null;
  onClearError: () => void;
}

export const LoginScreen: React.FC<LoginScreenProps> = ({
  onLogin,
  apiError,
  onClearError,
}) => {
  const [email, setEmail] = useState('user1@fpt.edu.vn');
  const [password, setPassword] = useState('123456');
  const [showPassword, setShowPassword] = useState(false);
  const [localError, setLocalError] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  const handleSelectDemoAccount = (targetEmail: string, targetPass: string) => {
    setEmail(targetEmail);
    setPassword(targetPass);
    setLocalError(null);
    onClearError();
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLocalError(null);
    onClearError();

    const validation = validateLoginInput(email, password);
    if (!validation.valid) {
      setLocalError(
        validation.error || 'Vui lòng kiểm tra lại thông tin đăng nhập.'
      );
      return;
    }

    setIsSubmitting(true);
    try {
      await onLogin(email, password);
    } catch (err) {
      setLocalError(
        err instanceof Error
          ? err.message
          : 'Email hoặc mật khẩu không chính xác. Vui lòng thử lại.'
      );
    } finally {
      setIsSubmitting(false);
    }
  };

  const activeError = localError || apiError;

  return (
    <motion.div
      initial={{ opacity: 0, y: 8 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.16, ease: 'easeOut' }}
      className="flex flex-col justify-between min-h-full px-5 pt-safe pb-safe select-none"
    >
      {/* Top Brand Lockup */}
      <div className="flex flex-col items-center text-center mt-4 mb-5">
        <motion.div
          initial={{ scale: 0.85, opacity: 0 }}
          animate={{ scale: 1, opacity: 1 }}
          transition={{ type: 'spring', stiffness: 360, damping: 24, delay: 0.05 }}
          className="w-16 h-16 rounded-[20px] flex items-center justify-center mb-3.5 relative border border-white/20 shadow-[0_12px_28px_-6px_rgba(16,185,129,0.35)]"
          style={{
            background:
              'linear-gradient(135deg, rgba(16, 185, 129, 0.24) 0%, rgba(99, 102, 241, 0.28) 100%)',
          }}
        >
          <Sparkles className="w-8 h-8 text-[#34D399]" />
        </motion.div>
        <h1 className="text-[24px] font-bold tracking-[-0.02em] text-[#F8FAFC]">
          AuraFinance
        </h1>
        <p className="text-[13px] font-medium text-[#94A3B8] mt-1">
          Quản lý Tài chính Cá nhân Thông minh
        </p>
      </div>

      {/* Tier 1 Frosted Glass Login Card */}
      <form
        onSubmit={handleSubmit}
        noValidate
        className="glass-tier-1 p-5 flex flex-col gap-4"
        aria-label="Biểu mẫu đăng nhập"
      >
        <div>
          <label
            htmlFor="login-email-input"
            className="block text-[12px] font-semibold text-[#94A3B8] mb-1.5"
          >
            Địa chỉ Email
          </label>
          <div className="glass-tier-2 glass-tier-2-interactive flex items-center px-3.5 h-12">
            <Mail className="w-4 h-4 text-[#94A3B8] shrink-0 mr-3" />
            <input
              id="login-email-input"
              type="email"
              value={email}
              onChange={(e) => {
                setEmail(e.target.value);
                if (localError) setLocalError(null);
              }}
              placeholder="Nhập địa chỉ email của bạn..."
              autoComplete="email"
              className="w-full bg-transparent text-[14px] text-[#F8FAFC] placeholder-[#64748B] focus:outline-none"
            />
          </div>
        </div>

        <div>
          <label
            htmlFor="login-password-input"
            className="block text-[12px] font-semibold text-[#94A3B8] mb-1.5"
          >
            Mật khẩu
          </label>
          <div className="glass-tier-2 glass-tier-2-interactive flex items-center px-3.5 h-12">
            <Lock className="w-4 h-4 text-[#94A3B8] shrink-0 mr-3" />
            <input
              id="login-password-input"
              type={showPassword ? 'text' : 'password'}
              value={password}
              onChange={(e) => {
                setPassword(e.target.value);
                if (localError) setLocalError(null);
              }}
              placeholder="Nhập mật khẩu..."
              autoComplete="current-password"
              className="w-full bg-transparent text-[14px] text-[#F8FAFC] placeholder-[#64748B] focus:outline-none font-tabular"
            />
            <button
              type="button"
              onClick={() => setShowPassword((prev) => !prev)}
              aria-label={showPassword ? 'Ẩn mật khẩu' : 'Hiện mật khẩu'}
              className="min-w-[44px] min-h-[44px] -mr-2 flex items-center justify-center text-[#94A3B8] hover:text-[#F8FAFC] transition-colors cursor-pointer"
            >
              {showPassword ? (
                <EyeOff className="w-4 h-4" />
              ) : (
                <Eye className="w-4 h-4" />
              )}
            </button>
          </div>
        </div>

        {/* Validation & Error Banner */}
        <AnimatePresence mode="wait">
          {activeError && (
            <motion.div
              key={activeError}
              initial={{ opacity: 0, height: 0, y: -4 }}
              animate={{ opacity: 1, height: 'auto', y: 0 }}
              exit={{ opacity: 0, height: 0 }}
              transition={{ duration: 0.2 }}
              role="alert"
              className="rounded-xl bg-[#F43F5E]/15 border border-[#F43F5E]/40 px-3.5 py-2.5 flex items-start gap-2.5 text-[#FB7185] text-[12.5px] leading-snug overflow-hidden"
            >
              <AlertCircle className="w-4 h-4 text-[#F43F5E] shrink-0 mt-0.5" />
              <span>{activeError}</span>
            </motion.div>
          )}
        </AnimatePresence>

        {/* Primary Gradient Button */}
        <motion.button
          whileTap={{ scale: 0.97 }}
          type="submit"
          disabled={isSubmitting}
          className="btn-primary-gradient w-full h-12 rounded-2xl text-[#080C14] font-bold text-[15px] flex items-center justify-center gap-2 disabled:opacity-60 cursor-pointer mt-1"
        >
          {isSubmitting ? (
            <>
              <Loader2 className="w-4 h-4 animate-spin" />
              <span>Đang đăng nhập...</span>
            </>
          ) : (
            <>
              <span>Đăng nhập</span>
              <ArrowRight className="w-4 h-4" />
            </>
          )}
        </motion.button>
      </form>

      {/* Quick Experience Accounts Card at Bottom */}
      <div className="mt-5">
        <div className="flex items-center justify-between mb-2 px-1">
          <span className="text-[11px] font-semibold uppercase tracking-[0.04em] text-[#94A3B8]">
            Tài khoản trải nghiệm nhanh
          </span>
          <span className="text-[11px] text-[#64748B]">Chạm để chọn</span>
        </div>

        <div className="flex flex-col gap-2">
          <motion.button
            whileTap={{ scale: 0.985 }}
            type="button"
            onClick={() => handleSelectDemoAccount('user1@fpt.edu.vn', '123456')}
            className={`glass-tier-2 glass-tier-2-interactive w-full p-3 text-left flex items-center justify-between cursor-pointer ${
              email === 'user1@fpt.edu.vn'
                ? 'border-[#38BDF8]/50 bg-[#1E2945]/90'
                : ''
            }`}
          >
            <div className="flex items-center gap-2.5 min-w-0">
              <div className="w-9 h-9 rounded-xl bg-[#34D399]/15 border border-[#34D399]/30 flex items-center justify-center text-[#34D399] shrink-0">
                <UserCheck className="w-4 h-4" />
              </div>
              <div className="min-w-0">
                <div className="text-[13px] font-semibold text-[#F8FAFC] truncate">
                  Tạ Tuấn Kỳ · 5 giao dịch
                </div>
                <div className="text-[11.5px] font-tabular text-[#94A3B8] truncate">
                  user1@fpt.edu.vn
                </div>
              </div>
            </div>
            <span className="text-[11px] font-semibold text-[#38BDF8] shrink-0 ml-2">
              {email === 'user1@fpt.edu.vn' ? 'Đang chọn' : 'Chọn'}
            </span>
          </motion.button>

          <motion.button
            whileTap={{ scale: 0.985 }}
            type="button"
            onClick={() => handleSelectDemoAccount('user2@fpt.edu.vn', '123456')}
            className={`glass-tier-2 glass-tier-2-interactive w-full p-3 text-left flex items-center justify-between cursor-pointer ${
              email === 'user2@fpt.edu.vn'
                ? 'border-[#38BDF8]/50 bg-[#1E2945]/90'
                : ''
            }`}
          >
            <div className="flex items-center gap-2.5 min-w-0">
              <div className="w-9 h-9 rounded-xl bg-[#818CF8]/15 border border-[#818CF8]/30 flex items-center justify-center text-[#818CF8] shrink-0">
                <UserCheck className="w-4 h-4" />
              </div>
              <div className="min-w-0">
                <div className="text-[13px] font-semibold text-[#F8FAFC] truncate">
                  Nguyễn Văn A · 3 giao dịch
                </div>
                <div className="text-[11.5px] font-tabular text-[#94A3B8] truncate">
                  user2@fpt.edu.vn
                </div>
              </div>
            </div>
            <span className="text-[11px] font-semibold text-[#38BDF8] shrink-0 ml-2">
              {email === 'user2@fpt.edu.vn' ? 'Đang chọn' : 'Chọn'}
            </span>
          </motion.button>
        </div>
      </div>
    </motion.div>
  );
};
