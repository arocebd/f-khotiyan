"""
Django REST Framework Serializers for F-Khotiyan
Handles data validation and serialization for API endpoints
"""

from rest_framework import serializers
from django.contrib.auth import authenticate
from core.models import (
    User, Product, Customer, Order, OrderItem,
    Expense, CourierConfig, SMSPurchase, Subscription, Return, CapitalInvestment
)


# ==================== AUTHENTICATION SERIALIZERS ====================

class UserRegistrationSerializer(serializers.ModelSerializer):
    """Serializer for user registration"""
    
    password = serializers.CharField(write_only=True, min_length=8)
    password_confirm = serializers.CharField(write_only=True)
    
    class Meta:
        model = User
        fields = [
            'phone_number', 'email', 'password', 'password_confirm',
            'business_name', 'owner_name', 'location', 'district'
        ]
    
    def validate(self, data):
        if data['password'] != data['password_confirm']:
            raise serializers.ValidationError("Passwords do not match")
        return data
    
    def create(self, validated_data):
        validated_data.pop('password_confirm')
        password = validated_data.pop('password')
        user = User.objects.create_user(**validated_data, password=password)
        return user


class UserLoginSerializer(serializers.Serializer):
    """Serializer for user login"""
    
    phone_number = serializers.CharField()
    password = serializers.CharField(write_only=True)
    
    def validate(self, data):
        phone_number = data.get('phone_number')
        password = data.get('password')
        
        if phone_number and password:
            user = authenticate(username=phone_number, password=password)
            if not user:
                raise serializers.ValidationError("Invalid credentials")
            if not user.is_active:
                raise serializers.ValidationError("User account is disabled")
            data['user'] = user
        else:
            raise serializers.ValidationError("Must include phone_number and password")
        
        return data


class UserProfileSerializer(serializers.ModelSerializer):
    """Serializer for user profile"""
    
    is_subscription_active = serializers.BooleanField(read_only=True)
    daily_order_limit = serializers.IntegerField(read_only=True)
    can_create_order = serializers.SerializerMethodField()
    
    class Meta:
        model = User
        fields = [
            'id', 'phone_number', 'email', 'business_name', 'owner_name',
            'location', 'district', 'country', 'logo', 'subscription_type',
            'subscription_start_date', 'subscription_end_date',
            'is_subscription_active', 'sms_balance', 'daily_order_count',
            'daily_order_limit', 'can_create_order', 'created_at'
        ]
        read_only_fields = ['phone_number', 'created_at']
    
    def get_can_create_order(self, obj):
        return obj.can_create_order()


# ==================== AI ORDER EXTRACTION SERIALIZERS ====================

class ExtractedProductSerializer(serializers.Serializer):
    """Serializer for extracted product data"""
    
    product_name = serializers.CharField(max_length=255)
    quantity = serializers.IntegerField(min_value=1)
    price = serializers.DecimalField(max_digits=10, decimal_places=2, min_value=0)


class OrderExtractionInputSerializer(serializers.Serializer):
    """Serializer for order extraction input (text or image)"""
    
    message_text = serializers.CharField(required=False, allow_blank=True)
    screenshot = serializers.ImageField(required=False)
    
    def validate(self, data):
        if not data.get('message_text') and not data.get('screenshot'):
            raise serializers.ValidationError(
                "Either message_text or screenshot is required"
            )
        return data


class ExtractedOrderDataSerializer(serializers.Serializer):
    """Serializer for extracted order data from AI"""
    
    customer_name = serializers.CharField(max_length=255)
    customer_phone = serializers.CharField(max_length=15)
    customer_address = serializers.CharField()
    district = serializers.CharField(max_length=100, required=False, allow_blank=True)
    products = ExtractedProductSerializer(many=True)
    total_amount = serializers.DecimalField(max_digits=12, decimal_places=2)
    delivery_charge = serializers.DecimalField(max_digits=10, decimal_places=2, default=0)
    discount = serializers.DecimalField(max_digits=10, decimal_places=2, default=0)
    notes = serializers.CharField(required=False, allow_blank=True, default='')
    courier_preference = serializers.ChoiceField(
        choices=['self', 'pathao', 'steadfast'],
        default='self'
    )


class OrderLimitInfoSerializer(serializers.Serializer):
    """Serializer for order limit information"""
    
    daily_order_count = serializers.IntegerField()
    daily_order_limit = serializers.IntegerField(allow_null=True)
    can_create_order = serializers.BooleanField()
    subscription_type = serializers.CharField()
    orders_remaining = serializers.IntegerField(allow_null=True)


