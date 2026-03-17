# F-Khotiyan API - URL Routes Reference

## 🔗 Complete URL Structure

### Base URL: `http://localhost:8000`

---

## 📋 Authentication Endpoints

### Register New User
```
POST /api/auth/register/

Body:
{
  "phone": "01712345678",
  "password": "SecurePass123",
  "password2": "SecurePass123",
  "name": "User Name"
}

Response: 201 Created
{
  "user": {
    "id": 1,
    "phone": "01712345678",
    "name": "User Name",
    "is_subscription_active": false,
    "daily_order_limit": 5
  },
  "access": "eyJ0eXAiOiJKV1QiLCJhbGc...",
  "refresh": "eyJ0eXAiOiJKV1QiLCJhbGc..."
}
```

### Login
```
POST /api/auth/login/

Body:
{
  "phone": "01712345678",
  "password": "SecurePass123"
}

Response: 200 OK
{
  "user": {...},
  "access": "token",
  "refresh": "token"
}
```

### Get Profile
```
GET /api/auth/profile/
Authorization: Bearer {access_token}

Response: 200 OK
{
  "id": 1,
  "phone": "01712345678",
  "name": "User Name",
  "email": "user@example.com",
  "sms_balance": 0,
  "is_subscription_active": false,
  "subscription_end_date": null,
  "daily_order_count": 0,
  "daily_order_limit": 5
}
```

### Update Profile
```
PUT /api/auth/profile/update/
Authorization: Bearer {access_token}

Body:
{
  "name": "Updated Name",
  "email": "newemail@example.com"
}
```

---

## 🤖 AI Order Extraction Endpoints

### Extract Order from Text/Image
```
POST /api/orders/extract/
Authorization: Bearer {access_token}

# Option 1: Extract from text
Body (JSON):
{
  "message_text": "আমার নাম রহিম। ফোন: 01812345678। ঠিকানা: ঢাকা, মিরপুর-১০। পণ্য: টিশার্ট ২টা"
}

# Option 2: Extract from image
Body (multipart/form-data):
screenshot: [image file]

Response: 200 OK
{
  "extracted_data": {
    "customer_name": "রহিম",
    "customer_phone": "01812345678",
    "district": "ঢাকা",
    "address": "মিরপুর-১০",
    "products": [
      {"name": "টিশার্ট", "quantity": 2}
    ]
  },
  "validation_errors": {},
  "daily_orders_remaining": 4
}
```

### Confirm AI-Extracted Order
```
POST /api/orders/confirm-ai-order/
Authorization: Bearer {access_token}

Body:
{
  "customer_name": "রহিম",
  "customer_phone": "01812345678",
  "district": "ঢাকা",
  "address": "মিরপুর-১০",
  "products": [
    {
      "name": "টিশার্ট",
      "quantity": 2,
      "price": 500
    }
  ],
  "delivery_cost": 60,
  "discount": 0,
  "note": "Order created from WhatsApp message"
}

Response: 201 Created
{
  "id": 1,
  "order_id": "ORD-20240310-0001",
  "customer": {...},
  "items": [...],
  "total_amount": 1060,
  "created_from_image": false,
  "created_at": "2024-03-10T10:30:00Z"
}
```

### Check Order Limit
```
GET /api/orders/limit-info/
Authorization: Bearer {access_token}

Response: 200 OK
{
  "daily_limit": 5,
  "orders_created_today": 2,
  "orders_remaining": 3,
  "can_create_order": true,
  "is_premium": false
}
```

---

## 📦 Product Management

### List Products
```
GET /api/products/
Authorization: Bearer {access_token}

Query Params:
- search: Search by name
- ordering: Sort by field (e.g., -created_at)
- page: Page number

Response: 200 OK
{
  "count": 10,
  "next": "http://localhost:8000/api/products/?page=2",
  "previous": null,
  "results": [
    {
      "id": 1,
      "name": "টিশার্ট",
      "buying_price": 300,
      "selling_price": 500,
      "stock": 50,
      "low_stock_threshold": 10,
      "is_low_stock": false
    }
  ]
}
```

### Create Product
```
POST /api/products/
Authorization: Bearer {access_token}

Body:
{
  "name": "টিশার্ট",
  "buying_price": 300,
  "selling_price": 500,
  "stock": 50,
  "low_stock_threshold": 10
}

Response: 201 Created
```

### Update Product
```
PUT /api/products/{id}/
Authorization: Bearer {access_token}

Body: Same as create
```

### Delete Product
```
DELETE /api/products/{id}/
Authorization: Bearer {access_token}

Response: 204 No Content
```

---

## 👥 Customer Management

### List Customers
```
GET /api/customers/
Authorization: Bearer {access_token}

Response: 200 OK
{
  "results": [
    {
      "id": 1,
      "name": "রহিম",
      "phone": "01812345678",
      "district": "ঢাকা",
      "address": "মিরপুর-১০",
      "total_orders": 5,
      "total_spent": 5000
    }
  ]
}
```

### Create Customer
```
POST /api/customers/
Authorization: Bearer {access_token}

Body:
{
  "name": "রহিম",
  "phone": "01812345678",
  "district": "ঢাকা",
  "address": "মিরপুর-১০"
}
```

---

## 📋 Order Management

