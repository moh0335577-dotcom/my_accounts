import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart' as intl;
import 'package:my_accounts/core/database/app_database.dart';

class PdfService {
  /// إنشاء تقرير مالي كامل
  static Future<void> generateFullReport({
    required String companyName,
    required String period,
    required String currency,
    required double totalIncome,
    required double totalExpense,
    required List<Map<String, dynamic>> transactionsData,
  }) async {
    final pdf = pw.Document();

    final font = await PdfGoogleFonts.cairoRegular();
    final boldFont = await PdfGoogleFonts.cairoBold();

    final format = intl.NumberFormat.decimalPattern();

    pdf.addPage(
      pw.MultiPage(
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(
          base: font,
          bold: boldFont,
        ),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Column(
              children: [
                pw.Text(
                  companyName,
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'تقرير مالي للفترة: $period',
                  style: const pw.TextStyle(
                    fontSize: 14,
                  ),
                ),
                pw.Divider(),
              ],
            ),
          ),

          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                'إجمالي المقبوضات',
                '${format.format(totalIncome)} $currency',
                PdfColors.green,
              ),
              _buildStatItem(
                'إجمالي المدفوعات',
                '${format.format(totalExpense)} $currency',
                PdfColors.red,
              ),
              _buildStatItem(
                'الصافي',
                '${format.format(totalIncome - totalExpense)} $currency',
                PdfColors.blue,
              ),
            ],
          ),

          pw.SizedBox(height: 20),

          pw.TableHelper.fromTextArray(
            headers: [
              'التاريخ',
              'النوع',
              'السبب',
              'المشروع',
              'المبلغ',
            ],
            data: transactionsData.map((data) {
              return [
                data['date']?.toString() ?? '-',
                data['type']?.toString() ?? '-',
                data['reason']?.toString() ?? '-',
                data['project']?.toString() ?? '-',
                data['amount']?.toString() ?? '-',
              ];
            }).toList(),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.blueGrey,
            ),
            cellAlignment: pw.Alignment.center,
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async {
        return pdf.save();
      },
    );
  }

  /// توافق مع ReportsScreen
  ///
  /// بعض أجزاء التطبيق تستدعي generateReport بدلاً من
  /// generateFullReport، لذلك نوفر هذه الدالة كواجهة موحدة.
  static Future<void> generateReport({
    required String companyName,
    required String period,
    required String currency,
    required double totalIncome,
    required double totalExpense,
    required List<Map<String, dynamic>> transactionsData,
  }) async {
    await generateFullReport(
      companyName: companyName,
      period: period,
      currency: currency,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      transactionsData: transactionsData,
    );
  }

  static pw.Widget _buildStatItem(
      String label,
      String value,
      PdfColor color,
      ) {
    return pw.Column(
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(
            fontSize: 12,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  /// إنشاء إيصال لمعاملة واحدة
  static Future<void> exportSingleTransaction(
      Transaction tx,
      Currency curr,
      Project? proj,
      ) async {
    final pdf = pw.Document();

    final font = await PdfGoogleFonts.cairoRegular();
    final boldFont = await PdfGoogleFonts.cairoBold();

    pdf.addPage(
      pw.Page(
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(
          base: font,
          bold: boldFont,
        ),
        build: (context) => pw.Center(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(30),

            // الإصلاح هنا:
            decoration: pw.BoxDecoration(
              border: pw.Border.all(
                color: PdfColors.grey,
              ),
              borderRadius: pw.BorderRadius.circular(8),
            ),

            child: pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Text(
                  tx.type == 'income'
                      ? 'إيصال قبض'
                      : 'إيصال دفع',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),

                pw.SizedBox(height: 20),

                _row(
                  'الرقم المرجعي',
                  tx.uuid.length >= 8
                      ? tx.uuid.substring(0, 8)
                      : tx.uuid,
                ),

                _row(
                  'المبلغ',
                  '${intl.NumberFormat.decimalPattern().format(tx.amount)} ${curr.code}',
                ),

                _row(
                  'التاريخ',
                  intl.DateFormat(
                    'yyyy-MM-dd HH:mm',
                  ).format(tx.transactionDate),
                ),

                _row(
                  'السبب',
                  tx.reason,
                ),

                _row(
                  'المشروع',
                  proj?.name ?? 'شخصي',
                ),

                _row(
                  'ملاحظات',
                  tx.notes ?? '-',
                ),

                pw.SizedBox(height: 40),

                pw.Text(
                  'توقيع المستلم: ............................',
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async {
        return pdf.save();
      },
    );
  }

  static pw.Widget _row(
      String label,
      String value,
      ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(
        vertical: 5,
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            '$label:',
            style: const pw.TextStyle(
              color: PdfColors.grey700,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}