import requests

# Test sandbox to verify code format is correct
print("=== Sandbox Test ===")
r = requests.post(
    'https://courier-api-sandbox.pathao.com/aladdin/api/v1/issue-token',
    json={
        'client_id': '7N1aMJQbWm',
        'client_secret': 'wRcaibZkUdSNz2EI9ZyuXLlNrnAv0TdPUPXMnD39',
        'grant_type': 'password',
        'username': 'test@pathao.com',
        'password': 'lovePathao',
    },
    headers={'Content-Type': 'application/json'},
    timeout=15,
)
print(f"Status: {r.status_code}")
print(f"Response: {r.text[:400]}")

# Test production endpoint format (with dummy creds just to see what error format looks like)
print("\n=== Production endpoint reachability ===")
r2 = requests.post(
    'https://api-hermes.pathao.com/aladdin/api/v1/issue-token',
    json={
        'client_id': 'TEST',
        'client_secret': 'TEST',
        'grant_type': 'password',
        'username': 'test@test.com',
        'password': 'test',
    },
    headers={'Content-Type': 'application/json'},
    timeout=15,
)
print(f"Status: {r2.status_code}")
print(f"Response: {r2.text[:400]}")
