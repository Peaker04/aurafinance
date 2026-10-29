import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Khóa định hướng dọc chuẩn mobile UX và thiết lập thanh trạng thái iOS trong suốt
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFF080C14),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final financeProvider = FinanceProvider();
  await financeProvider.initializeAndRestoreSession();

  runApp(
    ChangeNotifierProvider.value(
      value: financeProvider,
      child: const AuraFinanceApp(),
    ),
  );
}

// ============================================================================
// DOMAIN MODELS & VIETNAMESE LOCALIZATION (VNĐ)
// ============================================================================
enum TransactionType { income, expense }

class UserAccount {
  final String id;
  final String email;
  final String name;
  final String role;

  const UserAccount({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
  });

  factory UserAccount.fromJson(Map<String, dynamic> json) => UserAccount(
        id: json['id'] as String,
        email: json['email'] as String,
        name: json['name'] as String,
        role: (json['role'] ?? 'Tài khoản Cá nhân') as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'role': role,
      };
}

class TransactionModel {
  final String id;
  final String userId;
  final String ownerEmail;
  final TransactionType type;
  final double amount;
  final String category;
  final String date;
  final String note;

  const TransactionModel({
    required this.id,
    required this.userId,
    required this.ownerEmail,
    required this.type,
    required this.amount,
    required this.category,
    required this.date,
    required this.note,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) =>
      TransactionModel(
        id: json['id'] as String,
        userId: json['userId'] as String,
        ownerEmail: json['ownerEmail'] as String,
        type: json['type'] == 'Income'
            ? TransactionType.income
            : TransactionType.expense,
        amount: (json['amount'] as num).toDouble(),
        category: json['category'] as String,
        date: json['date'] as String,
        note: (json['note'] ?? '') as String,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'ownerEmail': ownerEmail,
        'type': type == TransactionType.income ? 'Income' : 'Expense',
        'amount': amount,
        'category': category,
        'date': date,
        'note': note,
      };
}

const List<String> kAllCategories = [
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

const List<String> kIncomeCategories = [
  'Salary',
  'Freelance',
  'Investment',
];

const List<String> kExpenseCategories = [
  'Food & Drink',
  'Transport',
  'Shopping',
  'Study',
  'Bills',
  'Entertainment',
];

const Map<String, String> kCategoryLabelsVi = {
  'Salary': 'Lương',
  'Freelance': 'Freelance',
  'Investment': 'Đầu tư',
  'Food & Drink': 'Ăn uống',
  'Transport': 'Di chuyển',
  'Shopping': 'Mua sắm',
  'Study': 'Học tập',
  'Bills': 'Hóa đơn',
  'Entertainment': 'Giải trí',
};

const List<UserAccount> kSeedUsers = [
  UserAccount(
    id: 'usr_01',
    email: 'user1@fpt.edu.vn',
    name: 'Tạ Tuấn Kỳ',
    role: 'Tài khoản Cá nhân',
  ),
  UserAccount(
    id: 'usr_02',
    email: 'user2@fpt.edu.vn',
    name: 'Nguyễn Văn A',
    role: 'Tài khoản Cá nhân',
  ),
];

const List<TransactionModel> kInitialSeedTransactions = [
  // User 1: Tạ Tuấn Kỳ (5 giao dịch — Đơn vị: VNĐ)
  TransactionModel(
    id: 'TXN-101',
    userId: 'usr_01',
    ownerEmail: 'user1@fpt.edu.vn',
    type: TransactionType.income,
    amount: 12000000,
    category: 'Salary',
    date: '2026-10-01',
    note: 'Trợ cấp thực tập kỹ sư phần mềm tháng 10',
  ),
  TransactionModel(
    id: 'TXN-102',
    userId: 'usr_01',
    ownerEmail: 'user1@fpt.edu.vn',
    type: TransactionType.income,
    amount: 4500000,
    category: 'Freelance',
    date: '2026-10-10',
    note: 'Dự án thiết kế giao diện ứng dụng di động',
  ),
  TransactionModel(
    id: 'TXN-103',
    userId: 'usr_01',
    ownerEmail: 'user1@fpt.edu.vn',
    type: TransactionType.expense,
    amount: 85000,
    category: 'Food & Drink',
    date: '2026-10-18',
    note: 'Cà phê và ăn trưa cùng nhóm tại trường',
  ),
  TransactionModel(
    id: 'TXN-104',
    userId: 'usr_01',
    ownerEmail: 'user1@fpt.edu.vn',
    type: TransactionType.expense,
    amount: 450000,
    category: 'Study',
    date: '2026-10-22',
    note: 'Gia hạn máy chủ đám mây & tên miền học tập',
  ),
  TransactionModel(
    id: 'TXN-105',
    userId: 'usr_01',
    ownerEmail: 'user1@fpt.edu.vn',
    type: TransactionType.expense,
    amount: 150000,
    category: 'Transport',
    date: '2026-10-27',
    note: 'Vé xe buýt và di chuyển tuần này',
  ),
  // User 2: Nguyễn Văn A (3 giao dịch độc lập — Đơn vị: VNĐ)
  TransactionModel(
    id: 'TXN-201',
    userId: 'usr_02',
    ownerEmail: 'user2@fpt.edu.vn',
    type: TransactionType.income,
    amount: 6500000,
    category: 'Salary',
    date: '2026-10-05',
    note: 'Lương trợ giảng bán thời gian tại khoa',
  ),
  TransactionModel(
    id: 'TXN-202',
    userId: 'usr_02',
    ownerEmail: 'user2@fpt.edu.vn',
    type: TransactionType.expense,
    amount: 1850000,
    category: 'Shopping',
    date: '2026-10-14',
    note: 'Bàn phím cơ phục vụ lập trình',
  ),
  TransactionModel(
    id: 'TXN-203',
    userId: 'usr_02',
    ownerEmail: 'user2@fpt.edu.vn',
    type: TransactionType.expense,
    amount: 520000,
    category: 'Bills',
    date: '2026-10-20',
    note: 'Thanh toán tiền điện và Internet tháng 10',
  ),
];

/// Định dạng tiền tệ VNĐ chuẩn dấu chấm phân tách hàng nghìn (1:1 với src/lib/financeEngine.ts)
String formatCurrencyVnd(double amount, [TransactionType? type]) {
  final absAmount = amount.abs().round();
  final digits = absAmount.toString();
  final buffer = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(digits[i]);
  }
  final formatted = '${buffer.toString()} ₫';
  if (type == TransactionType.income) return '+$formatted';
  if (type == TransactionType.expense) return '-$formatted';
  if (amount < 0) return '-$formatted';
  return formatted;
}

String formatLongDate(String dateStr) {
  final parts = dateStr.split('-').map(int.tryParse).toList();
  if (parts.length != 3 || parts.contains(null)) return dateStr;
  return '${parts[2]} tháng ${parts[1]}, ${parts[0]}';
}

IconData getLucideCategoryIcon(String category) {
  switch (category) {
    case 'Salary':
      return LucideIcons.briefcase;
    case 'Freelance':
      return LucideIcons.laptop;
    case 'Investment':
      return LucideIcons.trending_up;
    case 'Food & Drink':
      return LucideIcons.utensils;
    case 'Transport':
      return LucideIcons.car;
    case 'Shopping':
      return LucideIcons.shopping_bag;
    case 'Study':
      return LucideIcons.graduation_cap;
    case 'Bills':
      return LucideIcons.receipt;
    case 'Entertainment':
      return LucideIcons.film;
    default:
      return LucideIcons.wallet;
  }
}

// ============================================================================
// LOCAL SQLITE DATABASE HELPER + REST API SYNC
// ============================================================================
class LocalSqliteHelper {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dbPath, 'prm393_finance_vnd.sqlite'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE transactions (
            id TEXT PRIMARY KEY,
            userId TEXT NOT NULL,
            ownerEmail TEXT NOT NULL,
            type TEXT NOT NULL,
            amount REAL NOT NULL,
            category TEXT NOT NULL,
            date TEXT NOT NULL,
            note TEXT DEFAULT ''
          )
        ''');
        for (final t in kInitialSeedTransactions) {
          await db.insert('transactions', t.toMap());
        }
      },
    );
    return _db!;
  }

  static Future<List<TransactionModel>> getTransactionsByUser(
      String userId) async {
    final db = await database;
    final rows = await db.query(
      'transactions',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'date DESC, id DESC',
    );
    return rows.map((r) => TransactionModel.fromJson(r)).toList();
  }

  static Future<void> upsertTransaction(TransactionModel txn) async {
    final db = await database;
    await db.insert(
      'transactions',
      txn.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> deleteTransaction(String id, String userId) async {
    final db = await database;
    await db.delete(
      'transactions',
      where: 'id = ? AND userId = ?',
      whereArgs: [id, userId],
    );
  }

  static Future<void> resetToSeedData() async {
    final db = await database;
    await db.delete('transactions');
    for (final t in kInitialSeedTransactions) {
      await db.insert('transactions', t.toMap());
    }
  }
}

class FinanceProvider extends ChangeNotifier {
  static const String kSessionKey = 'prm393_auth_session';
  static const String kApiBaseUrl = 'http://localhost:3000/api';

  UserAccount? _currentUser;
  String? _authToken;
  List<TransactionModel> _transactions = [];
  String _searchQuery = '';
  String _typeFilter = 'All';
  String _categoryFilter = 'All Categories';
  String? _toastMessage;

  UserAccount? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null && _authToken != null;
  List<TransactionModel> get transactions => _transactions;
  String get searchQuery => _searchQuery;
  String get typeFilter => _typeFilter;
  String get categoryFilter => _categoryFilter;
  String? get toastMessage => _toastMessage;

  // Công thức bắt buộc: Số dư = Tổng thu nhập - Tổng chi tiêu
  double get totalIncome => _transactions
      .where((t) => t.type == TransactionType.income)
      .fold(0.0, (sum, t) => sum + t.amount);

  double get totalExpenses => _transactions
      .where((t) => t.type == TransactionType.expense)
      .fold(0.0, (sum, t) => sum + t.amount);

  double get balance => totalIncome - totalExpenses;

  int get incomeRatioPercent {
    final total = totalIncome + totalExpenses;
    if (total == 0) return 0;
    return ((totalIncome / total) * 100).round();
  }

  int get expenseRatioPercent {
    final total = totalIncome + totalExpenses;
    if (total == 0) return 0;
    return 100 - incomeRatioPercent;
  }

  List<TransactionModel> get filteredTransactions {
    final q = _searchQuery.trim().toLowerCase();
    return _transactions.where((txn) {
      if (_typeFilter == 'Income' && txn.type != TransactionType.income) {
        return false;
      }
      if (_typeFilter == 'Expense' && txn.type != TransactionType.expense) {
        return false;
      }
      if (_categoryFilter != 'All Categories' &&
          txn.category != _categoryFilter) {
        return false;
      }
      if (q.isNotEmpty) {
        final labelVi =
            (kCategoryLabelsVi[txn.category] ?? txn.category).toLowerCase();
        return txn.note.toLowerCase().contains(q) ||
            labelVi.contains(q) ||
            txn.category.toLowerCase().contains(q);
      }
      return true;
    }).toList();
  }

  void triggerToast(String msg) {
    _toastMessage = msg;
    notifyListeners();
    Future.delayed(const Duration(milliseconds: 2400), () {
      if (_toastMessage == msg) {
        _toastMessage = null;
        notifyListeners();
      }
    });
  }

  void setSearchQuery(String value) {
    _searchQuery = value;
    notifyListeners();
  }

  void setTypeFilter(String value) {
    _typeFilter = value;
    notifyListeners();
  }

  void setCategoryFilter(String value) {
    _categoryFilter = value;
    notifyListeners();
  }

  Future<void> initializeAndRestoreSession() async {
    // 1. Tải dữ liệu SQLite local ngay tức thì
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(kSessionKey);
      if (raw != null) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        _authToken = decoded['auth_token'] as String?;
        _currentUser = UserAccount.fromJson(
            decoded['current_user'] as Map<String, dynamic>);
      }
    } catch (_) {}

    // Nếu chưa đăng nhập, mặc định nạp sẵn tài khoản user1
    if (_currentUser == null) {
      _currentUser = kSeedUsers.first;
      _authToken = 'jwt_local_sqlite_${_currentUser!.id}';
    }

    _transactions =
        await LocalSqliteHelper.getTransactionsByUser(_currentUser!.id);
    notifyListeners();

    // Đồng bộ nền qua API nếu có server (không block UI)
    _backgroundApiSync();
  }

  Future<void> login(String email, String password) async {
    final cleanEmail = email.trim().toLowerCase();
    if (!cleanEmail.contains('@')) {
      throw Exception('Địa chỉ email không hợp lệ.');
    }
    if (password.length < 6) {
      throw Exception('Mật khẩu phải có ít nhất 6 ký tự.');
    }

    // 1. Kiểm tra xác thực tức thì qua Seed Users
    final matched = kSeedUsers.where((u) => u.email == cleanEmail).toList();
    if (matched.isEmpty || password != '123456') {
      throw Exception('Email hoặc mật khẩu không chính xác. Vui lòng thử lại.');
    }

    _currentUser = matched.first;
    _authToken = 'jwt_local_sqlite_${_currentUser!.id}';

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      kSessionKey,
      jsonEncode({
        'auth_token': _authToken,
        'current_user': _currentUser!.toJson(),
      }),
    );

    _transactions =
        await LocalSqliteHelper.getTransactionsByUser(_currentUser!.id);
    _searchQuery = '';
    _typeFilter = 'All';
    _categoryFilter = 'All Categories';
    triggerToast('Chào mừng trở lại, ${_currentUser!.name}');
    notifyListeners();

    // 2. Thử gọi API nền nếu server localhost/mạng khả dụng
    _backgroundApiSync();
  }

  Future<void> quickSwitchUser(String targetEmail) async {
    await login(targetEmail, '123456');
    triggerToast('Đã chuyển sang tài khoản: ${_currentUser!.name}');
  }

  Future<void> _backgroundApiSync() async {
    if (_currentUser == null) return;
    try {
      final res = await http
          .get(Uri.parse('$kApiBaseUrl/transactions?userId=${_currentUser!.id}'))
          .timeout(const Duration(milliseconds: 500));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        if (list.isNotEmpty) {
          _transactions = list
              .map((item) =>
                  TransactionModel.fromJson(item as Map<String, dynamic>))
              .toList();
          for (final t in _transactions) {
            await LocalSqliteHelper.upsertTransaction(t);
          }
          notifyListeners();
        }
      }
    } catch (_) {
      // Offline fallback
    }
  }

  Future<void> saveTransaction({
    String? existingId,
    required TransactionType type,
    required double amount,
    required String category,
    required String date,
    required String note,
  }) async {
    if (_currentUser == null) return;
    if (amount <= 0) {
      throw Exception('Số tiền phải lớn hơn 0 ₫.');
    }
    final isNew = existingId == null;
    final id = existingId ?? 'TXN-${10000 + Random().nextInt(89999)}';
    final model = TransactionModel(
      id: id,
      userId: _currentUser!.id,
      ownerEmail: _currentUser!.email,
      type: type,
      amount: amount,
      category: category,
      date: date,
      note: note,
    );
    await LocalSqliteHelper.upsertTransaction(model);
    _transactions =
        await LocalSqliteHelper.getTransactionsByUser(_currentUser!.id);
    triggerToast(isNew
        ? 'Đã lưu giao dịch thành công'
        : 'Đã cập nhật giao dịch thành công');
    notifyListeners();
  }

  Future<void> deleteTransaction(String id) async {
    if (_currentUser == null) return;
    await LocalSqliteHelper.deleteTransaction(id, _currentUser!.id);
    _transactions =
        await LocalSqliteHelper.getTransactionsByUser(_currentUser!.id);
    triggerToast('Đã xóa giao dịch — Số dư đã cập nhật');
    notifyListeners();
  }

  Future<void> resetDemoData() async {
    await LocalSqliteHelper.resetToSeedData();
    if (_currentUser != null) {
      _transactions =
          await LocalSqliteHelper.getTransactionsByUser(_currentUser!.id);
    }
    triggerToast('Đã khôi phục dữ liệu mẫu (VNĐ)');
    notifyListeners();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kSessionKey);
    _authToken = null;
    _currentUser = null;
    _transactions = [];
    triggerToast('Đã đăng xuất khỏi tài khoản');
    notifyListeners();
  }
}

// ============================================================================
// AMBIENT LIGHTING CANVAS & GLASSMORPHISM CORE (1:1 VỚI LOCALHOST:3000)
// ============================================================================
class AmbientLightingCanvas extends StatelessWidget {
  final Widget child;
  const AmbientLightingCanvas({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF080C14),
      child: Stack(
        children: [
          // Quả cầu phát quang mờ ngọc lục bảo (Top-Left)
          Positioned(
            top: -48,
            left: -48,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
              child: Container(
                width: 260,
                height: 260,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x2E10B981),
                ),
              ),
            ),
          ),
          // Quả cầu phát quang mờ tím chàm (Middle-Right)
          Positioned(
            top: 280,
            right: -64,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 110, sigmaY: 110),
              child: Container(
                width: 280,
                height: 280,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x296366F1),
                ),
              ),
            ),
          ),
          // Quả cầu phát quang mờ xanh dương (Bottom-Left)
          Positioned(
            bottom: 32,
            left: -40,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
              child: Container(
                width: 240,
                height: 240,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x1F0EA5E9),
                ),
              ),
            ),
          ),
          // Nội dung hiển thị
          child,
        ],
      ),
    );
  }
}

/// Thẻ Kính Mờ Frosted Glass Cấp 1 (Chuẩn .glass-tier-1 trong index.css)
class GlassTier1Container extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;

  const GlassTier1Container({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.12),
                  Colors.white.withOpacity(0.04),
                ],
              ),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: Colors.white.withOpacity(0.18),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.55),
                  blurRadius: 36,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Thẻ Bề Mặt Kính Bán Trong Suốt Cấp 2 (Chuẩn .glass-tier-2 trong index.css)
class GlassTier2Container extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Border? border;
  final Color? customBgColor;
  final double? height;
  final double? width;

  const GlassTier2Container({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 16.0,
    this.border,
    this.customBgColor,
    this.height,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: customBgColor ?? const Color(0xFF131C2E).withOpacity(0.68),
        borderRadius: BorderRadius.circular(borderRadius),
        border: border ??
            Border.all(
              color: Colors.white.withOpacity(0.08),
              width: 1,
            ),
      ),
      child: child,
    );
  }
}

/// Nút Bấm Gradient Thương Hiệu (Chuẩn .btn-primary-gradient trong index.css)
class PrimaryGradientButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final double height;
  final double borderRadius;

  const PrimaryGradientButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.height = 48.0,
    this.borderRadius = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF38BDF8), Color(0xFF818CF8)],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF38BDF8).withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: onPressed,
          child: Center(child: child),
        ),
      ),
    );
  }
}

/// Huy Hiệu Icon Danh Mục (1:1 với CategoryIconBadge.tsx)
class CategoryIconBadgeWidget extends StatelessWidget {
  final String category;
  final TransactionType type;
  final double size;

  const CategoryIconBadgeWidget({
    super.key,
    required this.category,
    required this.type,
    this.size = 44.0,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = type == TransactionType.income;
    final color =
        isIncome ? const Color(0xFF34D399) : const Color(0xFFFB7185);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(size * 0.32),
        border: Border.all(
          color: color.withOpacity(0.30),
          width: 1,
        ),
      ),
      child: Center(
        child: Icon(
          getLucideCategoryIcon(category),
          size: size * 0.48,
          color: color,
        ),
      ),
    );
  }
}

// ============================================================================
// MAIN APP & ROOT MOBILE NAVIGATOR
// ============================================================================
class AuraFinanceApp extends StatelessWidget {
  const AuraFinanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AuraFinance — Quản lý Tài chính Cá nhân',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF080C14),
        textTheme: GoogleFonts.beVietnamProTextTheme(
          ThemeData.dark().textTheme,
        ),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF38BDF8),
          secondary: Color(0xFF34D399),
          error: Color(0xFFFB7185),
        ),
      ),
      home: const RootMobileNavigator(),
    );
  }
}

class RootMobileNavigator extends StatefulWidget {
  const RootMobileNavigator({super.key});

  @override
  State<RootMobileNavigator> createState() => _RootMobileNavigatorState();
}

class _RootMobileNavigatorState extends State<RootMobileNavigator> {
  // Navigation stack: 'HOME_DASHBOARD' | 'TRANSACTION_LIST' | 'ADD_EDIT_MODAL' | 'TRANSACTION_DETAIL'
  String _activeScreen = 'HOME_DASHBOARD';
  String _previousTab = 'HOME_DASHBOARD';
  TransactionModel? _selectedTxn;
  TransactionModel? _editingTxn;

  void _navigateToDetail(TransactionModel txn) {
    setState(() {
      if (_activeScreen == 'HOME_DASHBOARD' || _activeScreen == 'TRANSACTION_LIST') {
        _previousTab = _activeScreen;
      }
      _selectedTxn = txn;
      _activeScreen = 'TRANSACTION_DETAIL';
    });
  }

  void _navigateToAddEdit([TransactionModel? txn]) {
    setState(() {
      _editingTxn = txn;
      _activeScreen = 'ADD_EDIT_MODAL';
    });
  }

  void _navigateBack() {
    setState(() {
      if (_editingTxn != null && _selectedTxn != null) {
        _editingTxn = null;
        _activeScreen = 'TRANSACTION_DETAIL';
      } else {
        _editingTxn = null;
        _selectedTxn = null;
        _activeScreen = _previousTab;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    if (!provider.isAuthenticated) {
      return const LoginMobileScreen();
    }

    final showBottomNav = _activeScreen == 'HOME_DASHBOARD' ||
        _activeScreen == 'TRANSACTION_LIST';

    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    final topSafe = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: const Color(0xFF080C14),
      body: AmbientLightingCanvas(
        child: Stack(
          children: [
            // Active Screen View
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.only(top: max(topSafe + 8, 24)),
                child: _buildCurrentScreen(provider),
              ),
            ),

            // Tier 1 Floating Bottom Tab Bar + Center FAB (`+`)
            if (showBottomNav)
              Positioned(
                left: 16,
                right: 16,
                bottom: max(bottomSafe + 4, 20),
                child: GlassTier1Container(
                  borderRadius: 24,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Tab Tổng quan
                      InkWell(
                        onTap: () =>
                            setState(() => _activeScreen = 'HOME_DASHBOARD'),
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                LucideIcons.house,
                                size: 20,
                                color: _activeScreen == 'HOME_DASHBOARD'
                                    ? const Color(0xFF38BDF8)
                                    : const Color(0xFF94A3B8),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Tổng quan',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _activeScreen == 'HOME_DASHBOARD'
                                      ? const Color(0xFF38BDF8)
                                      : const Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Floating Action Button (`+`) với Gradient và Shadow
                      Transform.translate(
                        offset: const Offset(0, -18),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF38BDF8), Color(0xFF818CF8)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFF080C14),
                              width: 2.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF38BDF8).withOpacity(0.40),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => _navigateToAddEdit(),
                              child: const Center(
                                child: Icon(
                                  LucideIcons.plus,
                                  color: Color(0xFF080C14),
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Tab Sổ giao dịch
                      InkWell(
                        onTap: () =>
                            setState(() => _activeScreen = 'TRANSACTION_LIST'),
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                LucideIcons.list_filter,
                                size: 20,
                                color: _activeScreen == 'TRANSACTION_LIST'
                                    ? const Color(0xFF38BDF8)
                                    : const Color(0xFF94A3B8),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Sổ giao dịch',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _activeScreen == 'TRANSACTION_LIST'
                                      ? const Color(0xFF38BDF8)
                                      : const Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Animated Glass Toast Notification (1:1 với src/App.tsx)
            if (provider.toastMessage != null)
              Positioned(
                left: 20,
                right: 20,
                bottom: showBottomNav ? 96 + bottomSafe : 32 + bottomSafe,
                child: GlassTier1Container(
                  borderRadius: 16,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.circle_check,
                        size: 16,
                        color: Color(0xFF34D399),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          provider.toastMessage!,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFF8FAFC),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentScreen(FinanceProvider provider) {
    switch (_activeScreen) {
      case 'HOME_DASHBOARD':
        return HomeDashboardMobileScreen(
          onSeeAll: () => setState(() => _activeScreen = 'TRANSACTION_LIST'),
          onSelectTransaction: _navigateToDetail,
          onOpenAddModal: () => _navigateToAddEdit(),
        );
      case 'TRANSACTION_LIST':
        return TransactionListMobileScreen(
          onSelectTransaction: _navigateToDetail,
        );
      case 'ADD_EDIT_MODAL':
        return AddEditTransactionMobileScreen(
          initialTxn: _editingTxn,
          onCancel: _navigateBack,
          onSaved: (isNew) {
            _navigateBack();
          },
        );
      case 'TRANSACTION_DETAIL':
        final txn = _selectedTxn ?? provider.transactions.first;
        return TransactionDetailMobileScreen(
          txn: txn,
          onBack: _navigateBack,
          onEdit: () => _navigateToAddEdit(txn),
          onDeleted: () {
            _selectedTxn = null;
            setState(() => _activeScreen = _previousTab);
          },
        );
      default:
        return HomeDashboardMobileScreen(
          onSeeAll: () => setState(() => _activeScreen = 'TRANSACTION_LIST'),
          onSelectTransaction: _navigateToDetail,
          onOpenAddModal: () => _navigateToAddEdit(),
        );
    }
  }
}

// ============================================================================
// MÀN HÌNH 1: ĐĂNG NHẬP (1:1 VỚI LOGINSCREEN.TSX)
// ============================================================================
class LoginMobileScreen extends StatefulWidget {
  const LoginMobileScreen({super.key});

  @override
  State<LoginMobileScreen> createState() => _LoginMobileScreenState();
}

class _LoginMobileScreenState extends State<LoginMobileScreen> {
  final _emailCtrl = TextEditingController(text: 'user1@fpt.edu.vn');
  final _passCtrl = TextEditingController(text: '123456');
  bool _showPass = false;
  bool _isLoading = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _isLoading = true;
    });
    try {
      await context
          .read<FinanceProvider>()
          .login(_emailCtrl.text, _passCtrl.text);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _selectDemo(String email, String pass) {
    setState(() {
      _emailCtrl.text = email;
      _passCtrl.text = pass;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080C14),
      body: AmbientLightingCanvas(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Top Brand Header (1:1 với Brand Lockup)
                      Column(
                        children: [
                          const SizedBox(height: 16),
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0x3D10B981),
                                  Color(0x476366F1),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.20),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF10B981).withOpacity(0.35),
                                  blurRadius: 28,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                LucideIcons.sparkles,
                                size: 32,
                                color: Color(0xFF34D399),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'AuraFinance',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                              color: Color(0xFFF8FAFC),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Quản lý Tài chính Cá nhân Thông minh',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),

                      // Frosted Glass Login Form Card
                      GlassTier1Container(
                        borderRadius: 24,
                        padding: const EdgeInsets.all(20),
                        margin: const EdgeInsets.symmetric(vertical: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Địa chỉ Email',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                            const SizedBox(height: 6),
                            GlassTier2Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              child: Row(
                                children: [
                                  const Icon(
                                    LucideIcons.mail,
                                    size: 16,
                                    color: Color(0xFF94A3B8),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextField(
                                      controller: _emailCtrl,
                                      style: const TextStyle(
                                        color: Color(0xFFF8FAFC),
                                        fontSize: 14,
                                      ),
                                      decoration: const InputDecoration(
                                        hintText: 'Nhập địa chỉ email...',
                                        hintStyle: TextStyle(
                                          color: Color(0xFF64748B),
                                          fontSize: 14,
                                        ),
                                        border: InputBorder.none,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Mật khẩu',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                            const SizedBox(height: 6),
                            GlassTier2Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              child: Row(
                                children: [
                                  const Icon(
                                    LucideIcons.lock,
                                    size: 16,
                                    color: Color(0xFF94A3B8),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextField(
                                      controller: _passCtrl,
                                      obscureText: !_showPass,
                                      style: GoogleFonts.jetBrainsMono(
                                        color: const Color(0xFFF8FAFC),
                                        fontSize: 14,
                                      ),
                                      decoration: const InputDecoration(
                                        hintText: 'Nhập mật khẩu...',
                                        hintStyle: TextStyle(
                                          color: Color(0xFF64748B),
                                          fontSize: 14,
                                        ),
                                        border: InputBorder.none,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      _showPass
                                          ? LucideIcons.eye_off
                                          : LucideIcons.eye,
                                      size: 16,
                                      color: const Color(0xFF94A3B8),
                                    ),
                                    onPressed: () =>
                                        setState(() => _showPass = !_showPass),
                                  ),
                                ],
                              ),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF43F5E).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFF43F5E).withOpacity(0.40),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      LucideIcons.circle_alert,
                                      size: 16,
                                      color: Color(0xFFF43F5E),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _error!,
                                        style: const TextStyle(
                                          color: Color(0xFFFB7185),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            PrimaryGradientButton(
                              onPressed: _isLoading ? null : _submit,
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFF080C14),
                                      ),
                                    )
                                  : const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Đăng nhập',
                                          style: TextStyle(
                                            color: Color(0xFF080C14),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Icon(
                                          LucideIcons.arrow_right,
                                          size: 16,
                                          color: Color(0xFF080C14),
                                        ),
                                      ],
                                    ),
                            ),
                          ],
                        ),
                      ),

                      // Quick Demo Accounts Section (1:1 với LoginScreen.tsx)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'TÀI KHOẢN TRẢI NGHIỆM NHANH',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                              Text(
                                'Chạm để chọn',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // User 1 Card
                          InkWell(
                            onTap: () => _selectDemo('user1@fpt.edu.vn', '123456'),
                            borderRadius: BorderRadius.circular(16),
                            child: GlassTier2Container(
                              padding: const EdgeInsets.all(12),
                              border: _emailCtrl.text == 'user1@fpt.edu.vn'
                                  ? Border.all(
                                      color: const Color(0xFF38BDF8)
                                          .withOpacity(0.60),
                                      width: 1.2,
                                    )
                                  : null,
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF34D399)
                                          .withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: const Color(0xFF34D399)
                                            .withOpacity(0.30),
                                      ),
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        LucideIcons.user_check,
                                        size: 18,
                                        color: Color(0xFF34D399),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Tạ Tuấn Kỳ · 5 giao dịch',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFFF8FAFC),
                                          ),
                                        ),
                                        Text(
                                          'user1@fpt.edu.vn',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    _emailCtrl.text == 'user1@fpt.edu.vn'
                                        ? 'Đang chọn'
                                        : 'Chọn',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF38BDF8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // User 2 Card
                          InkWell(
                            onTap: () => _selectDemo('user2@fpt.edu.vn', '123456'),
                            borderRadius: BorderRadius.circular(16),
                            child: GlassTier2Container(
                              padding: const EdgeInsets.all(12),
                              border: _emailCtrl.text == 'user2@fpt.edu.vn'
                                  ? Border.all(
                                      color: const Color(0xFF38BDF8)
                                          .withOpacity(0.60),
                                      width: 1.2,
                                    )
                                  : null,
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF818CF8)
                                          .withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: const Color(0xFF818CF8)
                                            .withOpacity(0.30),
                                      ),
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        LucideIcons.user_check,
                                        size: 18,
                                        color: Color(0xFF818CF8),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Nguyễn Văn A · 3 giao dịch',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFFF8FAFC),
                                          ),
                                        ),
                                        Text(
                                          'user2@fpt.edu.vn',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    _emailCtrl.text == 'user2@fpt.edu.vn'
                                        ? 'Đang chọn'
                                        : 'Chọn',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF38BDF8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// MÀN HÌNH 2: TỔNG QUAN / DASHBOARD (1:1 VỚI HOMEDASHBOARDSCREEN.TSX)
// ============================================================================
class HomeDashboardMobileScreen extends StatefulWidget {
  final VoidCallback onSeeAll;
  final ValueChanged<TransactionModel> onSelectTransaction;
  final VoidCallback onOpenAddModal;

  const HomeDashboardMobileScreen({
    super.key,
    required this.onSeeAll,
    required this.onSelectTransaction,
    required this.onOpenAddModal,
  });

  @override
  State<HomeDashboardMobileScreen> createState() =>
      _HomeDashboardMobileScreenState();
}

class _HomeDashboardMobileScreenState extends State<HomeDashboardMobileScreen> {
  bool _showAccountMenu = false;

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length == 1) {
      return parts[0].substring(0, min(2, parts[0].length)).toUpperCase();
    }
    return (parts[parts.length - 2][0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final user = provider.currentUser!;
    final initials = _getInitials(user.name);
    final recentItems = provider.transactions.take(5).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        // Top App Bar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            InkWell(
              onTap: () => setState(() => _showAccountMenu = !_showAccountMenu),
              borderRadius: BorderRadius.circular(16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0x4038BDF8), Color(0x40818CF8)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.15),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: Color(0xFFF8FAFC),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Xin chào, ${user.name}',
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFF8FAFC),
                        ),
                      ),
                      Text(
                        user.email,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Row(
              children: [
                // Switch Account Button
                InkWell(
                  onTap: () =>
                      setState(() => _showAccountMenu = !_showAccountMenu),
                  borderRadius: BorderRadius.circular(12),
                  child: GlassTier2Container(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      LucideIcons.users,
                      size: 16,
                      color: _showAccountMenu
                          ? const Color(0xFF38BDF8)
                          : const Color(0xFF94A3B8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Logout Button
                InkWell(
                  onTap: () => provider.logout(),
                  borderRadius: BorderRadius.circular(12),
                  child: GlassTier2Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: const Row(
                      children: [
                        Icon(
                          LucideIcons.log_out,
                          size: 14,
                          color: Color(0xFFFB7185),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Thoát',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFFB7185),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),

        // Collapsible Account Switcher & Reset Drawer (1:1 với HomeDashboardScreen.tsx)
        if (_showAccountMenu) ...[
          const SizedBox(height: 12),
          GlassTier2Container(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Chuyển nhanh Tài khoản (Cô lập dữ liệu)',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    InkWell(
                      onTap: () async {
                        await provider.resetDemoData();
                        setState(() => _showAccountMenu = false);
                      },
                      child: const Row(
                        children: [
                          Icon(
                            LucideIcons.rotate_ccw,
                            size: 12,
                            color: Color(0xFF38BDF8),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Khôi phục mẫu',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF38BDF8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    // Option 1
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          await provider.quickSwitchUser('user1@fpt.edu.vn');
                          setState(() => _showAccountMenu = false);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: user.email == 'user1@fpt.edu.vn'
                                ? const Color(0xFF34D399).withOpacity(0.15)
                                : const Color(0xFF080C14).withOpacity(0.50),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: user.email == 'user1@fpt.edu.vn'
                                  ? const Color(0xFF34D399).withOpacity(0.50)
                                  : Colors.white.withOpacity(0.10),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Tạ Tuấn Kỳ',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFF8FAFC),
                                    ),
                                  ),
                                  if (user.email == 'user1@fpt.edu.vn')
                                    const Icon(
                                      LucideIcons.check,
                                      size: 14,
                                      color: Color(0xFF34D399),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'user1@fpt.edu.vn',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Option 2
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          await provider.quickSwitchUser('user2@fpt.edu.vn');
                          setState(() => _showAccountMenu = false);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: user.email == 'user2@fpt.edu.vn'
                                ? const Color(0xFF38BDF8).withOpacity(0.15)
                                : const Color(0xFF080C14).withOpacity(0.50),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: user.email == 'user2@fpt.edu.vn'
                                  ? const Color(0xFF38BDF8).withOpacity(0.50)
                                  : Colors.white.withOpacity(0.10),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Nguyễn Văn A',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFF8FAFC),
                                    ),
                                  ),
                                  if (user.email == 'user2@fpt.edu.vn')
                                    const Icon(
                                      LucideIcons.check,
                                      size: 14,
                                      color: Color(0xFF38BDF8),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'user2@fpt.edu.vn',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 16),

        // Main Balance Hero Card (Tier 1 Frosted Glass)
        GlassTier1Container(
          borderRadius: 24,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'SỐ DƯ HIỆN TẠI (VNĐ)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  Text(
                    '${provider.transactions.length} giao dịch',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                formatCurrencyVnd(provider.balance),
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                  color: provider.balance < 0
                      ? const Color(0xFFFB7185)
                      : const Color(0xFFF8FAFC),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Số dư = Tổng thu nhập − Tổng chi tiêu',
                style: TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 16),
              // 2-Column Split inside Balance Card
              Container(
                padding: const EdgeInsets.only(top: 14),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withOpacity(0.12),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // Tổng thu nhập
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFF34D399).withOpacity(0.14),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFF34D399).withOpacity(0.30),
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                LucideIcons.arrow_down_left,
                                size: 16,
                                color: Color(0xFF34D399),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Tổng thu nhập',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                                Text(
                                  formatCurrencyVnd(
                                      provider.totalIncome, TransactionType.income),
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF34D399),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 32,
                      color: Colors.white.withOpacity(0.10),
                    ),
                    const SizedBox(width: 8),
                    // Tổng chi tiêu
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFB7185).withOpacity(0.14),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFFB7185).withOpacity(0.30),
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                LucideIcons.arrow_up_right,
                                size: 16,
                                color: Color(0xFFFB7185),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Tổng chi tiêu',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                                Text(
                                  formatCurrencyVnd(
                                      provider.totalExpenses, TransactionType.expense),
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFFB7185),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Cash Flow Ratio Bar
        GlassTier2Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.beVietnamPro(fontSize: 12),
                      children: [
                        const TextSpan(
                          text: 'Tỷ lệ dòng tiền ',
                          style: TextStyle(color: Color(0xFF94A3B8)),
                        ),
                        TextSpan(
                          text: '${provider.incomeRatioPercent}% Thu',
                          style: GoogleFonts.jetBrainsMono(
                            color: const Color(0xFF34D399),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${provider.expenseRatioPercent}% Chi',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      color: const Color(0xFFFB7185),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 8,
                  color: const Color(0xFF080C14).withOpacity(0.80),
                  child: Row(
                    children: [
                      Expanded(
                        flex: max(1, provider.incomeRatioPercent),
                        child: Container(color: const Color(0xFF34D399)),
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        flex: max(1, provider.expenseRatioPercent),
                        child: Container(color: const Color(0xFFFB7185)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Recent Transactions Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'GIAO DỊCH GẦN ĐÂY',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
                color: Color(0xFF94A3B8),
              ),
            ),
            InkWell(
              onTap: widget.onSeeAll,
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  children: [
                    Text(
                      'Xem tất cả',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF38BDF8),
                      ),
                    ),
                    Icon(
                      LucideIcons.chevron_right,
                      size: 16,
                      color: Color(0xFF38BDF8),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (recentItems.isEmpty)
          GlassTier2Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  'Chưa có giao dịch nào được ghi nhận cho ${user.name}.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 12),
                PrimaryGradientButton(
                  height: 40,
                  onPressed: widget.onOpenAddModal,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.plus, size: 16, color: Color(0xFF080C14)),
                      SizedBox(width: 4),
                      Text(
                        'Thêm giao dịch đầu tiên',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF080C14),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          ...recentItems.map(
            (txn) => TransactionRowTile(
              txn: txn,
              onTap: () => widget.onSelectTransaction(txn),
            ),
          ),
      ],
    );
  }
}

// ============================================================================
// HÀNG GIAO DỊCH CHUẨN KÍNH TIER 2
// ============================================================================
class TransactionRowTile extends StatelessWidget {
  final TransactionModel txn;
  final VoidCallback onTap;

  const TransactionRowTile({
    super.key,
    required this.txn,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = txn.type == TransactionType.income;
    final categoryVi = kCategoryLabelsVi[txn.category] ?? txn.category;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: GlassTier2Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              CategoryIconBadgeWidget(
                category: txn.category,
                type: txn.type,
                size: 42,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      categoryVi,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFF8FAFC),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      txn.note.isEmpty ? 'Không có ghi chú' : txn.note,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      txn.date,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                children: [
                  Text(
                    formatCurrencyVnd(txn.amount, txn.type),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: isIncome
                          ? const Color(0xFF34D399)
                          : const Color(0xFFFB7185),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    LucideIcons.chevron_right,
                    size: 16,
                    color: Color(0xFF64748B),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// MÀN HÌNH 3: SỔ GIAO DỊCH (1:1 VỚI TRANSACTIONLISTSCREEN.TSX)
// ============================================================================
class TransactionListMobileScreen extends StatelessWidget {
  final ValueChanged<TransactionModel> onSelectTransaction;

  const TransactionListMobileScreen({
    super.key,
    required this.onSelectTransaction,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final items = provider.filteredTransactions;

    final filteredIncome = items
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (sum, t) => sum + t.amount);
    final filteredExpense = items
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (sum, t) => sum + t.amount);
    final netTotal = filteredIncome - filteredExpense;

    final hasActiveFilters = provider.searchQuery.trim().isNotEmpty ||
        provider.typeFilter != 'All' ||
        provider.categoryFilter != 'All Categories';

    void resetFilters() {
      provider.setSearchQuery('');
      provider.setTypeFilter('All');
      provider.setCategoryFilter('All Categories');
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Sổ giao dịch',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
                color: Color(0xFFF8FAFC),
              ),
            ),
            if (hasActiveFilters)
              InkWell(
                onTap: resetFilters,
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        LucideIcons.rotate_ccw,
                        size: 14,
                        color: Color(0xFF38BDF8),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Đặt lại',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF38BDF8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // Search Bar (Tier 2 surface)
        GlassTier2Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              const Icon(
                LucideIcons.search,
                size: 16,
                color: Color(0xFF94A3B8),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  onChanged: provider.setSearchQuery,
                  style: const TextStyle(color: Color(0xFFF8FAFC), fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Tìm theo ghi chú hoặc danh mục...',
                    hintStyle: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
              if (provider.searchQuery.isNotEmpty)
                IconButton(
                  icon: const Icon(LucideIcons.x, size: 16),
                  onPressed: () => provider.setSearchQuery(''),
                ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Type Filter Segmented Control: Tất cả | Thu nhập | Chi tiêu
        GlassTier2Container(
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              for (final entry in [
                {'val': 'All', 'label': 'Tất cả'},
                {'val': 'Income', 'label': 'Thu nhập'},
                {'val': 'Expense', 'label': 'Chi tiêu'},
              ])
                Expanded(
                  child: InkWell(
                    onTap: () => provider.setTypeFilter(entry['val']!),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 36,
                      decoration: BoxDecoration(
                        color: provider.typeFilter == entry['val']
                            ? (entry['val'] == 'Income'
                                ? const Color(0xFF34D399).withOpacity(0.20)
                                : entry['val'] == 'Expense'
                                    ? const Color(0xFFFB7185).withOpacity(0.20)
                                    : Colors.white.withOpacity(0.15))
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: provider.typeFilter == entry['val']
                              ? (entry['val'] == 'Income'
                                  ? const Color(0xFF34D399).withOpacity(0.40)
                                  : entry['val'] == 'Expense'
                                      ? const Color(0xFFFB7185)
                                          .withOpacity(0.40)
                                      : Colors.white.withOpacity(0.20))
                              : Colors.transparent,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          entry['label']!,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: provider.typeFilter == entry['val']
                                ? (entry['val'] == 'Income'
                                    ? const Color(0xFF34D399)
                                    : entry['val'] == 'Expense'
                                        ? const Color(0xFFFB7185)
                                        : const Color(0xFFF8FAFC))
                                : const Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Category Horizontal Scrollable Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildCategoryChip(
                provider,
                'All Categories',
                'Tất cả danh mục',
              ),
              ...kCategoryLabelsVi.entries.map(
                (e) => _buildCategoryChip(provider, e.key, e.value),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Result Summary Strip (Hiển thị X giao dịch • Tổng ròng)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withOpacity(0.10),
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              RichText(
                text: TextSpan(
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 12,
                    color: const Color(0xFF94A3B8),
                  ),
                  children: [
                    const TextSpan(text: 'Hiển thị '),
                    TextSpan(
                      text: '${items.length}',
                      style: GoogleFonts.jetBrainsMono(
                        color: const Color(0xFFF8FAFC),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const TextSpan(text: ' giao dịch'),
                  ],
                ),
              ),
              RichText(
                text: TextSpan(
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 12,
                    color: const Color(0xFF94A3B8),
                  ),
                  children: [
                    const TextSpan(text: 'Tổng ròng: '),
                    TextSpan(
                      text: formatCurrencyVnd(netTotal),
                      style: GoogleFonts.jetBrainsMono(
                        color: netTotal >= 0
                            ? const Color(0xFF34D399)
                            : const Color(0xFFFB7185),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // List View / Empty State
        if (items.isEmpty)
          GlassTier2Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.10),
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      LucideIcons.funnel,
                      size: 20,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Không tìm thấy giao dịch',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFF8FAFC),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Không có khoản thu chi nào khớp với từ khóa hoặc bộ lọc hiện tại.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: resetFilters,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF38BDF8), Color(0xFF818CF8)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Đặt lại bộ lọc',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF080C14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          ...items.map(
            (txn) => TransactionRowTile(
              txn: txn,
              onTap: () => onSelectTransaction(txn),
            ),
          ),
      ],
    );
  }

  Widget _buildCategoryChip(
      FinanceProvider provider, String key, String label) {
    final isSelected = provider.categoryFilter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () => provider.setCategoryFilter(key),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF38BDF8).withOpacity(0.20)
                : const Color(0xFF131C2E).withOpacity(0.68),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF38BDF8).withOpacity(0.45)
                  : Colors.white.withOpacity(0.08),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected
                  ? const Color(0xFF38BDF8)
                  : const Color(0xFF94A3B8),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// MÀN HÌNH 4: THÊM / SỬA GIAO DỊCH (1:1 VỚI ADDEDITTRANSACTIONSCREEN.TSX)
// ============================================================================
class AddEditTransactionMobileScreen extends StatefulWidget {
  final TransactionModel? initialTxn;
  final VoidCallback onCancel;
  final ValueChanged<bool> onSaved;

  const AddEditTransactionMobileScreen({
    super.key,
    this.initialTxn,
    required this.onCancel,
    required this.onSaved,
  });

  @override
  State<AddEditTransactionMobileScreen> createState() =>
      _AddEditTransactionMobileScreenState();
}

class _AddEditTransactionMobileScreenState
    extends State<AddEditTransactionMobileScreen> {
  late TransactionType _type;
  late TextEditingController _amountCtrl;
  late TextEditingController _noteCtrl;
  late String _category;
  late String _date;
  String? _error;
  bool _isLoading = false;

  final List<Map<String, dynamic>> _quickPresets = const [
    {'label': '50k', 'val': 50000},
    {'label': '100k', 'val': 100000},
    {'label': '200k', 'val': 200000},
    {'label': '500k', 'val': 500000},
    {'label': '2Tr', 'val': 2000000},
    {'label': '10Tr', 'val': 10000000},
  ];

  @override
  void initState() {
    super.initState();
    final txn = widget.initialTxn;
    _type = txn?.type ?? TransactionType.expense;
    _amountCtrl = TextEditingController(
      text: txn != null ? txn.amount.round().toString() : '',
    );
    _noteCtrl = TextEditingController(text: txn?.note ?? '');
    _category = txn?.category ?? 'Food & Drink';
    _date = txn?.date ?? DateTime.now().toIso8601String().substring(0, 10);
  }

  void _handleTypeSwitch(TransactionType nextType) {
    setState(() {
      _type = nextType;
      if (nextType == TransactionType.income &&
          !kIncomeCategories.contains(_category)) {
        _category = 'Salary';
      } else if (nextType == TransactionType.expense &&
          !kExpenseCategories.contains(_category)) {
        _category = 'Food & Drink';
      }
    });
  }

  Future<void> _pickDate() async {
    final parts = _date.split('-').map(int.parse).toList();
    final current = DateTime(parts[0], parts[1], parts[2]);
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF38BDF8),
              surface: Color(0xFF131C2E),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _date = picked.toIso8601String().substring(0, 10);
      });
    }
  }

  Future<void> _save() async {
    final rawAmount =
        _amountCtrl.text.replaceAll('.', '').replaceAll(',', '').trim();
    final amount = double.tryParse(rawAmount);

    if (amount == null || amount <= 0) {
      setState(() => _error = 'Số tiền phải lớn hơn 0 ₫.');
      return;
    }

    setState(() {
      _error = null;
      _isLoading = true;
    });

    try {
      final provider = context.read<FinanceProvider>();
      final isNew = widget.initialTxn == null;
      await provider.saveTransaction(
        existingId: widget.initialTxn?.id,
        type: _type,
        amount: amount,
        category: _category,
        date: _date,
        note: _noteCtrl.text.trim(),
      );
      if (mounted) {
        widget.onSaved(isNew);
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initialTxn != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Header Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isEdit ? 'Chỉnh sửa giao dịch' : 'Thêm giao dịch',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                  color: Color(0xFFF8FAFC),
                ),
              ),
              InkWell(
                onTap: widget.onCancel,
                borderRadius: BorderRadius.circular(12),
                child: GlassTier2Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: const Text(
                    'Hủy',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (isEdit && widget.initialTxn != null) ...[
            const SizedBox(height: 2),
            Text(
              'Mã #${widget.initialTxn!.id}',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                color: const Color(0xFF94A3B8),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Glass Form Container (Tier 1)
          GlassTier1Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type Switcher
                GlassTier2Container(
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      // Thu nhập
                      Expanded(
                        child: InkWell(
                          onTap: () =>
                              _handleTypeSwitch(TransactionType.income),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            height: 38,
                            decoration: BoxDecoration(
                              color: _type == TransactionType.income
                                  ? const Color(0xFF34D399).withOpacity(0.20)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _type == TransactionType.income
                                    ? const Color(0xFF34D399).withOpacity(0.50)
                                    : Colors.transparent,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'Thu nhập',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: _type == TransactionType.income
                                      ? const Color(0xFF34D399)
                                      : const Color(0xFF94A3B8),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Chi tiêu
                      Expanded(
                        child: InkWell(
                          onTap: () =>
                              _handleTypeSwitch(TransactionType.expense),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            height: 38,
                            decoration: BoxDecoration(
                              color: _type == TransactionType.expense
                                  ? const Color(0xFFFB7185).withOpacity(0.20)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _type == TransactionType.expense
                                    ? const Color(0xFFFB7185).withOpacity(0.50)
                                    : Colors.transparent,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'Chi tiêu',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: _type == TransactionType.expense
                                      ? const Color(0xFFFB7185)
                                      : const Color(0xFF94A3B8),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Amount Input Field
                const Text(
                  'SỐ TIỀN (VNĐ) *',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 6),
                GlassTier2Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _amountCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFF8FAFC),
                          ),
                          decoration: const InputDecoration(
                            hintText: '0',
                            hintStyle: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 24,
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      Text(
                        '₫',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _type == TransactionType.income
                              ? const Color(0xFF34D399)
                              : const Color(0xFFFB7185),
                        ),
                      ),
                    ],
                  ),
                ),

                // Quick VNĐ Denomination Chips (1:1 với AddEditTransactionScreen.tsx)
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _quickPresets.map((preset) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: InkWell(
                          onTap: () {
                            _amountCtrl.text = preset['val'].toString();
                            setState(() => _error = null);
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.10),
                              ),
                            ),
                            child: Text(
                              '+${preset['label']}',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 18),

                // Category Selector Grid (3 columns, 1:1 với AddEditTransactionScreen.tsx)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'DANH MỤC *',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    Text(
                      _type == TransactionType.income
                          ? 'Gợi ý thu nhập'
                          : 'Gợi ý chi tiêu',
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.8,
                  children: kAllCategories.map((cat) {
                    final isSelected = _category == cat;
                    final isIncomeCategory = kIncomeCategories.contains(cat);

                    return InkWell(
                      onTap: () => setState(() => _category = cat),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (_type == TransactionType.income
                                  ? const Color(0xFF34D399).withOpacity(0.20)
                                  : const Color(0xFFFB7185).withOpacity(0.20))
                              : const Color(0xFF131C2E).withOpacity(0.68),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? (_type == TransactionType.income
                                    ? const Color(0xFF34D399).withOpacity(0.60)
                                    : const Color(0xFFFB7185).withOpacity(0.60))
                                : Colors.white.withOpacity(0.08),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CategoryIconBadgeWidget(
                              category: cat,
                              type: isIncomeCategory
                                  ? TransactionType.income
                                  : TransactionType.expense,
                              size: 26,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              kCategoryLabelsVi[cat] ?? cat,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? (_type == TransactionType.income
                                        ? const Color(0xFF34D399)
                                        : const Color(0xFFFB7185))
                                    : const Color(0xFFF8FAFC),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 18),

                // Transaction Date Picker
                const Text(
                  'NGÀY GIAO DỊCH *',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(16),
                  child: GlassTier2Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              LucideIcons.calendar,
                              size: 16,
                              color: Color(0xFF94A3B8),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _date,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 13,
                                color: const Color(0xFFF8FAFC),
                              ),
                            ),
                          ],
                        ),
                        const Icon(
                          LucideIcons.chevron_right,
                          size: 16,
                          color: Color(0xFF94A3B8),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // Note Input Field
                const Text(
                  'GHI CHÚ (TÙY CHỌN)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 6),
                GlassTier2Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Icon(
                          LucideIcons.file_text,
                          size: 16,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _noteCtrl,
                          maxLines: 2,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFFF8FAFC),
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Nhập ghi chú (ví dụ: Ăn trưa tại trường)...',
                            hintStyle: TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF64748B),
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF43F5E).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFF43F5E).withOpacity(0.40),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          LucideIcons.circle_alert,
                          size: 16,
                          color: Color(0xFFF43F5E),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              color: Color(0xFFFB7185),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                PrimaryGradientButton(
                  onPressed: _isLoading ? null : _save,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF080C14),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              LucideIcons.check,
                              size: 16,
                              color: Color(0xFF080C14),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isEdit ? 'Cập nhật giao dịch' : 'Lưu giao dịch',
                              style: const TextStyle(
                                color: Color(0xFF080C14),
                                fontWeight: FontWeight.bold,
                                fontSize: 14.5,
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

// ============================================================================
// MÀN HÌNH 5: CHI TIẾT GIAO DỊCH (1:1 VỚI TRANSACTIONDETAILSCREEN.TSX)
// ============================================================================
class TransactionDetailMobileScreen extends StatefulWidget {
  final TransactionModel txn;
  final VoidCallback onBack;
  final VoidCallback onEdit;
  final VoidCallback onDeleted;

  const TransactionDetailMobileScreen({
    super.key,
    required this.txn,
    required this.onBack,
    required this.onEdit,
    required this.onDeleted,
  });

  @override
  State<TransactionDetailMobileScreen> createState() =>
      _TransactionDetailMobileScreenState();
}

class _TransactionDetailMobileScreenState
    extends State<TransactionDetailMobileScreen> {
  bool _showDeleteDialog = false;
  bool _isDeleting = false;
  String? _deleteError;

  Future<void> _handleDelete() async {
    setState(() {
      _isDeleting = true;
      _deleteError = null;
    });
    try {
      await context
          .read<FinanceProvider>()
          .deleteTransaction(widget.txn.id);
      if (mounted) {
        widget.onDeleted();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _deleteError = e.toString().replaceFirst('Exception: ', '');
          _isDeleting = false;
          _showDeleteDialog = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final txn = widget.txn;
    final isIncome = txn.type == TransactionType.income;
    final categoryVi = kCategoryLabelsVi[txn.category] ?? txn.category;
    final typeVi = isIncome ? 'Thu nhập' : 'Chi tiêu';

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // Top Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: widget.onBack,
                  borderRadius: BorderRadius.circular(12),
                  child: GlassTier2Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.chevron_left,
                          size: 16,
                          color: Color(0xFF38BDF8),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Quay lại',
                          style: TextStyle(
                            color: Color(0xFFF8FAFC),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Text(
                  'Chi tiết giao dịch',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                    color: Color(0xFFF8FAFC),
                  ),
                ),
                const SizedBox(width: 80),
              ],
            ),

            const SizedBox(height: 16),

            // Hero Card (Tier 1 Frosted Glass — 1:1 với TransactionDetailScreen.tsx)
            GlassTier1Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Top Hero Section inside Card
                  Container(
                    padding: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.white.withOpacity(0.08),
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        CategoryIconBadgeWidget(
                          category: txn.category,
                          type: txn.type,
                          size: 56,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${typeVi.toUpperCase()} · $categoryVi',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          formatCurrencyVnd(txn.amount, txn.type),
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                            color: isIncome
                                ? const Color(0xFF34D399)
                                : const Color(0xFFFB7185),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Structured Metadata Rows (1:1 với dl/dt/dd trong Web)
                  const SizedBox(height: 6),
                  _buildMetaRow('Mã giao dịch', '#${txn.id}', isMono: true),
                  _buildDivider(),
                  _buildMetaRow(
                    'Loại giao dịch',
                    typeVi,
                    customColor: isIncome
                        ? const Color(0xFF34D399)
                        : const Color(0xFFFB7185),
                  ),
                  _buildDivider(),
                  _buildMetaRowWithIcon(
                    'Danh mục',
                    categoryVi,
                    getLucideCategoryIcon(txn.category),
                  ),
                  _buildDivider(),
                  _buildMetaRow(
                    'Ngày giao dịch',
                    formatLongDate(txn.date),
                    isMono: true,
                  ),
                  _buildDivider(),
                  _buildMetaRow(
                    'Tài khoản',
                    txn.ownerEmail,
                    isMono: true,
                    customColor: const Color(0xFF38BDF8),
                  ),
                  _buildDivider(),
                  _buildMetaRow(
                    'Ghi chú',
                    txn.note.isEmpty ? 'Không có ghi chú bổ sung' : txn.note,
                    isItalic: txn.note.isEmpty,
                  ),
                ],
              ),
            ),

            if (_deleteError != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF43F5E).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFF43F5E).withOpacity(0.40),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.circle_alert,
                      size: 16,
                      color: Color(0xFFF43F5E),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _deleteError!,
                        style: const TextStyle(
                          color: Color(0xFFFB7185),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Action Buttons Bar
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: widget.onEdit,
                    borderRadius: BorderRadius.circular(16),
                    child: GlassTier2Container(
                      height: 48,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            LucideIcons.pencil,
                            size: 16,
                            color: Color(0xFF38BDF8),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Chỉnh sửa',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFF8FAFC),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _showDeleteDialog = true),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFB7185).withOpacity(0.14),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFFB7185).withOpacity(0.35),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            LucideIcons.trash,
                            size: 16,
                            color: Color(0xFFFB7185),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Xóa',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFB7185),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 80),
          ],
        ),

        // Tier 1 Glass Delete Confirmation Dialog (1:1 với TransactionDetailScreen.tsx)
        if (_showDeleteDialog)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.80),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Center(
                child: GlassTier1Container(
                  borderRadius: 24,
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFB7185).withOpacity(0.20),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFFB7185).withOpacity(0.40),
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            LucideIcons.triangle_alert,
                            size: 24,
                            color: Color(0xFFFB7185),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Xóa giao dịch này?',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFF8FAFC),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Bạn có chắc chắn muốn xóa vĩnh viễn giao dịch này? Số dư tài khoản sẽ được tính toán lại ngay lập tức.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF94A3B8),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () =>
                                  setState(() => _showDeleteDialog = false),
                              borderRadius: BorderRadius.circular(12),
                              child: GlassTier2Container(
                                height: 44,
                                child: const Center(
                                  child: Text(
                                    'Hủy',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFF8FAFC),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: InkWell(
                              onTap: _isDeleting ? null : _handleDelete,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF43F5E),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: _isDeleting
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          'Xác nhận xóa',
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMetaRow(String label, String value,
      {bool isMono = false, Color? customColor, bool isItalic = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: isMono
                  ? GoogleFonts.jetBrainsMono(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: customColor ?? const Color(0xFFF8FAFC),
                      fontStyle:
                          isItalic ? FontStyle.italic : FontStyle.normal,
                    )
                  : TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: customColor ?? const Color(0xFFF8FAFC),
                      fontStyle:
                          isItalic ? FontStyle.italic : FontStyle.normal,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaRowWithIcon(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF94A3B8),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: const Color(0xFF38BDF8)),
              const SizedBox(width: 6),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFF8FAFC),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.white.withOpacity(0.07),
    );
  }
}
