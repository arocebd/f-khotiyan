# F-Khotiyan Database Setup Guide

## Step 1: Install MariaDB

### Windows
1. Download MariaDB from: https://mariadb.org/download/
2. Run the installer
3. Set root password during installation
4. Complete the installation

### Linux (Ubuntu/Debian)
```bash
sudo apt update
sudo apt install mariadb-server mariadb-client
sudo mysql_secure_installation
```

### macOS
```bash
brew install mariadb
brew services start mariadb
mysql_secure_installation
```

## Step 2: Create Database

### Open MariaDB Console
```bash
# Windows
mysql -u root -p

# Linux/Mac
sudo mysql -u root -p
```

### Run Database Setup Commands
```sql
-- Create database
CREATE DATABASE f_khotiyan_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Create user (Change password!)
CREATE USER 'f_khotiyan_user'@'localhost' IDENTIFIED BY 'your_secure_password_here';

-- Grant privileges
GRANT ALL PRIVILEGES ON f_khotiyan_db.* TO 'f_khotiyan_user'@'localhost';

-- Apply changes
FLUSH PRIVILEGES;

-- Verify database exists
SHOW DATABASES;

-- Verify user exists
SELECT User, Host FROM mysql.user WHERE User = 'f_khotiyan_user';

-- Exit
EXIT;
```

## Step 3: Configure Django

### Update .env file
```env
DB_ENGINE=django.db.backends.mysql
DB_NAME=f_khotiyan_db
DB_USER=f_khotiyan_user
DB_PASSWORD=your_secure_password_here
DB_HOST=localhost
DB_PORT=3306
```

## Step 4: Install Python MySQL Driver

```bash
# Activate virtual environment first
pip install mysqlclient

# If mysqlclient fails, try PyMySQL
pip install PyMySQL
```

### If using PyMySQL, add to Django's __init__.py:
```python
import pymysql
pymysql.install_as_MySQLdb()
```

## Step 5: Run Django Migrations

```bash
# Make migrations
python manage.py makemigrations

# Expected output:
# Migrations for 'core':
#   core/migrations/0001_initial.py
#     - Create model User
#     - Create model Product
#     - Create model Customer
#     - Create model Order
#     - Create model OrderItem
#     - Create model Expense
#     - Create model CourierConfig
#     - Create model SMSPurchase
#     - Create model SMSLog
#     - Create model Subscription
#     - Create model Return

# Apply migrations
python manage.py migrate

# Expected output:
# Operations to perform:
#   Apply all migrations: admin, auth, contenttypes, core, sessions
# Running migrations:
#   Applying contenttypes.0001_initial... OK
#   Applying contenttypes.0002_remove_content_type_name... OK
#   Applying auth.0001_initial... OK
#   [... more migrations ...]
#   Applying core.0001_initial... OK
```

## Step 6: Create Superuser

```bash
python manage.py createsuperuser

# Enter these details:
# Phone number: 01712345678 (11 digits)
# Email: admin@fkhotiyan.com
# Business name: Admin Business
# Owner name: Administrator
# Password: ******** (strong password)
```

## Step 7: Verify Database Tables

```bash
# Open MariaDB console
mysql -u f_khotiyan_user -p f_khotiyan_db

# List all tables
SHOW TABLES;
```

### Expected Tables:
```
+----------------------------------+
| Tables_in_f_khotiyan_db         |
+----------------------------------+
| auth_group                       |
| auth_group_permissions           |
| auth_permission                  |
| core_customer                    |
| core_courierconfig               |
| core_expense                     |
| core_order                       |
| core_orderitem                   |
| core_product                     |
| core_return                      |
| core_smspurchase                 |
| core_smslog                      |
| core_subscription                |
| core_user                        |
| core_user_groups                 |
| core_user_user_permissions       |
| django_admin_log                 |
| django_content_type              |
| django_migrations                |
| django_session                   |
+----------------------------------+
```

## Step 8: Test Database Connection

```bash
# Django shell
python manage.py shell
```

```python
# Test User model
from core.models import User

# Check if superuser exists
user = User.objects.first()
print(f"User: {user.business_name}")
print(f"Phone: {user.phone_number}")
print(f"Subscription: {user.subscription_type}")

# Exit
exit()
```

## Troubleshooting

### Error: "Can't connect to MySQL server"
**Solution:**
1. Verify MariaDB is running:
   ```bash
   # Windows
   services.msc  # Look for MariaDB service
   
   # Linux
   sudo systemctl status mariadb
   
   # Mac
   brew services list
   ```

2. Check database credentials in .env file

### Error: "Access denied for user"
**Solution:**
1. Reset user password in MariaDB:
   ```sql
   ALTER USER 'f_khotiyan_user'@'localhost' IDENTIFIED BY 'new_password';
   FLUSH PRIVILEGES;
   ```

2. Update .env with new password

### Error: "No module named 'MySQLdb'"
**Solution:**
```bash
pip install mysqlclient
# OR
pip install PyMySQL
```

### Error: "Unknown database 'f_khotiyan_db'"
**Solution:**
Recreate the database using Step 2 commands.

### Error during migrations: "Specified key was too long"
**Solution:**
Ensure database uses utf8mb4:
```sql
ALTER DATABASE f_khotiyan_db CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci;
```

## Database Backup & Restore

### Backup Database
```bash
mysqldump -u f_khotiyan_user -p f_khotiyan_db > backup_$(date +%Y%m%d).sql
```

### Restore Database
```bash
mysql -u f_khotiyan_user -p f_khotiyan_db < backup_20260310.sql
```

## Production Considerations

1. **Change default passwords**
2. **Use strong database passwords**
3. **Enable SSL for database connections**
4. **Regular backups (automated)**
5. **Monitor database performance**
6. **Optimize queries with indexes**
7. **Use connection pooling**

## Next Steps

After successful database setup:
1. ✅ Run Django server: `python manage.py runserver`
2. ✅ Access admin: http://127.0.0.1:8000/admin/
3. ✅ Start creating API endpoints
4. ✅ Implement business logic

---

**Database Setup Complete! 🎉**
