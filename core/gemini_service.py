"""
Gemini AI Service for Order Extraction from Images
Extracts order details from message screenshots using Google Gemini Flash
"""

import os
from google import genai
from google.genai import types
from PIL import Image
from typing import Dict, Optional, List
from django.conf import settings


class GeminiOrderExtractor:
    """
    Service class to extract order information from text or screenshots using Gemini AI
    """
    
    def __init__(self):
        """Initialize Gemini AI with API key"""
        api_key = getattr(settings, 'GEMINI_API_KEY', None)
        if not api_key:
            raise ValueError("GEMINI_API_KEY not found in settings")
        
        self.client = genai.Client(api_key=api_key)
        self.model_name = getattr(settings, 'GEMINI_MODEL', 'gemini-2.0-flash')
    
    def extract_order_from_text(self, message_text: str) -> Optional[Dict]:
        """
        Extract order details from a text message
        
        Args:
            message_text: Raw text message with order details
            
        Returns:
            Dictionary with extracted order data or None if extraction fails
        """
        try:
            # Create prompt for Gemini
            prompt = self._create_extraction_prompt()
            
            # Combine prompt with message text
            full_prompt = f"{prompt}\n\nMessage Text:\n{message_text}"
            
            # Generate content from text
            response = self.client.models.generate_content(
                model=self.model_name,
                contents=full_prompt,
            )
            
            # Parse response
            extracted_data = self._parse_gemini_response(response.text)
            
            return extracted_data
            
        except Exception as e:
            print(f"Error extracting order from text: {str(e)}")
            return None
    
    def extract_order_from_image(self, image_path: str) -> Optional[Dict]:
        """
        Extract order details from a screenshot image
        
        Args:
            image_path: Path to the screenshot image
            
        Returns:
            Dictionary with extracted order data or None if extraction fails
        """
        try:
            # Open and read image bytes
            with open(image_path, 'rb') as f:
                image_bytes = f.read()
            
            # Create prompt for Gemini
            prompt = self._create_extraction_prompt()
            
            # Generate content from image using new SDK
            response = self.client.models.generate_content(
                model=self.model_name,
                contents=[
                    types.Part.from_bytes(data=image_bytes, mime_type='image/jpeg'),
                    prompt,
                ],
            )
            
            # Parse response
            extracted_data = self._parse_gemini_response(response.text)
            
            return extracted_data
            
        except Exception as e:
            print(f"Error extracting order from image: {str(e)}")
            return None
    
    def _create_extraction_prompt(self) -> str:
        """
        Create a structured prompt for Gemini to extract order details
        """
        prompt = """
        Analyze this screenshot of a message/order and extract the following information in JSON format:

        {
            "customer_name": "Customer full name",
            "customer_phone": "Phone number (11 digits if Bangladesh)",
            "customer_address": "Full delivery address",
            "district": "District name (if mentioned)",
            "products": [
                {
                    "product_name": "Product name",
                    "quantity": 1,
                    "price": 0.00
                }
            ],
            "total_amount": 0.00,
            "delivery_charge": 0.00,
            "discount": 0.00,
            "notes": "Any special instructions or notes",
            "courier_preference": "pathao/steadfast/self (if mentioned)"
        }

        IMPORTANT RULES:
        1. Return ONLY valid JSON, no additional text or explanation
        2. If phone number doesn't have 11 digits, extract what's visible
        3. If a field is not found in the image, use null or empty string
        4. For products, extract all items with their quantities and prices
        5. Calculate total_amount as sum of all product prices
        6. If delivery charge is mentioned separately, extract it
        7. Extract any discount amount if visible
        8. Bengali text is acceptable, extract as-is
        9. For prices, use only numbers (remove currency symbols)
        10. Ensure all numeric values are numbers, not strings

        If you cannot extract any meaningful order information, return:
        {"error": "Unable to extract order information from this image"}
        """
        return prompt
    
    def _parse_gemini_response(self, response_text: str) -> Optional[Dict]:
        """
        Parse Gemini's response and validate the extracted data
        """
        import json
        import re
        
        try:
            # Try to extract JSON from response
            # Sometimes Gemini wraps JSON in code blocks
            json_match = re.search(r'```json\s*(.*?)\s*```', response_text, re.DOTALL)
            if json_match:
                json_text = json_match.group(1)
            else:
                # Try to find JSON directly
                json_match = re.search(r'\{.*\}', response_text, re.DOTALL)
                if json_match:
                    json_text = json_match.group(0)
                else:
                    json_text = response_text
            
            # Parse JSON
            data = json.loads(json_text)
            
            # Check for error response
            if 'error' in data:
                return None
            
            # Validate and clean data
            validated_data = self._validate_extracted_data(data)
            
            return validated_data
            
        except json.JSONDecodeError as e:
            print(f"Failed to parse Gemini response as JSON: {str(e)}")
            print(f"Response text: {response_text}")
            return None
    
    def _validate_extracted_data(self, data: Dict) -> Dict:
        """
        Validate and clean extracted data
        """
        # Ensure required fields exist
        validated = {
            'customer_name': (data.get('customer_name') or '').strip(),
            'customer_phone': self._clean_phone_number(data.get('customer_phone') or ''),
            'customer_address': (data.get('customer_address') or '').strip(),
            'district': (data.get('district') or '').strip(),
            'products': [],
            'total_amount': 0.0,
            'delivery_charge': float(data.get('delivery_charge') or 0),
            'discount': float(data.get('discount') or 0),
            'notes': (data.get('notes') or '').strip(),
            'courier_preference': (data.get('courier_preference') or 'self').lower(),
        }
        
        # Validate products
        products = data.get('products', [])
        if isinstance(products, list):
            for product in products:
                if isinstance(product, dict):
                    validated['products'].append({
                        'product_name': product.get('product_name', '').strip(),
                        'quantity': int(product.get('quantity', 1)),
                        'price': float(product.get('price', 0)),
                    })
        
        # Calculate total if not provided
        if data.get('total_amount'):
            validated['total_amount'] = float(data['total_amount'])
        else:
            # Calculate from products
            validated['total_amount'] = sum(
                p['quantity'] * p['price'] for p in validated['products']
            )
        
        # Validate courier preference
        if validated['courier_preference'] not in ['pathao', 'steadfast', 'self']:
            validated['courier_preference'] = 'self'
        
        return validated
    
    def _clean_phone_number(self, phone: str) -> str:
        """
        Clean and validate phone number
        """
        if not phone:
            return ''
        
        # Remove all non-digit characters
        phone = ''.join(filter(str.isdigit, str(phone)))
        
        # If starts with +880 or 880, remove it
        if phone.startswith('880'):
            phone = phone[3:]
        
        # If starts with 0, keep it (Bangladesh format: 01712345678)
        # Otherwise, add 0 if length is 10
        if len(phone) == 10 and not phone.startswith('0'):
            phone = '0' + phone
        
        return phone
    
    def validate_order_data(self, extracted_data: Dict) -> tuple[bool, List[str]]:
        """
        Validate extracted order data and return validation status with errors
        
        Returns:
            Tuple of (is_valid, list_of_errors)
        """
        errors = []
        
        # Required fields
        if not extracted_data.get('customer_name'):
            errors.append("Customer name is required")
        
        if not extracted_data.get('customer_phone'):
            errors.append("Customer phone number is required")
        elif len(extracted_data['customer_phone']) != 11:
            errors.append("Phone number must be 11 digits")
        
        if not extracted_data.get('customer_address'):
            errors.append("Customer address is required")
        
        if not extracted_data.get('products'):
            errors.append("At least one product is required")
        else:
            # Validate each product
            for idx, product in enumerate(extracted_data['products']):
                if not product.get('product_name'):
                    errors.append(f"Product {idx + 1}: Name is required")
                if product.get('quantity', 0) <= 0:
                    errors.append(f"Product {idx + 1}: Quantity must be greater than 0")
                if product.get('price', 0) < 0:
                    errors.append(f"Product {idx + 1}: Price cannot be negative")
        
        if extracted_data.get('total_amount', 0) <= 0:
            errors.append("Total amount must be greater than 0")
        
        return (len(errors) == 0, errors)


def extract_order_from_screenshot(image_path: str) -> Optional[Dict]:
    """
    Convenience function to extract order from screenshot
    
    Args:
        image_path: Path to the screenshot image
        
    Returns:
        Extracted order data dictionary or None
    """
    try:
        extractor = GeminiOrderExtractor()
        return extractor.extract_order_from_image(image_path)
    except Exception as e:
        print(f"Error in extract_order_from_screenshot: {str(e)}")
        return None