### List Orders
```
GET /api/orders/
Authorization: Bearer {access_token}

Query Params:
- status: Filter by status (pending/processing/shipped/delivered/cancelled)
- search: Search by order_id or customer name
- ordering: Sort by field

Response: 200 OK
{
  "results": [
    {
      "id": 1,
      "order_id": "ORD-20240310-0001",
      "customer": {...},
      "items": [...],
      "status": "pending",
      "payment_status": "unpaid",
      "total_amount": 1060,
      "created_from_image": false,
      "qr_code": "/media/qr_codes/ORD-20240310-0001.png"
    }
  ]
}
```

### Create Order (Manual)
```
POST /api/orders/
Authorization: Bearer {access_token}

Body:
{
  "customer_name": "রহিম",
  "customer_phone": "01812345678",
  "district": "ঢাকা",
  "address": "মিরপুর-১০",
  "items": [
    {
      "product": 1,
      "quantity": 2,
      "price": 500
    }
  ],
  "delivery_cost": 60,
  "discount": 0
}
```

### Order Statistics
```
GET /api/orders/statistics/
Authorization: Bearer {access_token}

Response: 200 OK
{
  "total_orders": 50,
  "pending_orders": 10,
  "completed_orders": 35,
  "cancelled_orders": 5,
  "total_revenue": 50000,
  "total_profit": 15000,
  "ai_generated_orders": 30,
  "manual_orders": 20
}
```

---

## 💰 Expense Management

### List Expenses
```
GET /api/expenses/
Authorization: Bearer {access_token}

Response: 200 OK
{
  "results": [
    {
      "id": 1,
      "expense_date": "2024-03-10",
      "category": "marketing",
      "amount": 2000,
      "description": "Facebook Ads",
      "note": "Monthly campaign"
    }
  ]
}
```

### Create Expense
```
POST /api/expenses/
Authorization: Bearer {access_token}

Body:
{
  "expense_date": "2024-03-10",
  "category": "marketing",
  "amount": 2000,
  "description": "Facebook Ads"
}
```

---

## 📱 Courier Configuration

### List Courier Configs
```
GET /api/courier-configs/
Authorization: Bearer {access_token}

Response: 200 OK
{
  "results": [
    {
      "id": 1,
      "service_name": "Pathao",
      "inside_dhaka": 60,
      "outside_dhaka": 120,
      "is_active": true
    }
  ]
}
```

---

## 📲 SMS Management

### List SMS Purchases
```
GET /api/sms-purchases/
Authorization: Bearer {access_token}

Response: 200 OK
{
  "results": [
    {
      "id": 1,
      "sms_count": 1000,
      "price": 500,
      "purchase_date": "2024-03-10",
      "is_confirmed": true
    }
  ]
}
```

---

## 🔐 JWT Token Management

### Obtain Token Pair
```
POST /api/token/

Body:
{
  "phone": "01712345678",
  "password": "SecurePass123"
}

Response: 200 OK
{
  "access": "eyJ0eXAiOiJKV1QiLCJhbGc...",
  "refresh": "eyJ0eXAiOiJKV1QiLCJhbGc..."
}
```

### Refresh Access Token
```
POST /api/token/refresh/

Body:
{
  "refresh": "eyJ0eXAiOiJKV1QiLCJhbGc..."
}

Response: 200 OK
{
  "access": "new_access_token"
}
```

### Verify Token
```
POST /api/token/verify/

Body:
{
  "token": "eyJ0eXAiOiJKV1QiLCJhbGc..."
}

Response: 200 OK (if valid)
```

---

## 📚 API Documentation

### Swagger UI
```
GET /api/docs/
```
Interactive API documentation with "Try it out" feature

### ReDoc
```
GET /api/redoc/
```
Clean, readable API documentation

### OpenAPI Schema
```
GET /api/swagger.json
```
JSON schema for API clients

---

## ⚠️ Error Responses

### 400 Bad Request
```json
{
  "field_name": ["Error message"]
}
```

### 401 Unauthorized
```json
{
  "detail": "Authentication credentials were not provided."
}
```

### 403 Forbidden
```json
{
  "detail": "You do not have permission to perform this action."
}
```

### 404 Not Found
```json
{
  "detail": "Not found."
}
```

### 429 Too Many Requests
```json
{
  "detail": "Daily order limit reached. Upgrade to premium for unlimited orders."
}
```

### 500 Internal Server Error
```json
{
  "error": "Internal server error",
  "message": "Error details"
}
```

---

## 🔧 Authentication Header Format

All authenticated endpoints require:
```
Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGc...
```

---

## 💡 Tips

1. **Token Expiry**: Access tokens expire after 60 minutes. Use refresh token to get new access token.

2. **Pagination**: Most list endpoints support pagination. Use `?page=2` to get next page.

3. **Filtering**: Use query params like `?status=pending` to filter results.

4. **Search**: Use `?search=keyword` to search across relevant fields.

5. **Ordering**: Use `?ordering=-created_at` for descending order (newest first).

6. **Multi-tenant**: All data is automatically filtered by the authenticated user.

7. **Daily Limits**: Free users can create 5 AI orders per day. Limit resets at midnight.

8. **Image Upload**: Use `multipart/form-data` for file uploads (screenshot extraction).

---

## 📖 Related Documentation

- [Deployment Guide](DEPLOYMENT_GUIDE.md)
- [AI Order Creation](AI_ORDER_CREATION.md)
- [Database Schema](DATABASE_SETUP.md)
- [Testing Guide](TESTING_GUIDE.md)
