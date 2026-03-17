"""
Custom Permissions for F-Khotiyan API
"""

from rest_framework import permissions


class IsOwner(permissions.BasePermission):
    """
    Custom permission to only allow owners of an object to access it.
    """
    
    def has_object_permission(self, request, view, obj):
        # Check if object has a 'user' attribute and it matches request user
        return hasattr(obj, 'user') and obj.user == request.user


class CanCreateOrder(permissions.BasePermission):
    """
    Permission to check if user can create order based on daily limit
    """
    
    def has_permission(self, request, view):
        # Allow GET, HEAD, OPTIONS requests
        if request.method in permissions.SAFE_METHODS:
            return True
        
        # Check if user can create order
        return request.user.can_create_order()
    
    message = "Daily order limit reached. Upgrade to premium for unlimited orders."


class IsSubscriptionActive(permissions.BasePermission):
    """
    Permission to check if user's subscription is active
    """
    
    def has_permission(self, request, view):
        return request.user.is_subscription_active
    
    message = "Your subscription has expired. Please renew to continue."


class HasSMSBalance(permissions.BasePermission):
    """
    Permission to check if user has SMS balance
    """
    
    def has_permission(self, request, view):
        if request.method in permissions.SAFE_METHODS:
            return True
        
        return request.user.sms_balance > 0
    
    message = "Insufficient SMS balance. Please purchase SMS credits."
