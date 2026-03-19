import sqlite3

DB='db.sqlite3'
PHONE='01912939036'

conn=sqlite3.connect(DB)
cur=conn.cursor()
# find user
cur.execute("SELECT id, wallet_balance FROM users WHERE phone_number=?", (PHONE,))
user=cur.fetchone()
if not user:
    print('USER_NOT_FOUND')
else:
    user_id, wallet_balance = user
    print('USER', user_id, 'wallet_balance=', wallet_balance)
    # purchases
    cur.execute("SELECT id, amount, transaction_id, status, created_at, reviewed_at FROM subscription_purchases WHERE user_id=? ORDER BY created_at DESC", (user_id,))
    purchases=cur.fetchall()
    print('PURCHASES:')
    for p in purchases:
        print(' ', p)
    # wallet transactions
    cur.execute("SELECT id, transaction_type, amount, balance_after, reference, created_at FROM wallet_transactions WHERE user_id=? ORDER BY created_at DESC", (user_id,))
    txs=cur.fetchall()
    print('WALLET_TRANSACTIONS:')
    for t in txs:
        print(' ', t)

conn.close()