# ==================== ORDER SERIALIZERS ====================

class OrderItemSerializer(serializers.ModelSerializer):
    """Serializer for order items"""

    profit = serializers.DecimalField(max_digits=12, decimal_places=2, read_only=True)

    class Meta:
        model = OrderItem
        fields = [
            'id', 'product', 'product_name', 'quantity',
            'purchase_price', 'selling_price', 'subtotal', 'profit'
        ]
        read_only_fields = ['subtotal', 'profit']
        extra_kwargs = {
            'product': {'required': False, 'allow_null': True},
            'purchase_price': {'required': False, 'default': 0},
        }


class OrderCreateSerializer(serializers.ModelSerializer):
    """Serializer for creating orders"""
    
    items = OrderItemSerializer(many=True, write_only=True)
    
    class Meta:
        model = Order
        fields = [
            'customer', 'customer_name', 'customer_phone', 'customer_address',
            'total_amount', 'discount', 'delivery_charge', 'grand_total',
            'payment_status', 'order_status', 'courier_type', 'notes',
            'created_from_image', 'source_image', 'items'
        ]
        extra_kwargs = {
            'customer': {'required': False},
        }
    
    def validate(self, data):
        # Check if user can create order
        user = self.context['request'].user
        if not user.can_create_order():
            raise serializers.ValidationError({
                'error': 'Daily order limit reached',
                'daily_limit': user.daily_order_limit,
                'orders_created_today': user.daily_order_count
            })

        # Validate stock availability for each item that has a product
        for item in data.get('items', []):
            product = item.get('product')
            qty = item.get('quantity', 0)
            if product and product.quantity < qty:
                raise serializers.ValidationError({
                    'items': f'পণ্য "{product.product_name}"-এর স্টক যথেষ্ট নেই। '
                             f'পাওয়া যাচ্ছে: {product.quantity}, চাওয়া হয়েছে: {qty}'
                })

        return data
    
    def create(self, validated_data):
        items_data = validated_data.pop('items')
        user = self.context['request'].user
        
        # Get or create customer
        customer = validated_data.get('customer')
        if not customer:
            customer, _ = Customer.objects.get_or_create(
                user=user,
                phone_number=validated_data['customer_phone'],
                defaults={
                    'customer_name': validated_data['customer_name'],
                    'address': validated_data['customer_address'],
                    'district': validated_data.get('district', '')
                }
            )
            validated_data['customer'] = customer
        
        # Create order
        order = Order.objects.create(user=user, **validated_data)
        
        # Create order items and deduct stock
        for item_data in items_data:
            OrderItem.objects.create(order=order, **item_data)
            product = item_data.get('product')
            if product:
                product.quantity -= item_data.get('quantity', 0)
                if product.quantity < 0:
                    product.quantity = 0
                product.save(update_fields=['quantity'])
        
        # Update customer statistics
        customer.total_orders += 1
        customer.total_amount += order.grand_total
        customer.save()
        
        # Increment user's order count
        user.increment_order_count()
        
        return order


class OrderListSerializer(serializers.ModelSerializer):
    """Serializer for order list"""
    
    items = OrderItemSerializer(many=True, read_only=True)
    customer_name = serializers.CharField()
    
    class Meta:
        model = Order
        fields = [
            'id', 'order_number', 'customer_name', 'customer_phone',
            'order_date', 'grand_total', 'payment_status', 'order_status',
            'courier_type', 'created_from_image', 'created_at', 'items'
        ]


class OrderDetailSerializer(serializers.ModelSerializer):
    """Serializer for order details"""
    
    items = OrderItemSerializer(many=True, read_only=True)
    
    class Meta:
        model = Order
        fields = '__all__'
        read_only_fields = ['order_number', 'user', 'created_at', 'updated_at']


# ==================== PRODUCT SERIALIZERS ====================

class ProductSerializer(serializers.ModelSerializer):
    """Serializer for products"""
    
    is_low_stock = serializers.BooleanField(read_only=True)
    profit_margin = serializers.DecimalField(
        max_digits=10, decimal_places=2, read_only=True
    )
    
    class Meta:
        model = Product
        fields = [
            'id', 'product_name', 'sku', 'category', 'purchase_price',
            'selling_price', 'quantity', 'reorder_level', 'unit',
            'description', 'image', 'is_active', 'is_low_stock',
            'profit_margin', 'created_at', 'updated_at'
        ]
        read_only_fields = ['created_at', 'updated_at']
    
    def create(self, validated_data):
        user = self.context['request'].user
        return Product.objects.create(user=user, **validated_data)


