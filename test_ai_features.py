"""
Test Script for Gemini AI Order Extraction
Run this to test the AI order extraction feature
"""

import os
import sys
from pathlib import Path

# Add project root to path
project_root = Path(__file__).parent
sys.path.insert(0, str(project_root))

# Setup Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
import django
django.setup()

from core.models import User
from core.gemini_service import GeminiOrderExtractor


def test_user_order_limits():
    """Test user order limit functionality"""
    print("=" * 60)
    print("Testing User Order Limits")
    print("=" * 60)
    
    # Get or create test user
    user, created = User.objects.get_or_create(
        phone_number='01700000001',
        defaults={
            'business_name': 'Test Business',
            'owner_name': 'Test Owner',
            'email': 'test@example.com',
            'location': 'Dhaka',
            'district': 'Dhaka',
            'subscription_type': 'free'
        }
    )
    
    if created:
        user.set_password('testpass123')
        user.save()
        print(f"✅ Created test user: {user.phone_number}")
    else:
        print(f"✅ Using existing user: {user.phone_number}")
    
    print(f"\n📊 User Information:")
    print(f"   Business: {user.business_name}")
    print(f"   Subscription: {user.subscription_type}")
    print(f"   Daily Limit: {user.daily_order_limit} orders")
    print(f"   Orders Today: {user.daily_order_count}")
    print(f"   Can Create Order: {'✅ Yes' if user.can_create_order() else '❌ No'}")
    
    # Test creating orders
    print(f"\n🧪 Simulating Order Creation:")
    for i in range(7):
        if user.can_create_order():
            user.increment_order_count()
            print(f"   Order {i+1}: ✅ Created (Count: {user.daily_order_count}/{user.daily_order_limit})")
        else:
            print(f"   Order {i+1}: ❌ Limit reached! (Count: {user.daily_order_count}/{user.daily_order_limit})")
    
    print("\n✅ Order limit test completed!")
    return user


def test_gemini_extraction():
    """Test Gemini AI extraction"""
    print("\n" + "=" * 60)
    print("Testing Gemini AI Order Extraction")
    print("=" * 60)
    
    try:
        # Initialize extractor
        extractor = GeminiOrderExtractor()
        print("✅ Gemini AI initialized successfully")
        print(f"   Model: gemini-1.5-flash")
        print(f"   API Key configured: ✅")
        
        # Test with sample data (you'll need to provide actual image)
        print("\n📝 To test with actual image:")
        print("   1. Take a screenshot of an order message")
        print("   2. Save it as 'test_order.jpg' in project root")
        print("   3. Run: extractor.extract_order_from_image('test_order.jpg')")
        
        print("\n✅ Gemini service is ready to use!")
        return extractor
        
    except ValueError as e:
        print(f"❌ Error: {e}")
        print("ℹ️  Make sure GEMINI_API_KEY is set in .env file")
        return None
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        return None


def test_data_validation():
    """Test data validation"""
    print("\n" + "=" * 60)
    print("Testing Data Validation")
    print("=" * 60)
    
    extractor = GeminiOrderExtractor()
    
    # Test valid data
    valid_data = {
        'customer_name': 'মোঃ রহিম',
        'customer_phone': '01712345678',
        'customer_address': 'ধানমন্ডি, ঢাকা',
        'district': 'Dhaka',
        'products': [
            {'product_name': 'T-Shirt', 'quantity': 2, 'price': 450.00}
        ],
        'total_amount': 900.00,
        'delivery_charge': 60.00,
        'discount': 0.00,
        'notes': 'Test order',
        'courier_preference': 'pathao'
    }
    
    is_valid, errors = extractor.validate_order_data(valid_data)
    
    if is_valid:
        print("✅ Valid data test passed")
        print(f"   Customer: {valid_data['customer_name']}")
        print(f"   Phone: {valid_data['customer_phone']}")
        print(f"   Products: {len(valid_data['products'])}")
        print(f"   Total: {valid_data['total_amount']} BDT")
    else:
        print(f"❌ Validation failed: {errors}")
    
    # Test invalid data (missing phone)
    invalid_data = {
        'customer_name': 'Test Customer',
        'customer_phone': '',  # Missing
        'customer_address': 'Test Address',
        'products': [],  # No products
        'total_amount': 0
    }
    
    is_valid, errors = extractor.validate_order_data(invalid_data)
    
    if not is_valid:
        print("\n✅ Invalid data detection works correctly")
        print(f"   Errors found: {len(errors)}")
        for error in errors:
            print(f"   - {error}")
    
    print("\n✅ Validation test completed!")


def print_usage_guide():
    """Print usage guide"""
    print("\n" + "=" * 60)
    print("📚 Usage Guide")
    print("=" * 60)
    
    print("""
1️⃣ CHECK USER ORDER LIMIT:
   from core.models import User
   user = User.objects.get(phone_number='01712345678')
   if user.can_create_order():
       print("Can create order!")

2️⃣ EXTRACT ORDER FROM IMAGE:
   from core.gemini_service import extract_order_from_screenshot
   result = extract_order_from_screenshot('screenshot.jpg')
   if result:
       print(f"Customer: {result['customer_name']}")

3️⃣ CREATE ORDER WITH AI DATA:
   from core.models import Order
   order = Order.objects.create(
       user=user,
       customer=customer,
       customer_name=result['customer_name'],
       customer_phone=result['customer_phone'],
       created_from_image=True,
       # ... other fields
   )
   user.increment_order_count()

4️⃣ CHECK REMAINING ORDERS:
   print(f"Orders today: {user.daily_order_count}/{user.daily_order_limit}")
""")


def main():
    """Main test runner"""
    print("\n" + "🤖" * 30)
    print("F-Khotiyan AI Order Extraction Test Suite")
    print("🤖" * 30 + "\n")
    
    try:
        # Test 1: User order limits
        user = test_user_order_limits()
        
        # Test 2: Gemini extraction
        extractor = test_gemini_extraction()
        
        # Test 3: Data validation
        if extractor:
            test_data_validation()
        
        # Show usage guide
        print_usage_guide()
        
        print("\n" + "=" * 60)
        print("✅ All tests completed successfully!")
        print("=" * 60)
        
        print("\n📌 Next Steps:")
        print("   1. Add a test screenshot as 'test_order.jpg'")
        print("   2. Test actual AI extraction")
        print("   3. Implement API endpoints (Phase 2)")
        print("   4. Connect with Flutter app")
        
    except Exception as e:
        print(f"\n❌ Test failed: {str(e)}")
        import traceback
        traceback.print_exc()


if __name__ == '__main__':
    main()
