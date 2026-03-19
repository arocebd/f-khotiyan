"""
F-Khotiyan SaaS Application Models
Multi-tenant Business Management System
Author: Senior Backend Developer
Created: March 10, 2026
"""

from django.db import models
from django.contrib.auth.models import AbstractUser, BaseUserManager
from django.core.validators import MinLengthValidator, MaxLengthValidator, MinValueValidator
from django.utils import timezone
from django.utils.translation import gettext_lazy as _
import uuid
import datetime


# ==================== CUSTOM USER MANAGER ====================

class UserManager(BaseUserManager):
    """Custom user manager for phone-based authentication"""
    
    def create_user(self, phone_number, password=None, **extra_fields):
        """Create and return a regular user with phone number"""
        if not phone_number:
            raise ValueError('Phone number is required')
        
        extra_fields.setdefault('is_staff', False)
        extra_fields.setdefault('is_superuser', False)
        
        user = self.model(phone_number=phone_number, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user
    
    def create_superuser(self, phone_number, password=None, **extra_fields):
        """Create and return a superuser with phone number"""
        extra_fields.setdefault('is_staff', True)
        extra_fields.setdefault('is_superuser', True)
        extra_fields.setdefault('is_active', True)
        
        if extra_fields.get('is_staff') is not True:
            raise ValueError('Superuser must have is_staff=True.')
        if extra_fields.get('is_superuser') is not True:
            raise ValueError('Superuser must have is_superuser=True.')
        
        return self.create_user(phone_number, password, **extra_fields)


# ==================== AUTHENTICATION & USER MANAGEMENT ====================

class User(AbstractUser):
    """
    Custom User model extending AbstractUser for multi-tenant SaaS architecture.
    Each user represents a business owner with their own isolated data.
    """
    
    # Use custom manager
    objects = UserManager()
    
    # Business Information
    business_name = models.CharField(
        max_length=255,
        blank=True,
        default='',
        verbose_name=_("Business Name"),
        help_text=_("Name of the business")
    )
    owner_name = models.CharField(
        max_length=255,
        blank=True,
        default='',
        verbose_name=_("Owner Name"),
        help_text=_("Full name of the business owner")
    )
    
    # Location Details
    location = models.CharField(
        max_length=255,
        blank=True,
        default='',
        verbose_name=_("Location/Address"),
        help_text=_("Full business address")
    )
    district = models.CharField(
        max_length=100,
        blank=True,
        default='',
        verbose_name=_("District"),
        help_text=_("District name")
    )
    country = models.CharField(
        max_length=100,
        default="Bangladesh",
        verbose_name=_("Country")
    )
    
    # Contact Information
    phone_number = models.CharField(
        max_length=11,
        unique=True,
        validators=[MinLengthValidator(11), MaxLengthValidator(11)],
        verbose_name=_("Phone Number"),
        help_text=_("11-digit phone number (unique)")
    )
    
    # Business Logo
    logo = models.ImageField(
        upload_to='business_logos/',
        null=True,
        blank=True,
        verbose_name=_("Business Logo")
    )
    
    # Subscription Details
    SUBSCRIPTION_CHOICES = [
        ('free', 'Free Plan'),
        ('monthly', 'Monthly Subscription'),
        ('yearly', 'Yearly Subscription'),
    ]
    
    subscription_type = models.CharField(
        max_length=20,
        choices=SUBSCRIPTION_CHOICES,
        default='free',
        verbose_name=_("Subscription Type")
    )
    subscription_start_date = models.DateTimeField(
        null=True,
        blank=True,
        verbose_name=_("Subscription Start Date")
    )
    subscription_end_date = models.DateTimeField(
        null=True,
        blank=True,
        verbose_name=_("Subscription Expiry Date")
    )
    
    # SMS Balance (legacy count-based, kept for migration compatibility)
    sms_balance = models.IntegerField(
        default=0,
        validators=[MinValueValidator(0)],
        verbose_name=_("SMS Balance"),
        help_text=_("Remaining SMS credits")
    )

    # Wallet (monetary, in BDT)
    wallet_balance = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=0,
        validators=[MinValueValidator(0)],
        verbose_name=_("Wallet Balance"),
        help_text=_("Wallet balance in BDT")
    )

    # SMS Sender ID (user's registered sender ID on bulksmsbd.net)
    sms_sender_id = models.CharField(
        max_length=50,
        blank=True,
        default='',
        verbose_name=_("SMS Sender ID"),
        help_text=_("Registered sender ID on bulksmsbd.net")
    )

    # AI free uses remaining (resets to 0 after first use beyond limit)
    ai_free_uses_remaining = models.IntegerField(
        default=3,
        validators=[MinValueValidator(0)],
        verbose_name=_("AI Free Uses Remaining"),
        help_text=_("Free AI order creation uses remaining")
    )
    
    # Daily Order Limit Tracking (for free users)
    daily_order_count = models.IntegerField(
        default=0,
        validators=[MinValueValidator(0)],
        verbose_name=_("Daily Order Count"),
        help_text=_("Number of orders created today")
    )
    last_order_date = models.DateField(
        null=True,
        blank=True,
        verbose_name=_("Last Order Date"),
        help_text=_("Date of last order creation")
    )
    
    # Timestamps
    created_at = models.DateTimeField(
        auto_now_add=True,
        verbose_name=_("Created At")
    )
    updated_at = models.DateTimeField(
        auto_now=True,
        verbose_name=_("Updated At")
    )
    
    # Override username field - not used, phone_number is the identifier
    username = None
    
    USERNAME_FIELD = 'phone_number'
    REQUIRED_FIELDS = []  # Only phone_number and password are required for createsuperuser
    
    class Meta:
        db_table = 'users'
        verbose_name = _("User")
        verbose_name_plural = _("Users")
        indexes = [
            models.Index(fields=['phone_number']),
            models.Index(fields=['subscription_end_date']),
            models.Index(fields=['created_at']),
        ]
    
    def __str__(self):
        return f"{self.business_name} ({self.phone_number})"
    
    @property
    def is_subscription_active(self):
        """Check if user's subscription is active"""
        if self.subscription_type == 'free':
            return True
        if self.subscription_end_date:
            return timezone.now() < self.subscription_end_date
        return False
    
    @property
    def is_premium(self):
        """Check if user has active premium subscription"""
        if self.subscription_type in ['monthly', 'yearly']:
            if self.subscription_end_date and timezone.now() < self.subscription_end_date:
                return True
        return False

    @property
    def daily_order_limit(self):
        """Get daily order limit based on subscription — unlimited for all"""
        return None  # All users: unlimited orders
    
    def can_create_order(self):
        """All users can create orders without limit"""
        return True
    
    def increment_order_count(self):
        """Increment daily order count"""
        from django.utils import timezone
        today = timezone.now().date()
        
        if self.last_order_date != today:
            self.daily_order_count = 1
            self.last_order_date = today
        else:
            self.daily_order_count += 1
        
        self.save(update_fields=['daily_order_count', 'last_order_date'])
    
    def save(self, *args, **kwargs):
        # Set username as phone_number if not provided
        if not self.username:
            self.username = self.phone_number
        super().save(*args, **kwargs)


