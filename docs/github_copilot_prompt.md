# GitHub Copilot Prompt for Business Management Flutter App

## Project Overview
Build a comprehensive business management mobile application for Bangladeshi small businesses using Flutter, Django backend, MariaDB database, and Firebase for authentication and real-time features.

---

## TECH STACK

### Frontend
- **Framework**: Flutter (latest stable version)
- **State Management**: Provider or Riverpod
- **Local Storage**: SQLite (sqflite package) + Shared Preferences
- **HTTP Client**: Dio package
- **PDF Generation**: pdf package
- **QR Code**: qr_flutter package
- **Image Picker**: image_picker package
- **Location**: geolocator package
- **SMS**: url_launcher package (for SMS intent)

### Backend
- **Framework**: Django 4.x + Django REST Framework
- **Database**: MariaDB 10
- **Authentication**: JWT (djangorestframework-simplejwt)
- **Firebase**: Admin SDK for notifications
- **Payment**: bKash PGW API integration
- **SMS Gateway**: Custom integration with Bangladeshi SMS provider
- **Courier API**: Pathao & Steadfast API integration

### Third-party Services
- **Ads**: Google AdMob (Flutter package: google_mobile_ads)
- **Payment**: bKash Merchant Account
- **Courier**: Pathao API, Steadfast API
- **Firebase**: Authentication, Cloud Messaging, Analytics

---

## DATABASE SCHEMA (MySQL)

### Users Table
```sql
CREATE TABLE users (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    business_name VARCHAR(255) NOT NULL,
    owner_name VARCHAR(255) NOT NULL,
    location VARCHAR(255) NOT NULL,
    district VARCHAR(100) NOT NULL,
    country VARCHAR(100) DEFAULT 'Bangladesh',
    phone_number VARCHAR(11) UNIQUE NOT NULL,
    email VARCHAR(255) NULL,
    password_hash VARCHAR(255) NOT NULL,
    logo_url VARCHAR(500) NULL,
    subscription_type ENUM('free', 'monthly', 'yearly') DEFAULT 'free',
    subscription_start_date DATETIME NULL,
    subscription_end_date DATETIME NULL,
    sms_balance INT DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_phone (phone_number),
    INDEX idx_subscription (subscription_end_date)
);
```

### Products Table
```sql
CREATE TABLE products (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL,
    product_name VARCHAR(255) NOT NULL,
    product_code VARCHAR(100) NULL,
    category VARCHAR(100) NULL,
    purchase_price DECIMAL(10, 2) NOT NULL,
    selling_price DECIMAL(10, 2) NOT NULL,
    stock_quantity INT NOT NULL DEFAULT 0,
    reorder_level INT DEFAULT 10,
    unit VARCHAR(50) DEFAULT 'pcs',
    description TEXT NULL,
    image_url VARCHAR(500) NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_user_product (user_id, product_code)
);
```

### Customers Table
```sql
CREATE TABLE customers (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL,
    customer_name VARCHAR(255) NOT NULL,
    phone_number VARCHAR(15) NOT NULL,
    address TEXT NULL,
    district VARCHAR(100) NULL,
    is_fake BOOLEAN DEFAULT FALSE,
    fake_reason TEXT NULL,
    total_orders INT DEFAULT 0,
    total_amount DECIMAL(12, 2) DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_user_customer (user_id, phone_number),
    INDEX idx_fake (user_id, is_fake)
);
```

### Orders Table
```sql
CREATE TABLE orders (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    order_number VARCHAR(50) UNIQUE NOT NULL,
    user_id BIGINT NOT NULL,
    customer_id BIGINT NOT NULL,
    order_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    total_amount DECIMAL(12, 2) NOT NULL,
    discount DECIMAL(10, 2) DEFAULT 0,
    delivery_charge DECIMAL(10, 2) DEFAULT 0,
    grand_total DECIMAL(12, 2) NOT NULL,
    payment_status ENUM('pending', 'partial', 'paid') DEFAULT 'pending',
    order_status ENUM('pending', 'processing', 'shipped', 'delivered', 'cancelled', 'returned') DEFAULT 'pending',
    delivery_method ENUM('self', 'pathao', 'steadfast') DEFAULT 'self',
    courier_tracking_id VARCHAR(100) NULL,
    notes TEXT NULL,
    sms_sent BOOLEAN DEFAULT FALSE,
    invoice_pdf_url VARCHAR(500) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE RESTRICT,
    INDEX idx_user_order (user_id, order_date),
    INDEX idx_order_number (order_number),
    INDEX idx_status (user_id, order_status)
);
```

### Order Items Table
```sql
CREATE TABLE order_items (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    order_id BIGINT NOT NULL,
    product_id BIGINT NOT NULL,
    product_name VARCHAR(255) NOT NULL,
    quantity INT NOT NULL,
    purchase_price DECIMAL(10, 2) NOT NULL,
    selling_price DECIMAL(10, 2) NOT NULL,
    subtotal DECIMAL(12, 2) NOT NULL,
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE RESTRICT,
    INDEX idx_order (order_id)
);
```

### Expenses Table
```sql
CREATE TABLE expenses (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL,
    expense_type ENUM('rent', 'utility', 'transport', 'salary', 'advertisement', 'delivery', 'other') NOT NULL,
    amount DECIMAL(10, 2) NOT NULL,
    description TEXT NULL,
    expense_date DATE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_user_expense (user_id, expense_date)
);
```

