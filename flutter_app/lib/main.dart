import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

String formatCurrencyVnd(double amount, [TransactionType? type]) {
  final absVal = amount.abs().round().toString();
  final buffer = StringBuffer();
  for (int i = 0; i < absVal.length; i++) {
    if (i > 0 && (absVal.length - i) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(absVal[i]);
  }
  final formatted = '${buffer.toString()} ₫';
  if (type == TransactionType.income) return '+$formatted';
  if (type == TransactionType.expense) return '-$formatted';
  if (amount < 0) return '-$formatted';
  return formatted;
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

  UserAccount? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null && _authToken != null;
  List<TransactionModel> get transactions => _transactions;
  String get searchQuery => _searchQuery;
  String get typeFilter => _typeFilter;
  String get categoryFilter => _categoryFilter;

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
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kSessionKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        _authToken = decoded['auth_token'] as String?;
        _currentUser = UserAccount.fromJson(
            decoded['current_user'] as Map<String, dynamic>);
        await syncTransactions();
      } catch (_) {
        await prefs.remove(kSessionKey);
      }
    }
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final cleanEmail = email.trim().toLowerCase();
    if (!cleanEmail.contains('@')) {
      throw Exception('Địa chỉ email không hợp lệ.');
    }
    if (password.length < 6) {
      throw Exception('Mật khẩu phải có ít nhất 6 ký tự.');
    }

    // Thử kết nối tới backend Node.js + SQLite REST API
    try {
      final res = await http
          .post(
            Uri.parse('$kApiBaseUrl/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': cleanEmail, 'password': password}),
          )
          .timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        _authToken = data['auth_token'] as String;
        _currentUser =
            UserAccount.fromJson(data['current_user'] as Map<String, dynamic>);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(kSessionKey, jsonEncode(data));
        await syncTransactions();
        notifyListeners();
        return;
      }
    } catch (_) {
      // Fallback sang xác thực SQLite trên máy độc lập khi không có server
    }

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
    await syncTransactions();
    notifyListeners();
  }

  Future<void> quickSwitchUser(String targetEmail) async {
    await login(targetEmail, '123456');
  }

  Future<void> syncTransactions() async {
    if (_currentUser == null) return;
    try {
      final res = await http
          .get(Uri.parse('$kApiBaseUrl/transactions?userId=${_currentUser!.id}'))
          .timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        _transactions = list
            .map((item) =>
                TransactionModel.fromJson(item as Map<String, dynamic>))
            .toList();
        for (final t in _transactions) {
          await LocalSqliteHelper.upsertTransaction(t);
        }
        notifyListeners();
        return;
      }
    } catch (_) {
      // Fallback sang SQLite trên thiết bị
    }
    _transactions =
        await LocalSqliteHelper.getTransactionsByUser(_currentUser!.id);
    notifyListeners();
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
    await syncTransactions();
  }

  Future<void> deleteTransaction(String id) async {
    if (_currentUser == null) return;
    await LocalSqliteHelper.deleteTransaction(id, _currentUser!.id);
    await syncTransactions();
  }

  Future<void> resetDemoData() async {
    await LocalSqliteHelper.resetToSeedData();
    await syncTransactions();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kSessionKey);
    _authToken = null;
    _currentUser = null;
    _transactions = [];
    notifyListeners();
  }
}

// ============================================================================
// LIQUID GLASSMORPHISM STYLING & AMBIENT CANVAS (1:1 VỚI LOCALHOST:3000)
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
          // Quả cầu phát quang ngọc lục bảo (Top-Left)
          Positioned(
            top: -60,
            left: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0x3310B981),
                    Color(0x0010B981),
                  ],
                ),
              ),
            ),
          ),
          // Quả cầu phát quang tím chàm (Middle-Right)
          Positioned(
            top: 260,
            right: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0x2B6366F1),
                    Color(0x006366F1),
                  ],
                ),
              ),
            ),
          ),
          // Quả cầu phát quang xanh dương nhạt (Bottom-Left)
          Positioned(
            bottom: 40,
            left: -60,
            child: Container(
              width: 240,
              height: 240,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0x240EA5E9),
                    Color(0x000EA5E9),
                  ],
                ),
              ),
            ),
          ),
          // Nội dung hiển thị chính
          child,
        ],
      ),
    );
  }
}

/// Thẻ Frosted Glass Cấp 1 (Dành cho Balance Hero Card, Bottom Nav, Detail Card)
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
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
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

