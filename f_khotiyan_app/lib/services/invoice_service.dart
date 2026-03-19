import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:barcode/barcode.dart' as bc;
import 'package:intl/intl.dart';

class InvoiceService {
  /// Show the PDF invoice preview with print/download options.
  static Future<void> showInvoice(
    BuildContext context,
    Map<String, dynamic> order,
    Map<String, dynamic>? profile,
  ) async {
    final pdfBytes = await _buildPdf(order, profile);
    final orderNumber = order['order_number'] ?? 'invoice';

    if (!context.mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _InvoicePreviewPage(
          pdfBytes: pdfBytes,
          orderNumber: orderNumber,
        ),
      ),
    );
  }

  static Future<Uint8List> _buildPdf(
    Map<String, dynamic> order,
    Map<String, dynamic>? profile,
  ) async {
    final doc = pw.Document();

    // ── Company info ──────────────────────────────────────
    final businessName = (profile?['business_name'] ?? 'F-Khotiyan').toString();
    final ownerName = (profile?['owner_name'] ?? '').toString();
    final phone = (profile?['phone_number'] ?? '').toString();
    final location = (profile?['location'] ?? '').toString();

    // ── Order info ────────────────────────────────────────
    final orderNumber = (order['order_number'] ?? 'N/A').toString();
    final orderDate = _formatDate(order['order_date']);
    final customerName = (order['customer_name'] ?? '').toString();
    final customerPhone = (order['customer_phone'] ?? '').toString();
    final customerAddress =
        (order['customer_address'] ?? order['shipping_address'] ?? '')
            .toString();
    final district = (order['district'] ?? '').toString();
    final notes = (order['notes'] ?? '').toString();
    final status = (order['order_status'] ?? '').toString();
    final courier = (order['courier_type'] ?? '').toString();
    final tracking = (order['tracking_number'] ?? '').toString();

    final items = (order['items'] as List?) ?? [];
    final subtotal = double.tryParse((order['subtotal'] ?? 0).toString()) ?? 0;
    final deliveryCharge = double.tryParse(
            (order['delivery_charge'] ?? order['shipping_charge'] ?? 0)
                .toString()) ??
        0;
    final discount = double.tryParse((order['discount'] ?? 0).toString()) ?? 0;
    final grandTotal =
        double.tryParse((order['grand_total'] ?? 0).toString()) ?? 0;

    // ── Barcode SVG ───────────────────────────────────────
    String barcodeSvg = '';
    try {
      final barcodeGen = bc.Barcode.code128();
      barcodeSvg = barcodeGen.toSvg(orderNumber, width: 220, height: 60);
    } catch (_) {}

    // ── Colors ────────────────────────────────────────────
    const headerBg = PdfColor.fromInt(0xFF1565C0);
    const accentBg = PdfColor.fromInt(0xFFF5F5F5);
    const borderColor = PdfColor.fromInt(0xFFBDBDBD);
    const greenColor = PdfColor.fromInt(0xFF2E7D32);

    // ── Fonts ─────────────────────────────────────────────
    final font = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();
    final fontSmall = await PdfGoogleFonts.notoSansRegular();

    pw.TextStyle style({
      double size = 10,
      pw.Font? fnt,
      PdfColor color = PdfColors.black,
    }) =>
        pw.TextStyle(font: fnt ?? font, fontSize: size, color: color);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        build: (pw.Context ctx) => [
          // ── HEADER ─────────────────────────────────────
          pw.Container(
            decoration: pw.BoxDecoration(
              color: headerBg,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            padding: const pw.EdgeInsets.all(18),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Left: Company info
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(businessName,
                          style: style(
                              size: 20, fnt: fontBold, color: PdfColors.white)),
                      if (ownerName.isNotEmpty)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(top: 3),
                          child: pw.Text(ownerName,
                              style: style(size: 11, color: PdfColors.blue100)),
                        ),
                      if (phone.isNotEmpty)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(top: 3),
                          child: pw.Text('Phone: $phone',
                              style: style(size: 10, color: PdfColors.white)),
                        ),
                      if (location.isNotEmpty)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(top: 2),
                          child: pw.Text(location,
                              style: style(size: 10, color: PdfColors.blue100)),
                        ),
                    ],
                  ),
                ),
                // Right: Invoice label + number
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('INVOICE',
                        style: style(
                            size: 26, fnt: fontBold, color: PdfColors.white)),
                    pw.SizedBox(height: 4),
                    pw.Text('#$orderNumber',
                        style: style(size: 10, color: PdfColors.blue100)),
                    pw.SizedBox(height: 4),
                    pw.Text('Date: $orderDate',
                        style: style(size: 10, color: PdfColors.white)),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // ── BARCODE ─────────────────────────────────────
          if (barcodeSvg.isNotEmpty)
            pw.Center(
              child: pw.Column(
                children: [
                  pw.SvgImage(svg: barcodeSvg, width: 220, height: 60),
                  pw.SizedBox(height: 2),
                  pw.Text(orderNumber,
                      style: pw.TextStyle(
                          font: fontSmall,
                          fontSize: 8,
                          color: PdfColors.grey600)),
                ],
              ),
            ),
          pw.SizedBox(height: 14),

          // ── BILL-TO / ORDER-INFO ROW ─────────────────────
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Bill To
              pw.Expanded(
                child: pw.Container(
                  decoration: pw.BoxDecoration(
                    color: accentBg,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: borderColor),
                  ),
                  padding: const pw.EdgeInsets.all(12),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('BILL TO',
                          style: style(
                              size: 9,
                              fnt: fontBold,
                              color: PdfColors.grey700)),
                      pw.Divider(color: borderColor, thickness: 0.5, height: 8),
                      pw.Text(customerName,
                          style: style(size: 11, fnt: fontBold)),
                      if (customerPhone.isNotEmpty)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(top: 3),
                          child: pw.Text('Phone: $customerPhone',
                              style: style(size: 10)),
                        ),
                      if (customerAddress.isNotEmpty)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(top: 3),
                          child:
                              pw.Text(customerAddress, style: style(size: 10)),
                        ),
                      if (district.isNotEmpty)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(top: 2),
                          child: pw.Text(district,
                              style: style(size: 10, color: PdfColors.grey700)),
                        ),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 12),
              // Order details
              pw.Expanded(
                child: pw.Container(
                  decoration: pw.BoxDecoration(
                    color: accentBg,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: borderColor),
                  ),
                  padding: const pw.EdgeInsets.all(12),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('ORDER DETAILS',
                          style: style(
                              size: 9,
                              fnt: fontBold,
                              color: PdfColors.grey700)),
                      pw.Divider(color: borderColor, thickness: 0.5, height: 8),
                      _detailRow('Order No', orderNumber, font, fontBold),
                      _detailRow('Date', orderDate, font, fontBold),
                      _detailRow(
                          'Status', status.toUpperCase(), font, fontBold),
                      if (courier.isNotEmpty)
                        _detailRow('Courier', courier, font, fontBold),
                      if (tracking.isNotEmpty)
                        _detailRow('Tracking', tracking, font, fontBold),
                    ],
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),

          // ── ITEMS TABLE ──────────────────────────────────
          pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FixedColumnWidth(60),
              2: const pw.FixedColumnWidth(70),
              3: const pw.FixedColumnWidth(70),
            },
            border: pw.TableBorder.all(color: borderColor, width: 0.5),
            children: [
              // Header row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: headerBg),
                children: [
                  _tableCell('Product', fontBold,
                      color: PdfColors.white, isHeader: true),
                  _tableCell('Qty', fontBold,
                      color: PdfColors.white,
                      isHeader: true,
                      align: pw.TextAlign.center),
                  _tableCell('Unit Price', fontBold,
                      color: PdfColors.white,
                      isHeader: true,
                      align: pw.TextAlign.right),
                  _tableCell('Total', fontBold,
                      color: PdfColors.white,
                      isHeader: true,
                      align: pw.TextAlign.right),
                ],
              ),
              // Item rows
              ...items.asMap().entries.map((entry) {
                final idx = entry.key;
                final item = entry.value as Map<String, dynamic>;
                final productName =
                    (item['product_name'] ?? 'Product #${item['product']}')
                        .toString();
                final qty = int.tryParse(item['quantity'].toString()) ?? 0;
                final unitPrice = double.tryParse(
                        (item['selling_price'] ?? item['price'] ?? 0)
                            .toString()) ??
                    0;
                final total = qty * unitPrice;
                final rowBg = idx.isOdd ? accentBg : PdfColors.white;

                return pw.TableRow(
                  decoration: pw.BoxDecoration(color: rowBg),
                  children: [
                    _tableCell(productName, font),
                    _tableCell('$qty', font, align: pw.TextAlign.center),
                    _tableCell(_fmt(unitPrice), font,
                        align: pw.TextAlign.right),
                    _tableCell(_fmt(total), font, align: pw.TextAlign.right),
                  ],
                );
              }),
            ],
          ),
          pw.SizedBox(height: 12),

          // ── TOTALS ───────────────────────────────────────
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Container(
                width: 230,
                decoration: pw.BoxDecoration(
                  color: accentBg,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: borderColor),
                ),
                padding: const pw.EdgeInsets.all(12),
                child: pw.Column(
                  children: [
                    _totalRow('Subtotal', subtotal, font, fontBold),
                    _totalRow(
                        'Delivery Charge', deliveryCharge, font, fontBold),
                    if (discount > 0)
                      _totalRow('Discount', -discount, font, fontBold),
                    pw.Divider(color: borderColor, thickness: 0.5),
                    _totalRow('GRAND TOTAL', grandTotal, fontBold, fontBold,
                        textColor: greenColor,
                        valueColor: greenColor,
                        size: 12),
                  ],
                ),
              ),
            ],
          ),

          // ── NOTES ────────────────────────────────────────
          if (notes.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Container(
              decoration: pw.BoxDecoration(
                color: accentBg,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: borderColor),
              ),
              padding: const pw.EdgeInsets.all(10),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Notes', style: style(size: 9, fnt: fontBold)),
                  pw.SizedBox(height: 4),
                  pw.Text(notes, style: style(size: 10)),
                ],
              ),
            ),
          ],
          pw.SizedBox(height: 20),

          // ── FOOTER ───────────────────────────────────────
          pw.Center(
            child: pw.Text(
              'Thank you for your business!  |  $businessName  |  $phone',
              style: style(size: 9, color: PdfColors.grey600),
            ),
          ),
        ],
      ),
    );

    return doc.save();
  }

  // ── Helpers ─────────────────────────────────────────────

  static String _fmt(double v) => NumberFormat('#,##0.00', 'en_US').format(v);

  static String _formatDate(dynamic raw) {
    if (raw == null) return '';
    try {
      return DateFormat('dd MMM yyyy').format(DateTime.parse(raw.toString()));
    } catch (_) {
      return raw.toString();
    }
  }

  static pw.Widget _tableCell(
    String text,
    pw.Font font, {
    PdfColor color = PdfColors.black,
    bool isHeader = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          font: font,
          fontSize: isHeader ? 10 : 10,
          color: color,
        ),
      ),
    );
  }

  static pw.Widget _detailRow(
    String label,
    String value,
    pw.Font font,
    pw.Font fontBold,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  font: font, fontSize: 10, color: PdfColors.grey700)),
          pw.Text(value, style: pw.TextStyle(font: fontBold, fontSize: 10)),
        ],
      ),
    );
  }

  static pw.Widget _totalRow(
    String label,
    double value,
    pw.Font labelFont,
    pw.Font valueFont, {
    PdfColor textColor = PdfColors.black,
    PdfColor valueColor = PdfColors.black,
    double size = 10,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  font: labelFont, fontSize: size, color: textColor)),
          pw.Text(_fmt(value),
              style: pw.TextStyle(
                  font: valueFont, fontSize: size, color: valueColor)),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// Invoice Preview Page — print / share / download
// ══════════════════════════════════════════════════════════
class _InvoicePreviewPage extends StatelessWidget {
  final Uint8List pdfBytes;
  final String orderNumber;

  const _InvoicePreviewPage({
    required this.pdfBytes,
    required this.orderNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Invoice #$orderNumber'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_rounded),
            tooltip: 'Print',
            onPressed: () async {
              await Printing.layoutPdf(
                onLayout: (_) async => pdfBytes,
                name: 'Invoice_$orderNumber',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Share / Download',
            onPressed: () async {
              await Printing.sharePdf(
                bytes: pdfBytes,
                filename: 'Invoice_$orderNumber.pdf',
              );
            },
          ),
        ],
      ),
      body: PdfPreview(
        build: (_) async => pdfBytes,
        allowPrinting: false,
        allowSharing: false,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        pdfFileName: 'Invoice_$orderNumber.pdf',
      ),
    );
  }
}