### Returns Table
```sql
CREATE TABLE returns (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    order_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    return_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    return_amount DECIMAL(12, 2) NOT NULL,
    reason TEXT NULL,
    status ENUM('pending', 'approved', 'rejected') DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE RESTRICT,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_user_return (user_id, return_date)
);
```

### SMS Purchases Table
```sql
CREATE TABLE sms_purchases (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL,
    quantity INT NOT NULL,
    total_price DECIMAL(10, 2) NOT NULL,
    bkash_transaction_id VARCHAR(100) NULL,
    payment_status ENUM('pending', 'confirmed', 'failed') DEFAULT 'pending',
    confirmed_by_admin BOOLEAN DEFAULT FALSE,
    purchase_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    confirmed_at DATETIME NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_user_purchase (user_id, payment_status)
);
```

### SMS Log Table
```sql
CREATE TABLE sms_logs (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL,
    order_id BIGINT NULL,
    phone_number VARCHAR(15) NOT NULL,
    message TEXT NOT NULL,
    status ENUM('sent', 'failed') DEFAULT 'sent',
    sent_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE SET NULL,
    INDEX idx_user_sms (user_id, sent_at)
);
```

### Courier Config Table
```sql
CREATE TABLE courier_configs (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL,
    courier_name ENUM('pathao', 'steadfast') NOT NULL,
    api_key VARCHAR(255) NULL,
    secret_key VARCHAR(255) NULL,
    client_id VARCHAR(255) NULL,
    client_secret VARCHAR(255) NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE KEY unique_user_courier (user_id, courier_name)
);
```

### Subscriptions Table
```sql
CREATE TABLE subscriptions (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL,
    plan_type ENUM('monthly', 'yearly') NOT NULL,
    amount DECIMAL(10, 2) NOT NULL,
    payment_method VARCHAR(50) DEFAULT 'bkash',
    transaction_id VARCHAR(100) NULL,
    start_date DATETIME NOT NULL,
    end_date DATETIME NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_user_subscription (user_id, is_active)
);
```

---

## DJANGO PROJECT STRUCTURE

```
business_management_backend/
├── manage.py
├── requirements.txt
├── .env
├── config/
│   ├── __init__.py
│   ├── settings.py
│   ├── urls.py
│   ├── wsgi.py
│   └── asgi.py
├── apps/
│   ├── authentication/
│   │   ├── __init__.py
│   │   ├── models.py
│   │   ├── serializers.py
│   │   ├── views.py
│   │   ├── urls.py
│   │   └── permissions.py
│   ├── products/
│   │   ├── __init__.py
│   │   ├── models.py
│   │   ├── serializers.py
│   │   ├── views.py
│   │   └── urls.py
│   ├── orders/
│   │   ├── __init__.py
│   │   ├── models.py
│   │   ├── serializers.py
│   │   ├── views.py
│   │   ├── urls.py
│   │   └── services.py
│   ├── customers/
│   │   ├── __init__.py
│   │   ├── models.py
│   │   ├── serializers.py
│   │   ├── views.py
│   │   └── urls.py
│   ├── expenses/
│   │   ├── __init__.py
│   │   ├── models.py
│   │   ├── serializers.py
│   │   ├── views.py
│   │   └── urls.py
│   ├── reports/
│   │   ├── __init__.py
│   │   ├── views.py
│   │   ├── urls.py
│   │   └── services.py
│   ├── invoices/
│   │   ├── __init__.py
│   │   ├── views.py
│   │   ├── urls.py
│   │   └── pdf_generator.py
│   ├── courier/
│   │   ├── __init__.py
│   │   ├── models.py
│   │   ├── views.py
│   │   ├── urls.py
│   │   ├── pathao_service.py
│   │   └── steadfast_service.py
│   ├── sms/
│   │   ├── __init__.py
│   │   ├── models.py
│   │   ├── views.py
│   │   ├── urls.py
│   │   └── sms_service.py
│   └── payments/
│       ├── __init__.py
│       ├── models.py
│       ├── views.py
│       ├── urls.py
│       └── bkash_service.py
└── media/
    ├── logos/
    ├── product_images/
    └── invoices/
```

---

## FLUTTER PROJECT STRUCTURE