# ==================== PRODUCT & INVENTORY MANAGEMENT ====================

class Product(models.Model):
    """
    Product/Stock management model for inventory tracking.
    Isolated per user for multi-tenant architecture.
    """
    
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='products',
        verbose_name=_("Business Owner")
    )
    
    # Product Information
    product_name = models.CharField(
        max_length=255,
        verbose_name=_("Product Name")
    )
    sku = models.CharField(
        max_length=100,
        verbose_name=_("SKU/Product Code"),
        help_text=_("Stock Keeping Unit"),
        blank=True,
        null=True
    )
    category = models.CharField(
        max_length=100,
        verbose_name=_("Category"),
        blank=True,
        null=True
    )
    
    # Pricing
    purchase_price = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        validators=[MinValueValidator(0)],
        verbose_name=_("Purchase Price"),
        help_text=_("Cost price per unit")
    )
    selling_price = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        validators=[MinValueValidator(0)],
        verbose_name=_("Selling Price"),
        help_text=_("Retail price per unit")
    )
    
    # Stock Management
    quantity = models.IntegerField(
        default=0,
        validators=[MinValueValidator(0)],
        verbose_name=_("Stock Quantity"),
        help_text=_("Available quantity in stock")
    )
    reorder_level = models.IntegerField(
        default=10,
        validators=[MinValueValidator(0)],
        verbose_name=_("Reorder Level"),
        help_text=_("Minimum stock level before reorder alert")
    )
    unit = models.CharField(
        max_length=50,
        default='pcs',
        verbose_name=_("Unit of Measurement"),
        help_text=_("e.g., pcs, kg, liter")
    )
    
    # Additional Information
    description = models.TextField(
        blank=True,
        null=True,
        verbose_name=_("Description")
    )
    image = models.ImageField(
        upload_to='product_images/',
        null=True,
        blank=True,
        verbose_name=_("Product Image")
    )
    
    # Status
    is_active = models.BooleanField(
        default=True,
        verbose_name=_("Is Active")
    )
    
    # Timestamps
    created_at = models.DateTimeField(
        auto_now_add=True,
        verbose_name=_("Created At")
    )
    updated_at = models.DateTimeField(
        auto_now=True,
        verbose_name=_("Updated At")
    )
    
    class Meta:
        db_table = 'products'
        verbose_name = _("Product")
        verbose_name_plural = _("Products")
        indexes = [
            models.Index(fields=['user', 'sku']),
            models.Index(fields=['user', 'product_name']),
            models.Index(fields=['created_at']),
        ]
        unique_together = [['user', 'sku']]
    
    def __str__(self):
        return f"{self.product_name} - {self.user.business_name}"
    
    @property
    def is_low_stock(self):
        """Check if product stock is below reorder level"""
        return self.quantity <= self.reorder_level
    
    @property
    def profit_margin(self):
        """Calculate profit margin percentage"""
        if self.purchase_price > 0:
            return ((self.selling_price - self.purchase_price) / self.purchase_price) * 100
        return 0


