# F-Khotiyan Database Model Relationships

## Entity Relationship Diagram (Text Format)

```
┌─────────────────────────────────────────────────────────────────────┐
│                          USER (AbstractUser)                         │
│  - phone_number (PK, unique, 11 digits)                             │
│  - business_name, owner_name                                         │
│  - location, district, country (default: Bangladesh)                │
│  - subscription_type (free/monthly/yearly)                           │
│  - subscription_start_date, subscription_end_date                    │
│  - sms_balance                                                       │
│  - logo                                                              │
│  - created_at, updated_at                                            │
└───────────────────────────┬─────────────────────────────────────────┘
                            │
                            │ (One-to-Many)
        ┌───────────────────┼───────────────────┐
        │                   │                   │
        ▼                   ▼                   ▼
┌───────────────┐   ┌───────────────┐   ┌───────────────┐
│   PRODUCT     │   │   CUSTOMER    │   │    EXPENSE    │
├───────────────┤   ├───────────────┤   ├───────────────┤
│ - user_id (FK)│   │ - user_id (FK)│   │ - user_id (FK)│
│ - product_name│   │ - name        │   │ - category    │
│ - sku         │   │ - phone       │   │   (rent, etc.)│
│ - category    │   │ - address     │   │ - amount      │
│ - purchase_pr │   │ - district    │   │ - description │
│ - selling_pr  │   │ - is_fake     │   │ - expense_date│
│ - quantity    │   │ - fake_reason │   │ - created_at  │
│ - reorder_lvl │   │ - total_orders│   └───────────────┘
│ - unit        │   │ - total_amount│
│ - description │   │ - created_at  │   ┌───────────────┐
│ - image       │   └───────┬───────┘   │ COURIERCONFIG │
│ - is_active   │           │           ├───────────────┤
│ - created_at  │           │           │ - user_id (FK)│
└──────┬────────┘           │           │ - courier_name│
       │                    │           │   (pathao/    │
       │                    │           │   steadfast)  │
       │                    │           │ - api_key     │
       │                    │           │ - api_secret  │
       │                    │           │ - client_id   │
       │          ┌─────────▼────────┐  │ - client_sec  │
       │          │      ORDER       │  │ - store_id    │
       │          ├──────────────────┤  │ - is_active   │
       │          │ - order_number   │  │ - created_at  │
       │          │ - user_id (FK)   │  └───────────────┘
       │          │ - customer_id FK │
       │          │ - customer_name  │  ┌───────────────┐
       │          │ - customer_phone │  │  SMSPURCHASE  │
       │          │ - customer_addr  │  ├───────────────┤
       │          │ - order_date     │  │ - user_id (FK)│
       │          │ - total_amount   │  │ - quantity    │
       │          │ - discount       │  │ - total_price │
       │          │ - delivery_chrg  │  │ - bkash_trx_id│
       │          │ - grand_total    │  │ - payment_sts │
       │          │ - payment_status │  │ - confirmed   │
       │          │ - order_status   │  │ - confirmed_at│
       │          │ - courier_type   │  │ - created_at  │
       │          │   (self/pathao/  │  └───────────────┘
       │          │   steadfast)     │
       │          │ - tracking_id    │  ┌───────────────┐
       │          │ - qr_code        │  │    SMSLOG     │
       │          │ - notes          │  ├───────────────┤
       │          │ - sms_sent       │  │ - user_id (FK)│
       │          │ - invoice_pdf    │  │ - order_id FK │
       │          │ - created_at     │  │ - phone_number│
       │          └────────┬─────────┘  │ - message     │
       │                   │            │ - status      │
       │                   │            │   (sent/fail) │
       │         ┌─────────┴────────┐   │ - sent_at     │
       │         ├──────────────────┤   └───────────────┘
       │         │   ORDER_ITEM     │
       │         ├──────────────────┤   ┌───────────────┐
       └────────►│ - order_id (FK)  │   │ SUBSCRIPTION  │
                 │ - product_id FK  │   ├───────────────┤
                 │ - product_name   │   │ - user_id (FK)│
                 │ - quantity       │   │ - plan_type   │
                 │ - purchase_price │   │   (monthly/   │
                 │ - selling_price  │   │   yearly)     │
                 │ - subtotal       │   │ - amount      │
                 └──────────────────┘   │ - payment_mth │
                                        │ - transaction │
                 ┌──────────────────┐   │ - start_date  │
                 │     RETURN       │   │ - end_date    │
                 ├──────────────────┤   │ - is_active   │
                 │ - order_id (FK)  │   │ - created_at  │
                 │ - user_id (FK)   │   └───────────────┘
                 │ - return_date    │
                 │ - return_amount  │
                 │ - reason         │
                 │ - status         │
                 │   (pending/      │
                 │   approved/      │
                 │   rejected)      │
                 │ - created_at     │
                 └──────────────────┘
```

