import React from 'react';
import {
  Briefcase,
  Laptop,
  TrendingUp,
  Utensils,
  Car,
  ShoppingBag,
  GraduationCap,
  Receipt,
  Film,
  Wallet,
} from 'lucide-react';
import { CategoryName, TransactionType } from '../lib/financeEngine';

interface CategoryIconBadgeProps {
  category: CategoryName;
  type?: TransactionType;
  size?: 'sm' | 'md' | 'lg';
}

export function getCategoryIcon(category: CategoryName, className = 'w-5 h-5') {
  switch (category) {
    case 'Salary':
      return <Briefcase className={className} />;
    case 'Freelance':
      return <Laptop className={className} />;
    case 'Investment':
      return <TrendingUp className={className} />;
    case 'Food & Drink':
      return <Utensils className={className} />;
    case 'Transport':
      return <Car className={className} />;
    case 'Shopping':
      return <ShoppingBag className={className} />;
    case 'Study':
      return <GraduationCap className={className} />;
    case 'Bills':
      return <Receipt className={className} />;
    case 'Entertainment':
      return <Film className={className} />;
    default:
      return <Wallet className={className} />;
  }
}

export const CategoryIconBadge: React.FC<CategoryIconBadgeProps> = ({
  category,
  type,
  size = 'md',
}) => {
  const isIncome =
    type === 'Income' ||
    (!type && ['Salary', 'Freelance', 'Investment'].includes(category));

  const dimensions =
    size === 'lg'
      ? 'w-14 h-14 rounded-2xl'
      : size === 'sm'
      ? 'w-8 h-8 rounded-lg'
      : 'w-11 h-11 rounded-[14px]';

  const iconSize =
    size === 'lg' ? 'w-7 h-7' : size === 'sm' ? 'w-4 h-4' : 'w-5 h-5';

  const colorClasses = isIncome
    ? 'bg-[#34D399]/[0.14] border border-[#34D399]/30 text-[#34D399]'
    : 'bg-[#FB7185]/[0.14] border border-[#FB7185]/30 text-[#FB7185]';

  return (
    <div
      className={`${dimensions} ${colorClasses} flex items-center justify-center shrink-0`}
      aria-hidden="true"
    >
      {getCategoryIcon(category, iconSize)}
    </div>
  );
};