```
business_management_app/
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── core/
│   │   ├── constants/
│   │   │   ├── app_constants.dart
│   │   │   ├── api_constants.dart
│   │   │   └── color_constants.dart
│   │   ├── theme/
│   │   │   ├── app_theme.dart
│   │   │   ├── dark_theme.dart
│   │   │   └── light_theme.dart
│   │   ├── utils/
│   │   │   ├── date_formatter.dart
│   │   │   ├── number_formatter.dart
│   │   │   ├── validators.dart
│   │   │   └── permissions_handler.dart
│   │   └── services/
│   │       ├── api_service.dart
│   │       ├── local_storage_service.dart
│   │       ├── firebase_service.dart
│   │       └── ad_service.dart
│   ├── models/
│   │   ├── user_model.dart
│   │   ├── product_model.dart
│   │   ├── order_model.dart
│   │   ├── customer_model.dart
│   │   ├── expense_model.dart
│   │   ├── invoice_model.dart
│   │   └── report_model.dart
│   ├── providers/
│   │   ├── auth_provider.dart
│   │   ├── product_provider.dart
│   │   ├── order_provider.dart
│   │   ├── customer_provider.dart
│   │   ├── expense_provider.dart
│   │   ├── theme_provider.dart
│   │   └── language_provider.dart
│   ├── screens/
│   │   ├── splash/
│   │   │   └── splash_screen.dart
│   │   ├── auth/
│   │   │   ├── login_screen.dart
│   │   │   └── register_screen.dart
│   │   ├── home/
│   │   │   ├── home_screen.dart
│   │   │   └── dashboard_screen.dart
│   │   ├── products/
│   │   │   ├── product_list_screen.dart
│   │   │   ├── add_product_screen.dart
│   │   │   └── product_detail_screen.dart
│   │   ├── orders/
│   │   │   ├── order_list_screen.dart
│   │   │   ├── create_order_screen.dart
│   │   │   └── order_detail_screen.dart
│   │   ├── customers/
│   │   │   ├── customer_list_screen.dart
│   │   │   ├── add_customer_screen.dart
│   │   │   └── fake_customer_screen.dart
│   │   ├── expenses/
│   │   │   ├── expense_list_screen.dart
│   │   │   └── add_expense_screen.dart
│   │   ├── reports/
│   │   │   ├── sales_report_screen.dart
│   │   │   ├── profit_loss_screen.dart
│   │   │   └── stock_report_screen.dart
│   │   ├── settings/
│   │   │   ├── settings_screen.dart
│   │   │   ├── profile_screen.dart
│   │   │   ├── courier_config_screen.dart
│   │   │   ├── invoice_settings_screen.dart
│   │   │   └── sms_purchase_screen.dart
│   │   └── subscription/
│   │       └── subscription_screen.dart
│   └── widgets/
│       ├── custom_button.dart
│       ├── custom_text_field.dart
│       ├── loading_widget.dart
│       ├── error_widget.dart
│       ├── bottom_nav_bar.dart
│       └── ad_banner_widget.dart
├── assets/
│   ├── images/
│   ├── icons/
│   └── fonts/
├── android/
├── ios/
├── pubspec.yaml
└── .env
```

---