# ==================== CUSTOMER MANAGEMENT ====================

class Customer(models.Model):
    """
    Customer information model for order management.
    """
    
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='customers',
        verbose_name=_("Business Owner")
    )
    
    # Customer Information
    customer_name = models.CharField(
        max_length=255,
        verbose_name=_("Customer Name")
    )
    phone_number = models.CharField(
        max_length=15,
        verbose_name=_("Phone Number")
    )
    address = models.TextField(
        blank=True,
        null=True,
        verbose_name=_("Address")
    )
    district = models.CharField(
        max_length=100,
        blank=True,
        null=True,
        verbose_name=_("District")
    )
    
    # Fake Customer Detection
    is_fake = models.BooleanField(
        default=False,
        verbose_name=_("Is Fake Customer"),
        help_text=_("Mark as fake if customer is fraudulent")
    )
    fake_reason = models.TextField(
        blank=True,
        null=True,
        verbose_name=_("Reason for Marking as Fake")
    )
    
    # Statistics
    total_orders = models.IntegerField(
        default=0,
        verbose_name=_("Total Orders")
    )
    total_amount = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        default=0,
        verbose_name=_("Total Purchase Amount")
    )
    
    # Timestamps
    created_at = models.DateTimeField(
        auto_now_add=True,
        verbose_name=_("Created At")
    )
    updated_at = models.DateTimeField(
        auto_now=True,
        verbose_name=_("Updated At")
    )
    
    class Meta:
        db_table = 'customers'
        verbose_name = _("Customer")
        verbose_name_plural = _("Customers")
        indexes = [
            models.Index(fields=['user', 'phone_number']),
            models.Index(fields=['user', 'is_fake']),
        ]
    
    def __str__(self):
        return f"{self.customer_name} - {self.phone_number}"


# ==================== ORDER MANAGEMENT ====================

