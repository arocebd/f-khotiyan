"""
Django REST Framework Views for F-Khotiyan API
Handles all API endpoints including AI order extraction
"""

from rest_framework import viewsets, status, permissions
from rest_framework.decorators import api_view, permission_classes, action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework_simplejwt.tokens import RefreshToken
from django.core.files.storage import default_storage
from django.core.files.base import ContentFile
from django.db.models import Q, Sum, Count
from django.utils import timezone
from datetime import timedelta
import os

from core.models import (
    User, Product, Customer, Order, OrderItem,
    Expense, CourierConfig, SMSPurchase, Return, CapitalInvestment, SMSLog,
    WalletTransaction, SubscriptionPurchase
)
from core.serializers import (
    UserRegistrationSerializer, UserLoginSerializer, UserProfileSerializer,
    ProductSerializer, CustomerSerializer, OrderCreateSerializer,
    OrderListSerializer, OrderDetailSerializer, ExpenseSerializer,
    CourierConfigSerializer, SMSPurchaseSerializer,
    OrderExtractionInputSerializer, ExtractedOrderDataSerializer,
    OrderLimitInfoSerializer, ReturnSerializer, CapitalInvestmentSerializer
)
from core.gemini_service import GeminiOrderExtractor


# ==================== AUTHENTICATION VIEWS ====================

@api_view(['POST'])
@permission_classes([AllowAny])
def register(request):
    """
    User registration endpoint
    POST /api/auth/register/
    """
    serializer = UserRegistrationSerializer(data=request.data)
    if serializer.is_valid():
        user = serializer.save()
        
        # Generate JWT tokens
        refresh = RefreshToken.for_user(user)
        
        return Response({
            'success': True,
            'message': 'Registration successful',
            'user': UserProfileSerializer(user).data,
            'tokens': {
                'refresh': str(refresh),
                'access': str(refresh.access_token),
            }
        }, status=status.HTTP_201_CREATED)
    
    return Response({
        'success': False,
        'errors': serializer.errors
    }, status=status.HTTP_400_BAD_REQUEST)


@api_view(['POST'])
@permission_classes([AllowAny])
def login(request):
    """
    User login endpoint
    POST /api/auth/login/
    """
    serializer = UserLoginSerializer(data=request.data)
    if serializer.is_valid():
        user = serializer.validated_data['user']
        
        # Generate JWT tokens
        refresh = RefreshToken.for_user(user)
        
        return Response({
            'success': True,
            'message': 'Login successful',
            'user': UserProfileSerializer(user).data,
            'tokens': {
                'refresh': str(refresh),
                'access': str(refresh.access_token),
            }
        }, status=status.HTTP_200_OK)
    
    return Response({
        'success': False,
        'errors': serializer.errors
    }, status=status.HTTP_400_BAD_REQUEST)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def profile(request):
    """
    Get user profile
    GET /api/auth/profile/
    """
    serializer = UserProfileSerializer(request.user)
    return Response({
        'success': True,
        'user': serializer.data
    })


@api_view(['PUT', 'PATCH'])
@permission_classes([IsAuthenticated])
def update_profile(request):
    """
    Update user profile
    PUT/PATCH /api/auth/profile/update/
    """
    serializer = UserProfileSerializer(
        request.user,
        data=request.data,
        partial=request.method == 'PATCH'
    )
    
    if serializer.is_valid():
        serializer.save()
        return Response({
            'success': True,
            'message': 'Profile updated successfully',
            'user': serializer.data
        })
    
    return Response({
        'success': False,
        'errors': serializer.errors
    }, status=status.HTTP_400_BAD_REQUEST)


