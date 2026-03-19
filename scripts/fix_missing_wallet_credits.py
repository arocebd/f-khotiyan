import sqlite3
from decimal import Decimal

DB = 'db.sqlite3'

def run():
    conn = sqlite3.connect(DB)
    cur = conn.cursor()

    # Find approved wallet_topup purchases
    cur.execute("""
    SELECT id, user_id, amount, transaction_id
    FROM subscription_purchases
    WHERE status='approved' AND plan='wallet_topup'
    """)
    purchases = cur.fetchall()
    fixed = 0
    for pid, user_id, amount, transaction_id in purchases:
        # Check if a WalletTransaction exists with this reference
        cur.execute("SELECT COUNT(1) FROM wallet_transactions WHERE reference=? AND transaction_type='topup'", (transaction_id,))
        exists = cur.fetchone()[0]
        if exists:
            continue
        # Fetch current user balance
        cur.execute("SELECT wallet_balance FROM users WHERE id=?", (user_id,))
        row = cur.fetchone()
        if not row:
            print(f"User not found for purchase {pid}, user_id={user_id}")
            continue
        current = Decimal(str(row[0] or 0))
        amt = Decimal(str(amount or 0))
        new_balance = current + amt
        # Update user balance
        cur.execute("UPDATE users SET wallet_balance=? WHERE id=?", (float(new_balance), user_id))
        # Insert WalletTransaction
        cur.execute(
            "INSERT INTO wallet_transactions (user_id, transaction_type, amount, balance_after, description, reference, created_at) VALUES (?,?,?,?,?,?,datetime('now'))",
            (user_id, 'topup', float(amt), float(new_balance), f'Wallet top-up (repaired) tx:{transaction_id}', transaction_id)
        )
        fixed += 1
        print(f"Fixed purchase {pid}: credited {amt} to user {user_id}, new balance {new_balance}")

    conn.commit()
    conn.close()
    print(f"Done. Fixed {fixed} purchases.")

if __name__ == '__main__':
    run()
