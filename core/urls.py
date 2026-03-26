"""
URL Configuration for F-Khotiyan Core App
Maps API endpoints to views
"""

from django.urls import path, include
from rest_framework.routers import DefaultRouter
from core import views

# Create router for ViewSets
router = DefaultRouter()
router.register(r'products', views.ProductViewSet, basename='product')
router.register(r'customers', views.CustomerViewSet, basename='customer')
router.register(r'orders', views.OrderViewSet, basename='order')
router.register(r'expenses', views.ExpenseViewSet, basename='expense')
router.register(r'courier-configs', views.CourierConfigViewSet, basename='courier-config')
router.register(r'sms-purchases', views.SMSPurchaseViewSet, basename='sms-purchase')
router.register(r'returns', views.ReturnViewSet, basename='return')
router.register(r'capital', views.CapitalInvestmentViewSet, basename='capital')

app_name = 'core'

urlpatterns = [
    # Authentication endpoints
    path('auth/register/', views.register, name='register'),
    path('auth/login/', views.login, name='login'),
    path('auth/profile/', views.profile, name='profile'),
    path('auth/profile/update/', views.update_profile, name='update-profile'),

    # AI Order Extraction endpoints
    path('orders/extract/', views.extract_order_from_message, name='extract-order'),
    path('orders/confirm-ai-order/', views.confirm_ai_order, name='confirm-ai-order'),
    path('orders/limit-info/', views.order_limit_info, name='order-limit-info'),

    # Order Actions
    path('orders/<int:order_id>/send-sms/', views.send_order_sms, name='send-order-sms'),
    path('orders/<int:order_id>/track-courier/', views.track_courier, name='track-courier'),
    path('orders/<int:order_id>/send-to-steadfast/', views.send_to_steadfast, name='send-to-steadfast'),
    path('orders/<int:order_id>/steadfast-status/', views.steadfast_delivery_status, name='steadfast-status'),

    # Steadfast
    path('steadfast/balance/', views.steadfast_balance, name='steadfast-balance'),

    # Pathao
    path('orders/<int:order_id>/send-to-pathao/', views.send_to_pathao, name='send-to-pathao'),
    path('orders/<int:order_id>/pathao-status/', views.pathao_delivery_status, name='pathao-status'),
    path('pathao/connect/', views.pathao_connect, name='pathao-connect'),
    path('pathao/balance/', views.pathao_balance, name='pathao-balance'),
    path('pathao/stores/', views.pathao_stores, name='pathao-stores'),
    path('pathao/set-store/', views.pathao_set_store, name='pathao-set-store'),

    # Reports
    path('reports/', views.reports, name='reports'),

    # Dashboard Stats
    path('dashboard-stats/', views.dashboard_stats, name='dashboard-stats'),

    # SMS
    path('sms/preview/', views.sms_preview, name='sms-preview'),
    path('sms/bulk/', views.send_bulk_sms, name='sms-bulk'),
    path('sms/logs/', views.sms_logs, name='sms-logs'),

    # Include router URLs (CRUD operations)
    path('', include(router.urls)),
]