class Order(models.Model):
    """
    Order management model with courier integration support.
    """
    
    # Order Status Choices
    PAYMENT_STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('partial', 'Partial'),
        ('paid', 'Paid'),
    ]
    
    ORDER_STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('processing', 'Processing'),
        ('shipped', 'Shipped'),
        ('delivered', 'Delivered'),
        ('cancelled', 'Cancelled'),
        ('returned', 'Returned'),
    ]
    
    COURIER_TYPE_CHOICES = [
        ('self', 'Self Delivery'),
        ('pathao', 'Pathao'),
        ('steadfast', 'Steadfast'),
    ]
    
    # Order Identification
    order_number = models.CharField(
        max_length=50,
        unique=True,
        verbose_name=_("Order Number"),
        editable=False
    )
    
    # Relationships
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='orders',
        verbose_name=_("Business Owner")
    )
    customer = models.ForeignKey(
        Customer,
        on_delete=models.RESTRICT,
        related_name='orders',
        verbose_name=_("Customer")
    )
    
    # Customer Information (denormalized for order history)
    customer_name = models.CharField(
        max_length=255,
        verbose_name=_("Customer Name")
    )
    customer_phone = models.CharField(
        max_length=15,
        verbose_name=_("Customer Phone")
    )
    customer_address = models.TextField(
        verbose_name=_("Delivery Address")
    )
    
    # Order Details
    order_date = models.DateTimeField(
        default=timezone.now,
        verbose_name=_("Order Date")
    )
    
    # Pricing
    total_amount = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        validators=[MinValueValidator(0)],
        verbose_name=_("Total Amount")
    )
    discount = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=0,
        validators=[MinValueValidator(0)],
        verbose_name=_("Discount")
    )
    delivery_charge = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=0,
        validators=[MinValueValidator(0)],
        verbose_name=_("Delivery Charge")
    )
    grand_total = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        validators=[MinValueValidator(0)],
        verbose_name=_("Grand Total")
    )
    
    # Status
    payment_status = models.CharField(
        max_length=20,
        choices=PAYMENT_STATUS_CHOICES,
        default='pending',
        verbose_name=_("Payment Status")
    )
    order_status = models.CharField(
        max_length=20,
        choices=ORDER_STATUS_CHOICES,
        default='pending',
        verbose_name=_("Order Status")
    )
    
    # Courier Integration
    courier_type = models.CharField(
        max_length=20,
        choices=COURIER_TYPE_CHOICES,
        default='self',
        verbose_name=_("Courier Type")
    )
    courier_tracking_id = models.CharField(
        max_length=100,
        blank=True,
        null=True,
        verbose_name=_("Courier Tracking ID")
    )

    # Steadfast Courier Integration
    consignment_id = models.CharField(
        max_length=50,
        blank=True,
        null=True,
        verbose_name=_("Steadfast Consignment ID")
    )
    steadfast_tracking_code = models.CharField(
        max_length=50,
        blank=True,
        null=True,
        verbose_name=_("Steadfast Tracking Code")
    )
    steadfast_status = models.CharField(
        max_length=50,
        blank=True,
        null=True,
        verbose_name=_("Steadfast Delivery Status")
    )

    # QR Code for order tracking
    qr_code = models.ImageField(
        upload_to='order_qrcodes/',
        null=True,
        blank=True,
        verbose_name=_("QR Code")
    )
    
    # Additional Information
    notes = models.TextField(
        blank=True,
        null=True,
        verbose_name=_("Order Notes")
    )
    
    # AI-Generated Order Tracking
    created_from_image = models.BooleanField(
        default=False,
        verbose_name=_("Created from Image"),
        help_text=_("Order created using AI image extraction")
    )
    source_image = models.ImageField(
        upload_to='order_screenshots/',
        null=True,
        blank=True,
        verbose_name=_("Source Screenshot"),
        help_text=_("Original screenshot used to create order")
    )
    
    # Return Information
    RETURN_REASON_CHOICES = [
        ('defective', 'Defective Product'),
        ('wrong_item', 'Wrong Item Sent'),
        ('not_delivered', 'Not Delivered'),
        ('size_issue', 'Size / Color Issue'),
        ('customer_request', 'Customer Request'),
        ('other', 'Other'),
    ]
    return_reason = models.CharField(
        max_length=20,
        choices=RETURN_REASON_CHOICES,
        blank=True,
        null=True,
        verbose_name=_("Return Reason")
    )
    return_description = models.TextField(
        blank=True,
        null=True,
        verbose_name=_("Return Description")
    )

    # SMS Tracking
    sms_sent = models.BooleanField(
        default=False,
        verbose_name=_("SMS Sent")
    )
    
    # Invoice
    invoice_pdf = models.FileField(
        upload_to='invoices/',
        null=True,
        blank=True,
        verbose_name=_("Invoice PDF")
    )
    
    # Timestamps
    created_at = models.DateTimeField(
        auto_now_add=True,
        verbose_name=_("Created At")
    )
    updated_at = models.DateTimeField(
        auto_now=True,
        verbose_name=_("Updated At")
    )
    
    class Meta:
        db_table = 'orders'
        verbose_name = _("Order")
        verbose_name_plural = _("Orders")
        ordering = ['-order_date']
        indexes = [
            models.Index(fields=['user', 'order_date']),
            models.Index(fields=['order_number']),
            models.Index(fields=['user', 'order_status']),
        ]
    
    def __str__(self):
        return f"Order {self.order_number} - {self.customer_name}"
    
    def save(self, *args, **kwargs):
        # Generate unique order number if not exists
        if not self.order_number:
            self.order_number = self._generate_order_number()
        super().save(*args, **kwargs)
    
    def _generate_order_number(self):
        """Generate unique order number"""
        import random
        import string
        timestamp = timezone.now().strftime('%Y%m%d%H%M%S')
        random_str = ''.join(random.choices(string.ascii_uppercase + string.digits, k=4))
        return f"ORD{timestamp}{random_str}"


class OrderItem(models.Model):
    """
    Order items/line items for each order.
    """
    
    order = models.ForeignKey(
        Order,
        on_delete=models.CASCADE,
        related_name='items',
        verbose_name=_("Order")
    )
    product = models.ForeignKey(
        Product,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='order_items',
        verbose_name=_("Product")
    )
    
    # Product Information (denormalized for order history)
    product_name = models.CharField(
        max_length=255,
        verbose_name=_("Product Name")
    )
    
    # Quantity and Pricing
    quantity = models.IntegerField(
        validators=[MinValueValidator(1)],
        verbose_name=_("Quantity")
    )
    purchase_price = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        validators=[MinValueValidator(0)],
        verbose_name=_("Purchase Price")
    )
    selling_price = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        validators=[MinValueValidator(0)],
        verbose_name=_("Selling Price")
    )
    subtotal = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        validators=[MinValueValidator(0)],
        verbose_name=_("Subtotal")
    )
    
    class Meta:
        db_table = 'order_items'
        verbose_name = _("Order Item")
        verbose_name_plural = _("Order Items")
        indexes = [
            models.Index(fields=['order']),
        ]
    
    def __str__(self):
        return f"{self.product_name} x {self.quantity}"
    
    def save(self, *args, **kwargs):
        # Calculate subtotal
        self.subtotal = self.quantity * self.selling_price
        super().save(*args, **kwargs)
    
    @property
    def profit(self):
        """Calculate profit for this order item"""
        return (self.selling_price - self.purchase_price) * self.quantity


