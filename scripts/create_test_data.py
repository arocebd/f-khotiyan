import requests

BASE = 'https://app.khotiyan.com/api'
s = requests.Session()

# Login
r = s.post(BASE+'/auth/login/', json={'phone_number':'01712345678','password':'Test@1234'}, timeout=15)
token = r.json()['tokens']['access']
h = {'Authorization': 'Bearer ' + token, 'Content-Type': 'application/json'}
print('[OK] Logged in')

# Create 5 products
products_data = [
    {'product_name':'Cotton T-Shirt','sku':'TS001','quantity':100,'purchase_price':'150.00','selling_price':'350.00','category':'Clothing'},
    {'product_name':'Linen Panjabi','sku':'LP002','quantity':50,'purchase_price':'400.00','selling_price':'900.00','category':'Clothing'},
    {'product_name':'Silk Saree','sku':'SS003','quantity':30,'purchase_price':'1200.00','selling_price':'2500.00','category':'Clothing'},
    {'product_name':'Leather Wallet','sku':'LW004','quantity':80,'purchase_price':'200.00','selling_price':'450.00','category':'Accessories'},
    {'product_name':'Sports Shoes','sku':'SH005','quantity':60,'purchase_price':'600.00','selling_price':'1200.00','category':'Footwear'},
]
# Get existing or create 5 products
products = []
existing = s.get(BASE+'/products/', headers=h, timeout=15).json()
existing_list = existing.get('results', existing) if isinstance(existing, dict) else existing
if isinstance(existing_list, list) and len(existing_list) >= 5:
    products = existing_list[:5]
    print('[OK] Using ' + str(len(products)) + ' existing products')
else:
    for p in products_data:
        r = s.post(BASE+'/products/', json=p, headers=h, timeout=15)
        if r.status_code in (200, 201):
            prod = r.json()
            products.append(prod)
            print('[OK] Product: ' + prod['product_name'] + ' (id=' + str(prod['id']) + ')')
        else:
            print('[FAIL] Product: ' + str(r.status_code) + ' ' + r.text[:200])

print('\nTotal products created: ' + str(len(products)))

# Create 5 orders
orders = []
customers = [
    ('Rahim Uddin', '01811111111', 'Mirpur, Dhaka'),
    ('Karim Mia', '01822222222', 'Gulshan, Dhaka'),
    ('Nasrin Akter', '01833333333', 'Chittagong'),
    ('Sumon Ahmed', '01844444444', 'Sylhet'),
    ('Ritu Begum', '01855555555', 'Rajshahi'),
]
for i, (cname, cphone, caddr) in enumerate(customers):
    prod = products[i % len(products)]
    qty = 2
    sp = float(prod['selling_price'])
    pp = float(prod['purchase_price'])
    grand = sp * qty
    payload = {
        'customer_name': cname,
        'customer_phone': cphone,
        'customer_address': caddr,
        'total_amount': str(grand),
        'discount': '0.00',
        'delivery_charge': '60.00',
        'grand_total': str(grand + 60),
        'payment_status': 'pending',
        'order_status': 'pending',
        'items': [{'product': prod['id'], 'product_name': prod['product_name'],
                   'quantity': qty, 'selling_price': str(sp), 'purchase_price': str(pp)}]
    }
    r = s.post(BASE+'/orders/', json=payload, headers=h, timeout=15)
    if r.status_code in (200, 201):
        resp = r.json()
        o = resp.get('order', resp)
        orders.append(o)
        print('[OK] Order #' + str(o.get('order_number', o.get('id', '?'))) + ' for ' + cname)
    else:
        print('[FAIL] Order for ' + cname + ': ' + str(r.status_code) + ' ' + r.text[:300])

print('\nTotal orders created: ' + str(len(orders)))

# Test return on first order
if orders and products:
    o = orders[0]
    oid = o['id']
    prod_id = products[0]['id']
    print('\n=== RETURN TEST on Order #' + str(o.get('order_number', oid)) + ' ===')
    ret_payload = {
        'order': oid,
        'product': prod_id,
        'quantity': 1,
        'reason': 'defective',
        'refund_amount': '350.00',
        'notes': 'Product was defective'
    }
    r = s.post(BASE+'/returns/', json=ret_payload, headers=h, timeout=15)
    print('Create return: ' + str(r.status_code) + ' ' + r.text[:300])
    if r.status_code in (200, 201):
        ret = r.json()
        rid = ret['id']
        r2 = s.patch(BASE+'/returns/'+str(rid)+'/', json={'status': 'approved'}, headers=h, timeout=15)
        print('Approve: ' + str(r2.status_code) + ' ' + r2.text[:200])
        r3 = s.patch(BASE+'/returns/'+str(rid)+'/', json={'status': 'refunded'}, headers=h, timeout=15)
        print('Refund: ' + str(r3.status_code) + ' ' + r3.text[:200])

print('\n=== DONE ===')
