"""
URL configuration for F-Khotiyan config project.
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
# from drf_yasg.views import get_schema_view
# from drf_yasg import openapi
from rest_framework import permissions

# Swagger/OpenAPI Documentation - Disabled temporarily
# schema_view = get_schema_view(...)

urlpatterns = [
    # Admin
    path('admin/', admin.site.urls),
    
    # API Documentation (Swagger) - Disabled temporarily
    # path('api/docs/', schema_view.with_ui('swagger', cache_timeout=0), name='swagger-docs'),
    
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
admin.site.index_title = "Welcome toF-Khotiyan Administration"