# ==================== EXPENSE MANAGEMENT ====================

class Expense(models.Model):
    """
    Expense tracking model for business expenditure management.
    """
    
    EXPENSE_CATEGORY_CHOICES = [
        ('rent', 'Rent'),
        ('utility', 'Utility Bills'),
        ('utilities', 'Utilities'),
        ('transport', 'Transport'),
        ('salary', 'Salary'),
        ('advertisement', 'Advertisement'),
        ('marketing', 'Marketing'),
        ('delivery', 'Delivery'),
        ('shipping', 'Shipping'),
        ('packaging', 'Packaging'),
        ('purchase', 'Product Purchase'),
        ('maintenance', 'Maintenance'),
        ('other', 'Other'),
    ]
    
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='expenses',
        verbose_name=_("Business Owner")
    )
    
    # Expense Details
    category = models.CharField(
        max_length=20,
        choices=EXPENSE_CATEGORY_CHOICES,
        verbose_name=_("Expense Category")
    )
    amount = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        validators=[MinValueValidator(0)],
        verbose_name=_("Amount")
    )
    description = models.TextField(
        blank=True,
        null=True,
        verbose_name=_("Description")
    )
    expense_date = models.DateField(
        default=datetime.date.today,
        verbose_name=_("Expense Date")
    )
    
    # Timestamps
    created_at = models.DateTimeField(
        auto_now_add=True,
        verbose_name=_("Created At")
    )
    updated_at = models.DateTimeField(
        auto_now=True,
        verbose_name=_("Updated At")
    )
    
    class Meta:
        db_table = 'expenses'
        verbose_name = _("Expense")
        verbose_name_plural = _("Expenses")
        ordering = ['-expense_date']
        indexes = [
            models.Index(fields=['user', 'expense_date']),
            models.Index(fields=['user', 'category']),
        ]
    
    def __str__(self):
        return f"{self.category} - {self.amount} BDT on {self.expense_date}"


# ==================== COURIER CONFIGURATION ====================

class CourierConfig(models.Model):
    """
    Store API credentials for courier services (Pathao, Steadfast).
    Encrypted storage recommended for production.
    """
    
    COURIER_CHOICES = [
        ('pathao', 'Pathao'),
        ('steadfast', 'Steadfast'),
    ]
    
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='courier_configs',
        verbose_name=_("Business Owner")
    )
    
    # Courier Details
    courier_name = models.CharField(
        max_length=20,
        choices=COURIER_CHOICES,
        verbose_name=_("Courier Name")
    )
    
    # API Credentials (Consider encryption in production)
    api_key = models.CharField(
        max_length=255,
        blank=True,
        null=True,
        verbose_name=_("API Key")
    )
    api_secret = models.CharField(
        max_length=255,
        blank=True,
        null=True,
        verbose_name=_("API Secret")
    )
    client_id = models.CharField(
        max_length=255,
        blank=True,
        null=True,
        verbose_name=_("Client ID")
    )
    client_secret = models.CharField(
        max_length=255,
        blank=True,
        null=True,
        verbose_name=_("Client Secret")
    )
    
    # Additional Config
    store_id = models.CharField(
        max_length=100,
        blank=True,
        null=True,
        verbose_name=_("Store ID")
    )

    # Pathao OAuth tokens
    pathao_access_token = models.TextField(blank=True, null=True, verbose_name=_("Pathao Access Token"))
    pathao_refresh_token = models.TextField(blank=True, null=True, verbose_name=_("Pathao Refresh Token"))
    pathao_token_expires_at = models.DateTimeField(blank=True, null=True, verbose_name=_("Pathao Token Expires At"))
    pathao_is_sandbox = models.BooleanField(default=True, verbose_name=_("Pathao Sandbox Mode"))

    # Status
    is_active = models.BooleanField(
        default=True,
        verbose_name=_("Is Active")
    )
    
    # Timestamps
    created_at = models.DateTimeField(
        auto_now_add=True,
        verbose_name=_("Created At")
    )
    updated_at = models.DateTimeField(
        auto_now=True,
        verbose_name=_("Updated At")
    )
    
    class Meta:
        db_table = 'courier_configs'
        verbose_name = _("Courier Configuration")
        verbose_name_plural = _("Courier Configurations")
        unique_together = [['user', 'courier_name']]
    
    def __str__(self):
        return f"{self.courier_name} - {self.user.business_name}"


