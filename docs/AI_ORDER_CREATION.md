# AI-Powered Order Creation Guide

## 🤖 Gemini AI Integration for Order Extraction

F-Khotiyan now supports **AI-powered order creation** from screenshots using Google Gemini Flash. Users can simply upload a screenshot of a message/order, and the system will automatically extract all order details.

---

## 🎯 Features

### 1. **AI Order Extraction**
- Upload screenshot of Facebook/WhatsApp/Messenger orders
- Automatically extracts:
  - Customer name
  - Phone number
  - Delivery address & district
  - Product list with quantities and prices
  - Total amount, delivery charge, discount
  - Special notes and courier preference
  - Bengali text support

### 2. **Manual Order Creation**
- Traditional form-based order entry
- Full control over all fields
- Product selection from inventory

### 3. **Daily Order Limits**
- **Free Users**: Maximum 5 orders per day
- **Paid Users** (Monthly/Yearly): Unlimited orders
- Automatic daily counter reset at midnight

---

## 📋 Order Creation Flow

### AI-Powered Creation (Screenshot Upload)

```
User uploads screenshot
       ↓
Gemini AI processes image
       ↓
Extracts order details (JSON)
       ↓
System validates data
       ↓
User reviews & confirms
       ↓
Order created with flag: created_from_image=True
       ↓
Daily order count incremented
```

### Manual Creation

```
User fills order form
       ↓
Selects products from inventory
       ↓
Enters customer details
       ↓
Reviews & submits
       ↓
Order created with flag: created_from_image=False
       ↓
Daily order count incremented
```

---

## 🔧 Technical Implementation

### Gemini Service ([core/gemini_service.py](core/gemini_service.py))

```python
from core.gemini_service import GeminiOrderExtractor

# Initialize extractor
extractor = GeminiOrderExtractor()

# Extract order from image
order_data = extractor.extract_order_from_image('path/to/screenshot.jpg')

# Validate extracted data
is_valid, errors = extractor.validate_order_data(order_data)

if is_valid:
    # Create order
    pass
else:
    # Show errors to user
    print(errors)
```

### User Order Limit Check

```python
from core.models import User

user = User.objects.get(phone_number='01712345678')

# Check if user can create order
if user.can_create_order():
    # Create order
    order = Order.objects.create(...)
    
    # Increment counter
    user.increment_order_count()
else:
    # Show limit reached message
    print(f"Daily limit reached: {user.daily_order_count}/{user.daily_order_limit}")
```

---

## 📊 Database Changes

### User Model - New Fields

```python
# Daily order tracking for free users
daily_order_count = models.IntegerField(default=0)
last_order_date = models.DateField(null=True, blank=True)
```

**Properties & Methods:**
- `daily_order_limit` - Returns 5 for free users, None for paid
- `can_create_order()` - Checks if user can create order today
- `increment_order_count()` - Increments daily counter

### Order Model - New Fields

```python
# AI tracking
created_from_image = models.BooleanField(default=False)
source_image = models.ImageField(upload_to='order_screenshots/')
```

---

## 🎨 Gemini Extraction Format

