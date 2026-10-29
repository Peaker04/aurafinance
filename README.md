# AuraFinance (PRM393_PE2) — Quản lý Tài chính Cá nhân bằng VNĐ

Ứng dụng quản lý tài chính cá nhân cao cấp tuân thủ chuẩn thiết kế **Impeccable iOS Liquid Glassmorphism**, tối ưu hóa hiển thị an toàn trên iOS (**SafeArea** `viewport-fit=cover`, `env(safe-area-inset-*)`), định dạng chuẩn tiền tệ **Việt Nam Đồng (VNĐ)**, hỗ trợ phân tách dữ liệu đa người dùng (**Multi-user Isolation**) và cơ chế lưu trữ **SQLite** trực tiếp trên thiết bị/máy chủ.

Dự án gồm 2 phân hệ đồng bộ kiến trúc:
1. **Web App & Backend (`./`)**: Node.js + Express + `better-sqlite3` + React 19 + TypeScript + Tailwind CSS v4 + Motion.
2. **Mobile App (`./flutter_app`)**: Flutter + `sqflite` + `shared_preferences` + `provider` + `http`.

---

## 🚀 Tính năng Nổi bật

- **Quản lý Tài chính Đơn vị VNĐ**: Tự động tính toán số dư `Số dư = Tổng thu nhập - Tổng chi tiêu` theo chuẩn tiền tệ `₫` (ví dụ: `12.000.000 ₫`).
- **Phân tách Đa Người dùng (Multi-User Isolation)**: Dữ liệu của từng người dùng (`usr_01`, `usr_02`) được cách ly hoàn toàn ở tầng SQLite và API.
- **Bộ lọc & Tìm kiếm Kép (Dual Filter)**: Tìm kiếm linh hoạt theo ghi chú, danh mục tiếng Việt (Lương, Ăn uống, Đầu tư, Mua sắm, Di chuyển...) và mã danh mục.
- **Chuẩn Thiết kế iOS**: Hiển thị sắc nét với hiệu ứng kính mờ (Liquid Glassmorphism) và hỗ trợ đầy đủ thanh điều hướng Dynamic Island / Home Indicator trên iPhone.
- **Tự động Build iOS `.ipa` qua GitHub Actions**: Đường ống CI/CD tự động đóng gói ứng dụng Flutter thành tệp `.ipa` không cần tài khoản Apple Developer 99$, sẵn sàng cài đặt qua Sideloadly / AltStore / TrollStore.

---

## 🛠️ Hướng dẫn Chạy Cục bộ (Local Setup)

### 1. Backend Node.js & Web App (Thư mục gốc `./`)

```bash
# 1. Cài đặt các gói phụ thuộc
npm install

# 2. Tạo tệp môi trường (nếu chưa có)
cp .env.example .env

# 3. Chạy kiểm thử đơn vị (Unit Tests xác minh logic tài chính VNĐ)
npx tsx --test src/lib/financeEngine.test.ts

# 4. Kiểm tra biên dịch & lint
npm run lint
npm run build

# 5. Khởi chạy máy chủ phát triển
npm run dev
```

Truy cập giao diện tại: **http://localhost:3000**

#### Tài khoản Đăng nhập Thử nghiệm:
| Email | Mật khẩu | Tên Người dùng | Giao dịch mẫu |
|-------|----------|----------------|---------------|
| `user1@fpt.edu.vn` | `123456` | Tạ Tuấn Kỳ | 5 giao dịch (Thu: 16.5M ₫, Chi: 685K ₫) |
| `user2@fpt.edu.vn` | `123456` | Nguyễn Văn A | 3 giao dịch (Thu: 6.5M ₫, Chi: 2.37M ₫) |

---

### 2. Mobile App Flutter (`./flutter_app`)

```bash
cd flutter_app

# 1. Cài đặt các package Flutter
flutter pub get

# 2. Phân tích tĩnh mã nguồn
flutter analyze

# 3. Chạy unit/widget test
flutter test

# 4. Khởi chạy ứng dụng trên thiết bị / máy ảo
flutter run
```

---

## 📦 Đường ống CI/CD GitHub Actions (.ipa cho iOS)

Dự án tích hợp sẵn workflow tại `.github/workflows/build-ios-ipa.yml`:
- Tự động chạy khi có code push lên nhánh `main` hoặc kích hoạt thủ công trong tab **Actions**.
- Sử dụng runner `macos-latest` để biên dịch Flutter iOS Release không cần ký chứng chỉ (`--no-codesign`).
- Đóng gói file `.ipa` sẵn sàng tại mục **Artifacts** (`AuraFinance-iOS-IPA`).

### Cài đặt vào iPhone qua Sideloadly:
1. Vào tab **Actions** trên GitHub -> chọn workflow run thành công -> tải xuống `AuraFinance-iOS-IPA.zip` và giải nén lấy `AuraFinance-iOS.ipa`.
2. Mở **Sideloadly** trên máy tính, kết nối iPhone qua cáp USB.
3. Kéo tệp `AuraFinance-iOS.ipa` vào Sideloadly, nhập Apple ID và bấm **Start**.
4. Trên iPhone, vào **Cài đặt** -> **Cài đặt chung** -> **Quản lý VPN & Thiết bị** -> Tin cậy chứng chỉ Apple ID để mở ứng dụng.

---

## 📄 Cấu trúc Thư mục

```
aurafinance/
├── .github/workflows/
│   └── build-ios-ipa.yml      # GitHub Actions CI/CD xuất .ipa
├── flutter_app/                # Ứng dụng di động Flutter
│   ├── android/                # Cấu hình Android
│   ├── ios/                    # Cấu hình iOS
│   ├── lib/main.dart           # Giao diện & SQLite Mobile
│   ├── pubspec.yaml            # Phụ thuộc Flutter
│   └── test/widget_test.dart   # Smoke tests
├── src/
│   ├── components/             # Màn hình React 19 Liquid Glassmorphism
│   └── lib/                    # Logic tính toán VNĐ, kiểm thử & SQLite Client
├── server.ts                   # Backend Express + better-sqlite3 API
├── package.json
└── vite.config.ts
```