## FLUTTER DEPENDENCIES (pubspec.yaml)

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # State Management
  provider: ^6.1.1
  
  # HTTP & API
  dio: ^5.4.0
  http: ^1.1.2
  
  # Local Storage
  sqflite: ^2.3.0
  shared_preferences: ^2.2.2
  path_provider: ^2.1.1
  
  # Firebase
  firebase_core: ^2.24.2
  firebase_auth: ^4.15.3
  firebase_messaging: ^14.7.9
  firebase_analytics: ^10.8.0
  
  # PDF & QR
  pdf: ^3.10.7
  qr_flutter: ^4.1.0
  printing: ^5.11.1
  
  # Image & File
  image_picker: ^1.0.5
  cached_network_image: ^3.3.0
  
  # Location & Permissions
  geolocator: ^10.1.0
  permission_handler: ^11.1.0
  
  # URL & Phone
  url_launcher: ^6.2.2
  
  # UI Components
  flutter_svg: ^2.0.9
  shimmer: ^3.0.0
  pull_to_refresh: ^2.0.0
  
  # Date & Time
  intl: ^0.18.1
  
  # AdMob
  google_mobile_ads: ^4.0.0
  
  # Utils
  flutter_dotenv: ^5.1.0
  connectivity_plus: ^5.0.2
  
  # Localization
  flutter_localizations:
    sdk: flutter

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.1
```

---

## DJANGO REQUIREMENTS (requirements.txt)

```
Django==4.2.7
djangorestframework==3.14.0
djangorestframework-simplejwt==5.3.0
mysqlclient==2.2.0
python-dotenv==1.0.0
Pillow==10.1.0
reportlab==4.0.7
qrcode==7.4.2
firebase-admin==6.2.0
requests==2.31.0
django-cors-headers==4.3.1
celery==5.3.4
redis==5.0.1
gunicorn==21.2.0
whitenoise==6.6.0
```

---

## KEY FEATURES IMPLEMENTATION GUIDE

### 1. USER REGISTRATION & LOGIN

**Flutter Screen: register_screen.dart**
```dart
// Create a registration form with the following fields:
// - Business Name (required, min 3 chars)
// - Owner Name (required, min 3 chars)
// - Location (required)
// - District (required, dropdown with BD districts)
// - Country (default: Bangladesh, non-editable)
// - Phone Number (required, exactly 11 digits, starts with 01)
// - Email (optional, valid email format)
// - Password (required, min 8 chars, 1 uppercase, 1 number)
// - Retype Password (must match password)
// - Logo upload (optional, max 2MB, jpg/png)
// 
// Implement form validation
// On submit, call Django API endpoint: POST /api/auth/register/
// Store JWT token in SharedPreferences
// Navigate to home screen on success
```

**Django View: authentication/views.py**
```python
# Create RegisterView (APIView)
# Validate all fields
# Check if phone number already exists
# Hash password using Django's make_password
# Create user record
# Return JWT tokens (access & refresh)
# Send welcome SMS (if SMS balance > 0)
```

**Flutter Screen: login_screen.dart**
```dart
// Create login form with:
// - Phone Number (11 digits validation)
// - Password
// - Remember Me checkbox
// - Forgot Password link
// 
// On submit, call: POST /api/auth/login/
// Store JWT in SharedPreferences
// Check subscription status
// Navigate to home or subscription screen
```

---

### 2. STOCK MANAGEMENT

**Flutter Screen: product_list_screen.dart**
```dart
// Display products in a list/grid view
// Show: Product name, image, stock quantity, selling price
// Color code low stock items (quantity < reorder_level)
// Search and filter functionality
// Pull to refresh
// Add product FAB button
// Show AdMob banner at bottom
```

**Flutter Screen: add_product_screen.dart**
```dart
// Form fields:
// - Product Name (required)
// - Product Code (optional, unique)
// - Category (dropdown)
// - Purchase Price (required, decimal)
// - Selling Price (required, decimal)
// - Stock Quantity (required, integer)
// - Reorder Level (default: 10)
// - Unit (dropdown: pcs, kg, liter, etc.)
// - Description (optional)
// - Product Image (camera/gallery)
// 
// Calculate profit margin automatically
// API: POST /api/products/
```

**Django View: products/views.py**
```python
# ProductViewSet (ModelViewSet)
# CRUD operations
# Filter by category, low stock
# Search by name, code
# Automatic stock deduction on order
# Stock alert notifications
```

---

### 3. ORDER MANAGEMENT

**Flutter Screen: create_order_screen.dart**
```dart
// Step 1: Select/Add Customer
// Step 2: Add Products (search, scan barcode)
//   - Show available stock
//   - Allow quantity input
//   - Show subtotal
// Step 3: Review Order
//   - Total Amount
//   - Discount (percentage/fixed)
//   - Delivery Charge
//   - Grand Total
// Step 4: Select Delivery Method
//   - Self Delivery
//   - Pathao
//   - Steadfast
// Step 5: Payment Status
// Step 6: Confirm Order
// 
// On confirm:
// - Generate invoice
// - Send SMS (if enabled & balance available)
// - Create courier order (if selected)
// - Update stock
// 
// API: POST /api/orders/
```

**Django View: orders/views.py**
```python
# OrderViewSet
# Create order with order items
# Generate unique order number (format: ORD-YYYYMMDD-XXXX)
# Deduct stock quantity
# Generate invoice PDF
// Create QR code with order URL
# Trigger SMS service
# Call courier API (if applicable)
# Return order details with invoice URL
```

---

### 4. INVOICE GENERATION

**Django Service: invoices/pdf_generator.py**
```python
# Use ReportLab to generate A4 PDF
# Layout:
# - Header: Business logo (if uploaded), Business name, Address
# - Invoice Number, Date
# - Customer Details
# - Product Table: Name, Quantity, Rate, Total
# - Subtotal, Discount, Delivery Charge, Grand Total
# - Footer: Custom footnote
# - QR Code: Link to order tracking page
# 
# Customization from user settings:
# - Logo position
# - Header color
# - Footnote text
# 
# Save to media/invoices/
# Return URL
```

**Flutter: Invoice Preview & Actions**
```dart
// Show PDF preview
// Actions:
// - Download to device
// - Share via WhatsApp, Email, Messenger
// - Print (using printing package)
```

---

### 5. DELIVERY TRACKING (PATHAO & STEADFAST)

**Flutter Screen: courier_config_screen.dart**
```dart
// Pathao Configuration:
// - Enable/Disable toggle
// - Client ID input
// - Client Secret input
// - Test Connection button
// 
// Steadfast Configuration:
// - Enable/Disable toggle
// - API Key input
// - Secret Key input
// - Test Connection button
// 
// API: POST /api/courier/config/
```

**Django Service: courier/pathao_service.py**
```python
# PathaoService class
# Methods:
# - authenticate() -> get access token
# - get_cities() -> list cities
# - get_zones(city_id) -> list zones
# - get_areas(zone_id) -> list areas
# - create_order(order_data) -> create delivery order
# - get_price(order_data) -> get delivery cost
# - track_order(tracking_id) -> get order status
# 
# API Endpoints (Pathao):
# - POST /aladdin/api/v1/token/refresh (auth)
# - POST /aladdin/api/v1/orders (create order)
# - GET /aladdin/api/v1/orders/{consignment_id} (track)
```

**Django Service: courier/steadfast_service.py**
```python
# SteadfastService class
# Methods:
# - create_order(order_data) -> create delivery
# - track_order(tracking_id) -> status
# - get_balance() -> account balance
# 
# API Endpoints (Steadfast):
# - POST /create_order (create order)
# - GET /status_by_trackingcode/{tracking_code} (track)
```

**Auto Sync on Order Creation:**
```python
# In orders/services.py
# When order is created and delivery method is pathao/steadfast:
# 1. Get customer address details
# 2. Get product details
# 3. Calculate COD amount
# 4. Call respective courier API
# 5. Save tracking ID in order
# 6. Update order status to 'shipped'
```

---

### 6. PRODUCT RETURN

**Flutter Screen: product_return_screen.dart**
```dart
// Search order by order number
// Show order details
// Select return reason:
//   - Damaged Product
//   - Wrong Product
//   - Customer Changed Mind
//   - Other (text input)
// Return amount (full/partial)
// Submit return request
// 
// API: POST /api/returns/
```

**Django View: orders/views.py**
```python
# ReturnViewSet
# Create return record
# Update order status to 'returned'
# Add stock back to inventory
# Adjust profit/loss calculations
# Send notification to user
```

---

### 7. FAKE CUSTOMER TRACKER

**Flutter Screen: fake_customer_screen.dart**
```dart
// List of customers marked as fake
// Show:
//   - Customer name, phone
//   - Total fake orders
//   - Total lost amount
//   - Reason for marking fake
//   - Date marked
// 
// Filter options:
//   - By date range
//   - By amount lost
// 
// Mark customer as fake from customer detail screen
// Warning alert when creating order with fake customer
```

**Django Model & View:**
```python
# In customers/models.py
# Add fields: is_fake, fake_reason, fake_marked_date
# 
# In customers/views.py
# POST /api/customers/{id}/mark_fake/
# - Set is_fake = True
# - Save reason
# - Calculate total loss from cancelled orders
```

---

### 8. EXPENSE MANAGEMENT

**Flutter Screen: add_expense_screen.dart**
```dart
// Form fields:
// - Expense Type (dropdown):
//   - Rent
//   - Utility Bill
//   - Transport Cost
//   - Employee Salary
//   - Advertisement Cost
//   - Delivery Cost
//   - Other
// - Amount (required, decimal)
// - Description (optional)
// - Expense Date (date picker, default today)
// 
// API: POST /api/expenses/
```

**Django View: expenses/views.py**
```python
# ExpenseViewSet
# CRUD operations
# Filter by date range, type
# Calculate total expenses by type
# Monthly expense summary
```

---

### 9. REPORTS & ANALYTICS

**Flutter Screen: sales_report_screen.dart**
```dart
// Date range selector (today, this week, this month, custom)
// Metrics:
// - Total Sales Revenue
// - Total Orders
// - Average Order Value
// - Top Selling Products (list with quantities)
// - Sales by Payment Status (pie chart)
// - Daily Sales Trend (line chart)
// 
// Export options: PDF, Excel
// 
// API: GET /api/reports/sales/?start_date=&end_date=
```

**Flutter Screen: profit_loss_screen.dart**
```dart
// Date range selector
// 
// Gross Profit Calculation:
// - Total Revenue (sum of all orders)
// - Cost of Goods Sold (sum of purchase prices)
// - Gross Profit = Revenue - COGS
// - Gross Profit Margin % = (Gross Profit / Revenue) * 100
// 
// Operating Profit Calculation:
// - Gross Profit (from above)
// - Total Expenses (sum from expenses table)
// - Operating Profit = Gross Profit - Expenses
// - Operating Profit Margin % = (Operating Profit / Revenue) * 100
// 
// Show breakdown by expense type
// Visual charts (bar chart, pie chart)
// 
// API: GET /api/reports/profit-loss/?start_date=&end_date=
```

**Flutter Screen: stock_report_screen.dart**
```dart
// Show all products with:
// - Current Stock
// - Stock Value (quantity × purchase price)
// - Reorder Status (OK, Low, Out of Stock)
// 
// Totals:
// - Total Stock Value
// - Number of Products
// - Low Stock Items Count
// - Out of Stock Items Count
// 
// Color coding for stock levels
// 
// API: GET /api/reports/stock/
```

**Django Service: reports/services.py**
```python
# ReportService class
# 
# Method: get_sales_report(user_id, start_date, end_date)
# - Query orders in date range
# - Calculate metrics
# - Get top products
// Return structured data
# 
# Method: get_profit_loss(user_id, start_date, end_date)
# - Calculate gross profit
# - Get expenses
# - Calculate operating profit
# - Return breakdown
# 
# Method: get_stock_report(user_id)
# - Get all products with current stock
# - Calculate total value
# - Identify low/out of stock
```

---

### 10. SMS SYSTEM

**SMS Purchase Flow:**

**Flutter Screen: sms_purchase_screen.dart**
```dart
// Show current SMS balance
// Package options:
// - 100 SMS = 45 BDT (0.45 TK/SMS)
// - 500 SMS = 225 BDT (bulk discount)
// - 1000 SMS = 450 BDT
// 
// Payment Instructions:
// 1. bKash to: 01791927084 (Merchant)
// 2. Enter transaction ID
// 3. Wait for admin confirmation
// 
// Form:
// - Select package
// - Transaction ID input
// - Submit button
// 
// Show pending purchases
// 
// API: POST /api/sms/purchase/
```

**Django Admin Panel:**
```python
# Create admin interface for SMS purchase confirmation
# List all pending SMS purchases
# Show: User, Quantity, Amount, Transaction ID, Date
# Action: Approve/Reject
# On approve:
#   - Update user.sms_balance
#   - Set payment_status = 'confirmed'
#   - Send confirmation notification
```

**SMS Sending on Order Creation:**

**Django Service: sms/sms_service.py**
```python
# SMSService class
# 
# Method: send_order_sms(user, order, customer_phone)
# - Check if user has SMS balance
# - If balance < 1, return error
# - Format message:
#   "আপনার অর্ডার #{order_number} গৃহীত হয়েছে। 
#    পণ্য: {product_names}
#    মোট: {grand_total} টাকা
#    ডেলিভারি: {delivery_method}
#    ধন্যবাদ - {business_name}"
# - Call SMS Gateway API
# - Deduct 1 from user.sms_balance
# - Log in sms_logs table
# - Return status
# 
# SMS Gateway Integration:
# Use Bangladesh SMS provider API (e.g., BulkSMSBD, Banglalink, Robi)
# POST request with API credentials
```

---

### 11. SUBSCRIPTION MANAGEMENT

**Flutter Screen: subscription_screen.dart**
```dart
// Show current subscription status:
// - Plan: Free/Monthly/Yearly
// - Start Date
// - End Date
// - Days Remaining
// 
// Plans:
// 
// FREE PLAN:
// - Features: All basic features
// - Limitations: Ads shown, Max 50 products
// 
// MONTHLY PLAN (200 BDT):
// - No Ads
// - Unlimited Products
// - Priority Support
// - Advanced Reports
// 
// YEARLY PLAN (1000 BDT):
// - All Monthly features
// - 2 months free (12 months for price of 10)
// - SMS bonus: 100 free SMS
// 
// Payment Button:
// - Select plan
// - Pay with bKash
// - Enter transaction ID
// - Wait for confirmation
// 
// API: POST /api/subscriptions/purchase/
```

**Django View: payments/views.py**
```python
# SubscriptionViewSet
# 
# Method: purchase_subscription(request)
# - Get user, plan_type, transaction_id
# - Create subscription record (status: pending)
# - Admin confirms payment
# - On confirmation:
#   - Update user.subscription_type
#   - Set start_date = now
#   - Set end_date = start_date + duration
#   - If yearly, add 100 SMS bonus
#   - Send confirmation SMS/email
```

**Subscription Check Middleware:**
```python
# Create middleware to check subscription status
# On each API request (except auth):
#   - Check if user subscription is active
#   - If expired, limit features (show ads, restrict products)
#   - Return subscription_status in API response
```

---

### 12. ADMOB INTEGRATION

**Flutter: ad_service.dart**
```dart
// AdService class
// 
// Methods:
// - loadBannerAd() -> show at bottom of screens
// - loadInterstitialAd() -> show after certain actions
// - showRewardedAd() -> optional feature
// 
// Ad Placement Strategy:
// FREE USERS:
// - Banner ad on: Home, Product List, Order List
// - Interstitial ad: After every 5th order creation
// 
// PAID USERS:
// - No ads
// 
// Check user subscription before showing ads
```

**AdMob Configuration:**
```yaml
# In android/app/src/main/AndroidManifest.xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy"/>

