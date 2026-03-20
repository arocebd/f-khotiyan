#!/usr/bin/env python
"""
Quick Setup Script for F-Khotiyan Project
Run this after creating the Django project with: django-admin startproject config .
"""

import os
import sys
import subprocess
from pathlib import Path

def print_step(step_num, message):
    """Print a formatted step"""
    print(f"\n{'='*60}")
    print(f"STEP {step_num}: {message}")
    print(f"{'='*60}\n")

def run_command(command, description):
    """Run a shell command and handle errors"""
    print(f"Running: {description}")
    print(f"Command: {command}\n")
    
    result = subprocess.run(command, shell=True, capture_output=True, text=True)
    
    if result.returncode == 0:
        print(f"✅ Success!")
        if result.stdout:
            print(result.stdout)
    else:
        print(f"❌ Error!")
        if result.stderr:
            print(result.stderr)
        return False
    
    return True

def check_django_project():
    """Check if Django project exists"""
    manage_py = Path("manage.py")
    config_dir = Path("config")
    
    if not manage_py.exists() or not config_dir.exists():
        print("❌ Django project not found!")
        print("\nPlease run first:")
        print("    django-admin startproject config .")
        print("\nThen run this script again.")
        return False
    
    print("✅ Django project found!")
    return True

def check_env_file():
    """Check if .env file exists"""
    env_file = Path(".env")
    env_example = Path(".env.example")
    
    if not env_file.exists():
        if env_example.exists():
            print("⚠️  .env file not found!")
            print("\nCopying from .env.example...")
            import shutil
            shutil.copy(env_example, env_file)
            print("✅ .env file created!")
            print("\n⚠️  IMPORTANT: Edit .env file with your database credentials and Gemini API key!")
            input("\nPress Enter after you've edited the .env file...")
        else:
            print("❌ .env.example not found!")
            return False
    else:
        print("✅ .env file exists!")
    
    return True

def check_database_connection():
    """Check if database is accessible"""
    print("Checking database connection...")
    
    try:
        from decouple import config
        import MySQLdb
        
        db_name = config('DB_NAME', default='fkhotiyan')
        db_user = config('DB_USER', default='root')
        db_password = config('DB_PASSWORD')
        db_host = config('DB_HOST', default='localhost')
        db_port = config('DB_PORT', default=3306, cast=int)
        
        conn = MySQLdb.connect(
            host=db_host,
            user=db_user,
            password=db_password,
            database=db_name,
            port=db_port
        )
        conn.close()
        
        print("✅ Database connection successful!")
        return True
        
    except Exception as e:
        print(f"❌ Database connection failed: {e}")
        print("\nMake sure:")
        print("1. MariaDB/MySQL is running")
        print("2. Database 'fkhotiyan' exists")
        print("3. Database credentials in .env are correct")
        return False

def main():
    """Main setup process"""
    print("""
    ╔════════════════════════════════════════════════════════╗
    ║                                                        ║
    ║        F-Khotiyan Quick Setup Script                   ║
    ║        Django + DRF + AI Order Management              ║
    ║                                                        ║
    ╚════════════════════════════════════════════════════════╝
    """)
    
    # Step 1: Check Django project
    print_step(1, "Checking Django Project")
    if not check_django_project():
        sys.exit(1)
    
    # Step 2: Check .env file
    print_step(2, "Checking Environment Variables")
    if not check_env_file():
        sys.exit(1)
    
    # Step 3: Install dependencies
    print_step(3, "Installing Python Dependencies")
    if not run_command("pip install -r requirements.txt", "Installing packages"):
        print("\n⚠️  Some packages failed to install. Continue anyway? (y/n)")
        if input().lower() != 'y':
            sys.exit(1)
    
    # Step 4: Check database
    print_step(4, "Checking Database Connection")
    if not check_database_connection():
        print("\n⚠️  Database connection failed. Continue anyway? (y/n)")
        if input().lower() != 'y':
            sys.exit(1)
    
    # Step 5: Create migrations
    print_step(5, "Creating Database Migrations")
    if not run_command("python manage.py makemigrations", "Creating migrations"):
        print("\n❌ Migration creation failed!")
        sys.exit(1)
    
    # Step 6: Run migrations
    print_step(6, "Running Database Migrations")
    if not run_command("python manage.py migrate", "Applying migrations"):
        print("\n❌ Migration failed!")
        sys.exit(1)
    
    # Step 7: Create superuser
    print_step(7, "Creating Superuser")
    print("Please enter superuser details:")
    run_command("python manage.py createsuperuser", "Creating superuser")
    
    # Step 8: Collect static files
    print_step(8, "Collecting Static Files")
    run_command("python manage.py collectstatic --noinput", "Collecting static files")
    
    # Success message
    print("""
    
    ╔════════════════════════════════════════════════════════╗
    ║                                                        ║
    ║              ✅ SETUP COMPLETE! ✅                     ║
    ║                                                        ║
    ╚════════════════════════════════════════════════════════╝
    
    🚀 Next Steps:
    
    1. Start the development server:
       python manage.py runserver
    
    2. Access the admin panel:
       http://localhost:8000/admin/
    
    3. View API documentation:
       http://localhost:8000/api/docs/
    
    4. Test API endpoints:
       See DEPLOYMENT_GUIDE.md for examples
    
    5. Integrate with Flutter app:
       See API_ROUTES.md for endpoint details
    
    📚 Documentation:
       - DEPLOYMENT_GUIDE.md - Complete setup guide
       - API_ROUTES.md - API endpoint reference
       - AI_ORDER_CREATION.md - AI features guide
       - TESTING_GUIDE.md - Testing instructions
    
    🎉 Happy coding!
    
    """)

if __name__ == "__main__":
    main()
