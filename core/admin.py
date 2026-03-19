"""
Django Admin Configuration for F-Khotiyan Models
Provides user-friendly admin interface for managing all models
"""

from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from django.utils.html import format_html
from .models import (
    User, Product, Customer, Order, OrderItem, 
    Expense, CourierConfig, SMSPurchase, SMSLog,
    Subscription, Return, WalletTransaction, SubscriptionPurchase
)


@admin.register(User)
class UserAdmin(BaseUserAdmin):
    """Custom User Admin Interface"""
    
    list_display = ['phone_number', 'business_name', 'owner_name', 'subscription_type', 
                   'subscription_status', 'daily_orders', 'sms_balance', 'created_at']
    list_filter = ['subscription_type', 'is_active', 'created_at', 'district']
    search_fields = ['phone_number', 'business_name', 'owner_name', 'email']
    ordering = ['-created_at']
    
    fieldsets = (
        ('Authentication', {
            'fields': ('phone_number', 'email', 'password')
        }),
        ('Business Information', {
            'fields': ('business_name', 'owner_name', 'logo')
        }),
        ('Location', {
            'fields': ('location', 'district', 'country')
        }),
        ('Subscription', {
            'fields': ('subscription_type', 'subscription_start_date', 'subscription_end_date')
        }),
        ('Order Limits', {
            'fields': ('daily_order_count', 'last_order_date')
        }),
        ('SMS Balance', {
            'fields': ('sms_balance',)
        }),
        ('Permissions', {
            'fields': ('is_active', 'is_staff', 'is_superuser', 'groups', 'user_permissions')
        }),
        ('Important Dates', {
            'fields': ('last_login', 'date_joined', 'created_at')
        }),
    )
    
    add_fieldsets = (
        ('Authentication', {
            'classes': ('wide',),
            'fields': ('phone_number', 'password1', 'password2'),
        }),
        ('Required Information', {
            'classes': ('wide',),
            'fields': ('business_name', 'owner_name'),
        }),
        ('Optional', {
            'classes': ('wide',),
            'fields': ('email', 'location', 'district'),
        }),
    )
    
    readonly_fields = ['created_at', 'date_joined', 'last_login']
    
    def daily_orders(self, obj):
        if obj.subscription_type == 'free':
            return format_html(
                '<span style="color: {};">{}/{}</span>',
                'red' if obj.daily_order_count >= 5 else 'green',
                obj.daily_order_count,
                obj.daily_order_limit
            )
        return format_html('<span style="color: green;">Unlimited</span>')
    daily_orders.short_description = 'Daily Orders'
    
    def subscription_status(self, obj):
        if obj.is_subscription_active:
            return format_html('<span style="color: green;">✓ Active</span>')
        return format_html('<span style="color: red;">✗ Expired</span>')
    subscription_status.short_description = 'Status'


@admin.register(Product)
class ProductAdmin(admin.ModelAdmin):
    """Product Admin Interface"""
    
    list_display = ['product_name', 'sku', 'user', 'selling_price', 'quantity', 
                   'stock_status', 'is_active', 'created_at']
    list_filter = ['is_active', 'created_at', 'category']
    search_fields = ['product_name', 'sku', 'user__business_name']
    ordering = ['-created_at']
    
    fieldsets = (
        ('Product Information', {
            'fields': ('user', 'product_name', 'sku', 'category', 'description')
        }),
        ('Pricing', {
            'fields': ('purchase_price', 'selling_price')
        }),
        ('Inventory', {
            'fields': ('quantity', 'reorder_level', 'unit')
        }),
        ('Media', {
            'fields': ('image',)
        }),
        ('Status', {
            'fields': ('is_active',)
        }),
    )
    
    def stock_status(self, obj):
        if obj.is_low_stock:
            return format_html('<span style="color: red;">⚠ Low Stock</span>')
        return format_html('<span style="color: green;">✓ In Stock</span>')
    stock_status.short_description = 'Stock Status'


@admin.register(Customer)
class CustomerAdmin(admin.ModelAdmin):
    """Customer Admin Interface"""
    
    list_display = ['customer_name', 'phone_number', 'user', 'total_orders', 
                   'total_amount', 'is_fake', 'created_at']
    list_filter = ['is_fake', 'district', 'created_at']
    search_fields = ['customer_name', 'phone_number', 'user__business_name']
    ordering = ['-created_at']


class OrderItemInline(admin.TabularInline):
    """Inline Order Items"""
    model = OrderItem
    extra = 0
    readonly_fields = ['subtotal']