# ==================== SMS MANAGEMENT ====================

class SMSPurchase(models.Model):
    """
    Track SMS package purchases by users.
    """
    
    PAYMENT_STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('confirmed', 'Confirmed'),
        ('failed', 'Failed'),
    ]
    
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='sms_purchases',
        verbose_name=_("Business Owner")
    )
    
    # Purchase Details
    quantity = models.IntegerField(
        validators=[MinValueValidator(1)],
        verbose_name=_("SMS Quantity"),
        help_text=_("Number of SMS credits purchased")
    )
    total_price = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        validators=[MinValueValidator(0)],
        verbose_name=_("Total Price")
    )
    
    # Payment Information
    bkash_transaction_id = models.CharField(
        max_length=100,
        blank=True,
        null=True,
        verbose_name=_("bKash Transaction ID")
    )
    payment_status = models.CharField(
        max_length=20,
        choices=PAYMENT_STATUS_CHOICES,
        default='pending',
        verbose_name=_("Payment Status")
    )
    
    # Admin Confirmation
    confirmed_by_admin = models.BooleanField(
        default=False,
        verbose_name=_("Confirmed by Admin")
    )
    confirmed_at = models.DateTimeField(
        null=True,
        blank=True,
        verbose_name=_("Confirmation Date")
    )
    
    # Timestamps
    created_at = models.DateTimeField(
        auto_now_add=True,
        verbose_name=_("Purchase Date")
    )
    
    class Meta:
        db_table = 'sms_purchases'
        verbose_name = _("SMS Purchase")
        verbose_name_plural = _("SMS Purchases")
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['user', 'payment_status']),
        ]
    
    def __str__(self):
        return f"{self.quantity} SMS - {self.user.business_name}"


class SMSLog(models.Model):
    """
    Log all SMS sent by the system.
    """

    STATUS_CHOICES = [
        ('sent', 'Sent'),
        ('failed', 'Failed'),
        ('pending', 'Pending'),
    ]

    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='sms_logs',
        verbose_name=_("Business Owner")
    )
    order = models.ForeignKey(
        Order,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='sms_logs',
        verbose_name=_("Related Order")
    )

    # SMS Details
    phone_number = models.CharField(
        max_length=20,
        verbose_name=_("Recipient Phone")
    )
    message = models.TextField(
        verbose_name=_("Message Content")
    )
    status = models.CharField(
        max_length=10,
        choices=STATUS_CHOICES,
        default='pending',
        verbose_name=_("Status")
    )
    failure_reason = models.TextField(
        blank=True,
        default='',
        verbose_name=_("Failure Reason")
    )

    # Billing
    sms_parts = models.PositiveSmallIntegerField(
        default=1,
        verbose_name=_("SMS Parts")
    )
    cost = models.DecimalField(
        max_digits=8,
        decimal_places=2,
        default=0,
        verbose_name=_("Cost (BDT)")
    )
    encoding = models.CharField(
        max_length=10,
        default='gsm7',
        verbose_name=_("Encoding"),
        help_text=_("gsm7 or unicode")
    )

    # Raw API response
    api_response = models.JSONField(
        null=True,
        blank=True,
        verbose_name=_("API Response")
    )

    # Timestamp
    sent_at = models.DateTimeField(
        auto_now_add=True,
        verbose_name=_("Sent At")
    )
    
    class Meta:
        db_table = 'sms_logs'
        verbose_name = _("SMS Log")
        verbose_name_plural = _("SMS Logs")
        ordering = ['-sent_at']
        indexes = [
            models.Index(fields=['user', 'sent_at']),
        ]
    
    def __str__(self):
        return f"SMS to {self.phone_number} - {self.status}"


# ==================== SUBSCRIPTION MANAGEMENT ====================

class Subscription(models.Model):
    """
    Track subscription payments and history.
    """
    
    PLAN_TYPE_CHOICES = [
        ('monthly', 'Monthly Plan'),
        ('yearly', 'Yearly Plan'),
    ]
    
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='subscriptions',
        verbose_name=_("Business Owner")
    )
    
    # Subscription Details
    plan_type = models.CharField(
        max_length=20,
        choices=PLAN_TYPE_CHOICES,
        verbose_name=_("Plan Type")
    )
    amount = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        validators=[MinValueValidator(0)],
        verbose_name=_("Amount Paid")
    )
    
    # Payment Information
    payment_method = models.CharField(
        max_length=50,
        default='bkash',
        verbose_name=_("Payment Method")
    )
    transaction_id = models.CharField(
        max_length=100,
        blank=True,
        null=True,
        verbose_name=_("Transaction ID")
    )
    
    # Subscription Period
    start_date = models.DateTimeField(
        verbose_name=_("Start Date")
    )
    end_date = models.DateTimeField(
        verbose_name=_("End Date")
    )
    
    # Status
    is_active = models.BooleanField(
        default=True,
        verbose_name=_("Is Active")
    )
    
    # Timestamp
    created_at = models.DateTimeField(
        auto_now_add=True,
        verbose_name=_("Created At")
    )
    
    class Meta:
        db_table = 'subscriptions'
        verbose_name = _("Subscription")
        verbose_name_plural = _("Subscriptions")
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['user', 'is_active']),
            models.Index(fields=['end_date']),
        ]
    
    def __str__(self):
        return f"{self.plan_type} - {self.user.business_name}"