# In ios/Runner/Info.plist
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy</string>
```

---

## LANGUAGE & THEME SETTINGS

**Language Implementation:**

**Create locale files:**
```dart
// lib/l10n/app_en.arb
{
  "appTitle": "Business Manager",
  "login": "Login",
  "register": "Register",
  "products": "Products",
  "orders": "Orders",
  // ... all strings
}

// lib/l10n/app_bn.arb
{
  "appTitle": "ব্যবসা ম্যানেজার",
  "login": "লগইন",
  "register": "রেজিস্টার",
  "products": "পণ্য",
  "orders": "অর্ডার",
  // ... all strings in Bangla
}
```

**Language Provider:**
```dart
// lib/providers/language_provider.dart
// Store language preference in SharedPreferences
// Methods: setLanguage(locale), getLanguage()
// Default: Bangla (bn)
```

**Theme Implementation:**

**lib/core/theme/light_theme.dart**
```dart
// Define light theme colors
// Primary: Blue (#2196F3)
// Accent: Orange (#FF9800)
// Background: White
// Text: Dark Grey
```

**lib/core/theme/dark_theme.dart**
```dart
// Define dark theme colors
// Primary: Dark Blue (#1976D2)
// Accent: Deep Orange (#FF5722)
// Background: Dark Grey (#121212)
// Text: Light Grey
```

**Theme Provider:**
```dart
// lib/providers/theme_provider.dart
// Store theme preference in SharedPreferences
// Methods: toggleTheme(), getTheme()
// Default: Light
```

---

## PERMISSIONS HANDLING

**Flutter: permissions_handler.dart**
```dart
// Request permissions on app first launch
// 
// Required Permissions:
// 1. STORAGE (READ/WRITE) - for invoice download, logo upload
// 2. CAMERA - for product image capture, barcode scan
// 3. LOCATION - for delivery address, courier integration
// 4. CONTACTS - for customer phone number selection
// 
// Implementation:
// - Check each permission status
// - Request if not granted
// - Show rationale dialog if denied
// - Handle permanent denial (open app settings)
```

**AndroidManifest.xml:**
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.READ_CONTACTS"/>
```