@admin.register(Order)
class OrderAdmin(admin.ModelAdmin):
    """Order Admin Interface"""
    
    list_display = ['order_number', 'customer_name', 'user', 'grand_total', 
                   'payment_status', 'order_status', 'courier_type', 'ai_created', 'created_at']
    list_filter = ['payment_status', 'order_status', 'courier_type', 'created_from_image', 'created_at']
    search_fields = ['order_number', 'customer_name', 'customer_phone']
    ordering = ['-created_at']
    inlines = [OrderItemInline]
    
    fieldsets = (
        ('Order Information', {
            'fields': ('order_number', 'user', 'customer', 'order_date')
        }),
        ('Customer Details', {
            'fields': ('customer_name', 'customer_phone', 'customer_address')
        }),
        ('Pricing', {
            'fields': ('total_amount', 'discount', 'delivery_charge', 'grand_total')
        }),
        ('Status', {
            'fields': ('payment_status', 'order_status')
        }),
        ('Courier', {
            'fields': ('courier_type', 'courier_tracking_id', 'qr_code')
        }),
        ('AI Order Creation', {
            'fields': ('created_from_image', 'source_image'),
            'classes': ('collapse',)
        }),
        ('Additional', {
            'fields': ('notes', 'sms_sent', 'invoice_pdf')
        }),
    )
    
    readonly_fields = ['order_number']
    
    def ai_created(self, obj):
        if obj.created_from_image:
            return format_html('<span style="color: blue;">🤖 AI</span>')
        return format_html('<span style="color: gray;">👤 Manual</span>')
    ai_created.short_description = 'Creation Method'


@admin.register(Expense)
class ExpenseAdmin(admin.ModelAdmin):
    """Expense Admin Interface"""
    
    list_display = ['category', 'amount', 'user', 'expense_date', 'created_at']
    list_filter = ['category', 'expense_date', 'created_at']
    search_fields = ['description', 'user__business_name']
    ordering = ['-expense_date']


@admin.register(CourierConfig)
class CourierConfigAdmin(admin.ModelAdmin):
    """Courier Configuration Admin"""
    
    list_display = ['courier_name', 'user', 'is_active', 'created_at']
    list_filter = ['courier_name', 'is_active']
    search_fields = ['user__business_name']


@admin.register(SMSPurchase)
class SMSPurchaseAdmin(admin.ModelAdmin):
    """SMS Purchase Admin"""
    
    list_display = ['user', 'quantity', 'total_price', 'payment_status', 
                   'confirmed_by_admin', 'created_at']
    list_filter = ['payment_status', 'confirmed_by_admin', 'created_at']
    search_fields = ['user__business_name', 'bkash_transaction_id']
    ordering = ['-created_at']
    
    actions = ['confirm_purchase']
    
    def confirm_purchase(self, request, queryset):
        from django.utils import timezone
        for purchase in queryset:
            if not purchase.confirmed_by_admin:
                purchase.confirmed_by_admin = True
                purchase.payment_status = 'confirmed'
                purchase.confirmed_at = timezone.now()
                purchase.user.sms_balance += purchase.quantity
                purchase.user.save()
                purchase.save()
        self.message_user(request, f"{queryset.count()} purchases confirmed.")
    confirm_purchase.short_description = "Confirm selected SMS purchases"


@admin.register(SMSLog)
class SMSLogAdmin(admin.ModelAdmin):
    """SMS Log Admin"""
    
    list_display = ['user', 'phone_number', 'status', 'order', 'sent_at']
    list_filter = ['status', 'sent_at']
    search_fields = ['user__business_name', 'phone_number', 'message']
    ordering = ['-sent_at']


@admin.register(Subscription)
class SubscriptionAdmin(admin.ModelAdmin):
    """Subscription Admin"""
    
    list_display = ['user', 'plan_type', 'amount', 'start_date', 'end_date', 
                   'is_active', 'created_at']
    list_filter = ['plan_type', 'is_active', 'created_at']
    search_fields = ['user__business_name', 'transaction_id']
    ordering = ['-created_at']


@admin.register(Return)
class ReturnAdmin(admin.ModelAdmin):
    """Return Admin"""
    
    list_display = ['order', 'user', 'refund_amount', 'status', 'return_date']
    list_filter = ['status', 'return_date']
    search_fields = ['order__order_number', 'user__business_name']
    ordering = ['-return_date']


@admin.register(WalletTransaction)
class WalletTransactionAdmin(admin.ModelAdmin):
    list_display = ['user', 'transaction_type', 'amount', 'balance_after', 'description', 'reference', 'created_at']
    list_filter = ['transaction_type', 'created_at']
    search_fields = ['user__business_name', 'user__phone_number', 'reference']
    readonly_fields = ['created_at']
    ordering = ['-created_at']


@admin.register(SubscriptionPurchase)
class SubscriptionPurchaseAdmin(admin.ModelAdmin):
    list_display = ['user', 'plan', 'amount', 'payment_method', 'transaction_id', 'sender_number', 'status', 'created_at']
    list_filter = ['plan', 'status', 'payment_method', 'created_at']
    search_fields = ['user__business_name', 'user__phone_number', 'transaction_id']
    readonly_fields = ['created_at', 'reviewed_at']
    actions = ['approve_selected', 'reject_selected']
    ordering = ['-created_at']

    def approve_selected(self, request, queryset):
        for purchase in queryset.filter(status='pending'):
            purchase.approve()
        self.message_user(request, f"{queryset.filter(status='approved').count()} purchase(s) approved.")
    approve_selected.short_description = "Approve selected purchases"

    def reject_selected(self, request, queryset):
        from django.utils import timezone
        queryset.filter(status='pending').update(status='rejected', reviewed_at=timezone.now())
        self.message_user(request, "Selected purchases rejected.")
    reject_selected.short_description = "Reject selected purchases"
