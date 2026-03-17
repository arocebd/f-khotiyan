# F-Khotiyan SaaS Application

## 🚀 Multi-Tenant Business Management System

A comprehensive Django-based backend for managing small businesses in Bangladesh. Built with multi-tenant architecture, courier integration (Pathao & Steadfast), SMS capabilities, and subscription management.

---

## 📋 Features

### Core Features
- ✅ **Multi-Tenant Architecture** - Complete data isolation per business
- ✅ **User Management** - Custom user model with business profiles
- ✅ **Product/Inventory Management** - Track stock, pricing, and reorder levels
- ✅ **Order Management** - Full order lifecycle with QR codes
- ✅ **🤖 AI Order Creation** - Extract orders from screenshots using Gemini AI
- ✅ **Daily Order Limits** - Free users: 5 orders/day, Paid: unlimited
- ✅ **Customer Database** - Track customer history and detect fake customers
- ✅ **Expense Tracking** - Categorized business expense management
- ✅ **Courier Integration** - Pathao and Steadfast API support
- ✅ **SMS System** - Purchase, track, and send SMS notifications
- ✅ **Subscription Management** - Monthly/Yearly plans with expiry tracking
- ✅ **Return Management** - Handle product returns and refunds

---

## 🛠️ Tech Stack

- **Framework:** Django 4.2+ with Django REST Framework
- **Database:** MariaDB 10+
- **Authentication:** JWT (djangorestframework-simplejwt)
- **Python:** 3.10+

---

## 📦 Installation

### 1. Clone the Repository
```bash
git clone <repository-url>
cd F-Khotiyan
```

### 2. Create Virtual Environment
```bash
# Windows
python -m venv venv
venv\Scripts\activate

# Linux/Mac
python3 -m venv venv
source venv/bin/activate
```

### 3. Install Dependencies
```bash
pip install -r requirements.txt
```

### 4. Configure Environment Variables
```bash
# Copy the example file
copy .env.example .env

# Edit .env and add your actual configuration
```

### 5. Setup Database

**Create MariaDB Database:**
```sql
CREATE DATABASE f_khotiyan_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'f_khotiyan_user'@'localhost' IDENTIFIED BY 'your_password';
GRANT ALL PRIVILEGES ON f_khotiyan_db.* TO 'f_khotiyan_user'@'localhost';
FLUSH PRIVILEGES;
```

**Run Migrations:**
```bash
python manage.py makemigrations
python manage.py migrate
```

### 6. Create Superuser
```bash
python manage.py createsuperuser
```

### 7. Run Development Server
```bash
python manage.py runserver
```

Visit: `http://127.0.0.1:8000/admin/`

---

## 📁 Project Structure

```
F-Khotiyan/
├── core/
│   ├── __init__.py
│   ├── models.py          # All database models
│   ├── admin.py           # Django admin configuration
│   ├── apps.py            # App configuration
│   ├── serializers.py     # DRF serializers (to be created)
│   ├── views.py           # API views (to be created)
│   └── urls.py            # URL routing (to be created)
├── manage.py
├── requirements.txt
├── .env.example
├── .env                   # Your local config (git ignored)
└── README.md
```

---

## 🗄️ Database Models

### 1. **User** (Custom AbstractUser)
- Business information (name, owner, location)
- Subscription management (free/monthly/yearly)
- SMS balance tracking
- Daily order limit tracking (5 orders/day for free users)
- Multi-tenant isolation

### 2. **Product**
- Product details (name, SKU, category)
- Pricing (purchase/selling price)
- Inventory management (quantity, reorder level)
- Low stock alerts

### 3. **Customer**
- Customer information
- Order history tracking
- Fake customer detection

### 4. **Order & OrderItem**
- Complete order management
- Multiple items per order
- Payment tracking
- Courier integration support
- QR code generation
- Invoice generation
- **🤖 AI-powered creation from screenshots**
- Source image storage

### 5. **Expense**
- Categorized expenses (rent, utility, salary, etc.)
- Date-wise tracking
- Per-user isolation

### 6. **CourierConfig**
- Store API credentials for Pathao/Steadfast
- Per-user configuration
- Multi-courier support

### 7. **SMSPurchase & SMSLog**
- SMS credit purchases
- Admin confirmation workflow
- SMS sending logs

### 8. **Subscription**
- Payment history
- Plan tracking
- Active/expired status

### 9. **Return**
- Product return management
- Refund tracking
- Status workflow

---

## 🔑 Key Features Explained

### 🤖 AI Order Creation (NEW!)
Upload screenshots of Facebook/WhatsApp orders and let Gemini AI automatically extract:
- Customer details (name, phone, address)
- Product list with quantities and prices
- Delivery charges and discounts
- Special notes and courier preferences
- **Supports Bengali text!**

