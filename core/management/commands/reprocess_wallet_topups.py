from django.core.management.base import BaseCommand
from django.db import transaction
from django.db.models import F
import logging

from core.models import SubscriptionPurchase, WalletTransaction, User

logger = logging.getLogger(__name__)


class Command(BaseCommand):
    help = 'Reprocess approved wallet top-ups: create WalletTransaction and ensure user wallet_balance is credited.'

    def add_arguments(self, parser):
        parser.add_argument('--purchase-id', type=int, help='Process a specific SubscriptionPurchase id')
        parser.add_argument('--transaction', type=str, help='Process by transaction_id')
        parser.add_argument('--all', action='store_true', help='Process all approved wallet top-ups')

    def handle(self, *args, **options):
        purchase_id = options.get('purchase_id')
        transaction = options.get('transaction')
        do_all = options.get('all')

        qs = SubscriptionPurchase.objects.filter(plan='wallet_topup', status='approved')
        if purchase_id:
            qs = qs.filter(id=purchase_id)
        if transaction:
            qs = qs.filter(transaction_id=transaction)
        if not (purchase_id or transaction or do_all):
            self.stdout.write(self.style.ERROR('Specify --purchase-id, --transaction or --all'))
            return

        total = qs.count()
        if total == 0:
            self.stdout.write('No matching approved wallet top-ups found.')
            return

        self.stdout.write(f'Processing {total} purchase(s)')
        fixed = 0
        for p in qs.select_related('user'):
            tx_exists = WalletTransaction.objects.filter(reference=p.transaction_id, transaction_type='topup').exists()
            if tx_exists:
                self.stdout.write(f'Purchase id={p.id} tx={p.transaction_id} already processed; skipping')
                continue

            with transaction.atomic():
                try:
                    # Atomically update user's wallet balance
                    User.objects.filter(pk=p.user.pk).update(wallet_balance=F('wallet_balance') + p.amount)
                    # Refresh user instance
                    p.user.refresh_from_db()
                    WalletTransaction.objects.create(
                        user=p.user,
                        transaction_type='topup',
                        amount=p.amount,
                        balance_after=p.user.wallet_balance,
                        description=f'Wallet top-up (reprocessed) tx:{p.transaction_id}',
                        reference=p.transaction_id,
                    )
                    fixed += 1
                    self.stdout.write(self.style.SUCCESS(f'Processed purchase id={p.id} user={p.user.id} amount={p.amount} new_balance={p.user.wallet_balance}'))
                except Exception as e:
                    logger.exception('Failed to process purchase id=%s', p.id)
                    self.stdout.write(self.style.ERROR(f'Failed purchase id={p.id}: {e}'))

        self.stdout.write(self.style.NOTICE(f'Done. Processed {fixed} purchases.'))