/// Thẻ Bề mặt Kính Bán trong suốt Cấp 2 (Hàng giao dịch, Ô tìm kiếm, Input)
class GlassTier2Container extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Border? border;
  final Color? customBgColor;

  const GlassTier2Container({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 16.0,
    this.border,
    this.customBgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: customBgColor ?? const Color(0xFF131C2E).withOpacity(0.72),
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

/// Nút bấm Gradient màu chính (`#38BDF8` -> `#818CF8`)
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

/// Huy hiệu Biểu tượng Danh mục 1:1 chuẩn thiết kế CategoryIconBadge.tsx
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

  IconData _getIcon(String cat) {
    switch (cat) {
      case 'Salary':
        return Icons.work_outline_rounded;
      case 'Freelance':
        return Icons.laptop_mac_rounded;
      case 'Investment':
        return Icons.trending_up_rounded;
      case 'Food & Drink':
        return Icons.restaurant_rounded;
      case 'Transport':
        return Icons.directions_car_rounded;
      case 'Shopping':
        return Icons.shopping_bag_outlined;
      case 'Study':
        return Icons.school_outlined;
      case 'Bills':
        return Icons.receipt_long_outlined;
      case 'Entertainment':
        return Icons.movie_outlined;
      default:
        return Icons.account_balance_wallet_outlined;
    }
  }

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
          _getIcon(category),
          size: size * 0.48,
          color: color,
        ),
      ),
    );
  }
}

// ============================================================================
// GIAO DIỆN CHÍNH (THEME & SHELL ĐỒNG BỘ CHUẨN IOS)
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
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    if (!provider.isAuthenticated) {
      return const LoginMobileScreen();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF080C14),
      body: AmbientLightingCanvas(
        child: SafeArea(
          top: true,
          bottom: false,
          child: IndexedStack(
            index: _tabIndex,
            children: [
              HomeDashboardMobileScreen(
                onSeeAll: () => setState(() => _tabIndex = 1),
                onAddTransaction: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AddEditTransactionMobileScreen(),
                    ),
                  );
                },
              ),
              const TransactionListMobileScreen(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        bottom: true,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: GlassTier1Container(
            borderRadius: 24,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Tab Tổng quan
                InkWell(
                  onTap: () => setState(() => _tabIndex = 0),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.home_rounded,
                          size: 22,
                          color: _tabIndex == 0
                              ? const Color(0xFF38BDF8)
                              : const Color(0xFF94A3B8),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tổng quan',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _tabIndex == 0
                                ? const Color(0xFF38BDF8)
                                : const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Nút Thêm giao dịch FAB nổi (`+`) với Gradient
                Transform.translate(
                  offset: const Offset(0, -14),
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF38BDF8), Color(0xFF818CF8)],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFF080C14),
                        width: 3,
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
                        borderRadius: BorderRadius.circular(18),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  const AddEditTransactionMobileScreen(),
                            ),
                          );
                        },
                        child: const Center(
                          child: Icon(
                            Icons.add,
                            color: Color(0xFF080C14),
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Tab Sổ giao dịch
                InkWell(
                  onTap: () => setState(() => _tabIndex = 1),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.format_list_bulleted_rounded,
                          size: 22,
                          color: _tabIndex == 1
                              ? const Color(0xFF38BDF8)
                              : const Color(0xFF94A3B8),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Sổ giao dịch',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _tabIndex == 1
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
      ),
    );
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
                      // Top Brand Header
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
                                Icons.auto_awesome_rounded,
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
                              child: TextField(
                                controller: _emailCtrl,
                                style: const TextStyle(
                                  color: Color(0xFFF8FAFC),
                                  fontSize: 14,
                                ),
                                decoration: const InputDecoration(
                                  icon: Icon(
                                    Icons.mail_outline_rounded,
                                    size: 18,
                                    color: Color(0xFF94A3B8),
                                  ),
                                  hintText: 'Nhập địa chỉ email...',
                                  hintStyle: TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 14,
                                  ),
                                  border: InputBorder.none,
                                ),
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
                              child: TextField(
                                controller: _passCtrl,
                                obscureText: !_showPass,
                                style: GoogleFonts.jetBrainsMono(
                                  color: const Color(0xFFF8FAFC),
                                  fontSize: 14,
                                ),
                                decoration: InputDecoration(
                                  icon: const Icon(
                                    Icons.lock_outline_rounded,
                                    size: 18,
                                    color: Color(0xFF94A3B8),
                                  ),
                                  hintText: 'Nhập mật khẩu...',
                                  hintStyle: GoogleFonts.jetBrainsMono(
                                    color: const Color(0xFF64748B),
                                    fontSize: 14,
                                  ),
                                  border: InputBorder.none,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _showPass
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      size: 18,
                                      color: const Color(0xFF94A3B8),
                                    ),
                                    onPressed: () =>
                                        setState(() => _showPass = !_showPass),
                                  ),
                                ),
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
                                      Icons.error_outline_rounded,
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
                                          Icons.arrow_forward_rounded,
                                          size: 18,
                                          color: Color(0xFF080C14),
                                        ),
                                      ],
                                    ),
                            ),
                          ],
                        ),
                      ),

                      // Quick Demo Accounts Section
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
                          // User 1
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
                                        Icons.how_to_reg_rounded,
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
                          // User 2
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
                                        Icons.how_to_reg_rounded,
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
  final VoidCallback onAddTransaction;

  const HomeDashboardMobileScreen({
    super.key,
    required this.onSeeAll,
    required this.onAddTransaction,
  });

  @override
  State<HomeDashboardMobileScreen> createState() =>
      _HomeDashboardMobileScreenState();
}

