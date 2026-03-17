"""
Migration to align the returns table with the correct Return model.

The old duplicate Return model was missing: return_number, description,
refund_amount (had return_amount instead), and reason was a TextField.
This migration:
1. Adds the missing columns (nullable first to handle existing rows)
2. Backfills return_number for existing rows
3. Drops the old columns that no longer exist on the model
4. Makes return_number non-nullable + unique after backfill
"""

import random
import string
from django.db import migrations, models
import django.core.validators
import django.utils.timezone


def backfill_return_numbers(apps, schema_editor):
    db = schema_editor.connection.alias
    Return = apps.get_model('core', 'Return')
    for ret in Return.objects.using(db).filter(return_number__isnull=True):
        ts = ret.created_at.strftime('%Y%m%d%H%M%S') if ret.created_at else '20260101000000'
        rnd = ''.join(random.choices(string.ascii_uppercase + string.digits, k=4))
        ret.return_number = f"RET{ts}{rnd}"
        ret.save(using=db, update_fields=['return_number'])


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0004_add_pathao_fields_to_courierconfig'),
    ]

    operations = [
        # --- Add new fields (nullable first so existing rows are ok) ---
        migrations.AddField(
            model_name='return',
            name='return_number',
            field=models.CharField(max_length=50, null=True, blank=True, editable=False),
        ),
        migrations.AddField(
            model_name='return',
            name='description',
            field=models.TextField(blank=True, default=''),
        ),
        migrations.AddField(
            model_name='return',
            name='refund_amount',
            field=models.DecimalField(
                max_digits=12, decimal_places=2,
                default=0,
                validators=[django.core.validators.MinValueValidator(0)],
            ),
        ),
        # Change reason from TextField to CharField with choices
        migrations.AlterField(
            model_name='return',
            name='reason',
            field=models.CharField(
                max_length=20,
                choices=[
                    ('defective', 'Defective Product'),
                    ('wrong_item', 'Wrong Item Delivered'),
                    ('not_delivered', 'Not Delivered'),
                    ('size_issue', 'Size / Color Issue'),
                    ('customer_request', 'Customer Request'),
                    ('other', 'Other'),
                ],
                default='customer_request',
            ),
        ),
        # Add 'refunded' to status choices
        migrations.AlterField(
            model_name='return',
            name='status',
            field=models.CharField(
                max_length=20,
                choices=[
                    ('pending', 'Pending'),
                    ('approved', 'Approved'),
                    ('rejected', 'Rejected'),
                    ('refunded', 'Refunded'),
                ],
                default='pending',
            ),
        ),
        # Change return_date from DateTimeField to DateField
        migrations.AlterField(
            model_name='return',
            name='return_date',
            field=models.DateField(default=django.utils.timezone.now),
        ),
        # Backfill return_number for existing rows
        migrations.RunPython(backfill_return_numbers, migrations.RunPython.noop),
        # Now make return_number non-nullable and unique
        migrations.AlterField(
            model_name='return',
            name='return_number',
            field=models.CharField(max_length=50, unique=True, editable=False),
        ),
        # Drop old column that no longer exists (return_amount)
        migrations.RemoveField(
            model_name='return',
            name='return_amount',
        ),
        # Add updated_at if missing
        migrations.AddField(
            model_name='return',
            name='updated_at',
            field=models.DateTimeField(auto_now=True),
        ),
    ]