# ==================== PRODUCT RETURN MANAGEMENT ====================

class Return(models.Model):
    """Track product returns and refunds."""

    RETURN_STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('approved', 'Approved'),
        ('rejected', 'Rejected'),
        ('refunded', 'Refunded'),
    ]

    RETURN_REASON_CHOICES = [
        ('defective', 'Defective Product'),
        ('wrong_item', 'Wrong Item Delivered'),
        ('not_delivered', 'Not Delivered'),
        ('size_issue', 'Size / Color Issue'),
        ('customer_request', 'Customer Request'),
        ('other', 'Other'),
    ]

    user = models.ForeignKey(
        User, on_delete=models.CASCADE, related_name='returns'
    )
    order = models.ForeignKey(
        Order, on_delete=models.CASCADE, related_name='returns'
    )
    return_number = models.CharField(max_length=50, unique=True, editable=False)
    reason = models.CharField(max_length=20, choices=RETURN_REASON_CHOICES)
    description = models.TextField(blank=True, default='')
    status = models.CharField(
        max_length=20, choices=RETURN_STATUS_CHOICES, default='pending'
    )
    refund_amount = models.DecimalField(
        max_digits=12, decimal_places=2,
        validators=[MinValueValidator(0)], default=0
    )
    return_date = models.DateField(default=datetime.date.today)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'returns'
        verbose_name = _("Return")
        verbose_name_plural = _("Returns")
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['user', 'status']),
            models.Index(fields=['user', 'return_date']),
        ]

    def __str__(self):
        return f"Return {self.return_number}"

    def save(self, *args, **kwargs):
        if not self.return_number:
            import random, string
            ts = timezone.now().strftime('%Y%m%d%H%M%S')
            rnd = ''.join(random.choices(string.ascii_uppercase + string.digits, k=4))
            self.return_number = f"RET{ts}{rnd}"
        super().save(*args, **kwargs)


# ==================== CAPITAL INVESTMENT ====================

class CapitalInvestment(models.Model):
    """Track capital investment and withdrawals for ROI calculation."""

    INVESTMENT_TYPE_CHOICES = [
        ('initial', 'Initial Capital'),
        ('additional', 'Additional Investment'),
        ('withdrawal', 'Capital Withdrawal'),
    ]

    user = models.ForeignKey(
        User, on_delete=models.CASCADE, related_name='capital_investments'
    )
    investment_type = models.CharField(max_length=20, choices=INVESTMENT_TYPE_CHOICES)
    amount = models.DecimalField(
        max_digits=12, decimal_places=2, validators=[MinValueValidator(0)]
    )
    description = models.TextField(blank=True, default='')
    investment_date = models.DateField(default=datetime.date.today)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'capital_investments'
        verbose_name = _("Capital Investment")
        verbose_name_plural = _("Capital Investments")
        ordering = ['-investment_date']
        indexes = [
            models.Index(fields=['user', 'investment_date']),
        ]

    def __str__(self):
        return f"{self.investment_type} ৳{self.amount} – {self.user.business_name}"


# ==================== WALLET & SUBSCRIPTION ====================

class WalletTransaction(models.Model):
    """Records every wallet credit/debit for audit trail."""

    TRANSACTION_TYPES = [
        ('topup', 'Top-up'),
        ('sms', 'SMS Charge'),
        ('ai', 'AI Feature Charge'),
        ('package', 'Package Purchase'),
        ('refund', 'Refund'),
    ]

    user = models.ForeignKey(
        User, on_delete=models.CASCADE, related_name='wallet_transactions'
    )
    transaction_type = models.CharField(max_length=20, choices=TRANSACTION_TYPES)
    amount = models.DecimalField(
        max_digits=10, decimal_places=2,
        help_text='Positive = credit, Negative = debit'
    )
    balance_after = models.DecimalField(max_digits=10, decimal_places=2)
    description = models.CharField(max_length=255, blank=True, default='')
    reference = models.CharField(max_length=100, blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'wallet_transactions'
        verbose_name = _("Wallet Transaction")
        verbose_name_plural = _("Wallet Transactions")
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['user', 'created_at']),
        ]

    def __str__(self):
        return f"{self.get_transaction_type_display()} {self.amount} – {self.user.business_name}"


