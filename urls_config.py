"""
Main URL Configuration for F-Khotiyan Project
Include this in your Django project's main urls.py
"""

from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static
from rest_framework_simplejwt.views import (
    TokenObtainPairView,
    TokenRefreshView,
    TokenVerifyView
)
from drf_yasg.views import get_schema_view
from drf_yasg import openapi
from rest_framework import permissions

# Swagger/OpenAPI Documentation
schema_view = get_schema_view(
    openapi.Info(
        title="F-Khotiyan API",
        default_version='v1',
        description="""
        F-Khotiyan SaaS Application API
        
        ## Features
        - 🤖 AI-powered order extraction from text/images
        - 📦 Product & inventory management
        - 📋 Order management with courier integration
        - 👥 Customer database
        - 💰 Expense tracking
        - 📱 SMS management
        - 🔔 Subscription management
        
        ## Authentication
        This API uses JWT (JSON Web Token) authentication.
        
        1. Register: POST /api/auth/register/
        2. Login: POST /api/auth/login/
        3. Use the access token in Authorization header: `Bearer <token>`
        
        ## Daily Order Limits
        - Free users: 5 orders per day
        - Paid users: Unlimited orders
        
        ## AI Order Extraction
        Extract order details from:
        - Text messages (WhatsApp, Facebook, etc.)
        - Screenshots
        
        Endpoints:
        - POST /api/orders/extract/ - Extract order data
        - POST /api/orders/confirm-ai-order/ - Create order from extracted data
        - GET /api/orders/limit-info/ - Check daily limit status
        """,
        terms_of_service="https://www.fkhotiyan.com/terms/",
        contact=openapi.Contact(email="support@fkhotiyan.com"),
        license=openapi.License(name="Proprietary License"),
    ),
    public=True,
    permission_classes=[permissions.AllowAny],
)

urlpatterns = [
    # Admin
    path('admin/', admin.site.urls),
    
    # API Documentation (Swagger)
    path('api/docs/', schema_view.with_ui('swagger', cache_timeout=0), name='swagger-docs'),
    path('api/redoc/', schema_view.with_ui('redoc', cache_timeout=0), name='redoc-docs'),
    path('api/swagger.json', schema_view.without_ui(cache_timeout=0), name='schema-json'),
    
    # JWT Token endpoints
    path('api/token/', TokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('api/token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('api/token/verify/', TokenVerifyView.as_view(), name='token_verify'),
    
    # Core API endpoints
    path('api/', include('core.urls')),
]

# Serve media files in development
if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
    urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)

# Custom admin site headers
admin.site.site_header = "F-Khotiyan Admin"
admin.site.site_title = "F-Khotiyan Admin Portal"
admin.site.index_title = "Welcome to F-Khotiyan Administration"
