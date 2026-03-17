# Testing Gemini AI Order Extraction - Quick Start

## 🚀 Quick Test Guide

### Step 1: Verify Setup
```bash
python test_ai_features.py
```

This will test:
- ✅ User order limits (5 orders/day for free users)
- ✅ Gemini AI initialization
- ✅ Data validation

### Step 2: Test with Real Screenshot

#### Create a Test Screenshot

Take a screenshot of a message with this format:

```
Customer Name: মোঃ আহমেদ
Phone: 01712345678
Address: ১২৩ রোড ৫, ধানমন্ডি, ঢাকা ১২০৯

Products:
- Premium T-Shirt (Black XL) x2 = 900 BDT
- Denim Jeans (Blue 32) x1 = 1500 BDT

Subtotal: 2400 BDT
Delivery: 60 BDT
Discount: 100 BDT
Total: 2360 BDT

Note: Please deliver before 5 PM
Courier: Pathao preferred
```

Save it as `test_order.jpg` in the project root.

### Step 3: Run Extraction Test

```python
python manage.py shell

from core.gemini_service import extract_order_from_screenshot

# Extract order
result = extract_order_from_screenshot('test_order.jpg')

# Print result
if result:
    print("✅ Extraction successful!")
    print(f"Customer: {result['customer_name']}")
    print(f"Phone: {result['customer_phone']}")
    print(f"Address: {result['customer_address']}")
    print(f"Products: {len(result['products'])}")
    for p in result['products']:
        print(f"  - {p['product_name']}: {p['quantity']} x {p['price']} BDT")
    print(f"Total: {result['total_amount']} BDT")
else:
    print("❌ Extraction failed")
```

### Step 4: Test Order Limit

```python
from core.models import User

# Get test user
user = User.objects.get(phone_number='01700000001')

# Check limit
print(f"Can create order: {user.can_create_order()}")
print(f"Orders today: {user.daily_order_count}/{user.daily_order_limit}")

# Simulate creating orders
for i in range(7):
    if user.can_create_order():
        user.increment_order_count()
        print(f"Order {i+1}: Created ✅")
    else:
        print(f"Order {i+1}: Limit reached ❌")
```

---

## 📱 Sample Screenshots to Test

### Bengali Order Message
```
নাম: মোঃ রহিম উদ্দিন
ফোন: ০১৮১২৩৪৫৬৭৮
ঠিকানা: বাড়ি নং ৪৫, রোড ৩, মিরপুর, ঢাকা

পণ্য:
১. কালো টি-শার্ট (এক্সএল) - ২টি = ৯০০ টাকা
২. নীল জিন্স (৩২) - ১টি = ১২০০ টাকা

মোট: ২১০০ টাকা
ডেলিভারি চার্জ: ৬০ টাকা
সর্বমোট: ২১৬০ টাকা

বিঃদ্রঃ সন্ধ্যার পরে ডেলিভারি দিবেন
```

### English Order Message
```
Customer: Ahmed Khan
Contact: 01987654321
Delivery: House 78, Road 12, Banani, Dhaka

Items:
- White Shirt (M) qty: 3 @ 500 = 1500
- Black Pants (34) qty: 2 @ 800 = 1600

Item Total: 3100 TK
Shipping: 80 TK
Discount: 200 TK
Grand Total: 2980 TK

Special: Cash on delivery
Courier: Steadfast
```

### Mixed Language Order
```
Customer: মাহমুদ Sir
Phone: 01555666777
Address: Plot 23, Sector 7, Uttara, Dhaka

Order List:
1. Premium Shirt (Blue L) - 2pcs = 1200/-
2. Formal Pants (Black 34) - 1pc = 1500/-
3. Leather Belt (Brown) - 1pc = 800/-

Sub-total: 3500 টাকা
Delivery Charge: 100 টাকা
Total Payable: 3600 টাকা

Note: Office delivery between 9-5 PM
```

---

## 🎯 Expected Output Format