---

## SECURITY BEST PRACTICES

### Django Backend:
```python
# 1. Use JWT for authentication
# 2. Implement rate limiting (django-ratelimit)
# 3. CORS configuration (allow only Flutter app)
# 4. SQL injection prevention (use ORM)
# 5. XSS protection (validate inputs)
# 6. HTTPS only in production
# 7. Environment variables for secrets
# 8. Password hashing (Django default)
# 9. CSRF protection for non-API views
# 10. Regular security updates
```

### Flutter App:
```dart
// 1. Store JWT in secure storage (flutter_secure_storage)
// 2. Validate all user inputs
// 3. Use HTTPS for API calls
// 4. Obfuscate code in release build
// 5. Implement certificate pinning
// 6. Logout on token expiry
// 7. Clear sensitive data on logout
// 8. Implement biometric authentication (optional)
```

---

## DEPLOYMENT CHECKLIST

### Backend (Django):
```
1. Set DEBUG=False
2. Configure allowed hosts
3. Setup production database (MySQL on server)
4. Configure static/media files storage (AWS S3 or local)
5. Setup Gunicorn + Nginx
6. SSL certificate (Let's Encrypt)
7. Setup Celery for async tasks
8. Redis for caching
9. Setup backup system
10. Monitoring (Sentry for errors)
```

