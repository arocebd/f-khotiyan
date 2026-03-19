import sqlite3

conn = sqlite3.connect('db.sqlite3')
cur = conn.cursor()
cur.execute("SELECT wallet_balance, subscription_type FROM users WHERE phone_number=?", ('01912939036',))
row = cur.fetchone()
print(row)
conn.close()
