import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart' as intl;
import 'package:my_accounts/core/database/app_database.dart' as db;
import 'package:flutter/foundation.dart' show debugPrint;

class PdfService {
  static Future<pw.Font> _loadRegularFont() async {
    try {
      final data = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
      return pw.Font.ttf(data);
    } catch (e) {
      debugPrint('Error loading regular font: $e');
      // Fallback if needed, though assets should be present
      return pw.Font.ttf(await rootBundle.load('assets/fonts/Cairo-Regular.ttf'));
    }
  }

  static Future<pw.Font> _loadBoldFont() async {
    try {
      final data = await rootBundle.load('assets/fonts/Cairo-Bold.ttf');
      return pw.Font.ttf(data);
    } catch (e) {
      debugPrint('Error loading bold font: $e');
      return pw.Font.ttf(await rootBundle.load('assets/fonts/Cairo-Bold.ttf'));
    }
  }

  /// تصدير إيصال مالي احترافي مطابق لشاشة التفاصيل
  static Future<void> exportSingleTransaction({
    required db.Transaction tx,
    required db.Currency curr,
    db.Project? proj,
    db.Category? cat,
    db.Person? person,
    String companyName = 'حساباتي',
  }) async {
    try {
      final pdf = pw.Document();
      final font = await _loadRegularFont();
      final boldFont = await _loadBoldFont();
      final isIncome = tx.type == 'income';
      final formattedAmount = intl.NumberFormat.decimalPattern().format(tx.amount);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          textDirection: pw.TextDirection.rtl,
          theme: pw.ThemeData.withFont(base: font, bold: boldFont),
          build: (context) => pw.Center(
            child: pw.Container(
              width: 440,
              padding: const pw.EdgeInsets.all(30),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColor.fromInt(0xFF1A237E), width: 2),
                borderRadius: pw.BorderRadius.circular(15),
              ),
              child: pw.Column(
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.Text(companyName, style: pw.TextStyle(fontSize: 16, color: PdfColors.blueGrey700)),
                  pw.Divider(color: PdfColor.fromInt(0xFF1A237E), thickness: 1),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    isIncome ? 'إيصال قبض مالي' : 'إيصال صرف مالي',
                    style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF1A237E)),
                  ),
                  pw.SizedBox(height: 25),
                  
                  // منطقة المبلغ
                  pw.Container(
                    padding: const pw.EdgeInsets.all(20),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blue50,
                      borderRadius: pw.BorderRadius.circular(10),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Text(
                          '${isIncome ? "+" : "-"} $formattedAmount ${curr.code}',
                          style: pw.TextStyle(
                            fontSize: 32,
                            fontWeight: pw.FontWeight.bold,
                            color: isIncome ? PdfColors.green800 : PdfColors.red800,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Text(
                          tx.reason,
                          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  
                  pw.SizedBox(height: 30),

                  // جدول التفاصيل
                  pw.Table(
                    columnWidths: {
                      0: const pw.FixedColumnWidth(100),
                      1: const pw.FixedColumnWidth(20),
                      2: const pw.FlexColumnWidth(),
                    },
                    children: [
                      _tableRow('المشروع', proj?.name ?? 'شخصي'),
                      _tableRow('التصنيف', cat?.name ?? 'غير محدد'),
                      _tableRow('الطرف / الشخص', person?.name ?? 'غير محدد'),
                      _tableRow('التاريخ', intl.DateFormat('yyyy-MM-dd HH:mm').format(tx.transactionDate)),
                      _tableRow('الرقم المرجعي', tx.uuid.substring(0, 8).toUpperCase()),
                      if (tx.notes != null && tx.notes!.isNotEmpty)
                        _tableRow('ملاحظات', tx.notes!),
                    ],
                  ),

                  pw.SizedBox(height: 50),
                  
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSignatureBox('توقيع المحاسب'),
                      _buildSignatureBox('توقيع المستلم'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Invoice_${tx.uuid.substring(0, 8)}');
    } catch (e) {
      debugPrint('Error generating PDF: $e');
    }
  }

  static pw.Widget _buildSignatureBox(String title) {
    return pw.Column(
      children: [
        pw.Text(title, style: const pw.TextStyle(fontSize: 12)),
        pw.SizedBox(height: 35),
        pw.Container(
          width: 120,
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey500, width: 0.5)),
          ),
        ),
      ],
    );
  }