### Flutter App:
```
1. Update version number in pubspec.yaml
2. Configure Firebase for production
3. Setup AdMob with real IDs
4. Configure signing (Android keystore, iOS certificates)
5. Obfuscate code: flutter build apk --obfuscate --split-debug-info=/<output-dir>
6. Test on real devices
7. Create app icons & splash screen
8. Prepare Play Store/App Store listings
9. Privacy policy URL
10. Beta testing (Google Play Internal Testing)
```

---

## GITHUB COPILOT USAGE TIPS

### For Backend Development:
```python
# Comment-driven development:
# Write detailed comments describing what you want
# Copilot will generate the code

# Example:
# Create a Django REST API view for user registration
# Accept POST request with business_name, owner_name, phone_number, password
# Validate phone number is 11 digits and unique
# Hash the password
# Create user and return JWT tokens
# Send welcome SMS if SMS balance > 0
```

### For Flutter Development:
```dart
// Use descriptive comments before each widget/function
// Copilot will suggest implementations

// Example:
// Create a custom text field widget with:
// - Label and hint text
// - Validation support
// - Prefix icon
// - Toggle password visibility (for password fields)
// - Error text display
// - Dark/Light theme support
```

### Best Practices:
1. Start with comments describing the feature
2. Let Copilot generate code
3. Review and modify as needed
4. Use specific naming conventions
5. Break complex features into smaller functions
6. Test incrementally

---

## STEP-BY-STEP IMPLEMENTATION ORDER

### Phase 1: Foundation (Week 1-2)
1. Setup Django project with MySQL
2. Create database tables
3. Setup Flutter project structure
4. Implement authentication (register, login)
5. Setup Firebase
6. Theme & Language switching

### Phase 2: Core Features (Week 3-4)
7. Product management (CRUD)
8. Customer management
9. Order creation & management
10. Invoice generation
11. Stock management

### Phase 3: Advanced Features (Week 5-6)
12. Expense tracking
13. Reports & analytics
14. SMS integration
15. Courier integration (Pathao & Steadfast)
16. Product returns
17. Fake customer tracker

### Phase 4: Monetization (Week 7)
18. AdMob integration
19. Subscription system
20. bKash payment integration
21. SMS purchase system

### Phase 5: Polish & Deploy (Week 8)
22. UI/UX improvements
23. Performance optimization
24. Testing (unit, integration, E2E)
25. Bug fixes
26. Deployment

---

## TESTING STRATEGY

### Backend Testing:
```python
# Use Django's TestCase
# Test each API endpoint:
# - Authentication
# - CRUD operations
# - Business logic
# - Edge cases
# - Error handling

# Example:
# tests/test_orders.py
# - test_create_order_success()
# - test_create_order_insufficient_stock()
# - test_create_order_invalid_customer()
# - test_sms_sent_on_order_creation()
```

### Flutter Testing:
```dart
// Widget tests for UI components
// Integration tests for user flows
// Unit tests for business logic

// Example:
// test/order_test.dart
// - test order creation flow
// - test stock deduction
// - test invoice generation
```

---

## MONITORING & ANALYTICS

### Backend:
```python
# 1. Sentry for error tracking
# 2. Google Analytics for usage stats
# 3. Custom logging for business metrics:
#    - Daily active users
#    - Orders created
#    - Revenue generated
#    - SMS sent
```

### Flutter:
```dart
// 1. Firebase Analytics for user behavior
// 2. Crashlytics for crash reports
// 3. Track key events:
//    - Screen views
//    - Feature usage
//    - Conversion funnel
```

---

## PERFORMANCE OPTIMIZATION

### Backend:
```python
# 1. Database indexing (already in schema)
# 2. Query optimization (select_related, prefetch_related)
# 3. Caching with Redis
# 4. Pagination for large datasets
# 5. Async tasks with Celery (SMS, email, reports)
# 6. CDN for static files
```

### Flutter:
```dart
// 1. Lazy loading for lists
// 2. Image caching
// 3. Pagination for API calls
// 4. Local database for offline support
// 5. Optimize widget rebuilds
// 6. Code splitting
```

---

## FUTURE ENHANCEMENTS (Post-MVP)

1. Multi-user support (employees with roles)
2. Barcode scanner for products
3. Accounting integration (profit/loss statements)
4. Customer loyalty program
5. Push notifications for low stock
6. WhatsApp integration for order updates
7. Excel import/export
8. Mobile POS system
9. Multi-location support
10. Advanced analytics dashboard

---

## SUPPORT & DOCUMENTATION

### User Documentation:
- Create in-app help/tutorial
- Video tutorials in Bangla
- FAQ section
- Customer support (WhatsApp, Email)

### Developer Documentation:
- API documentation (Swagger/Postman)
- Database schema diagram
- Code comments
- README files

---

## BUSINESS MODEL

### Revenue Streams:
1. **Subscription**: 200 TK/month or 1000 TK/year
2. **SMS Sales**: 0.45 TK per SMS
3. **AdMob**: Revenue from free users
4. **Future**: Commission from courier integration

