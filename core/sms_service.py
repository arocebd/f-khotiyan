"""
SMS Service for F-Khotiyan
Handles character encoding detection, SMS part calculation, and API calls to bulksmsbd.net

Encoding rules:
  - GSM-7 (English): 160 chars for single SMS, 153 chars per part for multi-part
  - Unicode/UTF-16 (Bengali etc): 70 chars for single SMS, 67 chars per part for multi-part
  - GSM-7 extended chars ([]{}|^~\€) count as 2 characters each

Cost: 0.45 BDT per SMS part
"""

import re
import json
import requests
import logging
from decimal import Decimal
from django.conf import settings

logger = logging.getLogger(__name__)

# ── GSM-7 character sets ────────────────────────────────────────────────────

# Standard GSM-7 basic charset
GSM7_BASIC = frozenset(
    '@£$¥èéùìòÇ\nØø\rÅåΔ_ΦΓΛΩΠΨΣΘΞ\x1bÆæßÉ !"#¤%&\'()*+,-./'
    '0123456789:;<=>?¡ABCDEFGHIJKLMNOPQRSTUVWXYZÄÖÑÜ§¿'
    'abcdefghijklmnopqrstuvwxyzäöñüà'
)

# GSM-7 extended table (each counts as 2 chars in total)
GSM7_EXTENDED = frozenset('[]{}\\|^~€\f')

# Combined set for quick "is this GSM-7?" check
GSM7_ALL = GSM7_BASIC | GSM7_EXTENDED


# ── Encoding detection ───────────────────────────────────────────────────────

def detect_encoding(message: str) -> str:
    """
    Returns 'gsm7' if message can be encoded in GSM-7, else 'unicode'.
    Any character outside GSM7_ALL forces the full message to Unicode.
    """
    for char in message:
        if char not in GSM7_ALL:
            return 'unicode'
    return 'gsm7'


def count_gsm7_chars(message: str) -> int:
    """Count GSM-7 encoded length (extended chars = 2 each)."""
    return sum(2 if c in GSM7_EXTENDED else 1 for c in message)


# ── SMS part calculation ─────────────────────────────────────────────────────

# Limits per encoding
LIMITS = {
    'gsm7':    {'single': 160, 'multi': 153},
    'unicode': {'single': 70,  'multi': 67},
}


def count_sms_parts(message: str) -> dict:
    """
    Returns a dict with:
      encoding    : 'gsm7' | 'unicode'
      char_count  : effective character count
      parts       : number of SMS parts
      chars_remaining_in_last_part : remaining capacity in the last part
    """
    if not message:
        return {'encoding': 'gsm7', 'char_count': 0, 'parts': 0, 'chars_remaining': 160}

    encoding = detect_encoding(message)
    lim = LIMITS[encoding]

    if encoding == 'gsm7':
        char_count = count_gsm7_chars(message)
    else:
        char_count = len(message)

    if char_count <= lim['single']:
        parts = 1
        remaining = lim['single'] - char_count
    else:
        parts = (char_count + lim['multi'] - 1) // lim['multi']
        used_in_last = char_count % lim['multi']
        remaining = lim['multi'] - used_in_last if used_in_last else 0

    return {
        'encoding': encoding,
        'char_count': char_count,
        'parts': parts,
        'chars_remaining': remaining,
    }


def calculate_cost(parts: int) -> Decimal:
    """Returns cost in BDT for the given number of SMS parts."""
    cost_per_part = Decimal(getattr(settings, 'BULKSMS_COST_PER_PART', '0.45'))
    return cost_per_part * parts


# ── Phone normalisation ───────────────────────────────────────────────────────

def normalise_phone(phone: str) -> str:
    """
    Normalise a Bangladeshi phone number to the 88XXXXXXXXXX format
    required by bulksmsbd.net.
    """
    phone = re.sub(r'[\s\-\(\)]', '', phone)
    if phone.startswith('+88'):
        phone = phone[1:]          # remove leading +
    elif phone.startswith('01') or phone.startswith('02'):
        phone = '88' + phone
    # already starts with 88XXXXXXXXXX — leave as-is
    return phone


# ── API call ─────────────────────────────────────────────────────────────────

def send_sms(phone: str, message: str, sender_id: str = None) -> dict:
    """
    Send a single SMS via bulksmsbd.net.

    Returns:
      {
        'success'     : bool,
        'response_code': int or None,
        'response'    : dict (raw API response),
        'parts'       : int,
        'cost'        : Decimal,
      }
    """
    api_key = getattr(settings, 'BULKSMS_API_KEY', '')
    api_url = getattr(settings, 'BULKSMS_API_URL', 'https://bulksmsbd.net/api/smsapi')
    default_sender = getattr(settings, 'BULKSMS_SENDER_ID', '')

    if not sender_id:
        sender_id = default_sender

    phone = normalise_phone(phone)
    sms_info = count_sms_parts(message)
    parts = sms_info['parts']
    cost = calculate_cost(parts)

    payload = {
        'api_key':  api_key,
        'number':   phone,
        'message':  message,
    }
    if sender_id:
        payload['senderid'] = sender_id

    try:
        resp = requests.post(api_url, data=payload, timeout=15)
        # bulksmsbd returns JSON with response_code 202 on success
        try:
            resp_data = resp.json()
        except ValueError:
            resp_data = {'raw': resp.text}

        response_code = resp_data.get('response_code') or resp_data.get('code')
        success = (resp.status_code == 200 and str(response_code) == '202')

        return {
            'success': success,
            'response_code': response_code,
            'response': resp_data,
            'parts': parts,
            'cost': cost,
        }

    except requests.Timeout:
        logger.error('BulkSMS API timeout for %s', phone)
        return {
            'success': False,
            'response_code': None,
            'response': {'error': 'Request timed out'},
            'parts': parts,
            'cost': cost,
        }
    except requests.RequestException as exc:
        logger.error('BulkSMS API error: %s', exc)
        return {
            'success': False,
            'response_code': None,
            'response': {'error': str(exc)},
            'parts': parts,
            'cost': cost,
        }


def send_sms_bulk(recipients: list[dict], sender_id: str = None) -> list[dict]:
    """
    Send SMS to multiple recipients.
    Each item in `recipients` must have 'phone' and 'message' keys.
    Returns a list of result dicts (same structure as send_sms).
    """
    results = []
    for r in recipients:
        result = send_sms(r['phone'], r['message'], sender_id=sender_id)
        result['phone'] = r['phone']
        results.append(result)
    return results
