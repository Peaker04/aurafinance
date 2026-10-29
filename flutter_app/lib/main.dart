import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
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
    date: '2026-10-25',
    note: 'Lương thực tập phần mềm tháng 10',
  ),
  TransactionModel(
    id: 'TXN-102',
    userId: 'usr_01',
    ownerEmail: 'user1@fpt.edu.vn',
    type: TransactionType.income,
    amount: 4500000,
    category: 'Freelance',
    date: '2026-10-26',
    note: 'Thiết kế giao diện ứng dụng di động',
  ),
  TransactionModel(
    id: 'TXN-103',
    userId: 'usr_01',
    ownerEmail: 'user1@fpt.edu.vn',
    type: TransactionType.expense,
    amount: 85000,
    category: 'Food & Drink',
    date: '2026-10-26',
    note: 'Cà phê sáng và bánh mì tại trường',
  ),
  TransactionModel(
    id: 'TXN-104',
    userId: 'usr_01',
    ownerEmail: 'user1@fpt.edu.vn',
    type: TransactionType.expense,
    amount: 450000,
    category: 'Study',
    date: '2026-10-27',
    note: 'Giáo trình lập trình Flutter & Mobile',
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
    amount: 5000000,
    category: 'Salary',
    date: '2026-10-24',
    note: 'Trợ cấp nghiên cứu khoa học tại trường',
  ),
  TransactionModel(
    id: 'TXN-202',
    userId: 'usr_02',
    ownerEmail: 'user2@fpt.edu.vn',
    type: TransactionType.expense,
    amount: 550000,
    category: 'Shopping',
    date: '2026-10-25',
    note: 'Chuột không dây phục vụ học tập',
  ),
  TransactionModel(
    id: 'TXN-203',
    userId: 'usr_02',
    ownerEmail: 'user2@fpt.edu.vn',
    type: TransactionType.expense,
    amount: 320000,
    category: 'Bills',
    date: '2026-10-26',
    note: 'Cước Internet cáp quang tháng 10',
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
// LOCAL SQLITE DATABASE HELPER + NODE.JS REST API SYNC + SHARED_PREFERENCES
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
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _authToken = decoded['auth_token'] as String?;
      _currentUser = UserAccount.fromJson(
          decoded['current_user'] as Map<String, dynamic>);
      await syncTransactions();
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
      // Fallback sang xác thực cục bộ khi chạy độc lập trên điện thoại
    }

    final matched = kSeedUsers.where((u) => u.email == cleanEmail).toList();
    if (matched.isEmpty || password != '123456') {
      throw Exception('Email hoặc mật khẩu không chính xác.');
    }

    _currentUser = matched.first;
    _authToken = 'local_sqlite_token_${_currentUser!.id}';
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
      // Fallback sang SQLite trên máy
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
    final id =
        existingId ?? 'TXN-${10000 + Random().nextInt(89999)}';
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
// MOBILE UI SHELL WITH MANDATORY iOS SAFEAREA
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
      body: SafeArea(
        top: true,
        bottom: true,
        child: _tabIndex == 0
            ? HomeDashboardMobileScreen(
                onSeeAll: () => setState(() => _tabIndex = 1),
              )
            : const TransactionListMobileScreen(),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF38BDF8),
        foregroundColor: const Color(0xFF080C14),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const AddEditTransactionMobileScreen(),
            ),
          );
        },
        child: const Icon(Icons.add, size: 28),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        bottom: true,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF131C2E).withOpacity(0.88),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.16)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: () => setState(() => _tabIndex = 0),
                icon: Icon(
                  Icons.home_rounded,
                  color: _tabIndex == 0
                      ? const Color(0xFF38BDF8)
                      : const Color(0xFF94A3B8),
                ),
                label: Text(
                  'Tổng quan',
                  style: TextStyle(
                    color: _tabIndex == 0
                        ? const Color(0xFF38BDF8)
                        : const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 48),
              TextButton.icon(
                onPressed: () => setState(() => _tabIndex = 1),
                icon: Icon(
                  Icons.filter_list_rounded,
                  color: _tabIndex == 1
                      ? const Color(0xFF38BDF8)
                      : const Color(0xFF94A3B8),
                ),
                label: Text(
                  'Sổ giao dịch',
                  style: TextStyle(
                    color: _tabIndex == 1
                        ? const Color(0xFF38BDF8)
                        : const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w600,
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
// SCREEN 1: LOGIN SCREEN (WITH iOS SAFEAREA)
// ============================================================================
class LoginMobileScreen extends StatefulWidget {
  const LoginMobileScreen({super.key});

  @override
  State<LoginMobileScreen> createState() => _LoginMobileScreenState();
}

class _LoginMobileScreenState extends State<LoginMobileScreen> {
  final _emailCtrl = TextEditingController(text: 'user1@fpt.edu.vn');
  final _passCtrl = TextEditingController(text: '123456');
  String? _error;

  Future<void> _submit() async {
    setState(() => _error = null);
    try {
      await context
          .read<FinanceProvider>()
          .login(_emailCtrl.text, _passCtrl.text);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080C14),
      body: SafeArea(
        top: true,
        bottom: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'AuraFinance',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFF8FAFC),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Quản lý Tài chính Cá nhân Thông minh',
                style: TextStyle(color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Địa chỉ Email',
                  filled: true,
                  fillColor: Color(0xFF131C2E),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _passCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Mật khẩu',
                  filled: true,
                  fillColor: Color(0xFF131C2E),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(color: Color(0xFFFB7185)),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF38BDF8),
                    foregroundColor: const Color(0xFF080C14),
                  ),
                  onPressed: _submit,
                  child: const Text(
                    'Đăng nhập',
                    style: TextStyle(fontWeight: FontWeight.bold),
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
// SCREEN 2: HOME / DASHBOARD SCREEN (BALANCE = INCOME - EXPENSES IN VNĐ)
// ============================================================================
class HomeDashboardMobileScreen extends StatelessWidget {
  final VoidCallback onSeeAll;
  const HomeDashboardMobileScreen({super.key, required this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final user = provider.currentUser!;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Xin chào, ${user.name}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFF8FAFC),
                  ),
                ),
                Text(
                  user.email,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: () => provider.logout(),
              icon: const Icon(Icons.logout, size: 16, color: Color(0xFFFB7185)),
              label: const Text(
                'Đăng xuất',
                style: TextStyle(color: Color(0xFFFB7185)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF131C2E),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SỐ DƯ HIỆN TẠI (VNĐ)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                formatCurrencyVnd(provider.balance),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFF8FAFC),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Số dư = Tổng thu nhập − Tổng chi tiêu',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
              ),
              const Divider(height: 24, color: Colors.white12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tổng thu nhập',
                          style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                        ),
                        Text(
                          formatCurrencyVnd(
                              provider.totalIncome, TransactionType.income),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF34D399),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tổng chi tiêu',
                          style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                        ),
                        Text(
                          formatCurrencyVnd(
                              provider.totalExpenses, TransactionType.expense),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFB7185),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'GIAO DỊCH GẦN ĐÂY',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF94A3B8),
              ),
            ),
            TextButton(
              onPressed: onSeeAll,
              child: const Text('Xem tất cả'),
            ),
          ],
        ),
        ...provider.transactions.take(5).map(
              (txn) => TransactionRowTile(txn: txn),
            ),
      ],
    );
  }
}

