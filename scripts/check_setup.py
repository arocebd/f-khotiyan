"""
Quick Setup Verification Script
Run this to check if your Django project is configured correctly
"""

import sys
import os


def check_python_version():
    """Check Python version"""
    print("🐍 Checking Python version...")
    version = sys.version_info
    if version.major >= 3 and version.minor >= 10:
        print(f"   ✅ Python {version.major}.{version.minor}.{version.micro}")
        return True
    else:
        print(f"   ❌ Python {version.major}.{version.minor} (Required: 3.10+)")
        return False


def check_env_file():
    """Check if .env file exists"""
    print("\n🔐 Checking environment file...")
    if os.path.exists('.env'):
        print("   ✅ .env file found")
        return True
    else:
        print("   ❌ .env file not found")
        print("   ℹ️  Copy .env.example to .env and configure it")
        return False


def check_dependencies():
    """Check if required packages are installed"""
    print("\n📦 Checking dependencies...")
    
    required_packages = [
        'django',
        'djangorestframework',
        'mysqlclient',
        'rest_framework',
    ]
    
    missing = []
    installed = []
    
    for package in required_packages:
        try:
            __import__(package.replace('-', '_'))
            installed.append(package)
            print(f"   ✅ {package}")
        except ImportError:
            missing.append(package)
            print(f"   ❌ {package}")
    
    if missing:
        print(f"\n   ℹ️  Install missing packages:")
        print(f"   pip install {' '.join(missing)}")
        return False
    
    return True


def check_database_config():
    """Check database configuration"""
    print("\n🗄️  Checking database configuration...")
    
    try:
        from decouple import config
        
        db_name = config('DB_NAME', default=None)
        db_user = config('DB_USER', default=None)
        db_password = config('DB_PASSWORD', default=None)
        
        if db_name and db_user and db_password:
            print(f"   ✅ Database: {db_name}")
            print(f"   ✅ User: {db_user}")
            print(f"   ✅ Password: {'*' * len(db_password)}")
            return True
        else:
            print("   ❌ Database credentials not found in .env")
            return False
            
    except ImportError:
        print("   ⚠️  python-decouple not installed")
        print("   pip install python-decouple")
        return False


def check_models():
    """Check if models are accessible"""
    print("\n📋 Checking models...")
    
    try:
        # This will work if Django is properly configured
        os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
        import django
        django.setup()
        
        from core.models import User, Product, Order
        print("   ✅ Models imported successfully")
        return True
        
    except Exception as e:
        print(f"   ❌ Error importing models: {str(e)}")
        return False


def main():
    """Run all checks"""
    print("=" * 60)
    print("🚀 F-Khotiyan Setup Verification")
    print("=" * 60)
    
    checks = [
        check_python_version(),
        check_env_file(),
        check_dependencies(),
        check_database_config(),
    ]
    
    print("\n" + "=" * 60)
    
    if all(checks):
        print("✅ All checks passed! Your setup is ready.")
        print("\nNext steps:")
        print("1. python manage.py makemigrations")
        print("2. python manage.py migrate")
        print("3. python manage.py createsuperuser")
        print("4. python manage.py runserver")
    else:
        print("❌ Some checks failed. Please fix the issues above.")
        print("\nRefer to README.md and DATABASE_SETUP.md for help.")
    
    print("=" * 60)


if __name__ == '__main__':
    main()