# ==================== CUSTOMER SERIALIZERS ====================

class CustomerSerializer(serializers.ModelSerializer):
    """Serializer for customers"""
    
    class Meta:
        model = Customer
        fields = [
            'id', 'customer_name', 'phone_number', 'address', 'district',
            'is_fake', 'fake_reason', 'total_orders', 'total_amount',
            'created_at'
        ]
        read_only_fields = ['total_orders', 'total_amount', 'created_at']
    
    def create(self, validated_data):
        user = self.context['request'].user
        return Customer.objects.create(user=user, **validated_data)


# ==================== EXPENSE SERIALIZERS ====================

class ExpenseSerializer(serializers.ModelSerializer):
    """Serializer for expenses"""
    
    class Meta:
        model = Expense
        fields = [
            'id', 'category', 'amount', 'description', 'expense_date',
            'created_at'
        ]
        read_only_fields = ['created_at']
    
    def create(self, validated_data):
        user = self.context['request'].user
        return Expense.objects.create(user=user, **validated_data)


# ==================== COURIER CONFIG SERIALIZERS ====================

class CourierConfigSerializer(serializers.ModelSerializer):
    """Serializer for courier configurations"""
    
    class Meta:
        model = CourierConfig
        fields = [
            'id', 'courier_name', 'api_key', 'api_secret', 'client_id',
            'client_secret', 'store_id', 'is_active', 'pathao_is_sandbox', 'created_at'
        ]
        read_only_fields = ['created_at']
        extra_kwargs = {
            'api_key': {'write_only': True},
            'api_secret': {'write_only': True},
            'client_id': {'write_only': True},
            'client_secret': {'write_only': True}
        }
    
    def create(self, validated_data):
        user = self.context['request'].user
        return CourierConfig.objects.create(user=user, **validated_data)


# ==================== SMS SERIALIZERS ====================

class SMSPurchaseSerializer(serializers.ModelSerializer):
    """Serializer for SMS purchases"""
    
    class Meta:
        model = SMSPurchase
        fields = [
            'id', 'quantity', 'total_price', 'bkash_transaction_id',
            'payment_status', 'confirmed_by_admin', 'created_at'
        ]
        read_only_fields = ['payment_status', 'confirmed_by_admin', 'created_at']
    
    def create(self, validated_data):
        user = self.context['request'].user
        return SMSPurchase.objects.create(user=user, **validated_data)


# ==================== SUBSCRIPTION SERIALIZERS ====================

class SubscriptionSerializer(serializers.ModelSerializer):
    """Serializer for subscriptions"""
    
    class Meta:
        model = Subscription
        fields = [
            'id', 'plan_type', 'amount', 'payment_method', 'transaction_id',
            'start_date', 'end_date', 'is_active', 'created_at'
        ]
        read_only_fields = ['is_active', 'created_at']
    
    def create(self, validated_data):
        user = self.context['request'].user
        return Subscription.objects.create(user=user, **validated_data)


# ==================== RETURN SERIALIZERS ====================

class ReturnSerializer(serializers.ModelSerializer):
    """Serializer for product returns"""

    order_number = serializers.CharField(source='order.order_number', read_only=True)
    customer_name = serializers.CharField(source='order.customer_name', read_only=True)
    customer_phone = serializers.CharField(source='order.customer_phone', read_only=True)

    class Meta:
        model = Return
        fields = [
            'id', 'order', 'order_number', 'customer_name', 'customer_phone',
            'return_number', 'reason', 'description', 'status',
            'refund_amount', 'return_date', 'created_at', 'updated_at'
        ]
        read_only_fields = ['return_number', 'created_at', 'updated_at']

    def create(self, validated_data):
        user = self.context['request'].user
        return Return.objects.create(user=user, **validated_data)

    def validate(self, data):
        # Ensure the order belongs to the requesting user
        request = self.context.get('request')
        if request and data.get('order'):
            if data['order'].user != request.user:
                raise serializers.ValidationError("Invalid order.")
        return data


# ==================== CAPITAL INVESTMENT SERIALIZERS ====================

class CapitalInvestmentSerializer(serializers.ModelSerializer):
    """Serializer for capital investments"""

    class Meta:
        model = CapitalInvestment
        fields = [
            'id', 'investment_type', 'amount', 'description',
            'investment_date', 'created_at'
        ]
        read_only_fields = ['created_at']

    def create(self, validated_data):
        user = self.context['request'].user
        return CapitalInvestment.objects.create(user=user, **validated_data)