### Target Market:
- Small shops (grocery, clothing, electronics)
- Online sellers (Facebook marketplace)
- Service providers
- Freelancers
- Small restaurants

### Marketing Strategy:
1. Facebook ads targeting business owners
2. YouTube tutorials in Bangla
3. Referral program
4. Partnership with business communities
5. Free trial (1 month)

---

## PROMPT FOR GITHUB COPILOT

When starting development, use these prompts in your IDE with Copilot:

### Starting Backend:
```python
# I'm building a business management app backend with Django and MySQL
# The app helps small businesses manage products, orders, customers, expenses
# Features include: stock management, invoice generation, SMS notifications, courier integration
# Target users: Bangladeshi small business owners
# 
# Current task: [describe what you're building]
# Requirements: [list specific requirements]
# Expected output: [describe expected result]
```

### Starting Flutter:
```dart
// I'm building a business management mobile app with Flutter
// Backend: Django REST API with JWT authentication
// Features: multi-language (Bangla/English), dark/light theme, offline support
// Target: Small businesses in Bangladesh
// 
// Current task: [describe what you're building]
// Requirements: [list specific requirements]
// UI: [describe the UI you want]
```

---

## EXAMPLE COPILOT PROMPTS FOR SPECIFIC FEATURES

### Example 1: Product List Screen
```dart
// Create a Flutter screen to display a list of products
// Requirements:
// - Fetch products from API endpoint: GET /api/products/
// - Show product image (or placeholder), name, stock quantity, price
// - Use shimmer loading effect while fetching
// - Pull to refresh
// - Search functionality at top
// - Color code items with low stock (red if stock < 10)
// - FAB button to add new product
// - Navigate to product detail on tap
// - Show AdMob banner ad at bottom (only for free users)
// - Support both dark and light theme
// - Support Bangla and English languages
```

### Example 2: Invoice PDF Generation
```python
# Create a Django service to generate PDF invoices
# Requirements:
# - Use ReportLab library
# - A4 size, portrait orientation
# - Header: Business logo (if exists), business name, address
# - Invoice details: Number, Date, Customer name, Phone
# - Table with columns: Product Name, Quantity, Rate, Total
# - Summary: Subtotal, Discount, Delivery Charge, Grand Total
# - Footer: Custom footnote from settings
# - QR code containing invoice URL: https://domain.com/invoice/{order_id}
# - Save to media/invoices/{user_id}/INV-{order_number}.pdf
# - Return file URL
# - Handle Bengali text rendering
```

### Example 3: SMS Service
```python
# Create a Django service for sending SMS
# Requirements:
# - Check user's SMS balance before sending
# - If balance < 1, raise InsufficientBalanceError
# - Format message in Bengali:
#   "আপনার অর্ডার #{order_number} গৃহীত হয়েছে।
#    পণ্য: {product_list}
#    মোট: {amount} টাকা
#    ধন্যবাদ - {business_name}"
# - Call SMS gateway API (provide API details when implementing)
# - Deduct 1 from user.sms_balance
# - Log SMS in sms_logs table with status
# - Return success/failure status
# - Handle API failures gracefully
```

### Example 4: Pathao Integration
```python
# Create a Django service for Pathao courier integration
# Requirements:
# - Authenticate using client_id and client_secret
# - Get access token and store for reuse (expires in 1 hour)
# - Method: create_delivery_order(order_obj)
#   - Format order data for Pathao API
#   - Required fields: item_type, delivery_type, item_weight
#   - Recipient: name, phone, address
#   - Calculate COD amount
#   - Make POST request to /aladdin/api/v1/orders
#   - Parse response and extract consignment_id
#   - Return tracking ID
# - Method: track_order(consignment_id)
#   - GET request to fetch order status
#   - Return status, current_location, expected_delivery
# - Handle authentication errors
# - Retry logic for network failures
```

### Example 5: Profit/Loss Calculation
```python
# Create a Django API view to calculate profit and loss
# Endpoint: GET /api/reports/profit-loss/
# Query params: start_date, end_date
# 
# Calculations:
# 1. Gross Profit:
#    - Get all delivered orders in date range
#    - For each order:
#      - Revenue = order.grand_total
#      - COGS = sum of (order_item.quantity * order_item.purchase_price)
#    - Gross Profit = Total Revenue - Total COGS
#    - Gross Profit Margin = (Gross Profit / Total Revenue) * 100
# 
# 2. Operating Profit:
#    - Get all expenses in date range
#    - Total Expenses = sum of all expenses
#    - Operating Profit = Gross Profit - Total Expenses
#    - Operating Profit Margin = (Operating Profit / Total Revenue) * 100
# 
# Return JSON with:
# - total_revenue
# - total_cogs
# - gross_profit
# - gross_profit_margin
# - expenses_by_type (breakdown)
# - total_expenses
# - operating_profit
# - operating_profit_margin
```

---

## FINAL NOTES

This prompt provides a complete blueprint for building your business management app. Key points:

1. **Start Small**: Begin with core features (auth, products, orders)
2. **Test Frequently**: Test each feature before moving to next
3. **Use Version Control**: Commit regularly to Git
4. **Document**: Add comments to help Copilot understand context
5. **Iterate**: Build MVP first, then add advanced features
6. **Get Feedback**: Test with real users early

Remember: GitHub Copilot is a tool to assist you. Always review and understand the generated code before using it.

Good luck with your app development! 🚀