See [AI_ORDER_CREATION.md](AI_ORDER_CREATION.md) for complete guide.

### Daily Order Limits
- **Free Users**: 5 orders per day
- **Paid Users**: Unlimited orders
- Automatic midnight reset
- Upgrade prompts when limit reached

### Multi-Tenant Architecture
Each user (business) has completely isolated data. All models are linked to the `User` model via ForeignKey with `CASCADE` deletion to ensure data integrity.

### Authentication
Uses Django's `AbstractUser` with phone number as the primary authentication field:
- **USERNAME_FIELD:** `phone_number`
- **Required:** 11-digit Bangladesh phone number
- **JWT tokens** for API authentication

### Subscription Management
```python
# Check if subscription is active
if user.is_subscription_active:
    # Allow access
    pass
```

### SMS Balance System
1. User purchases SMS credits via bKash
2. Admin confirms payment
3. SMS balance updated automatically
4. Each SMS sent decrements balance

### Courier Integration
Store multiple courier configurations per user:
- Pathao API credentials
- Steadfast API credentials
- Easy switching between couriers

---

## 🚀 Next Steps (Phase 2)

After setting up models, proceed with:

1. **Serializers** - Create DRF serializers for API
2. **Views** - Build API endpoints (ViewSets)
3. **Permissions** - Implement multi-tenant permissions
4. **URLs** - Setup API routing
5. **Tests** - Write comprehensive tests
6. **API Documentation** - Generate Swagger docs

---

## 🔒 Security Considerations

### Production Checklist:
- [ ] Change `SECRET_KEY` and `JWT_SECRET_KEY`
- [ ] Set `DEBUG=False`
- [ ] Configure `ALLOWED_HOSTS`
- [ ] Use environment variables for all secrets
- [ ] Encrypt courier API credentials
- [ ] Enable HTTPS
- [ ] Setup CORS properly
- [ ] Configure rate limiting
- [ ] Enable database backups
- [ ] Setup monitoring and logging

---

## 📝 Django Settings Configuration

Add this to your `settings.py`:

```python
# Custom User Model
AUTH_USER_MODEL = 'core.User'

# Database
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.mysql',
        'NAME': os.getenv('DB_NAME'),
        'USER': os.getenv('DB_USER'),
        'PASSWORD': os.getenv('DB_PASSWORD'),
        'HOST': os.getenv('DB_HOST'),
        'PORT': os.getenv('DB_PORT'),
        'OPTIONS': {
            'charset': 'utf8mb4',
            'init_command': "SET sql_mode='STRICT_TRANS_TABLES'",
        }
    }
}

# Media Files
MEDIA_URL = '/media/'
MEGemini AI Configuration
GEMINI_API_KEY = os.getenv('GEMINI_API_KEY')
GEMINI_MODEL = os.getenv('GEMINI_MODEL', 'gemini-1.5-flash')

# DIA_ROOT = os.path.join(BASE_DIR, 'media')

# Static Files
STATIC_URL = '/static/'
STATIC_ROOT = os.path.join(BASE_DIR, 'staticfiles')

# JWT Settings
from datetime import timedelta

SIMPLE_JWT = {
    'ACCESS_TOKEN_LIFETIME': timedelta(minutes=60),
    'REFRESH_TOKEN_LIFETIME': timedelta(days=7),
    'ROTATE_REFRESH_TOKENS': False,
    'BLACKLIST_AFTER_ROTATION': True,
}

# Installed Apps
INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    
    # Third-party
    'rest_framework',
    'rest_framework_simplejwt',
    'corsheaders',
    'drf_yasg',
    
    # Local apps
    'core',
]

# REST Framework
REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': [
        'rest_framework_simplejwt.authentication.JWTAuthentication',
    ],
    'DEFAULT_PERMISSION_CLASSES': [
        'rest_framework.permissions.IsAuthenticated',
    ],
    'DEFAULT_PAGINATION_CLASS': 'rest_framework.pagination.PageNumberPagination',
    'PAGE_SIZE': 20
}
```

---

## 🤝 Contributing

This is a private SaaS project. For questions or support, contact the development team.

---

## 📄 License

Proprietary - All rights reserved

---

## 👨‍💻 Development Team

- **Backend Developer:** Senior Django Developer
- **Project:** F-Khotiyan SaaS
- **Started:** March 10, 2026

---

## 📞 Support

For technical support or questions:
- Review the code documentation
- Check Django logs
- Refer to [github_copilot_prompt.md](github_copilot_prompt.md) for full specifications

---

**Happy Coding! 🎉**