class SubscriptionPurchase(models.Model):
    """Manual payment record for subscription or wallet top-up."""

    PLAN_CHOICES = [
        ('monthly', 'Monthly (৳200)'),
        ('yearly', 'Yearly (৳1099)'),
        ('wallet_topup', 'Wallet Top-up'),
    ]
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('approved', 'Approved'),
        ('rejected', 'Rejected'),
    ]
    PAYMENT_METHODS = [
        ('bkash', 'bKash'),
        ('nagad', 'Nagad'),
        ('rocket', 'Rocket'),
        ('bank', 'Bank Transfer'),
    ]

    # Pricing config
    MONTHLY_PRICE = 200
    YEARLY_PRICE = 1099
    MONTHLY_DURATION_DAYS = 30
    YEARLY_DURATION_DAYS = 365

    user = models.ForeignKey(
        User, on_delete=models.CASCADE, related_name='subscription_purchases'
    )
    plan = models.CharField(max_length=20, choices=PLAN_CHOICES)
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    payment_method = models.CharField(max_length=20, choices=PAYMENT_METHODS)
    transaction_id = models.CharField(
        max_length=100,
        help_text='bKash/Nagad transaction ID provided by user'
    )
    sender_number = models.CharField(max_length=15, blank=True, default='')
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    admin_note = models.TextField(blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)
    reviewed_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        db_table = 'subscription_purchases'
        verbose_name = _("Subscription Purchase")
        verbose_name_plural = _("Subscription Purchases")
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.user.business_name} – {self.get_plan_display()} – {self.status}"

    def approve(self, admin_note=''):
        """Approve this purchase: activate subscription or credit wallet."""
        from django.utils import timezone as tz
        import logging
        from django.db import transaction
        from django.db.models import F

        logger = logging.getLogger(__name__)

        with transaction.atomic():
            self.status = 'approved'
            self.admin_note = admin_note
            self.reviewed_at = tz.now()
            self.save()

            if self.plan == 'wallet_topup':
                # Atomically increase user's wallet balance using F expression
                User.objects.filter(pk=self.user.pk).update(
                    wallet_balance=F('wallet_balance') + self.amount
                )
                # Refresh user instance to get the new balance
                self.user.refresh_from_db()
                try:
                    WalletTransaction.objects.create(
                        user=self.user,
                        transaction_type='topup',
                        amount=self.amount,
                        balance_after=self.user.wallet_balance,
                        description=f'Wallet top-up via {self.get_payment_method_display()}',
                        reference=self.transaction_id,
                    )
                except Exception:
                    logger.exception('Failed to create WalletTransaction for SubscriptionPurchase id=%s', self.id)
            else:
                # Activate subscription
                now = tz.now()
                days = (
                    self.MONTHLY_DURATION_DAYS if self.plan == 'monthly'
                    else self.YEARLY_DURATION_DAYS
                )
                plan_key = 'monthly' if self.plan == 'monthly' else 'yearly'
                # Extend existing subscription if still active
                current_end = self.user.subscription_end_date
                start = max(now, current_end) if current_end and current_end > now else now
                self.user.subscription_type = plan_key
                self.user.subscription_start_date = now
                self.user.subscription_end_date = start + datetime.timedelta(days=days)
                self.user.save(update_fields=[
                    'subscription_type', 'subscription_start_date', 'subscription_end_date'
                ])
                WalletTransaction.objects.create(
                    user=self.user,
                    transaction_type='package',
                    amount=-self.amount,
                    balance_after=self.user.wallet_balance,
                    description=f'{self.get_plan_display()} subscription activated',
                    reference=self.transaction_id,
                )
        else:
            # Activate subscription
            now = tz.now()
            days = (
                self.MONTHLY_DURATION_DAYS if self.plan == 'monthly'
                else self.YEARLY_DURATION_DAYS
            )
            plan_key = 'monthly' if self.plan == 'monthly' else 'yearly'
            # Extend existing subscription if still active
            current_end = self.user.subscription_end_date
            start = max(now, current_end) if current_end and current_end > now else now
            self.user.subscription_type = plan_key
            self.user.subscription_start_date = now
            self.user.subscription_end_date = start + datetime.timedelta(days=days)
            self.user.save(update_fields=[
                'subscription_type', 'subscription_start_date', 'subscription_end_date'
            ])
            WalletTransaction.objects.create(
                user=self.user,
                transaction_type='package',
                amount=-self.amount,
                balance_after=self.user.wallet_balance,
                description=f'{self.get_plan_display()} subscription activated',
                reference=self.transaction_id,
            )

