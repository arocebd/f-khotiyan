import requests
import json

url = 'http://127.0.0.1:8000/api/auth/register/'

payload1 = {
    'phone_number': '01710000001',
    'email': 'test1@example.com',
    'password': 'SecurePass123',
    'password_confirm': 'SecurePass123',
    'business_name': 'TestBiz',
    'owner_name': 'Owner Name',
    'location': 'Dhaka',
    'district': 'Dhaka',
}

payload2 = {
    'phone': '01710000002',
    'password': 'SecurePass123',
    'password2': 'SecurePass123',
    'business_name': 'TestBiz2',
    'owner_name': 'Owner2',
    'address': 'Some address'
}

for i, payload in enumerate((payload1, payload2), start=1):
    print(f"\n--- Test {i} ---")
    try:
        r = requests.post(url, json=payload, timeout=10)
        print('Status:', r.status_code)
        try:
            print('JSON:', json.dumps(r.json(), indent=2))
        except Exception:
            print('Text:', r.text)
    except Exception as e:
        print('Request failed:', repr(e))