```json
{
  "customer_name": "মোঃ রহিম উদ্দিন",
  "customer_phone": "01812345678",
  "customer_address": "বাড়ি নং ৪৫, রোড ৩, মিরপুর, ঢাকা",
  "district": "Dhaka",
  "products": [
    {
      "product_name": "কালো টি-শার্ট (এক্সএল)",
      "quantity": 2,
      "price": 450.0
    },
    {
      "product_name": "নীল জিন্স (৩২)",
      "quantity": 1,
      "price": 1200.0
    }
  ],
  "total_amount": 2100.0,
  "delivery_charge": 60.0,
  "discount": 0.0,
  "notes": "সন্ধ্যার পরে ডেলিভারি দিবেন",
  "courier_preference": "self"
}
```

---

## 🧪 Validation Tests

### Test 1: Valid Data
```python
from core.gemini_service import GeminiOrderExtractor

extractor = GeminiOrderExtractor()

valid_data = {
    'customer_name': 'Test Customer',
    'customer_phone': '01712345678',
    'customer_address': '123 Test Road, Dhaka',
    'district': 'Dhaka',
    'products': [
        {'product_name': 'Product 1', 'quantity': 2, 'price': 100.00}
    ],
    'total_amount': 200.00,
    'delivery_charge': 60.00,
    'discount': 0.00,
    'notes': '',
    'courier_preference': 'self'
}

is_valid, errors = extractor.validate_order_data(valid_data)
print(f"Valid: {is_valid}")  # Should be True
print(f"Errors: {errors}")    # Should be []
```

### Test 2: Invalid Phone
```python
invalid_data = {
    'customer_name': 'Test Customer',
    'customer_phone': '12345',  # Too short
    'customer_address': '123 Test Road',
    'products': [
        {'product_name': 'Product 1', 'quantity': 1, 'price': 100}
    ],
    'total_amount': 100
}

is_valid, errors = extractor.validate_order_data(invalid_data)
print(f"Valid: {is_valid}")  # Should be False
print(f"Errors: {errors}")    # Should contain phone error
```

### Test 3: No Products
```python
no_products_data = {
    'customer_name': 'Test Customer',
    'customer_phone': '01712345678',
    'customer_address': '123 Test Road',
    'products': [],  # Empty
    'total_amount': 0
}

is_valid, errors = extractor.validate_order_data(no_products_data)
print(f"Valid: {is_valid}")  # Should be False
print(f"Errors: {errors}")    # Should require products
```

---

## 🐛 Troubleshooting

### Error: "GEMINI_API_KEY not found"
**Solution:**
```bash
# Add to .env file
GEMINI_API_KEY=AIzaSyAPeJt1PJ1Auz4aSdGHvkYtAj1bdhmbm5g
```

### Error: "Unable to extract order information"
**Possible causes:**
1. Image quality too low
2. Text not clearly visible
3. Unexpected format

**Solution:**
- Use clear, high-resolution screenshots
- Ensure text is readable
- Follow the sample formats above

### Error: "Daily limit reached"
**Expected behavior for free users:**
- After 5 orders, limit is reached
- Counter resets at midnight (Bangladesh time)

**Solution:**
- Upgrade to paid subscription for unlimited orders
- Or wait until next day

---

## 📊 Performance Benchmarks

| Test Case | Expected Time | Status |
|-----------|---------------|--------|
| Order limit check | < 0.01s | ✅ |
| Image upload | < 1s | ✅ |
| AI extraction | 2-5s | ✅ |
| Data validation | < 0.1s | ✅ |
| Order creation | < 0.5s | ✅ |

---

## ✅ Success Checklist

- [ ] Test file runs without errors
- [ ] User order limit works correctly
- [ ] Gemini AI initializes successfully
- [ ] Can extract data from test screenshot
- [ ] Bengali text is extracted correctly
- [ ] Phone number validation works
- [ ] Product list parsing works
- [ ] Daily limit enforcement works
- [ ] Free user limited to 5 orders
- [ ] Paid user has unlimited orders

---

## 🎉 Next Steps

Once all tests pass:
1. ✅ Create API endpoints (Phase 2)
2. ✅ Add authentication middleware
3. ✅ Implement Flutter integration
4. ✅ Add error handling
5. ✅ Deploy to production

---

**Happy Testing! 🚀**