## Relationship Summary

### User Relationships (Hub Model)
**USER** is the central model with one-to-many relationships to:
- `Product` (CASCADE) - Products belong to a user
- `Customer` (CASCADE) - Customers belong to a user
- `Order` (CASCADE) - Orders belong to a user
- `Expense` (CASCADE) - Expenses belong to a user
- `CourierConfig` (CASCADE) - Courier configs belong to a user
- `SMSPurchase` (CASCADE) - SMS purchases belong to a user
- `SMSLog` (CASCADE) - SMS logs belong to a user
- `Subscription` (CASCADE) - Subscriptions belong to a user
- `Return` (CASCADE) - Returns belong to a user

### Order Relationships
**ORDER** has:
- Many-to-One with `User` (CASCADE)
- Many-to-One with `Customer` (RESTRICT - can't delete customer with orders)
- One-to-Many with `OrderItem` (CASCADE - delete items when order deleted)
- One-to-Many with `SMSLog` (SET_NULL - keep logs if order deleted)
- One-to-Many with `Return` (RESTRICT - can't delete order with returns)

### Product Relationships
**PRODUCT** has:
- Many-to-One with `User` (CASCADE)
- One-to-Many with `OrderItem` (RESTRICT - can't delete product in orders)

### OrderItem Relationships
**ORDERITEM** has:
- Many-to-One with `Order` (CASCADE)
- Many-to-One with `Product` (RESTRICT)

## Deletion Behaviors

| Parent Model | Child Model    | On Delete Behavior |
|--------------|----------------|-------------------|
| User         | Product        | CASCADE           |
| User         | Customer       | CASCADE           |
| User         | Order          | CASCADE           |
| User         | Expense        | CASCADE           |
| User         | CourierConfig  | CASCADE           |
| User         | SMSPurchase    | CASCADE           |
| User         | SMSLog         | CASCADE           |
| User         | Subscription   | CASCADE           |
| User         | Return         | CASCADE           |
| Customer     | Order          | RESTRICT          |
| Product      | OrderItem      | RESTRICT          |
| Order        | OrderItem      | CASCADE           |
| Order        | SMSLog         | SET_NULL          |
| Order        | Return         | RESTRICT          |

**CASCADE**: Delete child records when parent is deleted  
**RESTRICT**: Prevent deletion if child records exist  
**SET_NULL**: Set foreign key to NULL when parent deleted

## Data Isolation (Multi-Tenancy)

All user data is isolated by the `user_id` foreign key:

```python
# Example: Get all products for a specific user
user_products = Product.objects.filter(user=current_user)

# Example: Get all orders for a specific user
user_orders = Order.objects.filter(user=current_user)

# PostgreSQL Row Level Security equivalent:
# All queries automatically filtered by user_id
```

## Indexes for Performance

### User Model
- `phone_number` (Unique Index)
- `subscription_end_date` (B-Tree Index)
- `created_at` (B-Tree Index)

### Product Model
- `(user, sku)` (Composite Index)
- `(user, product_name)` (Composite Index)
- `created_at` (B-Tree Index)

### Customer Model
- `(user, phone_number)` (Composite Index)
- `(user, is_fake)` (Composite Index)

### Order Model
- `(user, order_date)` (Composite Index)
- `order_number` (Unique Index)
- `(user, order_status)` (Composite Index)

### Expense Model
- `(user, expense_date)` (Composite Index)
- `(user, category)` (Composite Index)

## Unique Constraints

1. **User.phone_number** - Unique across all users
2. **Order.order_number** - Unique across all orders
3. **(Product.user, Product.sku)** - SKU unique per user
4. **(CourierConfig.user, CourierConfig.courier_name)** - One config per courier per user

## Choice Fields (ENUM-like)

### User Model
- `subscription_type`: free, monthly, yearly

### Order Model
- `payment_status`: pending, partial, paid
- `order_status`: pending, processing, shipped, delivered, cancelled, returned
- `courier_type`: self, pathao, steadfast

### Expense Model
- `category`: rent, utility, transport, salary, advertisement, delivery, purchase, maintenance, other

### CourierConfig Model
- `courier_name`: pathao, steadfast

### SMSPurchase Model
- `payment_status`: pending, confirmed, failed

### SMSLog Model
- `status`: sent, failed

### Subscription Model
- `plan_type`: monthly, yearly

### Return Model
- `status`: pending, approved, rejected

## Calculated Properties

### Product Model
- `is_low_stock` - Returns True if quantity ≤ reorder_level
- `profit_margin` - Calculates percentage profit margin

### OrderItem Model
- `profit` - Calculates profit for the order item

### User Model
- `is_subscription_active` - Checks if subscription is active

## Automatic Fields

All models include:
- `created_at` - Auto-set on creation
- `updated_at` - Auto-updated on modification (where applicable)

---

**This diagram represents the complete Phase 1 database architecture.**