# ==================== AI ORDER EXTRACTION VIEWS ====================

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def extract_order_from_message(request):
    """
    Extract order details from text message or screenshot using Gemini AI
    
    POST /api/orders/extract/
    
    Body:
        - message_text (optional): Raw text message
        - screenshot (optional): Image file
    
    Returns:
        - extracted_data: Parsed order information
        - validation_errors: List of validation issues (if any)
    """
    user = request.user

    # AI billing: 3 free uses, then deduct from wallet
    # Gemini Flash rates converted to BDT (≈120 BDT/USD):
    # Input: $0.075/1M tokens → 0.009 BDT/1K tokens
    # Output: $0.30/1M tokens → 0.036 BDT/1K tokens
    # Minimum charge per request: ৳0.10
    AI_MIN_COST = 0.10  # BDT, minimum per request

    if user.ai_free_uses_remaining > 0:
        # Consume a free use
        user.ai_free_uses_remaining -= 1
        user.save(update_fields=['ai_free_uses_remaining'])
    else:
        from decimal import Decimal
        cost = Decimal(str(AI_MIN_COST))
        if user.wallet_balance < cost:
            return Response({
                'success': False,
                'error': 'insufficient_wallet_balance',
                'message': f'ওয়ালেট ব্যালেন্স অপর্যাপ্ত। AI অর্ডার তৈরিতে ন্যূনতম ৳{AI_MIN_COST} প্রয়োজন। বর্তমান ব্যালেন্স: ৳{user.wallet_balance}',
                'wallet_balance': float(user.wallet_balance),
                'required': AI_MIN_COST,
                'ai_free_uses_remaining': 0,
            }, status=status.HTTP_402_PAYMENT_REQUIRED)

    # Validate input
    input_serializer = OrderExtractionInputSerializer(data=request.data)
    if not input_serializer.is_valid():
        return Response({
            'success': False,
            'errors': input_serializer.errors
        }, status=status.HTTP_400_BAD_REQUEST)
    
    try:
        # Initialize Gemini extractor
        extractor = GeminiOrderExtractor()
        
        # Extract from text or image
        if request.data.get('message_text'):
            message_text = request.data['message_text']
            extracted_data = extractor.extract_order_from_text(message_text)
        
        elif request.FILES.get('screenshot'):
            screenshot = request.FILES['screenshot']
            
            # Save image temporarily
            file_name = f"temp_extract_{user.id}_{timezone.now().timestamp()}.jpg"
            file_path = default_storage.save(
                f"temp_extractions/{file_name}",
                ContentFile(screenshot.read())
            )
            full_path = default_storage.path(file_path)
            
            # Extract from image
            extracted_data = extractor.extract_order_from_image(full_path)
            
            # Clean up temporary file
            default_storage.delete(file_path)
        
        else:
            return Response({
                'success': False,
                'error': 'Either message_text or screenshot is required'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Check extraction result
        if not extracted_data:
            return Response({
                'success': False,
                'error': 'extraction_failed',
                'message': 'Unable to extract order information. Please try again or create order manually.',
                'suggestion': 'Ensure the message contains customer name, phone, address, and product details.'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Validate extracted data
        is_valid, validation_errors = extractor.validate_order_data(extracted_data)

        # Deduct wallet if free uses are exhausted (charge AI cost)
        from decimal import Decimal
        ai_cost_charged = Decimal('0')
        if user.ai_free_uses_remaining == 0:
            # We already decremented to 0 before the call; charge now
            # Use flat rate: 0.10 BDT minimum per request
            cost = Decimal(str(AI_MIN_COST))
            if user.wallet_balance >= cost:
                user.wallet_balance -= cost
                user.save(update_fields=['wallet_balance'])
                ai_cost_charged = cost
                WalletTransaction.objects.create(
                    user=user,
                    transaction_type='ai',
                    amount=-cost,
                    balance_after=user.wallet_balance,
                    description='AI Order Extraction',
                )

        # Return extracted data even if validation has issues
        # Flutter app can let user correct the data
        return Response({
            'success': True,
            'extracted_data': extracted_data,
            'is_valid': is_valid,
            'validation_errors': validation_errors,
            'message': 'Order data extracted successfully. Please review and confirm.' if is_valid else 'Please review and correct the highlighted fields.',
            'ai_free_uses_remaining': user.ai_free_uses_remaining,
            'wallet_balance': float(user.wallet_balance),
            'ai_cost_charged': float(ai_cost_charged),
        }, status=status.HTTP_200_OK)
    
    except ValueError as e:
        return Response({
            'success': False,
            'error': 'configuration_error',
            'message': str(e)
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    except Exception as e:
        return Response({
            'success': False,
            'error': 'internal_error',
            'message': 'An unexpected error occurred',
            'details': str(e)
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def confirm_ai_order(request):
    """
    Confirm and create order from AI-extracted data
    
    POST /api/orders/confirm-ai-order/
    
    Body:
        - customer_name
        - customer_phone
        - customer_address
        - district (optional)
        - products: [{product_name, quantity, price}]
        - total_amount
        - delivery_charge
        - discount
        - notes (optional)
        - courier_preference
        - screenshot (optional): Original screenshot file
    """
    user = request.user
    
    # Check order limit again
    if not user.can_create_order():
        return Response({
            'success': False,
            'error': 'daily_limit_reached',
            'message': 'Daily order limit reached'
        }, status=status.HTTP_429_TOO_MANY_REQUESTS)
    
    # Validate extracted data
    data_serializer = ExtractedOrderDataSerializer(data=request.data)
    if not data_serializer.is_valid():
        return Response({
            'success': False,
            'errors': data_serializer.errors
        }, status=status.HTTP_400_BAD_REQUEST)
    
    validated_data = data_serializer.validated_data
    
    try:
        # Get or create customer
        customer, created = Customer.objects.get_or_create(
            user=user,
            phone_number=validated_data['customer_phone'],
            defaults={
                'customer_name': validated_data['customer_name'],
                'address': validated_data['customer_address'],
                'district': validated_data.get('district', '')
            }
        )
        
        # Calculate grand total
        grand_total = (
            validated_data['total_amount'] +
            validated_data['delivery_charge'] -
            validated_data['discount']
        )
        
        # Create order
        order = Order.objects.create(
            user=user,
            customer=customer,
            customer_name=validated_data['customer_name'],
            customer_phone=validated_data['customer_phone'],
            customer_address=validated_data['customer_address'],
            total_amount=validated_data['total_amount'],
            delivery_charge=validated_data['delivery_charge'],
            discount=validated_data['discount'],
            grand_total=grand_total,
            courier_type=validated_data['courier_preference'],
            notes=validated_data.get('notes', ''),
            created_from_image=bool(request.FILES.get('screenshot')),
            source_image=request.FILES.get('screenshot')
        )
        
        # Create order items
        for product_data in validated_data['products']:
            # Try to match with existing product
            existing_product = Product.objects.filter(
                user=user,
                product_name__iexact=product_data['product_name']
            ).first()
            
            OrderItem.objects.create(
                order=order,
                product=existing_product,
                product_name=product_data['product_name'],
                quantity=product_data['quantity'],
                purchase_price=existing_product.purchase_price if existing_product else 0,
                selling_price=product_data['price'],
                subtotal=product_data['quantity'] * product_data['price']
            )
            
            # Update stock if product exists
            if existing_product and existing_product.quantity >= product_data['quantity']:
                existing_product.quantity -= product_data['quantity']
                existing_product.save()
        
        # Update customer statistics
        customer.total_orders += 1
        customer.total_amount += grand_total
        customer.save()
        
        # Increment user's order count
        user.increment_order_count()
        
        return Response({
            'success': True,
            'message': 'Order created successfully',
            'order': {
                'id': order.id,
                'order_number': order.order_number,
                'grand_total': float(order.grand_total),
                'created_at': order.created_at
            },
            'order_limit_info': {
                'orders_today': user.daily_order_count,
                'daily_limit': user.daily_order_limit,
                'orders_remaining': (
                    user.daily_order_limit - user.daily_order_count
                    if user.daily_order_limit else None
                )
            }
        }, status=status.HTTP_201_CREATED)
    
    except Exception as e:
        return Response({
            'success': False,
            'error': 'order_creation_failed',
            'message': str(e)
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def order_limit_info(request):
    """
    Get current order limit information
    
    GET /api/orders/limit-info/
    """
    user = request.user
    
    orders_remaining = None
    if user.daily_order_limit:
        orders_remaining = max(0, user.daily_order_limit - user.daily_order_count)
    
    data = {
        'daily_order_count': user.daily_order_count,
        'daily_order_limit': user.daily_order_limit,
        'can_create_order': user.can_create_order(),
        'subscription_type': user.subscription_type,
        'orders_remaining': orders_remaining
    }
    
    serializer = OrderLimitInfoSerializer(data)
    
    return Response({
        'success': True,
        'limit_info': serializer.data
    })


# ==================== ORDER VIEWSET ====================

class OrderViewSet(viewsets.ModelViewSet):
    """
    ViewSet for managing orders
    
    list: GET /api/orders/
    create: POST /api/orders/
    retrieve: GET /api/orders/{id}/
    update: PUT /api/orders/{id}/
    partial_update: PATCH /api/orders/{id}/
    destroy: DELETE /api/orders/{id}/
    """
    permission_classes = [IsAuthenticated]
    
    def get_serializer_class(self):
        if self.action == 'list':
            return OrderListSerializer
        elif self.action == 'create':
            return OrderCreateSerializer
        return OrderDetailSerializer
    
    @action(detail=True, methods=['post'], url_path='update-items')
    def update_items(self, request, pk=None):
        """
        Replace all items of an order and recalculate totals.
        POST /api/orders/{id}/update-items/
        Body: {"items": [{product, product_name, quantity, selling_price, purchase_price}]}
        """
        order = self.get_object()
        items_data = request.data.get('items', [])

        # Restore stock for existing items
        for item in order.items.all():
            if item.product:
                item.product.quantity += item.quantity
                item.product.save(update_fields=['quantity'])

        # Remove old items
        order.items.all().delete()

        subtotal = 0.0
        for item_data in items_data:
            product_id = item_data.get('product')
            product = None
            purchase_price = float(item_data.get('purchase_price') or 0)
            selling_price = float(item_data.get('selling_price') or 0)
            quantity = int(item_data.get('quantity') or 1)
            product_name = str(item_data.get('product_name') or '')

            if product_id:
                try:
                    product = Product.objects.get(id=product_id, user=order.user)
                    product.quantity = max(0, product.quantity - quantity)
                    product.save(update_fields=['quantity'])
                    if not product_name:
                        product_name = product.product_name
                    if not purchase_price:
                        purchase_price = float(product.purchase_price or 0)
                except Product.DoesNotExist:
                    pass

            item_subtotal = selling_price * quantity
            subtotal += item_subtotal

            OrderItem.objects.create(
                order=order,
                product=product,
                product_name=product_name,
                quantity=quantity,
                purchase_price=purchase_price,
                selling_price=selling_price,
                subtotal=item_subtotal,
            )

        delivery_charge = float(order.delivery_charge or 0)
        discount = float(order.discount or 0)
        order.total_amount = subtotal
        order.grand_total = subtotal - discount + delivery_charge
        order.save(update_fields=['total_amount', 'grand_total'])

        return Response({
            'success': True,
            'order': OrderDetailSerializer(order).data,
        })

    def get_queryset(self):
        user = self.request.user
        queryset = Order.objects.filter(user=user).order_by('-created_at')

        # Filter by status
        status_filter = self.request.query_params.get('status')
        if status_filter:
            queryset = queryset.filter(order_status=status_filter)
        
        # Filter by payment status
        payment_filter = self.request.query_params.get('payment_status')
        if payment_filter:
            queryset = queryset.filter(payment_status=payment_filter)
        
        # Filter by date range
        start_date = self.request.query_params.get('start_date')
        end_date = self.request.query_params.get('end_date')
        if start_date:
            queryset = queryset.filter(order_date__gte=start_date)
        if end_date:
            queryset = queryset.filter(order_date__lte=end_date)
        
        # Filter by AI-created
        ai_created = self.request.query_params.get('ai_created')
        if ai_created is not None:
            queryset = queryset.filter(created_from_image=ai_created.lower() == 'true')

        # Search by order number or customer name/phone
        search = self.request.query_params.get('search')
        if search:
            from django.db.models import Q
            queryset = queryset.filter(
                Q(order_number__icontains=search) |
                Q(customer_name__icontains=search) |
                Q(customer_phone__icontains=search)
            )

        return queryset
    
    def create(self, request, *args, **kwargs):
        """Create manual order"""
        serializer = self.get_serializer(data=request.data, context={'request': request})
        
        if serializer.is_valid():
            order = serializer.save()
            return Response({
                'success': True,
                'message': 'Order created successfully',
                'order': OrderDetailSerializer(order).data
            }, status=status.HTTP_201_CREATED)
        
        return Response({
            'success': False,
            'errors': serializer.errors
        }, status=status.HTTP_400_BAD_REQUEST)

    def perform_update(self, serializer):
        old_status = serializer.instance.order_status
        instance = serializer.save()
        # Auto-create Return record when order is marked as returned
        if instance.order_status == 'returned' and old_status != 'returned':
            return_reason = self.request.data.get('return_reason', 'customer_request')
            return_description = self.request.data.get('return_description', '')
            valid_reasons = [r[0] for r in Return.RETURN_REASON_CHOICES]
            if return_reason not in valid_reasons:
                return_reason = 'customer_request'
            Return.objects.get_or_create(
                order=instance,
                user=instance.user,
                defaults={
                    'reason': return_reason,
                    'description': return_description,
                    'status': 'pending',
                    'refund_amount': instance.grand_total or 0,
                }
            )

    @action(detail=False, methods=['get'])
    def statistics(self, request):
        """
        Get order statistics
        GET /api/orders/statistics/
        """
        user = request.user
        today = timezone.now().date()
        
        # Date ranges
        week_ago = today - timedelta(days=7)
        month_ago = today - timedelta(days=30)
        
        stats = {
            'total_orders': Order.objects.filter(user=user).count(),
            'today_orders': Order.objects.filter(user=user, order_date__date=today).count(),
            'week_orders': Order.objects.filter(user=user, order_date__date__gte=week_ago).count(),
            'month_orders': Order.objects.filter(user=user, order_date__date__gte=month_ago).count(),
            'pending_orders': Order.objects.filter(user=user, order_status='pending').count(),
            'delivered_orders': Order.objects.filter(user=user, order_status='delivered').count(),
            'ai_created_orders': Order.objects.filter(user=user, created_from_image=True).count(),
            'manual_orders': Order.objects.filter(user=user, created_from_image=False).count(),
            'total_revenue': Order.objects.filter(
                user=user,
                payment_status='paid'
            ).aggregate(total=Sum('grand_total'))['total'] or 0
        }
        
        return Response({
            'success': True,
            'statistics': stats
        })


# ==================== PRODUCT VIEWSET ====================

class ProductViewSet(viewsets.ModelViewSet):
    """ViewSet for managing products"""
    permission_classes = [IsAuthenticated]
    serializer_class = ProductSerializer
    
    def get_queryset(self):
        user = self.request.user
        queryset = Product.objects.filter(user=user, is_active=True)
        
        # Search by name or SKU
        search = self.request.query_params.get('search')
        if search:
            queryset = queryset.filter(
                Q(product_name__icontains=search) |
                Q(sku__icontains=search)
            )
        
        # Filter by category
        category = self.request.query_params.get('category')
        if category:
            queryset = queryset.filter(category=category)
        
        # Filter low stock
        low_stock = self.request.query_params.get('low_stock')
        if low_stock == 'true':
            queryset = [p for p in queryset if p.is_low_stock]
        
        return queryset


# ==================== CUSTOMER VIEWSET ====================

class CustomerViewSet(viewsets.ModelViewSet):
    """ViewSet for managing customers"""
    permission_classes = [IsAuthenticated]
    serializer_class = CustomerSerializer
    
    def get_queryset(self):
        user = self.request.user
        queryset = Customer.objects.filter(user=user)
        
        # Search by name or phone
        search = self.request.query_params.get('search')
        if search:
            queryset = queryset.filter(
                Q(customer_name__icontains=search) |
                Q(phone_number__icontains=search)
            )
        
        return queryset


# ==================== EXPENSE VIEWSET ====================

class ExpenseViewSet(viewsets.ModelViewSet):
    """ViewSet for managing expenses"""
    permission_classes = [IsAuthenticated]
    serializer_class = ExpenseSerializer
    
    def get_queryset(self):
        user = self.request.user
        queryset = Expense.objects.filter(user=user)
        
        # Filter by category
        category = self.request.query_params.get('category')
        if category:
            queryset = queryset.filter(category=category)
        
        # Filter by date range
        start_date = self.request.query_params.get('start_date')
        end_date = self.request.query_params.get('end_date')
        if start_date:
            queryset = queryset.filter(expense_date__gte=start_date)
        if end_date:
            queryset = queryset.filter(expense_date__lte=end_date)
        
        return queryset


# ==================== COURIER CONFIG VIEWSET ====================

class CourierConfigViewSet(viewsets.ModelViewSet):
    """ViewSet for managing courier configurations"""
    permission_classes = [IsAuthenticated]
    serializer_class = CourierConfigSerializer
    
    def get_queryset(self):
        return CourierConfig.objects.filter(user=self.request.user)


# ==================== SMS PURCHASE VIEWSET ====================

class SMSPurchaseViewSet(viewsets.ModelViewSet):
    """ViewSet for managing SMS purchases"""
    permission_classes = [IsAuthenticated]
    serializer_class = SMSPurchaseSerializer

    def get_queryset(self):
        return SMSPurchase.objects.filter(user=self.request.user)


# ==================== RETURN VIEWSET ====================

class ReturnViewSet(viewsets.ModelViewSet):
    """ViewSet for product returns"""
    permission_classes = [IsAuthenticated]
    serializer_class = ReturnSerializer

    def get_queryset(self):
        user = self.request.user
        qs = Return.objects.filter(user=user)
        status_filter = self.request.query_params.get('status')
        if status_filter:
            qs = qs.filter(status=status_filter)
        return qs

    def perform_update(self, serializer):
        old_status = serializer.instance.status
        instance = serializer.save()
        # Restore stock when return is approved or refunded (only once)
        if instance.status in ('approved', 'refunded') and old_status not in ('approved', 'refunded'):
            for item in instance.order.items.select_related('product').all():
                if item.product:
                    item.product.quantity += item.quantity
                    item.product.save(update_fields=['quantity'])


# ==================== CAPITAL INVESTMENT VIEWSET ====================

class CapitalInvestmentViewSet(viewsets.ModelViewSet):
    """ViewSet for capital investments"""
    permission_classes = [IsAuthenticated]
    serializer_class = CapitalInvestmentSerializer

    def get_queryset(self):
        return CapitalInvestment.objects.filter(user=self.request.user)


# ==================== REPORTS ENDPOINT ====================

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def reports(request):
    """
    Comprehensive financial and business reports.
    GET /api/reports/?start_date=YYYY-MM-DD&end_date=YYYY-MM-DD
    """
    user = request.user
    start_date = request.query_params.get('start_date')
    end_date = request.query_params.get('end_date')

    orders_qs = Order.objects.filter(user=user)
    expenses_qs = Expense.objects.filter(user=user)
    returns_qs = Return.objects.filter(user=user)
    capital_qs = CapitalInvestment.objects.filter(user=user)
    products_qs = Product.objects.filter(user=user, is_active=True)
    items_qs = OrderItem.objects.filter(order__user=user)

    if start_date:
        orders_qs = orders_qs.filter(order_date__date__gte=start_date)
        expenses_qs = expenses_qs.filter(expense_date__gte=start_date)
        returns_qs = returns_qs.filter(return_date__gte=start_date)
        items_qs = items_qs.filter(order__order_date__date__gte=start_date)
    if end_date:
        orders_qs = orders_qs.filter(order_date__date__lte=end_date)
        expenses_qs = expenses_qs.filter(expense_date__lte=end_date)
        returns_qs = returns_qs.filter(return_date__lte=end_date)
        items_qs = items_qs.filter(order__order_date__date__lte=end_date)

    # Order counts
    total_orders = orders_qs.count()
    delivered = orders_qs.filter(order_status='delivered').count()
    cancelled = orders_qs.filter(order_status='cancelled').count()
    returned = orders_qs.filter(order_status='returned').count()
    pending = orders_qs.filter(order_status='pending').count()
    processing = orders_qs.filter(order_status='processing').count()
    shipped = orders_qs.filter(order_status='shipped').count()

    # Revenue
    gross_revenue = float(orders_qs.aggregate(t=Sum('grand_total'))['t'] or 0)
    delivery_revenue = float(orders_qs.aggregate(t=Sum('delivery_charge'))['t'] or 0)
    discount_given = float(orders_qs.aggregate(t=Sum('discount'))['t'] or 0)
    sales_revenue = float(
        orders_qs.filter(payment_status='paid').aggregate(t=Sum('grand_total'))['t'] or 0
    )
    operating_revenue = gross_revenue - delivery_revenue

    # COGS and gross profit
    items_list = list(items_qs.select_related())
    cogs = float(sum(
        (item.purchase_price or 0) * item.quantity for item in items_list
    ))
    selling_total = float(sum(item.selling_price * item.quantity for item in items_list))
    gross_profit = selling_total - cogs

    # Expenses
    total_expenses = float(expenses_qs.aggregate(t=Sum('amount'))['t'] or 0)
    expense_by_category = list(
        expenses_qs.values('category').annotate(total=Sum('amount')).order_by('-total')
    )

    # Operating / net profit
    operating_profit = gross_profit - total_expenses
    net_profit = operating_profit

    # Capital & ROI
    invested = float(
        capital_qs.filter(investment_type__in=['initial', 'additional'])
        .aggregate(t=Sum('amount'))['t'] or 0
    )
    withdrawn = float(
        capital_qs.filter(investment_type='withdrawal').aggregate(t=Sum('amount'))['t'] or 0
    )
    net_capital = invested - withdrawn
    roi = round((net_profit / net_capital * 100), 2) if net_capital > 0 else 0

    # Returns
    total_returns = returns_qs.count()
    total_refunded = float(
        returns_qs.filter(status='refunded').aggregate(t=Sum('refund_amount'))['t'] or 0
    )

    # Stock
    low_stock = [p for p in products_qs if p.is_low_stock]
    stock_value = float(sum((p.purchase_price or 0) * p.quantity for p in products_qs))
    stock_report = [
        {
            'id': p.id,
            'product_name': p.product_name,
            'sku': p.sku,
            'quantity': p.quantity,
            'reorder_level': p.reorder_level,
            'purchase_price': float(p.purchase_price),
            'selling_price': float(p.selling_price),
            'is_low_stock': p.is_low_stock,
            'stock_value': float((p.purchase_price or 0) * p.quantity),
        }
        for p in products_qs.order_by('quantity')[:50]
    ]

    # Delivery success
    success_rate = round((delivered / total_orders * 100), 2) if total_orders > 0 else 0

    # Daily sales trend (last 30 days)
    from django.db.models.functions import TruncDate
    daily_trend = list(
        orders_qs.annotate(date=TruncDate('order_date'))
        .values('date')
        .annotate(count=Count('id'), revenue=Sum('grand_total'))
        .order_by('date')
    )

    # Convert Decimal to float for JSON serialization
    for row in daily_trend:
        row['revenue'] = float(row['revenue'] or 0)
        if row['date']:
            row['date'] = str(row['date'])

    for row in expense_by_category:
        row['total'] = float(row['total'] or 0)

    return Response({
        'success': True,
        'period': {'start_date': start_date, 'end_date': end_date},
        'overview': {
            'total_orders': total_orders,
            'delivered_orders': delivered,
            'cancelled_orders': cancelled,
            'returned_orders': returned,
            'pending_orders': pending,
            'processing_orders': processing,
            'shipped_orders': shipped,
            'delivery_success_rate': success_rate,
        },
        'revenue': {
            'gross_revenue': round(gross_revenue, 2),
            'sales_revenue': round(sales_revenue, 2),
            'operating_revenue': round(operating_revenue, 2),
            'delivery_revenue': round(delivery_revenue, 2),
            'discount_given': round(discount_given, 2),
        },
        'profit_loss': {
            'gross_profit': round(gross_profit, 2),
            'cogs': round(cogs, 2),
            'total_expenses': round(total_expenses, 2),
            'operating_profit': round(operating_profit, 2),
            'net_profit': round(net_profit, 2),
        },
        'capital': {
            'total_invested': round(invested, 2),
            'total_withdrawn': round(withdrawn, 2),
            'net_capital': round(net_capital, 2),
            'roi': roi,
        },
        'stock': {
            'total_products': products_qs.count(),
            'low_stock_count': len(low_stock),
            'stock_value': round(stock_value, 2),
            'products': stock_report,
        },
        'expenses': {
            'total': round(total_expenses, 2),
            'by_category': expense_by_category,
        },
        'returns': {
            'total': total_returns,
            'pending': returns_qs.filter(status='pending').count(),
            'refunded': returns_qs.filter(status='refunded').count(),
            'total_refunded': round(total_refunded, 2),
        },
        'daily_trend': daily_trend,
    })


# ==================== SMS SEND ENDPOINT ====================

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def sms_preview(request):
    """
    Preview SMS cost before sending.
    GET /api/sms/preview/?message=...
    Returns encoding, parts count, cost, remaining chars.
    """
    from core.sms_service import count_sms_parts, calculate_cost
    message = request.query_params.get('message', '')
    info = count_sms_parts(message)
    return Response({
        'encoding': info['encoding'],
        'char_count': info['char_count'],
        'parts': info['parts'],
        'chars_remaining': info['chars_remaining'],
        'cost': float(calculate_cost(info['parts'])),
        'cost_per_part': float(calculate_cost(1)),
    })


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def send_order_sms(request, order_id):
    """
    Send SMS to customer for an order.
    POST /api/orders/{id}/send-sms/
    Body (optional): { "message": "custom message" }
    Cost is calculated per SMS part (0.45 BDT each).
    """
    from decimal import Decimal
    from core.sms_service import count_sms_parts, calculate_cost, send_sms

    user = request.user

    try:
        order = Order.objects.get(id=order_id, user=user)
    except Order.DoesNotExist:
        return Response({'success': False, 'error': 'Order not found'},
                        status=status.HTTP_404_NOT_FOUND)

    status_labels = {
        'pending': 'অপেক্ষারত',
        'processing': 'প্রক্রিয়াকরণ হচ্ছে',
        'shipped': 'পাঠানো হয়েছে',
        'delivered': 'ডেলিভারি হয়েছে',
        'cancelled': 'বাতিল করা হয়েছে',
        'returned': 'ফেরত দেওয়া হয়েছে',
    }
    status_bn = status_labels.get(order.order_status, order.order_status)
    default_msg = (
        f"প্রিয় {order.customer_name}, আপনার অর্ডার #{order.order_number} "
        f"এর বর্তমান অবস্থা: {status_bn}। "
        f"মোট পরিমাণ: ৳{order.grand_total}। "
        f"ধন্যবাদ - {user.business_name}"
    )
    message = request.data.get('message', default_msg).strip()
    if not message:
        message = default_msg

    # Calculate cost based on actual SMS parts
    sms_info = count_sms_parts(message)
    parts = sms_info['parts']
    cost = calculate_cost(parts)

    # Check wallet balance
    if user.wallet_balance < cost:
        return Response({
            'success': False,
            'error': 'insufficient_wallet_balance',
            'message': f'ওয়ালেট ব্যালেন্স অপর্যাপ্ত। {parts}টি SMS পার্টের জন্য ৳{cost} প্রয়োজন। বর্তমান ব্যালেন্স: ৳{user.wallet_balance}',
            'wallet_balance': float(user.wallet_balance),
            'required': float(cost),
            'parts': parts,
        }, status=status.HTTP_402_PAYMENT_REQUIRED)

    # Create log entry (pending)
    log = SMSLog.objects.create(
        user=user,
        order=order,
        phone_number=order.customer_phone,
        message=message,
        status='pending',
        sms_parts=parts,
        cost=cost,
        encoding=sms_info['encoding'],
    )

    # Call the actual API
    sender_id = user.sms_sender_id or None
    result = send_sms(order.customer_phone, message, sender_id=sender_id)

    if result['success']:
        log.status = 'sent'
        log.api_response = result['response']
        log.save(update_fields=['status', 'api_response'])

        # Deduct wallet
        user.wallet_balance = max(Decimal('0'), user.wallet_balance - cost)
        user.save(update_fields=['wallet_balance'])

        WalletTransaction.objects.create(
            user=user,
            transaction_type='sms',
            amount=-cost,
            balance_after=user.wallet_balance,
            description=f'SMS ({parts} part{"s" if parts > 1 else ""}) to {order.customer_phone} — Order #{order.order_number}',
            reference=str(order.id),
        )

        order.sms_sent = True
        order.save(update_fields=['sms_sent'])

        return Response({
            'success': True,
            'message': f'{order.customer_phone} নম্বরে SMS পাঠানো হয়েছে।',
            'sms_parts': parts,
            'cost': float(cost),
            'encoding': sms_info['encoding'],
            'wallet_balance': float(user.wallet_balance),
        })
    else:
        log.status = 'failed'
        log.failure_reason = str(result['response'])
        log.api_response = result['response']
        log.save(update_fields=['status', 'failure_reason', 'api_response'])

        return Response({
            'success': False,
            'error': 'sms_api_failed',
            'message': 'SMS পাঠাতে ব্যর্থ হয়েছে। পুনরায় চেষ্টা করুন।',
            'details': result['response'],
        }, status=status.HTTP_502_BAD_GATEWAY)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def send_bulk_sms(request):
    """
    Send SMS to multiple customers at once.
    POST /api/sms/bulk/
    Body: {
      "recipients": [
        {"phone": "01712345678", "name": "Customer 1"},
        ...
      ],
      "message": "Custom message (use {name} placeholder)",
      "order_ids": [1, 2, 3]   // optional – links log to orders
    }
    """
    from decimal import Decimal
    from core.sms_service import count_sms_parts, calculate_cost, send_sms

    user = request.user
    recipients = request.data.get('recipients', [])
    message_template = request.data.get('message', '').strip()
    order_ids = request.data.get('order_ids', [])

    if not recipients:
        return Response({'success': False, 'error': 'recipients is required'},
                        status=status.HTTP_400_BAD_REQUEST)
    if not message_template:
        return Response({'success': False, 'error': 'message is required'},
                        status=status.HTTP_400_BAD_REQUEST)

    # Pre-calculate total cost using first recipient's message as representative
    sample_msg = message_template.replace('{name}', recipients[0].get('name', ''))
    sms_info = count_sms_parts(sample_msg)
    parts_per_sms = sms_info['parts']
    cost_per_sms = calculate_cost(parts_per_sms)
    total_cost = cost_per_sms * len(recipients)

    if user.wallet_balance < total_cost:
        return Response({
            'success': False,
            'error': 'insufficient_wallet_balance',
            'message': f'{len(recipients)} জনকে SMS পাঠাতে ৳{total_cost} প্রয়োজন। বর্তমান ব্যালেন্স: ৳{user.wallet_balance}',
            'wallet_balance': float(user.wallet_balance),
            'required': float(total_cost),
            'count': len(recipients),
            'parts_per_sms': parts_per_sms,
        }, status=status.HTTP_402_PAYMENT_REQUIRED)

    # Map order IDs to Order objects
    order_map = {}
    if order_ids:
        for o in Order.objects.filter(id__in=order_ids, user=user):
            order_map[str(o.id)] = o

    sender_id = user.sms_sender_id or None
    sent_count = 0
    failed_count = 0
    total_deducted = Decimal('0')

    for i, recipient in enumerate(recipients):
        phone = recipient.get('phone', '').strip()
        name = recipient.get('name', '')
        order_id_key = str(recipient.get('order_id', ''))
        order_obj = order_map.get(order_id_key)

        if not phone:
            failed_count += 1
            continue

        message = message_template.replace('{name}', name)
        sms_info = count_sms_parts(message)
        parts = sms_info['parts']
        cost = calculate_cost(parts)

        log = SMSLog.objects.create(
            user=user,
            order=order_obj,
            phone_number=phone,
            message=message,
            status='pending',
            sms_parts=parts,
            cost=cost,
            encoding=sms_info['encoding'],
        )

        result = send_sms(phone, message, sender_id=sender_id)

        if result['success']:
            log.status = 'sent'
            log.api_response = result['response']
            log.save(update_fields=['status', 'api_response'])

            user.wallet_balance = max(Decimal('0'), user.wallet_balance - cost)
            user.save(update_fields=['wallet_balance'])
            total_deducted += cost

            WalletTransaction.objects.create(
                user=user,
                transaction_type='sms',
                amount=-cost,
                balance_after=user.wallet_balance,
                description=f'Bulk SMS to {phone}',
                reference=order_id_key or f'bulk_{i}',
            )
            sent_count += 1
        else:
            log.status = 'failed'
            log.failure_reason = str(result['response'])
            log.api_response = result['response']
            log.save(update_fields=['status', 'failure_reason', 'api_response'])
            failed_count += 1

    return Response({
        'success': True,
        'sent': sent_count,
        'failed': failed_count,
        'total': len(recipients),
        'total_cost': float(total_deducted),
        'wallet_balance': float(user.wallet_balance),
        'message': f'{sent_count}টি SMS সফলভাবে পাঠানো হয়েছে।',
    })


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def sms_logs(request):
    """
    Get SMS logs for the current user.
    GET /api/sms/logs/?page=1&limit=20
    """
    logs = SMSLog.objects.filter(user=request.user).order_by('-sent_at')[:100]
    data = [{
        'id': log.id,
        'phone_number': log.phone_number,
        'message': log.message,
        'status': log.status,
        'sms_parts': log.sms_parts,
        'cost': float(log.cost),
        'encoding': log.encoding,
        'failure_reason': log.failure_reason,
        'order_number': log.order.order_number if log.order else None,
        'sent_at': log.sent_at.isoformat(),
    } for log in logs]
    return Response({'results': data, 'count': len(data)})


# ==================== STEADFAST COURIER INTEGRATION ====================

STEADFAST_BASE_URL = 'https://portal.packzy.com/api/v1'



def _steadfast_headers(config):
    return {
        'Api-Key': config.api_key or '',
        'Secret-Key': config.api_secret or '',
        'Content-Type': 'application/json',
    }


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def send_to_steadfast(request, order_id):
    """
    Send a single order to Steadfast courier.
    POST /api/orders/{id}/send-to-steadfast/
    """
    import requests as req

    user = request.user
    try:
        order = Order.objects.get(id=order_id, user=user)
    except Order.DoesNotExist:
        return Response({'success': False, 'error': 'Order not found'}, status=404)

    if order.consignment_id:
        return Response({
            'success': False,
            'error': 'already_sent',
            'message': 'এই অর্ডার ইতিমধ্যে Steadfast-এ পাঠানো হয়েছে।',
            'consignment_id': order.consignment_id,
            'tracking_code': order.steadfast_tracking_code,
        })

    try:
        config = CourierConfig.objects.get(user=user, courier_name='steadfast', is_active=True)
    except CourierConfig.DoesNotExist:
        return Response({
            'success': False,
            'error': 'no_config',
            'message': 'Steadfast API কনফিগারেশন পাওয়া যায়নি। প্রথমে কুরিয়ার সেটিংসে API Key যোগ করুন।',
        })

    import re as _re
    # Steadfast invoice: alphanumeric + hyphens + underscores only, max 50 chars
    safe_invoice = _re.sub(r'[^A-Za-z0-9\-_]', '-', order.order_number or str(order.id))[:50]

    payload = {
        'invoice': safe_invoice,
        'recipient_name': (order.customer_name or 'N/A')[:100],
        'recipient_phone': (order.customer_phone or '')[:11],
        'recipient_address': (order.customer_address or 'N/A')[:250],
        'cod_amount': float(order.grand_total or 0),
        'note': (order.notes or '')[:250],
        'item_description': ', '.join(
            item.product_name for item in order.items.all() if item.product_name
        ) or '',
    }

    try:
        resp = req.post(
            f'{STEADFAST_BASE_URL}/create_order',
            json=payload,
            headers=_steadfast_headers(config),
            timeout=15,
        )
        try:
            data = resp.json()
        except Exception:
            data = {'raw_body': resp.text[:500]}
    except Exception as e:
        return Response({'success': False, 'message': f'নেটওয়ার্ক ত্রুটি: {e}'})

    if resp.status_code == 200 and data.get('status') == 200:
        consignment = data.get('consignment', {})
        order.consignment_id = str(consignment.get('consignment_id', ''))
        order.steadfast_tracking_code = consignment.get('tracking_code', '')
        order.steadfast_status = consignment.get('status', 'in_review')
        order.courier_type = 'steadfast'
        order.save(update_fields=['consignment_id', 'steadfast_tracking_code', 'steadfast_status', 'courier_type'])
        return Response({
            'success': True,
            'message': 'Steadfast-এ অর্ডার পাঠানো হয়েছে।',
            'consignment_id': order.consignment_id,
            'tracking_code': order.steadfast_tracking_code,
            'steadfast_status': order.steadfast_status,
        })
    else:
        # Build a user-friendly message from the Steadfast response
        raw_msg = data.get('message') or data.get('error') or str(data)
        return Response({
            'success': False,
            'message': f'Steadfast ত্রুটি (HTTP {resp.status_code}): {raw_msg}',
            'detail': data,
            'sent_payload': payload,
        })


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def steadfast_balance(request):
    """
    Get current Steadfast balance.
    GET /api/steadfast/balance/
    """
    import requests as req

    user = request.user
    try:
        config = CourierConfig.objects.get(user=user, courier_name='steadfast', is_active=True)
    except CourierConfig.DoesNotExist:
        return Response({
            'success': False,
            'error': 'no_config',
            'message': 'Steadfast API কনফিগারেশন পাওয়া যায়নি।',
        })

    try:
        resp = req.get(
            f'{STEADFAST_BASE_URL}/get_balance',
            headers=_steadfast_headers(config),
            timeout=10,
        )
        try:
            data = resp.json()
        except Exception:
            data = {}
    except Exception as e:
        return Response({'success': False, 'message': f'নেটওয়ার্ক ত্রুটি: {e}'})

    if data.get('status') == 200 or 'current_balance' in data:
        return Response({
            'success': True,
            'current_balance': data.get('current_balance', 0),
        })
    return Response({
        'success': False,
        'message': data.get('message') or str(data),
    })


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def steadfast_delivery_status(request, order_id):
    """
    Fetch live delivery status for an order from Steadfast.
    GET /api/orders/{id}/steadfast-status/
    """
    import requests as req

    user = request.user
    try:
        order = Order.objects.get(id=order_id, user=user)
    except Order.DoesNotExist:
        return Response({'success': False, 'error': 'Order not found'}, status=404)

    if not order.consignment_id:
        return Response({
            'success': False,
            'error': 'not_sent',
            'message': 'এই অর্ডার এখনো Steadfast-এ পাঠানো হয়নি।',
        })

    try:
        config = CourierConfig.objects.get(user=user, courier_name='steadfast', is_active=True)
    except CourierConfig.DoesNotExist:
        return Response({'success': False, 'message': 'Steadfast কনফিগ পাওয়া যায়নি।'})

    try:
        resp = req.get(
            f'{STEADFAST_BASE_URL}/status_by_cid/{order.consignment_id}',
            headers=_steadfast_headers(config),
            timeout=10,
        )
        try:
            data = resp.json()
        except Exception:
            data = {}
    except Exception as e:
        return Response({'success': False, 'message': f'নেটওয়ার্ক ত্রুটি: {e}'})

    delivery_status = data.get('delivery_status', order.steadfast_status or 'unknown')
    # Cache the status locally
    if delivery_status and delivery_status != order.steadfast_status:
        order.steadfast_status = delivery_status
        order.save(update_fields=['steadfast_status'])

    return Response({
        'success': True,
        'consignment_id': order.consignment_id,
        'tracking_code': order.steadfast_tracking_code,
        'delivery_status': delivery_status,
        'raw': data,
    })


# ==================== COURIER TRACKING ENDPOINT ====================

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def track_courier(request, order_id):
    """
    Full tracking info for an order.
    GET /api/orders/{id}/track-courier/
    Returns live status + tracking URL + courier details.
    """
    import requests as req

    user = request.user
    try:
        order = Order.objects.get(id=order_id, user=user)
    except Order.DoesNotExist:
        return Response({'success': False, 'error': 'Order not found'}, status=404)

    courier_type = order.courier_type or 'self'
    consignment_id = order.consignment_id or order.courier_tracking_id or ''

    if not consignment_id:
        return Response({
            'success': True,
            'courier': courier_type,
            'consignment_id': '',
            'tracking_url': None,
            'status': None,
            'live_data': None,
            'message': 'এই অর্ডারে এখনো কোনো কুরিয়ার কনসাইনমেন্ট নেই।',
        })

    result = {
        'success': True,
        'courier': courier_type,
        'consignment_id': consignment_id,
        'tracking_code': order.steadfast_tracking_code or consignment_id,
        'cached_status': order.steadfast_status or '',
        'tracking_url': None,
        'live_data': None,
    }

    if courier_type == 'steadfast':
        tracking_code = order.steadfast_tracking_code or consignment_id
        result['tracking_url'] = f'https://steadfast.com.bd/t/{tracking_code}'
        # Try live status
        try:
            config = CourierConfig.objects.get(user=user, courier_name='steadfast', is_active=True)
            resp = req.get(
                f'https://portal.steadfast.com.bd/api/v1/status/by-consignment-id/{consignment_id}',
                headers={'Api-Key': config.api_key or '', 'Secret-Key': config.api_secret or ''},
                timeout=10,
            )
            if resp.status_code == 200:
                data = resp.json()
                result['live_data'] = data
                result['status'] = data.get('delivery_status') or data.get('status') or order.steadfast_status
            else:
                result['status'] = order.steadfast_status
        except Exception:
            result['status'] = order.steadfast_status

    elif courier_type == 'pathao':
        result['tracking_url'] = f'https://pathao.com/track/{consignment_id}'
        # Try live status from Pathao
        try:
            config = CourierConfig.objects.get(user=user, courier_name='pathao', is_active=True)
            token, err = _pathao_get_token(config)
            if not err:
                base = _pathao_base_url(config)
                resp = req.get(
                    f'{base}/aladdin/api/v1/orders/{consignment_id}/info',
                    headers={'Authorization': f'Bearer {token}'},
                    timeout=10,
                )
                if resp.status_code == 200:
                    data = resp.json()
                    order_info = data.get('data', {})
                    result['live_data'] = order_info
                    result['status'] = order_info.get('order_status_slug') or order_info.get('order_status') or order.steadfast_status
                else:
                    result['status'] = order.steadfast_status
            else:
                result['status'] = order.steadfast_status
        except Exception:
            result['status'] = order.steadfast_status
    else:
        result['message'] = 'নিজস্ব ডেলিভারি।'
        result['status'] = order.order_status

    return Response(result)


# ==================== PATHAO COURIER INTEGRATION ====================

PATHAO_SANDBOX_URL = 'https://courier-api-sandbox.pathao.com'
PATHAO_LIVE_URL = 'https://api-hermes.pathao.com'


def _pathao_base_url(config):
    return PATHAO_SANDBOX_URL if config.pathao_is_sandbox else PATHAO_LIVE_URL


def _pathao_get_token(config):
    """
    Returns a valid Pathao access token, refreshing or re-issuing as needed.
    Saves updated tokens back to config.
    """
    import requests as req
    import datetime
    from django.utils import timezone as tz

    base = _pathao_base_url(config)
    # If token exists and not expired (with 60s buffer)
    if config.pathao_access_token and config.pathao_token_expires_at:
        if config.pathao_token_expires_at > tz.now() + datetime.timedelta(seconds=60):
            return config.pathao_access_token, None

    # Try refresh token first
    if config.pathao_refresh_token:
        try:
            resp = req.post(
                f'{base}/aladdin/api/v1/issue-token',
                json={
                    'client_id': config.client_id or '',
                    'client_secret': config.client_secret or '',
                    'grant_type': 'refresh_token',
                    'refresh_token': config.pathao_refresh_token,
                },
                headers={'Content-Type': 'application/json'},
                timeout=15,
            )
            if resp.status_code == 200:
                data = resp.json()
                if data.get('access_token'):
                    config.pathao_access_token = data['access_token']
                    config.pathao_refresh_token = data.get('refresh_token', config.pathao_refresh_token)
                    expires_in = int(data.get('expires_in', 432000))
                    config.pathao_token_expires_at = tz.now() + datetime.timedelta(seconds=expires_in)
                    config.save(update_fields=['pathao_access_token', 'pathao_refresh_token', 'pathao_token_expires_at'])
                    return config.pathao_access_token, None
        except Exception:
            pass

    # Issue fresh token using password grant (api_key=username, api_secret=password)
    try:
        resp = req.post(
            f'{base}/aladdin/api/v1/issue-token',
            json={
                'client_id': config.client_id or '',
                'client_secret': config.client_secret or '',
                'grant_type': 'password',
                'username': config.api_key or '',
                'password': config.api_secret or '',
            },
            headers={'Content-Type': 'application/json'},
            timeout=15,
        )
        try:
            data = resp.json()
        except Exception:
            return None, f'Pathao token error (HTTP {resp.status_code}): {resp.text[:200]}'

        if resp.status_code == 200 and data.get('access_token'):
            config.pathao_access_token = data['access_token']
            config.pathao_refresh_token = data.get('refresh_token', '')
            expires_in = int(data.get('expires_in', 432000))
            config.pathao_token_expires_at = tz.now() + datetime.timedelta(seconds=expires_in)
            config.save(update_fields=['pathao_access_token', 'pathao_refresh_token', 'pathao_token_expires_at'])
            return config.pathao_access_token, None
        else:
            msg = data.get('message') or data.get('error') or str(data)
            return None, f'Pathao token error (HTTP {resp.status_code}): {msg}'
    except Exception as e:
        return None, f'নেটওয়ার্ক ত্রুটি: {e}'


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def pathao_connect(request):
    """
    Issue and store Pathao access token.
    POST /api/pathao/connect/
    Body: {client_id, client_secret, username, password, store_id, is_sandbox}
    """
    import requests as req
    import datetime
    from django.utils import timezone as tz

    user = request.user
    client_id = (request.data.get('client_id') or '').strip()
    client_secret = (request.data.get('client_secret') or '').strip()
    username = (request.data.get('username') or '').strip()
    password = (request.data.get('password') or '').strip()
    store_id = (request.data.get('store_id') or '').strip()
    is_sandbox = bool(request.data.get('is_sandbox', True))

    if not all([client_id, client_secret, username, password]):
        return Response({'success': False, 'message': 'client_id, client_secret, username, password আবশ্যক।'})

    base = PATHAO_SANDBOX_URL if is_sandbox else PATHAO_LIVE_URL
    try:
        resp = req.post(
            f'{base}/aladdin/api/v1/issue-token',
            json={
                'client_id': client_id,
                'client_secret': client_secret,
                'grant_type': 'password',
                'username': username,
                'password': password,
            },
            headers={'Content-Type': 'application/json'},
            timeout=15,
        )
        try:
            data = resp.json()
        except Exception:
            return Response({'success': False, 'message': f'Pathao সংযোগ ত্রুটি: {resp.text[:200]}'})
    except Exception as e:
        return Response({'success': False, 'message': f'নেটওয়ার্ক ত্রুটি: {e}'})

    if resp.status_code != 200 or not data.get('access_token'):
        msg = data.get('message') or data.get('error') or str(data)
        return Response({'success': False, 'message': f'Pathao লগইন ব্যর্থ: {msg}', 'detail': data})

    expires_in = int(data.get('expires_in', 432000))
    config, _ = CourierConfig.objects.get_or_create(
        user=user,
        courier_name='pathao',
        defaults={'is_active': True},
    )
    config.client_id = client_id
    config.client_secret = client_secret
    config.api_key = username
    config.api_secret = password
    if store_id:
        config.store_id = store_id
    config.pathao_is_sandbox = is_sandbox
    config.pathao_access_token = data['access_token']
    config.pathao_refresh_token = data.get('refresh_token', '')
    config.pathao_token_expires_at = tz.now() + datetime.timedelta(seconds=expires_in)
    config.is_active = True
    config.save()

    # Fetch store list for the user to pick from
    try:
        stores_resp = req.get(
            f'{base}/aladdin/api/v1/stores',
            headers={'Authorization': f'Bearer {data["access_token"]}'},
            timeout=15,
        )
        stores = stores_resp.json().get('data', {}).get('data', []) if stores_resp.status_code == 200 else []
    except Exception:
        stores = []

    return Response({
        'success': True,
        'message': 'Pathao সংযোগ সফল হয়েছে।',
        'store_id': config.store_id,
        'stores': stores,
    })


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def send_to_pathao(request, order_id):
    """
    Send a single order to Pathao courier.
    POST /api/orders/{id}/send-to-pathao/
    """
    import requests as req

    user = request.user
    try:
        order = Order.objects.get(id=order_id, user=user)
    except Order.DoesNotExist:
        return Response({'success': False, 'error': 'Order not found'})

    if order.consignment_id:
        return Response({
            'success': False,
            'error': 'already_sent',
            'message': 'এই অর্ডার ইতিমধ্যে কুরিয়ারে পাঠানো হয়েছে।',
            'consignment_id': order.consignment_id,
        })

    try:
        config = CourierConfig.objects.get(user=user, courier_name='pathao', is_active=True)
    except CourierConfig.DoesNotExist:
        return Response({
            'success': False,
            'error': 'no_config',
            'message': 'Pathao API কনফিগারেশন পাওয়া যায়নি। প্রথমে কুরিয়ার সেটিংসে Pathao সংযুক্ত করুন।',
        })

    if not config.store_id:
        return Response({'success': False, 'message': 'Pathao Store ID সেট করা নেই। কুরিয়ার সেটিংস আপডেট করুন।'})

    token, err = _pathao_get_token(config)
    if err:
        return Response({'success': False, 'message': err})

    import re as _re
    safe_order_id = _re.sub(r'[^A-Za-z0-9\-_]', '-', order.order_number or str(order.id))[:50]
    item_desc = ', '.join(
        item.product_name for item in order.items.all() if item.product_name
    ) or 'পণ্য'

    payload = {
        'store_id': int(config.store_id),
        'merchant_order_id': safe_order_id,
        'recipient_name': (order.customer_name or 'N/A')[:100],
        'recipient_phone': (order.customer_phone or '')[:11],
        'recipient_address': (order.customer_address or 'N/A')[:220],
        'delivery_type': 48,
        'item_type': 2,
        'item_quantity': max(1, sum(i.quantity for i in order.items.all())),
        'item_weight': 0.5,
        'amount_to_collect': int(float(order.grand_total or 0)),
        'item_description': item_desc[:255],
        'special_instruction': (order.notes or '')[:255],
    }

    base = _pathao_base_url(config)
    try:
        resp = req.post(
            f'{base}/aladdin/api/v1/orders',
            json=payload,
            headers={'Content-Type': 'application/json', 'Authorization': f'Bearer {token}'},
            timeout=15,
        )
        try:
            data = resp.json()
        except Exception:
            data = {'raw_body': resp.text[:500]}
    except Exception as e:
        return Response({'success': False, 'message': f'নেটওয়ার্ক ত্রুটি: {e}'})

    if resp.status_code == 200 and data.get('code') == 200:
        order_data = data.get('data', {})
        order.consignment_id = str(order_data.get('consignment_id', ''))
        order.steadfast_tracking_code = str(order_data.get('consignment_id', ''))
        order.steadfast_status = (order_data.get('order_status') or 'Pending').lower()
        order.courier_type = 'pathao'
        order.save(update_fields=['consignment_id', 'steadfast_tracking_code', 'steadfast_status', 'courier_type'])
        return Response({
            'success': True,
            'message': 'Pathao-তে অর্ডার পাঠানো হয়েছে।',
            'consignment_id': order.consignment_id,
            'order_status': order_data.get('order_status', 'Pending'),
            'delivery_fee': order_data.get('delivery_fee'),
        })
    else:
        raw_msg = data.get('message') or data.get('error') or str(data)
        field_errors = data.get('errors', {})
        if field_errors:
            raw_msg = raw_msg + ' | ' + '; '.join(
                f'{k}: {v[0] if isinstance(v, list) else v}'
                for k, v in field_errors.items()
            )
        return Response({
            'success': False,
            'message': f'Pathao ত্রুটি (HTTP {resp.status_code}): {raw_msg}',
            'detail': data,
        })


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def pathao_delivery_status(request, order_id):
    """
    Fetch live delivery status from Pathao.
    GET /api/orders/{id}/pathao-status/
    """
    import requests as req

    user = request.user
    try:
        order = Order.objects.get(id=order_id, user=user)
    except Order.DoesNotExist:
        return Response({'success': False, 'error': 'Order not found'})

    if not order.consignment_id:
        return Response({'success': False, 'error': 'not_sent', 'message': 'এই অর্ডার এখনো Pathao-তে পাঠানো হয়নি।'})

    try:
        config = CourierConfig.objects.get(user=user, courier_name='pathao', is_active=True)
    except CourierConfig.DoesNotExist:
        return Response({'success': False, 'message': 'Pathao কনফিগারেশন পাওয়া যায়নি।'})

    token, err = _pathao_get_token(config)
    if err:
        return Response({'success': False, 'message': err})

    base = _pathao_base_url(config)
    try:
        resp = req.get(
            f'{base}/aladdin/api/v1/orders/{order.consignment_id}/info',
            headers={'Authorization': f'Bearer {token}'},
            timeout=15,
        )
        try:
            data = resp.json()
        except Exception:
            data = {'raw_body': resp.text[:500]}
    except Exception as e:
        return Response({'success': False, 'message': f'নেটওয়ার্ক ত্রুটি: {e}'})

    order_info = data.get('data', {})
    order_status = order_info.get('order_status_slug') or order_info.get('order_status') or order.steadfast_status

    if order_status and order_status != order.steadfast_status:
        order.steadfast_status = order_status
        order.save(update_fields=['steadfast_status'])

    return Response({
        'success': True,
        'consignment_id': order.consignment_id,
        'order_status': order_status,
        'raw': data,
    })


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def pathao_balance(request):
    """
    Get current Pathao wallet balance.
    GET /api/pathao/balance/
    """
    import requests as req

    user = request.user
    try:
        config = CourierConfig.objects.get(user=user, courier_name='pathao', is_active=True)
    except CourierConfig.DoesNotExist:
        return Response({'success': False, 'error': 'no_config', 'message': 'Pathao কনফিগারেশন পাওয়া যায়নি।'})

    token, err = _pathao_get_token(config)
    if err:
        return Response({'success': False, 'message': err})

    base = _pathao_base_url(config)
    try:
        resp = req.get(
            f'{base}/aladdin/api/v1/merchant/balance',
            headers={'Authorization': f'Bearer {token}'},
            timeout=15,
        )
        try:
            data = resp.json()
        except Exception:
            data = {}
    except Exception as e:
        return Response({'success': False, 'message': f'নেটওয়ার্ক ত্রুটি: {e}'})

    if resp.status_code == 200 and data.get('code') == 200:
        balance_data = data.get('data', {})
        return Response({
            'success': True,
            'current_balance': balance_data.get('current_balance', 0),
            'withdraw_balance': balance_data.get('withdraw_balance', 0),
        })
    elif data.get('message') == 'Unauthorized!':
        return Response({
            'success': False,
            'error': 'unauthorized',
            'message': 'Pathao পোর্টালে ব্যালেন্স দেখুন',
        })
    else:
        return Response({'success': False, 'message': data.get('message', 'Balance fetch failed'), 'raw': data})


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def pathao_stores(request):
    """
    Fetch Pathao store list for this merchant account.
    GET /api/pathao/stores/
    """
    import requests as req

    user = request.user
    try:
        config = CourierConfig.objects.get(user=user, courier_name='pathao', is_active=True)
    except CourierConfig.DoesNotExist:
        return Response({'success': False, 'message': 'Pathao কনফিগারেশন পাওয়া যায়নি।'})

    token, err = _pathao_get_token(config)
    if err:
        return Response({'success': False, 'message': err})

    base = _pathao_base_url(config)
    try:
        resp = req.get(
            f'{base}/aladdin/api/v1/stores',
            headers={'Authorization': f'Bearer {token}'},
            timeout=15,
        )
        data = resp.json()
    except Exception as e:
        return Response({'success': False, 'message': f'নেটওয়ার্ক ত্রুটি: {e}'})

    if resp.status_code == 200:
        stores = data.get('data', {}).get('data', [])
        return Response({'success': True, 'stores': stores})
    else:
        return Response({'success': False, 'message': data.get('message', 'Store list fetch failed')})


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def pathao_set_store(request):
    """
    Update the Pathao store_id for this user's config.
    POST /api/pathao/set-store/
    Body: {store_id}
    """
    user = request.user
    store_id = str(request.data.get('store_id', '')).strip()
    if not store_id:
        return Response({'success': False, 'message': 'store_id আবশ্যক।'})

    try:
        config = CourierConfig.objects.get(user=user, courier_name='pathao', is_active=True)
    except CourierConfig.DoesNotExist:
        return Response({'success': False, 'message': 'Pathao কনফিগারেশন পাওয়া যায়নি।'})

    config.store_id = store_id
    config.save(update_fields=['store_id'])
    return Response({'success': True, 'message': 'স্টোর আপডেট হয়েছে।', 'store_id': store_id})


# ==================== DASHBOARD STATS ENDPOINT ====================

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def dashboard_stats(request):
    """
    Quick dashboard statistics.
    GET /api/dashboard-stats/
    """
    user = request.user
    today = timezone.now().date()
    month_start = today.replace(day=1)

    orders = Order.objects.filter(user=user)
    products = Product.objects.filter(user=user, is_active=True)
    customers = Customer.objects.filter(user=user)

    today_orders = orders.filter(order_date__date=today).count()
    today_revenue = float(
        orders.filter(order_date__date=today).aggregate(t=Sum('grand_total'))['t'] or 0
    )
    month_revenue = float(
        orders.filter(order_date__date__gte=month_start).aggregate(t=Sum('grand_total'))['t'] or 0
    )
    total_orders = orders.count()
    pending_orders = orders.filter(order_status='pending').count()
    processing_orders = orders.filter(order_status='processing').count()
    shipped_orders = orders.filter(order_status='shipped').count()
    delivered_orders = orders.filter(order_status='delivered').count()
    cancelled_orders = orders.filter(order_status='cancelled').count()
    returned_orders = orders.filter(order_status='returned').count()
    low_stock = len([p for p in products if p.is_low_stock])
    total_customers = customers.count()
    total_products = products.count()

    recent_orders = list(
        orders.order_by('-created_at')[:5].values(
            'id', 'order_number', 'customer_name', 'grand_total',
            'order_status', 'payment_status', 'order_date'
        )
    )
    for o in recent_orders:
        o['grand_total'] = float(o['grand_total'])
        if o['order_date']:
            o['order_date'] = str(o['order_date'])

    return Response({
        'success': True,
        'stats': {
            'today_orders': today_orders,
            'today_revenue': round(today_revenue, 2),
            'month_revenue': round(month_revenue, 2),
            'total_orders': total_orders,
            'pending_orders': pending_orders,
            'processing_orders': processing_orders,
            'shipped_orders': shipped_orders,
            'delivered_orders': delivered_orders,
            'cancelled_orders': cancelled_orders,
            'returned_orders': returned_orders,
            'low_stock_count': low_stock,
            'total_customers': total_customers,
            'total_products': total_products,
            'sms_balance': user.sms_balance,
            'wallet_balance': float(user.wallet_balance),
            'is_premium': user.is_premium,
            'ai_free_uses_remaining': user.ai_free_uses_remaining,
            'subscription_type': user.subscription_type,
            'subscription_end_date': str(user.subscription_end_date) if user.subscription_end_date else None,
        },
        'recent_orders': recent_orders,
    })


# ==================== WALLET & SUBSCRIPTION VIEWS ====================

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def wallet_info(request):
    """GET /api/wallet/ - wallet balance + recent transactions"""
    user = request.user
    transactions = WalletTransaction.objects.filter(user=user).order_by('-created_at')[:50]
    txn_data = [
        {
            'id': t.id,
            'type': t.transaction_type,
            'type_display': t.get_transaction_type_display(),
            'amount': float(t.amount),
            'balance_after': float(t.balance_after),
            'description': t.description,
            'reference': t.reference,
            'created_at': t.created_at.strftime('%Y-%m-%d %H:%M'),
        }
        for t in transactions
    ]
    return Response({
        'success': True,
        'wallet_balance': float(user.wallet_balance),
        'is_premium': user.is_premium,
        'subscription_type': user.subscription_type,
        'subscription_end_date': str(user.subscription_end_date) if user.subscription_end_date else None,
        'ai_free_uses_remaining': user.ai_free_uses_remaining,
        'transactions': txn_data,
    })


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def request_topup(request):
    """
    POST /api/wallet/topup/
    Body: { amount, payment_method, transaction_id, sender_number }
    Creates a pending top-up request for admin approval.
    """
    user = request.user
    amount = request.data.get('amount')
    payment_method = request.data.get('payment_method')
    transaction_id = request.data.get('transaction_id', '').strip()
    sender_number = request.data.get('sender_number', '').strip()

    if not amount or float(amount) < 10:
        return Response({'success': False, 'error': 'Minimum top-up is ৳10'}, status=400)
    if payment_method not in ['bkash', 'nagad', 'rocket', 'bank']:
        return Response({'success': False, 'error': 'Invalid payment method'}, status=400)
    if not transaction_id:
        return Response({'success': False, 'error': 'Transaction ID required'}, status=400)

    # Check for duplicate transaction_id
    if SubscriptionPurchase.objects.filter(transaction_id=transaction_id).exists():
        return Response({'success': False, 'error': 'This transaction ID has already been submitted'}, status=400)

    purchase = SubscriptionPurchase.objects.create(
        user=user,
        plan='wallet_topup',
        amount=amount,
        payment_method=payment_method,
        transaction_id=transaction_id,
        sender_number=sender_number,
        status='pending',
    )
    return Response({
        'success': True,
        'message': 'Top-up request submitted. Balance will be credited after admin verification (usually within 1 hour).',
        'request_id': purchase.id,
    })


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def purchase_subscription(request):
    """
    POST /api/subscription/purchase/
    Body: { plan (monthly/yearly), payment_method, transaction_id, sender_number }
    """
    user = request.user
    plan = request.data.get('plan')
    payment_method = request.data.get('payment_method')
    transaction_id = request.data.get('transaction_id', '').strip()
    sender_number = request.data.get('sender_number', '').strip()

    plan_prices = {'monthly': 200, 'yearly': 1099}
    if plan not in plan_prices:
        return Response({'success': False, 'error': 'Invalid plan. Choose monthly or yearly.'}, status=400)
    if payment_method not in ['bkash', 'nagad', 'rocket', 'bank']:
        return Response({'success': False, 'error': 'Invalid payment method'}, status=400)
    if not transaction_id:
        return Response({'success': False, 'error': 'Transaction ID required'}, status=400)
    if SubscriptionPurchase.objects.filter(transaction_id=transaction_id).exists():
        return Response({'success': False, 'error': 'This transaction ID has already been submitted'}, status=400)

    purchase = SubscriptionPurchase.objects.create(
        user=user,
        plan=plan,
        amount=plan_prices[plan],
        payment_method=payment_method,
        transaction_id=transaction_id,
        sender_number=sender_number,
        status='pending',
    )
    return Response({
        'success': True,
        'message': f'{plan.capitalize()} subscription request submitted. Will be activated after admin verification.',
        'request_id': purchase.id,
        'amount': plan_prices[plan],
    })


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def purchase_history(request):
    """GET /api/subscription/history/ - list all purchase requests"""
    user = request.user
    purchases = SubscriptionPurchase.objects.filter(user=user).order_by('-created_at')[:20]
    data = [
        {
            'id': p.id,
            'plan': p.plan,
            'plan_display': p.get_plan_display(),
            'amount': float(p.amount),
            'payment_method': p.get_payment_method_display(),
            'transaction_id': p.transaction_id,
            'status': p.status,
            'created_at': p.created_at.strftime('%Y-%m-%d %H:%M'),
        }
        for p in purchases
    ]
    return Response({'success': True, 'purchases': data})


# ==================== WALLET & SUBSCRIPTION VIEWS ====================

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def wallet_info(request):
    """GET /api/wallet/ - wallet balance + recent transactions"""
    user = request.user
    transactions = WalletTransaction.objects.filter(user=user).order_by('-created_at')[:50]
    txn_data = [
        {
            'id': t.id,
            'type': t.transaction_type,
            'type_display': t.get_transaction_type_display(),
            'amount': float(t.amount),
            'balance_after': float(t.balance_after),
            'description': t.description,
            'reference': t.reference,
            'created_at': t.created_at.strftime('%Y-%m-%d %H:%M'),
        }
        for t in transactions
    ]
    return Response({
        'success': True,
        'wallet_balance': float(user.wallet_balance),
        'is_premium': user.is_premium,
        'subscription_type': user.subscription_type,
        'subscription_end_date': str(user.subscription_end_date) if user.subscription_end_date else None,
        'ai_free_uses_remaining': user.ai_free_uses_remaining,
        'transactions': txn_data,
    })


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def request_topup(request):
    """
    POST /api/wallet/topup/
    Body: { amount, payment_method, transaction_id, sender_number }
    Creates a pending top-up request for admin approval.
    """
    user = request.user
    amount = request.data.get('amount')
    payment_method = request.data.get('payment_method')
    transaction_id = request.data.get('transaction_id', '').strip()
    sender_number = request.data.get('sender_number', '').strip()

    if not amount or float(amount) < 10:
        return Response({'success': False, 'error': 'Minimum top-up is ৳10'}, status=400)
    if payment_method not in ['bkash', 'nagad', 'rocket', 'bank']:
        return Response({'success': False, 'error': 'Invalid payment method'}, status=400)
    if not transaction_id:
        return Response({'success': False, 'error': 'Transaction ID required'}, status=400)

    # Check for duplicate transaction_id
    if SubscriptionPurchase.objects.filter(transaction_id=transaction_id).exists():
        return Response({'success': False, 'error': 'This transaction ID has already been submitted'}, status=400)

    purchase = SubscriptionPurchase.objects.create(
        user=user,
        plan='wallet_topup',
        amount=amount,
        payment_method=payment_method,
        transaction_id=transaction_id,
        sender_number=sender_number,
        status='pending',
    )
    return Response({
        'success': True,
        'message': 'Top-up request submitted. Balance will be credited after admin verification (usually within 1 hour).',
        'request_id': purchase.id,
    })


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def purchase_subscription(request):
    """
    POST /api/subscription/purchase/
    Body: { plan (monthly/yearly), payment_method, transaction_id, sender_number }
    """
    user = request.user
    plan = request.data.get('plan')
    payment_method = request.data.get('payment_method')
    transaction_id = request.data.get('transaction_id', '').strip()
    sender_number = request.data.get('sender_number', '').strip()

    plan_prices = {'monthly': 200, 'yearly': 1099}
    if plan not in plan_prices:
        return Response({'success': False, 'error': 'Invalid plan. Choose monthly or yearly.'}, status=400)
    if payment_method not in ['bkash', 'nagad', 'rocket', 'bank']:
        return Response({'success': False, 'error': 'Invalid payment method'}, status=400)
    if not transaction_id:
        return Response({'success': False, 'error': 'Transaction ID required'}, status=400)
    if SubscriptionPurchase.objects.filter(transaction_id=transaction_id).exists():
        return Response({'success': False, 'error': 'This transaction ID has already been submitted'}, status=400)

    purchase = SubscriptionPurchase.objects.create(
        user=user,
        plan=plan,
        amount=plan_prices[plan],
        payment_method=payment_method,
        transaction_id=transaction_id,
        sender_number=sender_number,
        status='pending',
    )
    return Response({
        'success': True,
        'message': f'{plan.capitalize()} subscription request submitted. Will be activated after admin verification.',
        'request_id': purchase.id,
        'amount': plan_prices[plan],
    })


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def purchase_history(request):
    """GET /api/subscription/history/ - list all purchase requests"""
    user = request.user
    purchases = SubscriptionPurchase.objects.filter(user=user).order_by('-created_at')[:20]
    data = [
        {
            'id': p.id,
            'plan': p.plan,
            'plan_display': p.get_plan_display(),
            'amount': float(p.amount),
            'payment_method': p.get_payment_method_display(),
            'transaction_id': p.transaction_id,
            'status': p.status,
            'created_at': p.created_at.strftime('%Y-%m-%d %H:%M'),
        }
        for p in purchases
    ]
    return Response({'success': True, 'purchases': data})