class _HomeDashboardMobileScreenState extends State<HomeDashboardMobileScreen> {
  bool _showAccountMenu = false;

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length == 1) return parts[0].substring(0, min(2, parts[0].length)).toUpperCase();
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
                      Icons.people_outline_rounded,
                      size: 18,
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
                          Icons.logout_rounded,
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

        // Collapsible Account Switcher & Reset Drawer
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
                            Icons.refresh_rounded,
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
                                      Icons.check_rounded,
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
                                      Icons.check_rounded,
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
                                Icons.arrow_downward_rounded,
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
                                Icons.arrow_upward_rounded,
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
                      Icons.chevron_right_rounded,
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
                  onPressed: widget.onAddTransaction,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 16, color: Color(0xFF080C14)),
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
          ...recentItems.map((txn) => TransactionRowTile(txn: txn)),
      ],
    );
  }
}

// ============================================================================
// HÀNG GIAO DỊCH CHUẨN KÍNH TIER 2
// ============================================================================
class TransactionRowTile extends StatelessWidget {
  final TransactionModel txn;
  const TransactionRowTile({super.key, required this.txn});

  @override
  Widget build(BuildContext context) {
    final isIncome = txn.type == TransactionType.income;
    final categoryVi = kCategoryLabelsVi[txn.category] ?? txn.category;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TransactionDetailMobileScreen(txn: txn),
            ),
          );
        },
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
                    Icons.chevron_right_rounded,
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
  const TransactionListMobileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final items = provider.filteredTransactions;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        const Text(
          'Sổ giao dịch',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFFF8FAFC),
          ),
        ),
        const SizedBox(height: 12),

        // Search Bar
        GlassTier2Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: TextField(
            onChanged: provider.setSearchQuery,
            style: const TextStyle(color: Color(0xFFF8FAFC), fontSize: 14),
            decoration: InputDecoration(
              icon: const Icon(
                Icons.search_rounded,
                size: 20,
                color: Color(0xFF94A3B8),
              ),
              hintText: 'Tìm theo ghi chú hoặc danh mục...',
              hintStyle: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 14,
              ),
              border: InputBorder.none,
              suffixIcon: provider.searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () => provider.setSearchQuery(''),
                    )
                  : null,
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Type Filter Chips ("Tất cả", "Thu nhập", "Chi tiêu")
        Row(
          children: [
            for (final entry in [
              {'val': 'All', 'label': 'Tất cả'},
              {'val': 'Income', 'label': 'Thu nhập'},
              {'val': 'Expense', 'label': 'Chi tiêu'},
            ])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: InkWell(
                    onTap: () => provider.setTypeFilter(entry['val']!),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: provider.typeFilter == entry['val']
                            ? const LinearGradient(
                                colors: [Color(0xFF38BDF8), Color(0xFF818CF8)],
                              )
                            : null,
                        color: provider.typeFilter != entry['val']
                            ? const Color(0xFF131C2E).withOpacity(0.72)
                            : null,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: provider.typeFilter == entry['val']
                              ? Colors.transparent
                              : Colors.white.withOpacity(0.08),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          entry['label']!,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: provider.typeFilter == entry['val']
                                ? const Color(0xFF080C14)
                                : const Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 12),

        // Category Filter Chips
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

        const SizedBox(height: 16),

        // List View
        if (items.isEmpty)
          GlassTier2Container(
            padding: const EdgeInsets.all(32),
            child: const Center(
              child: Text(
                'Không tìm thấy giao dịch nào phù hợp.',
                style: TextStyle(color: Color(0xFF94A3B8)),
              ),
            ),
          )
        else
          ...items.map((txn) => TransactionRowTile(txn: txn)),
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
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF38BDF8).withOpacity(0.20)
                : const Color(0xFF131C2E).withOpacity(0.60),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF38BDF8).withOpacity(0.60)
                  : Colors.white.withOpacity(0.06),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
  const AddEditTransactionMobileScreen({super.key, this.initialTxn});

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
      await provider.saveTransaction(
        existingId: widget.initialTxn?.id,
        type: _type,
        amount: amount,
        category: _category,
        date: _date,
        note: _noteCtrl.text.trim(),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initialTxn != null;

    return Scaffold(
      backgroundColor: const Color(0xFF080C14),
      body: AmbientLightingCanvas(
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Row(
                          children: [
                            Icon(Icons.chevron_left_rounded,
                                color: Color(0xFF38BDF8), size: 24),
                            Text(
                              'Hủy',
                              style: TextStyle(
                                color: Color(0xFF38BDF8),
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Text(
                      isEdit ? 'Chỉnh sửa giao dịch' : 'Thêm giao dịch mới',
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFF8FAFC),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              // Form Body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Segmented Type Selector (Thu nhập / Chi tiêu)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF131C2E).withOpacity(0.80),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() {
                                  _type = TransactionType.income;
                                  if (!['Salary', 'Freelance', 'Investment']
                                      .contains(_category)) {
                                    _category = 'Salary';
                                  }
                                }),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: _type == TransactionType.income
                                        ? const Color(0xFF34D399)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Thu nhập',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.bold,
                                        color: _type == TransactionType.income
                                            ? const Color(0xFF080C14)
                                            : const Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() {
                                  _type = TransactionType.expense;
                                  if (['Salary', 'Freelance', 'Investment']
                                      .contains(_category)) {
                                    _category = 'Food & Drink';
                                  }
                                }),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: _type == TransactionType.expense
                                        ? const Color(0xFFFB7185)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Chi tiêu',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.bold,
                                        color: _type == TransactionType.expense
                                            ? const Color(0xFF080C14)
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

                      const SizedBox(height: 20),

                      // Amount Input
                      const Text(
                        'Số tiền (VNĐ) *',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 6),
                      GlassTier2Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: TextField(
                          controller: _amountCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _type == TransactionType.income
                                ? const Color(0xFF34D399)
                                : const Color(0xFFFB7185),
                          ),
                          decoration: InputDecoration(
                            suffixText: '₫',
                            suffixStyle: GoogleFonts.jetBrainsMono(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF94A3B8),
                            ),
                            hintText: '0',
                            hintStyle: GoogleFonts.jetBrainsMono(
                              fontSize: 18,
                              color: const Color(0xFF64748B),
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Category Grid / Selector
                      const Text(
                        'Danh mục giao dịch *',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: kCategoryLabelsVi.entries.map((entry) {
                          final isSelected = _category == entry.key;
                          return InkWell(
                            onTap: () => setState(() => _category = entry.key),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF38BDF8).withOpacity(0.20)
                                    : const Color(0xFF131C2E).withOpacity(0.60),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF38BDF8).withOpacity(0.60)
                                      : Colors.white.withOpacity(0.08),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CategoryIconBadgeWidget(
                                    category: entry.key,
                                    type: _type,
                                    size: 26,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    entry.value,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isSelected
                                          ? const Color(0xFF38BDF8)
                                          : const Color(0xFFF8FAFC),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 20),

                      // Date Picker Field
                      const Text(
                        'Ngày giao dịch (YYYY-MM-DD) *',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(16),
                        child: GlassTier2Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _date,
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 14,
                                  color: const Color(0xFFF8FAFC),
                                ),
                              ),
                              const Icon(
                                Icons.calendar_today_rounded,
                                size: 18,
                                color: Color(0xFF38BDF8),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Note Input
                      const Text(
                        'Ghi chú / Mô tả',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 6),
                      GlassTier2Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: TextField(
                          controller: _noteCtrl,
                          style: const TextStyle(
                            color: Color(0xFFF8FAFC),
                            fontSize: 14,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Nhập mô tả giao dịch...',
                            hintStyle: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                      ),

                      if (_error != null) ...[
                        const SizedBox(height: 16),
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
                                Icons.error_outline_rounded,
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

                      const SizedBox(height: 28),

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
                            : Text(
                                isEdit ? 'Cập nhật giao dịch' : 'Lưu giao dịch',
                                style: const TextStyle(
                                  color: Color(0xFF080C14),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
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
      ),
    );
  }
}

// ============================================================================
// MÀN HÌNH 5: CHI TIẾT GIAO DỊCH (1:1 VỚI TRANSACTIONDETAILSCREEN.TSX)
// ============================================================================
class TransactionDetailMobileScreen extends StatelessWidget {
  final TransactionModel txn;
  const TransactionDetailMobileScreen({super.key, required this.txn});

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131C2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Xác nhận xóa giao dịch?',
          style: TextStyle(color: Color(0xFFF8FAFC), fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Hành động này sẽ xóa vĩnh viễn giao dịch này khỏi hệ thống và cập nhật lại số dư của bạn.',
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFB7185),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xóa ngay'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<FinanceProvider>().deleteTransaction(txn.id);
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIncome = txn.type == TransactionType.income;
    final categoryVi = kCategoryLabelsVi[txn.category] ?? txn.category;

    return Scaffold(
      backgroundColor: const Color(0xFF080C14),
      body: AmbientLightingCanvas(
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Row(
                          children: [
                            Icon(Icons.chevron_left_rounded,
                                color: Color(0xFF38BDF8), size: 24),
                            Text(
                              'Quay lại',
                              style: TextStyle(
                                color: Color(0xFF38BDF8),
                                fontSize: 15,
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
                        fontSize: 16.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFF8FAFC),
                      ),
                    ),
                    const SizedBox(width: 72),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Hero Glass Card
                      GlassTier1Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 28),
                        child: Center(
                          child: Column(
                            children: [
                              CategoryIconBadgeWidget(
                                category: txn.category,
                                type: txn.type,
                                size: 64,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                formatCurrencyVnd(txn.amount, txn.type),
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.5,
                                  color: isIncome
                                      ? const Color(0xFF34D399)
                                      : const Color(0xFFFB7185),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isIncome
                                      ? const Color(0xFF34D399).withOpacity(0.15)
                                      : const Color(0xFFFB7185).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isIncome
                                        ? const Color(0xFF34D399).withOpacity(0.35)
                                        : const Color(0xFFFB7185).withOpacity(0.35),
                                  ),
                                ),
                                child: Text(
                                  isIncome ? 'Thu nhập' : 'Chi tiêu',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isIncome
                                        ? const Color(0xFF34D399)
                                        : const Color(0xFFFB7185),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Info Details List
                      GlassTier2Container(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _buildInfoRow('Danh mục', categoryVi),
                            const Divider(color: Colors.white12, height: 24),
                            _buildInfoRow('Ngày giao dịch', txn.date,
                                isMono: true),
                            const Divider(color: Colors.white12, height: 24),
                            _buildInfoRow('Ghi chú',
                                txn.note.isEmpty ? 'Không có ghi chú' : txn.note),
                            const Divider(color: Colors.white12, height: 24),
                            _buildInfoRow('Mã giao dịch', txn.id, isMono: true),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Action Buttons (Chỉnh sửa / Xóa)
                      Row(
                        children: [
                          Expanded(
                            child: PrimaryGradientButton(
                              onPressed: () {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (_) => AddEditTransactionMobileScreen(
                                      initialTxn: txn,
                                    ),
                                  ),
                                );
                              },
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.edit_outlined,
                                      size: 16, color: Color(0xFF080C14)),
                                  SizedBox(width: 6),
                                  Text(
                                    'Chỉnh sửa',
                                    style: TextStyle(
                                      color: Color(0xFF080C14),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () => _confirmDelete(context),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  color:
                                      const Color(0xFFFB7185).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFFFB7185)
                                        .withOpacity(0.35),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.delete_outline_rounded,
                                        size: 18, color: Color(0xFFFB7185)),
                                    SizedBox(width: 6),
                                    Text(
                                      'Xóa giao dịch',
                                      style: TextStyle(
                                        color: Color(0xFFFB7185),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isMono = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: isMono
                ? GoogleFonts.jetBrainsMono(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFF8FAFC),
                  )
                : const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFF8FAFC),
                  ),
          ),
        ),
      ],
    );
  }
}
