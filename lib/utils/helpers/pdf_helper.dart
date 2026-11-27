import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../utils/constants/image_strings.dart';
import '../../utils/constants/text_strings.dart';
import '../../features/personalization/controllers/localization_controller.dart';
import '../../features/shop/models/booking_model.dart';

class AvailPdfHelper {
  static Future<void> generateAndShareWaybill(BookingModel booking) async {
    final pdf = pw.Document();

    final String rawId = booking.bookingId.isNotEmpty ? booking.bookingId.trim() : booking.id.trim();
    String displayId = rawId.toUpperCase();
    if (!displayId.startsWith('FT')) {
      displayId = 'FT-$displayId';
    }

    // Load official app logo for header branding
    pw.MemoryImage? logoImage;
    try {
      final logoBytes = await rootBundle.load(AvailImages.appLogo);
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (e) {
      // In case image asset fails to load, gracefully proceed without it
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          _buildHeader(displayId, booking.timestamp, logoImage),
          pw.SizedBox(height: 20),
          _buildContactSection(booking),
          pw.SizedBox(height: 20),
          _buildCargoSection(booking),
          pw.SizedBox(height: 20),
          if (booking.inventory.isNotEmpty) ...[
            _buildInventorySection(booking.inventory),
            pw.SizedBox(height: 20),
          ],
          _buildRouteSection(booking),
          pw.SizedBox(height: 20),
          _buildPricingSection(booking),
          pw.SizedBox(height: 40),
          _buildSignatureSection(),
          pw.SizedBox(height: 30),
          _buildFooter(),
        ],
      ),
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: 'Waybill_$displayId.pdf');
  }

  static pw.Widget _buildHeader(String id, DateTime date, pw.MemoryImage? logoImage) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (logoImage != null) ...[
              pw.Container(
                width: 44,
                height: 44,
                margin: const pw.EdgeInsets.only(right: 12),
                child: pw.Image(logoImage, fit: pw.BoxFit.contain),
              ),
            ],
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('${AvailTexts.appName.toUpperCase()} LOGISTICS',
                    style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900)),
                pw.Text('Professional Freight Haulage & Manifest System',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              ],
            ),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('WAYBILL #$id', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.Text('Date: ${DateFormat('dd MMM yyyy HH:mm').format(date)}', style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildContactSection(BookingModel booking) {
    return pw.Row(
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('CONSIGNOR (SENDER)', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
              pw.Divider(thickness: 1, color: PdfColors.grey300),
              pw.Text(booking.senderName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text('Phone: ${booking.senderPhone}'),
              pw.Text('Address: ${booking.pickupAddress}', style: const pw.TextStyle(fontSize: 9)),
            ],
          ),
        ),
        pw.SizedBox(width: 40),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('CONSIGNEE (RECEIVER)', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
              pw.Divider(thickness: 1, color: PdfColors.grey300),
              pw.Text(booking.receiverName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text('Phone: ${booking.receiverPhone}'),
              pw.Text('Address: ${booking.dropoffAddress}', style: const pw.TextStyle(fontSize: 9)),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildCargoSection(BookingModel booking) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('CARGO SPECIFICATIONS', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
        pw.Divider(thickness: 1, color: PdfColors.grey300),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _buildInfoCol('Type', booking.cargoType),
            _buildInfoCol('Weight', '${booking.weight} Tons'),
            if (booking.containerSize.isNotEmpty) _buildInfoCol('Size', booking.containerSize),
            _buildInfoCol('Insured', booking.isInsured ? 'YES' : 'NO'),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Text('Description: ${booking.loadDescription}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.black)),
      ],
    );
  }

  static pw.Widget _buildInventorySection(List<Map<String, dynamic>> inventory) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('DETAILED INVENTORY', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
        pw.SizedBox(height: 5),
        pw.Table.fromTextArray(
          headers: ['Item Description', 'Quantity'],
          data: inventory.map((item) => [item['name'].toString(), item['quantity'].toString()]).toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
          cellStyle: const pw.TextStyle(fontSize: 9),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
        ),
      ],
    );
  }

  static pw.Widget _buildRouteSection(BookingModel booking) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('LOGISTICS ROUTE', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
        pw.Divider(thickness: 1, color: PdfColors.grey300),
        pw.Text('1. Origin: ${booking.pickupAddress}', style: const pw.TextStyle(fontSize: 10)),
        ...booking.stops.asMap().entries.map((e) => 
          pw.Text('${e.key + 2}. Stop: ${e.value['address']}', style: const pw.TextStyle(fontSize: 10))
        ).toList(),
        pw.Text('${booking.stops.length + 2}. Destination: ${booking.dropoffAddress}', style: const pw.TextStyle(fontSize: 10)),
        pw.SizedBox(height: 5),
        pw.Text('Total Estimated Distance: ${booking.distance.toStringAsFixed(1)} KM', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  static pw.Widget _buildPricingSection(BookingModel booking) {
    final isPaidOnline = booking.isPaidOnline;
    final displayCurrency =
        booking.currency.trim().isNotEmpty ? booking.currency.trim().toUpperCase() : 'GHS';
    final formattedTotal = LocalizationController.instance
        .formatPriceForCurrency(booking.price, displayCurrency);
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: const pw.BoxDecoration(color: PdfColors.grey50),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('TOTAL HAULAGE RATE ($displayCurrency)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
              pw.Text(formattedTotal, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: PdfColors.blue800)),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('PAYMENT STATUS', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
              pw.Text(
                isPaidOnline
                    ? 'PAID ONLINE VIA PAYSTACK${(booking.paymentReference ?? '').isNotEmpty ? ' (REF: ${booking.paymentReference})' : ''}'
                    : (booking.paymentMethod ?? 'CASH ON DELIVERY').toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: isPaidOnline ? PdfColors.green800 : PdfColors.orange800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSignatureSection() {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          children: [
            pw.Container(width: 150, decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 1)))),
            pw.SizedBox(height: 5),
            pw.Text('Authorized Consignor Signature', style: const pw.TextStyle(fontSize: 8)),
          ],
        ),
        pw.Column(
          children: [
            pw.Container(width: 150, decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 1)))),
            pw.SizedBox(height: 5),
            pw.Text('Driver Verification', style: const pw.TextStyle(fontSize: 8)),
          ],
        ),
        pw.Column(
          children: [
            pw.Container(width: 150, decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 1)))),
            pw.SizedBox(height: 5),
            pw.Text('Consignee Receipt Signature', style: const pw.TextStyle(fontSize: 8)),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildInfoCol(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
        pw.Text(value, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  static pw.Widget _buildFooter() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('TERMS & CONDITIONS', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text(
          '1. The carrier is responsible for the goods from pickup until delivery to the consignee. '
          '2. Fragile items must be declared and insured separately. '
          '3. Any discrepancies must be noted at the time of delivery on this manifest.',
          style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 10),
        pw.Divider(thickness: 0.5, color: PdfColors.grey300),
        pw.Center(
          child: pw.Text('Generated by ${AvailTexts.appName} Freight Logistics Manifest System', style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey)),
        ),
      ],
    );
  }
}