### Input: Screenshot Image
![Order Screenshot Example](https://via.placeholder.com/400x600/EEE/000?text=Message+Screenshot)

### Output: Structured JSON

```json
{
  "customer_name": "মোঃ রহিম উদ্দিন",
  "customer_phone": "01712345678",
  "customer_address": "বাড়ি নং ১২৩, রোড ৫, ধানমন্ডি",
  "district": "Dhaka",
  "products": [
    {
      "product_name": "Premium T-Shirt (Black - XL)",
      "quantity": 2,
      "price": 450.00
    },
    {
      "product_name": "Cotton Jeans (Blue - 32)",
      "quantity": 1,
      "price": 1200.00
    }
  ],
  "total_amount": 2100.00,
  "delivery_charge": 60.00,
  "discount": 100.00,
  "notes": "Delivery after 5 PM please",
  "courier_preference": "pathao"
}
```

---

## 🚀 API Implementation (Phase 2)

### Endpoint: Create Order from Screenshot

```python
# views.py
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import status
from core.gemini_service import GeminiOrderExtractor

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def create_order_from_image(request):
    """
    Create order from screenshot using AI
    """
    user = request.user
    
    # Check order limit
    if not user.can_create_order():
        return Response({
            'error': 'Daily order limit reached',
            'daily_limit': user.daily_order_limit,
            'orders_created_today': user.daily_order_count,
            'message': 'Upgrade to premium for unlimited orders'
        }, status=status.HTTP_429_TOO_MANY_REQUESTS)
    
    # Get uploaded image
    image = request.FILES.get('screenshot')
    if not image:
        return Response({
            'error': 'Screenshot image is required'
        }, status=status.HTTP_400_BAD_REQUEST)
    
    # Save image temporarily
    temp_path = handle_uploaded_file(image)
    
    try:
        # Extract order using Gemini
        extractor = GeminiOrderExtractor()
        order_data = extractor.extract_order_from_image(temp_path)
        
        if not order_data:
            return Response({
                'error': 'Failed to extract order from image',
                'message': 'Please try with a clearer screenshot or create order manually'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Validate extracted data
        is_valid, errors = extractor.validate_order_data(order_data)
        
        if not is_valid:
            return Response({
                'error': 'Validation failed',
                'details': errors,
                'extracted_data': order_data,
                'message': 'Please review and correct the details'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Return extracted data for user confirmation
        return Response({
            'success': True,
            'extracted_data': order_data,
            'message': 'Order details extracted successfully. Please review and confirm.'
        }, status=status.HTTP_200_OK)
        
    except Exception as e:
        return Response({
            'error': 'Internal error',
            'message': str(e)
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def confirm_ai_order(request):
    """
    Confirm and create order after AI extraction
    """
    user = request.user
    
    # Check order limit again
    if not user.can_create_order():
        return Response({
            'error': 'Daily order limit reached'
        }, status=status.HTTP_429_TOO_MANY_REQUESTS)
    
    order_data = request.data
    
    # Create or get customer
    customer, created = Customer.objects.get_or_create(
        user=user,
        phone_number=order_data['customer_phone'],
        defaults={
            'customer_name': order_data['customer_name'],
            'address': order_data['customer_address'],
            'district': order_data['district']
        }
    )
    
    # Create order
    order = Order.objects.create(
        user=user,
        customer=customer,
        customer_name=order_data['customer_name'],
        customer_phone=order_data['customer_phone'],
        customer_address=order_data['customer_address'],
        total_amount=order_data['total_amount'],
        delivery_charge=order_data['delivery_charge'],
        discount=order_data['discount'],
        grand_total=order_data['total_amount'] + order_data['delivery_charge'] - order_data['discount'],
        courier_type=order_data.get('courier_preference', 'self'),
        notes=order_data.get('notes', ''),
        created_from_image=True,
        source_image=request.FILES.get('screenshot')
    )
    
    # Create order items (match with existing products or create note)
    for product_data in order_data['products']:
        OrderItem.objects.create(
            order=order,
            product_name=product_data['product_name'],
            quantity=product_data['quantity'],
            selling_price=product_data['price'],
            purchase_price=0,  # Will be matched later
            subtotal=product_data['quantity'] * product_data['price']
        )
    
    # Increment user's order count
    user.increment_order_count()
    
    return Response({
        'success': True,
        'order_number': order.order_number,
        'order_id': order.id,
        'daily_orders_used': user.daily_order_count,
        'daily_limit': user.daily_order_limit
    }, status=status.HTTP_201_CREATED)
```

---

## 📱 Flutter Integration Example

```dart
// Order creation from screenshot
Future<Map<String, dynamic>> createOrderFromScreenshot(File imageFile) async {
  try {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/orders/create-from-image/'),
    );
    
    request.headers['Authorization'] = 'Bearer $accessToken';
    request.files.add(
      await http.MultipartFile.fromPath('screenshot', imageFile.path),
    );
    
    var response = await request.send();
    var responseData = await response.stream.bytesToString();
    var data = json.decode(responseData);
    
    if (response.statusCode == 200) {
      // Show extracted data for confirmation
      return {
        'success': true,
        'data': data['extracted_data']
      };
    } else if (response.statusCode == 429) {
      // Daily limit reached
      return {
        'success': false,
        'error': 'daily_limit_reached',
        'message': data['message']
      };
    } else {
      return {
        'success': false,
        'error': data['error']
      };
    }
  } catch (e) {
    return {
      'success': false,
      'error': e.toString()
    };
  }
}
```

---

## ⚙️ Configuration

### 1. Add to `.env`

```env
GEMINI_API_KEY=AIzaSyAPeJt1PJ1Auz4aSdGHvkYtAj1bdhmbm5g
GEMINI_MODEL=gemini-1.5-flash
```

### 2. Install Dependencies

```bash
pip install google-generativeai==0.3.2
```

### 3. Run Migrations

```bash
python manage.py makemigrations
python manage.py migrate
```

---

## 🎯 Order Limit Logic

### Free Users (Free Plan)
- **Limit**: 5 orders per day
- **Reset**: Automatic at midnight (Bangladesh time)
- **Tracking**: `daily_order_count` and `last_order_date`
- **Enforcement**: Both API endpoints and UI check limit

### Paid Users (Monthly/Yearly)
- **Limit**: Unlimited orders
- **Tracking**: Still tracked for analytics
- **No enforcement**: Can create unlimited orders

### Upgrade Flow
```
Free User (5 orders limit)
       ↓
Hits limit (5th order)
       ↓
Shows upgrade prompt
       ↓
Purchases subscription
       ↓
Unlimited orders unlocked
```

---

## 📊 Admin Features

### Order List
- **AI Created Badge**: 🤖 AI or 👤 Manual
- **Filter**: View only AI-created orders
- **Source Screenshot**: View original image used

### User Dashboard
- **Daily Orders**: Shows X/5 for free users
- **Color Coded**: 
  - Green: Under limit
  - Red: Limit reached
- **Unlimited**: For paid users

---

## 🛠️ Testing

### Test Order Limit

```python
from core.models import User
from django.utils import timezone

user = User.objects.get(phone_number='01712345678')
print(f"Can create order: {user.can_create_order()}")
print(f"Orders today: {user.daily_order_count}/{user.daily_order_limit}")

# Simulate creating orders
for i in range(6):
    if user.can_create_order():
        # Create order
        user.increment_order_count()
        print(f"Order {i+1} created")
    else:
        print(f"Limit reached after {i} orders")
```

### Test AI Extraction

```python
from core.gemini_service import extract_order_from_screenshot

# Test with screenshot
result = extract_order_from_screenshot('path/to/test_screenshot.jpg')

if result:
    print("Extracted successfully:")
    print(f"Customer: {result['customer_name']}")
    print(f"Phone: {result['customer_phone']}")
    print(f"Products: {len(result['products'])}")
    print(f"Total: {result['total_amount']}")
else:
    print("Extraction failed")
```

---

## 🚨 Error Handling

### Common Scenarios

1. **No API Key**
   ```
   Error: GEMINI_API_KEY not found in settings
   Solution: Add API key to .env file
   ```

2. **Daily Limit Reached**
   ```
   HTTP 429: Daily order limit reached
   Response: Upgrade prompt with subscription plans
   ```

3. **Invalid Image**
   ```
   Error: Unable to extract order information
   Solution: Request clearer screenshot or manual entry
   ```

4. **Validation Failed**
   ```
   Error: Missing required fields
   Response: Show extracted data with errors for correction
   ```

---

## 📈 Future Enhancements

- [ ] Multi-language support (Bengali OCR improvement)
- [ ] Automatic product matching with inventory
- [ ] Bulk order creation from multiple screenshots
- [ ] Voice-to-order conversion
- [ ] WhatsApp Business API integration
- [ ] Facebook Marketplace order sync

---

## 🎉 Benefits

### For Users
- ⚡ **Fast order entry** - No manual typing
- 📱 **Mobile-first** - Upload from phone gallery
- 🌐 **Bengali support** - Works with Bengali text
- 🎯 **Accurate** - AI reduces entry errors
- 💰 **Free tier** - Test before subscribing

### For Business
- 📊 **Higher conversion** - Easier to process orders
- ⏰ **Time saving** - 10x faster data entry
- 📈 **Scalability** - Handle more orders
- 💡 **Smart insights** - Track AI vs manual orders

---

**Powered by Google Gemini Flash AI** 🤖
