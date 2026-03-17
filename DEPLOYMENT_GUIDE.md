# 🚀 F-Khotiyan API - Setup & Deployment Guide

## 📋 Table of Contents
1. [Quick Start](#quick-start)
2. [Project Setup](#project-setup)
3. [URL Configuration](#url-configuration)
4. [Database Setup](#database-setup)
5. [Running the Server](#running-the-server)
6. [Testing the API](#testing-the-api)
7. [API Endpoints](#api-endpoints)

---

## ⚡ Quick Start

```bash
# 1. Install dependencies
pip install -r requirements.txt

# 2. Set up environment variables
cp .env.example .env
# Edit .env with your settings

# 3. Create Django project (if not exists)
django-admin startproject config .

# 4. Configure URLs (see step 3 below)

# 5. Run migrations
python manage.py makemigrations
python manage.py migrate

# 6. Create superuser
python manage.py createsuperuser

# 7. Run server
python manage.py runserver
```

---

## 🏗️ Project Setup

### 1. Install Python Dependencies

```bash
pip install -r requirements.txt
```

**Required packages:**
- Django 4.2.9
- Django REST Framework
- djangorestframework-simplejwt (JWT auth)
- mysqlclient (MariaDB driver)
- google-generativeai (Gemini AI)
- Pillow (Image processing)
- qrcode (QR code generation)
- drf-yasg (API documentation)
- python-decouple (Environment variables)

### 2. Create Django Project

If you haven't created a Django project yet:

```bash
django-admin startproject config .
```

This creates:
```
F-Khotiyan/
├── config/
│   ├── __init__.py
│   ├── settings.py
│   ├── urls.py
│   ├── asgi.py
│   └── wsgi.py
├── core/
│   ├── models.py
│   ├── views.py
│   ├── serializers.py
│   ├── admin.py
│   ├── gemini_service.py
│   ├── permissions.py
│   └── urls.py
└── manage.py
```

### 3. Configure Settings

Open `config/settings.py` and merge content from `settings_template.py`:

```python
# Add to INSTALLED_APPS
INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    
    # Third-party apps
    'rest_framework',
    'rest_framework_simplejwt',
    'corsheaders',
    'drf_yasg',
    
    # Local apps
    'core',
]

# Add CORS middleware
MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'whitenoise.middleware.WhiteNoiseMiddleware',  # For static files
    'corsheaders.middleware.CorsMiddleware',  # Add this
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

# Custom User Model
AUTH_USER_MODEL = 'core.User'

# Copy the entire REST_FRAMEWORK, SIMPLE_JWT, DATABASES, 
# GEMINI_API_KEY, CORS, and MEDIA settings from settings_template.py
```

**Full settings template is available in `settings_template.py`**

---

## 🔗 URL Configuration

### Step 1: Configure Main URLs

Open `config/urls.py` and replace with content from `urls_config.py`:

```python
from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static
from rest_framework_simplejwt.views import (
    TokenObtainPairView,
    TokenRefreshView,
    TokenVerifyView
)

urlpatterns = [
    path('admin/', admin.site.urls),
    
    # JWT Token endpoints
    path('api/token/', TokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('api/token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('api/token/verify/', TokenVerifyView.as_view(), name='token_verify'),
    
    # Core API endpoints
    path('api/', include('core.urls')),
]

# Serve media files in development
if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
```

### Step 2: Verify Core URLs

The file `core/urls.py` is already created with all routes:

**Authentication Routes:**
- `POST /api/auth/register/` - User registration
- `POST /api/auth/login/` - User login
- `GET /api/auth/profile/` - Get user profile
- `PUT /api/auth/profile/update/` - Update profile

**AI Order Extraction:**
- `POST /api/orders/extract/` - Extract order from text/image
- `POST /api/orders/confirm-ai-order/` - Create order from AI data
- `GET /api/orders/limit-info/` - Check daily order limit

**CRUD Operations:**
- `/api/products/` - Product management
- `/api/customers/` - Customer management
- `/api/orders/` - Order management
- `/api/expenses/` - Expense tracking
- `/api/courier-configs/` - Courier configuration
- `/api/sms-purchases/` - SMS balance management

---

## 💾 Database Setup

### 1. Install MariaDB

**Windows:**
```bash
# Download from: https://mariadb.org/download/
# Run installer and set root password
```

**Linux:**
```bash
sudo apt update
sudo apt install mariadb-server
sudo mysql_secure_installation
```

### 2. Create Database

```sql
mysql -u root -p

CREATE DATABASE fkhotiyan CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'fkhotiyan_user'@'localhost' IDENTIFIED BY 'your_password_here';
GRANT ALL PRIVILEGES ON fkhotiyan.* TO 'fkhotiyan_user'@'localhost';
FLUSH PRIVILEGES;
EXIT;
```

### 3. Configure .env File

```bash
cp .env.example .env
```

Edit `.env`:
```env
SECRET_KEY=your-secret-key-here-generate-new-one
DEBUG=True
ALLOWED_HOSTS=localhost,127.0.0.1

# Database
DB_NAME=fkhotiyan
DB_USER=fkhotiyan_user
DB_PASSWORD=your_password_here
DB_HOST=localhost
DB_PORT=3306

# Gemini AI
GEMINI_API_KEY=AIzaSyAPeJt1PJ1Auz4aSdGHvkYtAj1bdhmbm5g

# JWT
JWT_SECRET_KEY=your-jwt-secret-key
JWT_ACCESS_TOKEN_LIFETIME_MINUTES=60
JWT_REFRESH_TOKEN_LIFETIME_DAYS=7
```

### 4. Run Migrations

```bash
python manage.py makemigrations
python manage.py migrate
```

### 5. Create Superuser

```bash
python manage.py createsuperuser
```

Enter phone number (11 digits for Bangladesh), name, and password.

---

## 🚀 Running the Server

### Development Server

```bash
python manage.py runserver
```

Server will run at: `http://localhost:8000`

### Access Points

- **API Root:** http://localhost:8000/api/
- **Admin Panel:** http://localhost:8000/admin/
- **API Docs (Swagger):** http://localhost:8000/api/docs/
- **API Docs (ReDoc):** http://localhost:8000/api/redoc/

### Production Server

```bash
# Collect static files
python manage.py collectstatic --noinput

# Run with Gunicorn
gunicorn config.wsgi:application --bind 0.0.0.0:8000 --workers 4
```

---

## 🧪 Testing the API

### 1. Register a User

```bash
curl -X POST http://localhost:8000/api/auth/register/ \
  -H "Content-Type: application/json" \
  -d '{
    "phone": "01712345678",
    "password": "SecurePass123",
    "password2": "SecurePass123",
    "name": "Test User"
  }'
```

**Response:**
```json
{
  "user": {
    "id": 1,
    "phone": "01712345678",
    "name": "Test User",
    "is_subscription_active": false,
    "daily_order_limit": 5
  },
  "access": "eyJ0eXAiOiJKV1QiLCJhbGc...",
  "refresh": "eyJ0eXAiOiJKV1QiLCJhbGc..."
}
```

### 2. Login

```bash
curl -X POST http://localhost:8000/api/auth/login/ \
  -H "Content-Type: application/json" \
  -d '{
    "phone": "01712345678",
    "password": "SecurePass123"
  }'
```

### 3. Get Profile (Authenticated)

```bash
curl -X GET http://localhost:8000/api/auth/profile/ \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

### 4. Extract Order from Text

```bash
curl -X POST http://localhost:8000/api/orders/extract/ \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "message_text": "আমার নাম রহিম। ফোন: 01812345678। ঠিকানা: ঢাকা, মিরপুর-১০। পণ্য: টিশার্ট ২টা, প্যান্ট ১টা"
  }'
```

**Response:**
```json
{
  "extracted_data": {
    "customer_name": "রহিম",
    "customer_phone": "01812345678",
    "district": "ঢাকা",
    "address": "মিরপুর-১০",
    "products": [
      {"name": "টিশার্ট", "quantity": 2},
      {"name": "প্যান্ট", "quantity": 1}
    ]
  },
  "validation_errors": {},
  "daily_orders_remaining": 4
}
```

### 5. Extract Order from Image

```bash
curl -X POST http://localhost:8000/api/orders/extract/ \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -F "screenshot=@/path/to/message_screenshot.jpg"
```

### 6. Confirm AI Order

```bash
curl -X POST http://localhost:8000/api/orders/confirm-ai-order/ \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "customer_name": "রহিম",
    "customer_phone": "01812345678",
    "district": "ঢাকা",
    "address": "মিরপুর-১০",
    "products": [
      {"name": "টিশার্ট", "quantity": 2, "price": 500},
      {"name": "প্যান্ট", "quantity": 1, "price": 800}
    ]
  }'
```

### 7. Check Order Limit

```bash
curl -X GET http://localhost:8000/api/orders/limit-info/ \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

### 8. Get Order Statistics

```bash
curl -X GET http://localhost:8000/api/orders/statistics/ \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

---

## 📚 API Endpoints

### Authentication

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| POST | `/api/auth/register/` | Register new user | No |
| POST | `/api/auth/login/` | Login user | No |
| GET | `/api/auth/profile/` | Get user profile | Yes |
| PUT | `/api/auth/profile/update/` | Update profile | Yes |

### JWT Tokens

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/token/` | Obtain access & refresh token |
| POST | `/api/token/refresh/` | Refresh access token |
| POST | `/api/token/verify/` | Verify token validity |

### AI Order Extraction

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| POST | `/api/orders/extract/` | Extract order data from text/image | Yes |
| POST | `/api/orders/confirm-ai-order/` | Create order from extracted data | Yes |
| GET | `/api/orders/limit-info/` | Check daily order limit status | Yes |

### Products

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| GET | `/api/products/` | List all products | Yes |
| POST | `/api/products/` | Create product | Yes |
| GET | `/api/products/{id}/` | Get product details | Yes |
| PUT | `/api/products/{id}/` | Update product | Yes |
| DELETE | `/api/products/{id}/` | Delete product | Yes |

### Customers

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| GET | `/api/customers/` | List all customers | Yes |
| POST | `/api/customers/` | Create customer | Yes |
| GET | `/api/customers/{id}/` | Get customer details | Yes |
| PUT | `/api/customers/{id}/` | Update customer | Yes |
| DELETE | `/api/customers/{id}/` | Delete customer | Yes |

### Orders

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| GET | `/api/orders/` | List all orders | Yes |
| POST | `/api/orders/` | Create order manually | Yes |
| GET | `/api/orders/{id}/` | Get order details | Yes |
| PUT | `/api/orders/{id}/` | Update order | Yes |
| DELETE | `/api/orders/{id}/` | Delete order | Yes |
| GET | `/api/orders/statistics/` | Get order statistics | Yes |

### Expenses

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| GET | `/api/expenses/` | List expenses | Yes |
| POST | `/api/expenses/` | Create expense | Yes |
| GET | `/api/expenses/{id}/` | Get expense details | Yes |
| PUT | `/api/expenses/{id}/` | Update expense | Yes |
| DELETE | `/api/expenses/{id}/` | Delete expense | Yes |

### Courier Configuration

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| GET | `/api/courier-configs/` | List courier configs | Yes |
| POST | `/api/courier-configs/` | Create config | Yes |
| GET | `/api/courier-configs/{id}/` | Get config details | Yes |
| PUT | `/api/courier-configs/{id}/` | Update config | Yes |
| DELETE | `/api/courier-configs/{id}/` | Delete config | Yes |

### SMS Management

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| GET | `/api/sms-purchases/` | List SMS purchases | Yes |
| POST | `/api/sms-purchases/` | Create SMS purchase | Yes |
| GET | `/api/sms-purchases/{id}/` | Get purchase details | Yes |

---

## 🔧 Troubleshooting

### Common Issues

**1. ModuleNotFoundError: No module named 'core'**
```bash
# Make sure you have __init__.py in core directory
touch core/__init__.py
```

**2. Database connection error**
```bash
# Check if MariaDB is running
sudo systemctl status mariadb

# Test connection
mysql -u fkhotiyan_user -p fkhotiyan
```

**3. Gemini API error**
```bash
# Verify API key in .env
# Test with: python check_setup.py
```

**4. JWT token expired**
```bash
# Use refresh token to get new access token
curl -X POST http://localhost:8000/api/token/refresh/ \
  -d '{"refresh": "YOUR_REFRESH_TOKEN"}'
```

---

## 📖 Additional Resources

- [API Documentation](AI_ORDER_CREATION.md)
- [Database Schema](DATABASE_SETUP.md)
- [Model Relationships](MODEL_RELATIONSHIPS.md)
- [Testing Guide](TESTING_GUIDE.md)
- [Update Summary](UPDATE_SUMMARY.md)

---

## 🎉 You're All Set!

Your F-Khotiyan API is now ready to use. Access the Swagger documentation at:
**http://localhost:8000/api/docs/**

Happy coding! 🚀
