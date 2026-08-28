import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart' as intl;
import 'package:my_accounts/core/database/app_database.dart';
import 'package:flutter/foundation.dart' show debugPrint; // تم التعديل هنا لاستيراد debugPrint فقط وتجنب تضارب الأسماء

class PdfService {
  static Future<pw.Font> _loadRegularFont() async {
    try {
      final data = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
      return pw.Font.ttf(data);
    } catch (e) {
      debugPrint('Error loading regular font: $e');
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

  /// تصدير إيصال مالي مطابق لشاشة التفاصيل
  static Future<void> exportSingleTransaction({
    required Transaction tx,
    required Currency curr,
    Project? proj,
    Category? cat,
    Person? person,
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
                border: pw.Border.all(color: PdfColors.grey400, width: 1),
                borderRadius: pw.BorderRadius.circular(12),
              ),
              child: pw.Column(
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.Text(companyName, style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    isIncome ? 'إيصال قبض مالي' : 'إيصال صرف مالي',
                    style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 20),
                  
                  // منطقة المبلغ الكبير (مثل شاشة التفاصيل)
                  pw.Container(
                    padding: const pw.EdgeInsets.all(15),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Text(
                          '${isIncome ? "+" : "-"} $formattedAmount ${curr.code}',
                          style: pw.TextStyle(
                            fontSize: 28,
                            fontWeight: pw.FontWeight.bold,
                            color: isIncome ? PdfColors.green : PdfColors.red,
                          ),
                        ),
                        pw.SizedBox(height: 5),
                        pw.Text(
                          tx.reason,
                          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  
                  pw.SizedBox(height: 30),

                  // جدول التفاصيل
                  pw.Table(
                    columnWidths: {
                      0: const pw.FixedColumnWidth(100), // العنوان
                      1: const pw.FixedColumnWidth(20),  // النقطتان
                      2: const pw.FlexColumnWidth(),     // القيمة
                    },
                    children: [
                      _tableRow('المشروع', proj?.name ?? 'شخصي'),
                      _tableRow('التصنيف', cat?.name ?? 'غير محدد'),
                      _tableRow('الطرف / الشخص', person?.name ?? 'غير محدد'),
                      _tableRow('التاريخ والوقت', intl.DateFormat('yyyy-MM-dd  HH:mm').format(tx.transactionDate)),
                      _tableRow('الرقم المرجعي', tx.uuid.substring(0, 8)),
                      _tableRow('ملاحظات', (tx.notes?.isEmpty ?? true) ? '-' : tx.notes!),
                    ],
                  ),

                  pw.SizedBox(height: 60),
                  
                  // التوقيعات
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        children: [
                          pw.Text('توقيع المحاسب', style: const pw.TextStyle(fontSize: 12)),
                          pw.SizedBox(height: 40),
                          pw.Text('........................', style: const pw.TextStyle(color: PdfColors.grey400)),
                        ],
                      ),
                      pw.Column(
                        children: [
                          pw.Text('توقيع المستلم', style: const pw.TextStyle(fontSize: 12)),
                          pw.SizedBox(height: 40),
                          pw.Text('........................', style: const pw.TextStyle(color: PdfColors.grey400)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name: 'Receipt_${tx.uuid.substring(0, 8)}',
      );
    } catch (e) {
      debugPrint('Error generating PDF: $e');
    }
  }

  static pw.TableRow _tableRow(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 8),
          child: pw.Text(label, style: const pw.TextStyle(color: PdfColors.black, fontSize: 12), textAlign: pw.TextAlign.right),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 8),
          child: pw.Text(':', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12), textAlign: pw.TextAlign.center),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 8),
          child: pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12), textAlign: pw.TextAlign.right),
        ),
      ],
    );
  }

  /// التقرير المالي الكامل
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

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          textDirection: pw.TextDirection.rtl,
          margin: const pw.EdgeInsets.all(20),
          theme: pw.ThemeData.withFont(base: font, bold: boldFont),
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Column(
                children: [
                  pw.Text(companyName, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                  pw.Text('تقرير مالي للفترة: $period', style: const pw.TextStyle(fontSize: 12)),
                  pw.Divider(thickness: 1),
                ],
              ),
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('إجمالي المقبوضات', '${format.format(totalIncome)} $currency', PdfColors.green),
                _buildStatItem('إجمالي المدفوعات', '${format.format(totalExpense)} $currency', PdfColors.red),
                _buildStatItem('الصافي', '${format.format(totalIncome - totalExpense)} $currency', PdfColors.blue),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              headers: ['التاريخ', 'النوع', 'المشروع', 'التصنيف', 'البيان', 'الطرف', 'المبلغ', 'الملاحظات'],
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
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
              cellStyle: const pw.TextStyle(fontSize: 8),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
              cellAlignment: pw.Alignment.center,
              columnWidths: {
                0: const pw.FixedColumnWidth(65),
                1: const pw.FixedColumnWidth(35),
                2: const pw.FixedColumnWidth(65),
                3: const pw.FixedColumnWidth(65),
                4: const pw.FlexColumnWidth(2),
                5: const pw.FixedColumnWidth(65),
                6: const pw.FixedColumnWidth(80),
                7: const pw.FlexColumnWidth(2),
              },
            ),
          ],
        ),
      );

      await Printing.layoutPdf(onLayout: (format) async => pdf.save());
    } catch (e) {
      debugPrint('Error generating report: $e');
    }
  }

  static pw.Widget _buildStatItem(String label, String value, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
        pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: color)),
      ],
    );
  }
}