// ============================================================================
// SCREEN 3: TRANSACTION LIST WITH SEARCH & FILTER
// ============================================================================
class TransactionListMobileScreen extends StatelessWidget {
  const TransactionListMobileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final items = provider.filteredTransactions;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
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
        TextField(
          onChanged: provider.setSearchQuery,
          decoration: const InputDecoration(
            hintText: 'Tìm theo ghi chú hoặc danh mục...',
            prefixIcon: Icon(Icons.search),
            filled: true,
            fillColor: Color(0xFF131C2E),
          ),
        ),
        const SizedBox(height: 12),
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
                  child: OutlinedButton(
                    onPressed: () => provider.setTypeFilter(entry['val']!),
                    child: Text(entry['label']!),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        ...items.map((txn) => TransactionRowTile(txn: txn)),
      ],
    );
  }
}

class TransactionRowTile extends StatelessWidget {
  final TransactionModel txn;
  const TransactionRowTile({super.key, required this.txn});

  @override
  Widget build(BuildContext context) {
    final isIncome = txn.type == TransactionType.income;
    final categoryVi = kCategoryLabelsVi[txn.category] ?? txn.category;

    return Card(
      color: const Color(0xFF131C2E),
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TransactionDetailMobileScreen(txn: txn),
            ),
          );
        },
        title: Text(
          categoryVi,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFFF8FAFC),
          ),
        ),
        subtitle: Text(
          '${txn.note.isEmpty ? "Không có ghi chú" : txn.note} • ${txn.date}',
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
        ),
        trailing: Text(
          formatCurrencyVnd(txn.amount, txn.type),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color:
                isIncome ? const Color(0xFF34D399) : const Color(0xFFFB7185),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// SCREEN 4: ADD / EDIT TRANSACTION SCREEN (WITH SAFEAREA & VALIDATION > 0 ₫)
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

  @override
  void initState() {
    super.initState();
    _type = widget.initialTxn?.type ?? TransactionType.expense;
    _amountCtrl = TextEditingController(
      text: widget.initialTxn != null
          ? widget.initialTxn!.amount.round().toString()
          : '',
    );
    _noteCtrl = TextEditingController(text: widget.initialTxn?.note ?? '');
    _category = widget.initialTxn?.category ?? 'Food & Drink';
    _date = widget.initialTxn?.date ?? '2026-10-28';
  }

  Future<void> _save() async {
    setState(() => _error = null);
    final parsed = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (parsed <= 0) {
      setState(() => _error = 'Số tiền phải lớn hơn 0 ₫.');
      return;
    }
    await context.read<FinanceProvider>().saveTransaction(
          existingId: widget.initialTxn?.id,
          type: _type,
          amount: parsed,
          category: _category,
          date: _date,
          note: _noteCtrl.text.trim(),
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080C14),
      body: SafeArea(
        top: true,
        bottom: true,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.initialTxn != null
                      ? 'Chỉnh sửa giao dịch'
                      : 'Thêm giao dịch',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Hủy'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Số tiền (VNĐ) *',
                suffixText: '₫',
                filled: true,
                fillColor: Color(0xFF131C2E),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _category,
              items: kCategoryLabelsVi.entries
                  .map(
                    (e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(e.value),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _category = v ?? 'Food & Drink'),
              decoration: const InputDecoration(
                labelText: 'Danh mục *',
                filled: true,
                fillColor: Color(0xFF131C2E),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Ghi chú (Tùy chọn)',
                filled: true,
                fillColor: Color(0xFF131C2E),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Color(0xFFFB7185))),
            ],
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _save,
                child: const Text('Lưu giao dịch'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// SCREEN 5: TRANSACTION DETAIL & DELETE CONFIRMATION DIALOG (WITH SAFEAREA)
// ============================================================================
class TransactionDetailMobileScreen extends StatelessWidget {
  final TransactionModel txn;
  const TransactionDetailMobileScreen({super.key, required this.txn});

  @override
  Widget build(BuildContext context) {
    final categoryVi = kCategoryLabelsVi[txn.category] ?? txn.category;

    return Scaffold(
      backgroundColor: const Color(0xFF080C14),
      body: SafeArea(
        top: true,
        bottom: true,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.chevron_left),
                        label: const Text('Quay lại'),
                      ),
                      const Text(
                        'Chi tiết giao dịch',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 72),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131C2E),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: [
                        Text(
                          categoryVi,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          formatCurrencyVnd(txn.amount, txn.type),
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: txn.type == TransactionType.income
                                ? const Color(0xFF34D399)
                                : const Color(0xFFFB7185),
                          ),
                        ),
                        const Divider(height: 28, color: Colors.white12),
                        ListTile(
                          dense: true,
                          title: const Text('Mã giao dịch'),
                          trailing: Text('#${txn.id}'),
                        ),
                        ListTile(
                          dense: true,
                          title: const Text('Ngày giao dịch'),
                          trailing: Text(txn.date),
                        ),
                        ListTile(
                          dense: true,
                          title: const Text('Ghi chú'),
                          subtitle: Text(
                            txn.note.isEmpty
                                ? 'Không có ghi chú bổ sung'
                                : txn.note,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) =>
                                AddEditTransactionMobileScreen(initialTxn: txn),
                          ),
                        );
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('Chỉnh sửa'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF43F5E),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: const Color(0xFF131C2E),
                            title: const Text('Xóa giao dịch này?'),
                            content: const Text(
                              'Bạn có chắc chắn muốn xóa vĩnh viễn giao dịch này? Số dư sẽ được tính toán lại ngay lập tức.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: const Text('Hủy'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF43F5E),
                                ),
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: const Text('Xác nhận xóa'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true && context.mounted) {
                          await context
                              .read<FinanceProvider>()
                              .deleteTransaction(txn.id);
                          if (context.mounted) Navigator.of(context).pop();
                        }
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Xóa'),
                    ),
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