  static pw.TableRow _tableRow(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 8),
          child: pw.Text(label, style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700), textAlign: pw.TextAlign.right),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 8),
          child: pw.Text(':', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 8),
          child: pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13), textAlign: pw.TextAlign.right),
        ),
      ],
    );
  }

  /// تقرير كشف حساب احترافي (فاتورة مجمعة)
  static Future<void> generateFullReport({
    required String companyName,
    required String period,
    required String currency,
    required double totalIncome,
    required double totalExpense,
    required List<Map<String, dynamic>> transactionsData,
  }) async {
    try {
      final pdf = pw.Document();
      final font = await _loadRegularFont();
      final boldFont = await _loadBoldFont();
      final format = intl.NumberFormat.decimalPattern();
      final net = totalIncome - totalExpense;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          textDirection: pw.TextDirection.rtl,
          margin: const pw.EdgeInsets.all(30),
          theme: pw.ThemeData.withFont(base: font, bold: boldFont),
          header: (context) => pw.Column(
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(companyName, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF1A237E))),
                      pw.Text('كشف حساب للفترة: $period', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('تقرير مالي رسمي', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                      pw.Text('تاريخ الإصدار: ${intl.DateFormat('yyyy-MM-dd').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Divider(thickness: 2, color: PdfColor.fromInt(0xFF1A237E)),
              pw.SizedBox(height: 20),
            ],
          ),
          build: (context) => [
            // مربعات الملخص
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _buildSummaryBox('إجمالي المقبوضات', '${format.format(totalIncome)} $currency', PdfColors.green700),
                _buildSummaryBox('إجمالي المدفوعات', '${format.format(totalExpense)} $currency', PdfColors.red700),
                _buildSummaryBox('صافي الرصيد', '${format.format(net)} $currency', net >= 0 ? PdfColors.blue700 : PdfColors.orange900),
              ],
            ),
            pw.SizedBox(height: 30),
            
            // جدول البيانات
            pw.TableHelper.fromTextArray(
              headers: ['التاريخ', 'النوع', 'المشروع', 'التصنيف', 'البيان', 'الطرف', 'المبلغ', 'ملاحظات'],
              data: transactionsData.map((data) => [
                data['date'] ?? '-',
                data['type'] ?? '-',
                data['project'] ?? '-',
                data['category'] ?? '-',
                data['reason'] ?? '-',
                data['person'] ?? '-',
                data['amount'] ?? '-',
                data['notes'] ?? '-',
              ]).toList(),
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF1A237E)),
              rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
              cellAlignment: pw.Alignment.center,
              columnWidths: {
                0: const pw.FixedColumnWidth(70),
                1: const pw.FixedColumnWidth(40),
                2: const pw.FixedColumnWidth(70),
                3: const pw.FixedColumnWidth(70),
                4: const pw.FlexColumnWidth(3),
                5: const pw.FixedColumnWidth(70),
                6: const pw.FixedColumnWidth(90),
                7: const pw.FlexColumnWidth(2),
              },
            ),
          ],
          footer: (context) => pw.Container(
            alignment: pw.Alignment.centerLeft,
            margin: const pw.EdgeInsets.only(top: 20),
            child: pw.Text('صفحة ${context.pageNumber} من ${context.pagesCount}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
          ),
        ),
      );

      await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Financial_Report_$currency');
    } catch (e) {
      debugPrint('Error generating report: $e');
    }
  }

  static pw.Widget _buildSummaryBox(String label, String value, PdfColor color) {
    return pw.Container(
      width: 200,
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: color, width: 1.5),
      ),
      child: pw.Column(
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
          pw.SizedBox(height: 5),
          pw.Text(value, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
