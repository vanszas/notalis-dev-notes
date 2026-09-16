import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/resume_data.dart';

class ResumePdfService {
  static PdfColor _parseHex(String hex, {PdfColor fallback = PdfColors.blue900}) {
    try {
      final clean = hex.replaceAll('#', '').trim();
      if (clean.length == 6) {
        final val = int.parse('FF$clean', radix: 16);
        return PdfColor.fromInt(val);
      } else if (clean.length == 8) {
        final val = int.parse(clean, radix: 16);
        return PdfColor.fromInt(val);
      }
    } catch (_) {}
    return fallback;
  }

  static Future<Uint8List> generatePdf(ResumeData data) async {
    final pdf = pw.Document();
    final primaryColor = _parseHex(data.metadata.primaryColor);
    final template = data.metadata.template.toLowerCase();
    final isIndonesiaPro = template == 'indonesia_pro';
    final isModern = template == 'modern';

    if (isIndonesiaPro) {
      pw.ImageProvider? photoImg;
      try {
        final pic = data.basics.picture.trim();
        if (pic.isNotEmpty) {
          final file = File(pic);
          if (file.existsSync()) {
            photoImg = pw.MemoryImage(file.readAsBytesSync());
          }
        }
      } catch (_) {}

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          build: (pw.Context context) {
            final contactParts = [
              if (data.basics.phone.isNotEmpty) data.basics.phone,
              if (data.basics.email.isNotEmpty) data.basics.email,
              if (data.basics.url.isNotEmpty) data.basics.url,
              for (final p in data.basics.profiles) if (p.url.isNotEmpty) p.url,
            ];

            return [
              // Header
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (data.metadata.showPhoto) ...[
                    pw.Container(
                      width: 85,
                      height: 114,
                      decoration: pw.BoxDecoration(
                        color: const PdfColor.fromInt(0xFFC8102E),
                        border: pw.Border.all(color: PdfColors.black, width: 0.5),
                      ),
                      child: photoImg != null
                          ? pw.Image(photoImg, fit: pw.BoxFit.cover)
                          : pw.Center(
                              child: pw.Text(
                                'PAS FOTO 3:4',
                                style: pw.TextStyle(color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold),
                              ),
                            ),
                    ),
                    pw.SizedBox(width: 14),
                  ],
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          data.basics.name.toUpperCase(),
                          style: pw.TextStyle(
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.black,
                            letterSpacing: 0.5,
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          contactParts.join(' | '),
                          style: pw.TextStyle(fontSize: 8, color: const PdfColor.fromInt(0xFF555555), lineSpacing: 1.2),
                        ),
                        if (data.basics.location.isNotEmpty) ...[
                          pw.SizedBox(height: 1.5),
                          pw.Text(
                            data.basics.location,
                            style: pw.TextStyle(fontSize: 8, color: const PdfColor.fromInt(0xFF666666)),
                          ),
                        ],
                        if (data.basics.summary.isNotEmpty) ...[
                          pw.SizedBox(height: 5),
                          pw.Text(
                            data.basics.summary,
                            style: pw.TextStyle(fontSize: 8.8, color: PdfColors.black, lineSpacing: 1.3),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),

              // Work Experiences
              if (data.work.isNotEmpty) ...[
                _indonesiaSectionTitle('Work Experiences'),
                for (final w in data.work) ...[
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(
                        child: pw.RichText(
                          text: pw.TextSpan(
                            text: w.company,
                            style: pw.TextStyle(fontSize: 9.8, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                            children: [
                              if (w.website.isNotEmpty)
                                pw.TextSpan(
                                  text: ' - ${w.website}',
                                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.normal, color: const PdfColor.fromInt(0xFF666666)),
                                ),
                            ],
                          ),
                        ),
                      ),
                      pw.Text(
                        '${w.startDate} - ${w.endDate}',
                        style: pw.TextStyle(fontSize: 9, color: PdfColors.black),
                      ),
                    ],
                  ),
                  pw.Text(
                    w.position,
                    style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic, color: PdfColors.black),
                  ),
                  if (w.summary.isNotEmpty) ...[
                    pw.SizedBox(height: 1.5),
                    pw.Text(
                      w.summary,
                      style: pw.TextStyle(fontSize: 8.2, color: const PdfColor.fromInt(0xFF71717A)),
                    ),
                  ],
                  for (final hl in w.highlights)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(left: 8, top: 1.5),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('• ', style: pw.TextStyle(fontSize: 9, color: PdfColors.black)),
                          pw.Expanded(
                            child: pw.Text(
                              hl,
                              style: pw.TextStyle(fontSize: 8.5, color: PdfColors.black, lineSpacing: 1.2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  pw.SizedBox(height: 7),
                ],
              ],

              // Education Level
              if (data.education.isNotEmpty) ...[
                _indonesiaSectionTitle('Education Level'),
                for (final edu in data.education) ...[
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(
                        child: pw.RichText(
                          text: pw.TextSpan(
                            text: edu.institution,
                            style: pw.TextStyle(fontSize: 9.8, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                            children: [
                              if (edu.area.isNotEmpty)
                                pw.TextSpan(
                                  text: ' - ${edu.area}',
                                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.normal, color: const PdfColor.fromInt(0xFF666666)),
                                ),
                            ],
                          ),
                        ),
                      ),
                      pw.Text(
                        '${edu.startDate} - ${edu.endDate}',
                        style: pw.TextStyle(fontSize: 9, color: PdfColors.black),
                      ),
                    ],
                  ),
                  pw.Text(
                    '${edu.studyType}${edu.score.isNotEmpty ? ', ${edu.score}' : ''}',
                    style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic, color: PdfColors.black),
                  ),
                  for (final c in edu.courses)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(left: 8, top: 1.5),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('• ', style: pw.TextStyle(fontSize: 9, color: PdfColors.black)),
                          pw.Expanded(
                            child: pw.Text(
                              c,
                              style: pw.TextStyle(fontSize: 8.5, color: PdfColors.black),
                            ),
                          ),
                        ],
                      ),
                    ),
                  pw.SizedBox(height: 7),
                ],
              ],

              // Skills & Achievements
              if (data.skills.isNotEmpty) ...[
                _indonesiaSectionTitle('Skills, Achievements & Other Experience'),
                for (final s in data.skills)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(left: 4, bottom: 3),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('• ', style: pw.TextStyle(fontSize: 9, color: PdfColors.black)),
                        pw.Expanded(
                          child: pw.RichText(
                            text: pw.TextSpan(
                              text: s.name,
                              style: pw.TextStyle(fontSize: 8.8, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                              children: [
                                pw.TextSpan(text: ': '),
                                pw.TextSpan(
                                  text: s.keywords.join(', '),
                                  style: pw.TextStyle(fontWeight: pw.FontWeight.normal, color: PdfColors.black),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ];
          },
        ),
      );
      return pdf.save();
    }

    if (isModern) {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(0),
          build: (pw.Context context) {
            return [
              pw.Partitions(
                children: [
                  // Left Sidebar (32%)
                  pw.Partition(
                    width: 190,
                    child: pw.Container(
                      color: PdfColor(primaryColor.red, primaryColor.green, primaryColor.blue, 0.08),
                      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          // Monogram Avatar
                          pw.Center(
                            child: pw.Container(
                              width: 72,
                              height: 72,
                              decoration: pw.BoxDecoration(
                                color: primaryColor,
                                shape: pw.BoxShape.circle,
                              ),
                              child: pw.Center(
                                child: pw.Text(
                                  data.basics.name.isNotEmpty
                                      ? data.basics.name
                                          .split(' ')
                                          .map((e) => e.isNotEmpty ? e[0] : '')
                                          .take(2)
                                          .join('')
                                      : 'CV',
                                  style: pw.TextStyle(
                                    color: PdfColors.white,
                                    fontSize: 24,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          pw.SizedBox(height: 20),

                          // Contact Info
                          _sidebarHeading('CONTACT', primaryColor),
                          if (data.basics.email.isNotEmpty) _sidebarItem('Email', data.basics.email),
                          if (data.basics.phone.isNotEmpty) _sidebarItem('Phone', data.basics.phone),
                          if (data.basics.location.isNotEmpty) _sidebarItem('Location', data.basics.location),
                          if (data.basics.url.isNotEmpty) _sidebarItem('Portfolio', data.basics.url),
                          for (final prof in data.basics.profiles)
                            if (prof.username.isNotEmpty) _sidebarItem(prof.network, prof.username),
                          pw.SizedBox(height: 20),

                          // Skills
                          if (data.skills.isNotEmpty) ...[
                            _sidebarHeading('SKILLS', primaryColor),
                            for (final skill in data.skills) ...[
                              pw.Text(
                                skill.name,
                                style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.blueGrey900,
                                ),
                              ),
                              if (skill.keywords.isNotEmpty) ...[
                                pw.SizedBox(height: 3),
                                pw.Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: skill.keywords
                                      .map(
                                        (kw) => pw.Container(
                                          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                          decoration: pw.BoxDecoration(
                                            color: PdfColors.white,
                                            borderRadius: pw.BorderRadius.circular(3),
                                            border: pw.Border.all(
                                              color: PdfColor(primaryColor.red, primaryColor.green, primaryColor.blue, 0.3),
                                              width: 0.5,
                                            ),
                                          ),
                                          child: pw.Text(
                                            kw,
                                            style: pw.TextStyle(
                                              fontSize: 8,
                                              color: primaryColor,
                                              fontWeight: pw.FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ],
                              pw.SizedBox(height: 8),
                            ],
                            pw.SizedBox(height: 14),
                          ],

                          // Education
                          if (data.education.isNotEmpty) ...[
                            _sidebarHeading('EDUCATION', primaryColor),
                            for (final edu in data.education) ...[
                              pw.Text(
                                edu.institution,
                                style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.blueGrey900,
                                ),
                              ),
                              pw.Text(
                                edu.studyType,
                                style: pw.TextStyle(fontSize: 8.5, color: PdfColors.blueGrey700),
                              ),
                              if (edu.area.isNotEmpty)
                                pw.Text(
                                  edu.area,
                                  style: pw.TextStyle(fontSize: 8, color: PdfColors.blueGrey600),
                                ),
                              pw.Row(
                                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  pw.Text(
                                    '${edu.startDate} – ${edu.endDate}',
                                    style: pw.TextStyle(fontSize: 8, color: primaryColor, fontWeight: pw.FontWeight.bold),
                                  ),
                                  if (edu.score.isNotEmpty)
                                    pw.Text(
                                      'GPA: ${edu.score}',
                                      style: pw.TextStyle(fontSize: 8, color: PdfColors.blueGrey700),
                                    ),
                                ],
                              ),
                              pw.SizedBox(height: 10),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Right Main Column (68%)
                  pw.Partition(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 22, vertical: 24),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          // Header Name & Label
                          pw.Text(
                            data.basics.name.toUpperCase(),
                            style: pw.TextStyle(
                              fontSize: 22,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blueGrey900,
                              letterSpacing: 1.2,
                            ),
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text(
                            data.basics.label,
                            style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                          pw.SizedBox(height: 10),
                          pw.Container(height: 1.5, color: primaryColor),
                          pw.SizedBox(height: 14),

                          // Summary
                          if (data.basics.summary.isNotEmpty) ...[
                            _mainHeading('PROFILE SUMMARY', primaryColor),
                            pw.Text(
                              data.basics.summary,
                              style: pw.TextStyle(
                                fontSize: 9.5,
                                color: PdfColors.blueGrey800,
                                lineSpacing: 1.4,
                              ),
                            ),
                            pw.SizedBox(height: 18),
                          ],

                          // Work Experience
                          if (data.work.isNotEmpty) ...[
                            _mainHeading('WORK EXPERIENCE', primaryColor),
                            for (final w in data.work) ...[
                              pw.Row(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  pw.Expanded(
                                    child: pw.Column(
                                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                                      children: [
                                        pw.Text(
                                          w.position,
                                          style: pw.TextStyle(
                                            fontSize: 11,
                                            fontWeight: pw.FontWeight.bold,
                                            color: PdfColors.blueGrey900,
                                          ),
                                        ),
                                        pw.Text(
                                          w.company,
                                          style: pw.TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: pw.FontWeight.bold,
                                            color: primaryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  pw.Text(
                                    '${w.startDate} – ${w.endDate}',
                                    style: pw.TextStyle(
                                      fontSize: 9,
                                      fontWeight: pw.FontWeight.bold,
                                      color: PdfColors.blueGrey600,
                                    ),
                                  ),
                                ],
                              ),
                              if (w.summary.isNotEmpty) ...[
                                pw.SizedBox(height: 3),
                                pw.Text(
                                  w.summary,
                                  style: pw.TextStyle(
                                    fontSize: 9,
                                    fontStyle: pw.FontStyle.italic,
                                    color: PdfColors.blueGrey700,
                                  ),
                                ),
                              ],
                              if (w.highlights.isNotEmpty) ...[
                                pw.SizedBox(height: 4),
                                for (final hl in w.highlights)
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.only(left: 6, bottom: 2.5),
                                    child: pw.Row(
                                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                                      children: [
                                        pw.Container(
                                          width: 3.5,
                                          height: 3.5,
                                          margin: const pw.EdgeInsets.only(top: 3.5, right: 6),
                                          decoration: pw.BoxDecoration(
                                            color: primaryColor,
                                            shape: pw.BoxShape.circle,
                                          ),
                                        ),
                                        pw.Expanded(
                                          child: pw.Text(
                                            hl,
                                            style: pw.TextStyle(
                                              fontSize: 8.8,
                                              color: PdfColors.blueGrey800,
                                              lineSpacing: 1.2,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                              pw.SizedBox(height: 12),
                            ],
                            pw.SizedBox(height: 6),
                          ],

                          // Projects
                          if (data.projects.isNotEmpty) ...[
                            _mainHeading('KEY PROJECTS', primaryColor),
                            for (final p in data.projects) ...[
                              pw.Row(
                                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  pw.Text(
                                    p.name,
                                    style: pw.TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: pw.FontWeight.bold,
                                      color: PdfColors.blueGrey900,
                                    ),
                                  ),
                                  if (p.url.isNotEmpty)
                                    pw.Text(
                                      p.url,
                                      style: pw.TextStyle(fontSize: 8, color: primaryColor),
                                    ),
                                ],
                              ),
                              if (p.description.isNotEmpty) ...[
                                pw.SizedBox(height: 2),
                                pw.Text(
                                  p.description,
                                  style: pw.TextStyle(fontSize: 8.8, color: PdfColors.blueGrey800),
                                ),
                              ],
                              if (p.keywords.isNotEmpty) ...[
                                pw.SizedBox(height: 3),
                                pw.Text(
                                  'Tech: ${p.keywords.join(' • ')}',
                                  style: pw.TextStyle(
                                    fontSize: 7.8,
                                    fontWeight: pw.FontWeight.bold,
                                    color: primaryColor,
                                  ),
                                ),
                              ],
                              pw.SizedBox(height: 10),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ];
          },
        ),
      );
    } else {
      // Classic 1-Column ATS Layout
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          build: (pw.Context context) {
            return [
              // Header
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      data.basics.name.toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blueGrey900,
                        letterSpacing: 1.5,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      data.basics.label,
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      [
                        if (data.basics.location.isNotEmpty) data.basics.location,
                        if (data.basics.email.isNotEmpty) data.basics.email,
                        if (data.basics.phone.isNotEmpty) data.basics.phone,
                        if (data.basics.url.isNotEmpty) data.basics.url,
                      ].join(' | '),
                      style: pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey700),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Container(height: 1, color: primaryColor),
                    pw.SizedBox(height: 14),
                  ],
                ),
              ),

              // Summary
              if (data.basics.summary.isNotEmpty) ...[
                _mainHeading('PROFESSIONAL SUMMARY', primaryColor),
                pw.Text(
                  data.basics.summary,
                  style: pw.TextStyle(fontSize: 9.5, color: PdfColors.blueGrey800, lineSpacing: 1.3),
                ),
                pw.SizedBox(height: 16),
              ],

              // Experience
              if (data.work.isNotEmpty) ...[
                _mainHeading('EXPERIENCE', primaryColor),
                for (final w in data.work) ...[
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        '${w.position} — ${w.company}',
                        style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
                      ),
                      pw.Text(
                        '${w.startDate} – ${w.endDate}',
                        style: pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey700),
                      ),
                    ],
                  ),
                  if (w.summary.isNotEmpty) ...[
                    pw.SizedBox(height: 2),
                    pw.Text(w.summary, style: pw.TextStyle(fontSize: 8.8, fontStyle: pw.FontStyle.italic)),
                  ],
                  for (final hl in w.highlights)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(left: 10, top: 2),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('• ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: primaryColor)),
                          pw.Expanded(
                            child: pw.Text(hl, style: pw.TextStyle(fontSize: 8.8, color: PdfColors.blueGrey800)),
                          ),
                        ],
                      ),
                    ),
                  pw.SizedBox(height: 10),
                ],
                pw.SizedBox(height: 10),
              ],

              // Education
              if (data.education.isNotEmpty) ...[
                _mainHeading('EDUCATION', primaryColor),
                for (final edu in data.education) ...[
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        '${edu.studyType} in ${edu.area}',
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
                      ),
                      pw.Text(
                        '${edu.startDate} – ${edu.endDate}',
                        style: pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey700),
                      ),
                    ],
                  ),
                  pw.Text(edu.institution, style: pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey700)),
                  pw.SizedBox(height: 8),
                ],
                pw.SizedBox(height: 10),
              ],

              // Skills
              if (data.skills.isNotEmpty) ...[
                _mainHeading('SKILLS', primaryColor),
                for (final s in data.skills)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 3),
                    child: pw.RichText(
                      text: pw.TextSpan(
                        text: '${s.name}: ',
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
                        children: [
                          pw.TextSpan(
                            text: s.keywords.join(', '),
                            style: pw.TextStyle(fontWeight: pw.FontWeight.normal, color: PdfColors.blueGrey800),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ];
          },
        ),
      );
    }

    return pdf.save();
  }

  static pw.Widget _indonesiaSectionTitle(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 8, bottom: 4),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
            ),
          ),
          pw.SizedBox(height: 1.5),
          pw.Container(height: 1.2, color: PdfColors.black),
        ],
      ),
    );
  }

  static pw.Widget _sidebarHeading(String title, PdfColor color) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: color,
              letterSpacing: 1.1,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Container(width: 25, height: 1.5, color: color),
        ],
      ),
    );
  }

  static pw.Widget _sidebarItem(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey500,
            ),
          ),
          pw.SizedBox(height: 1),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 8.5, color: PdfColors.blueGrey900),
          ),
        ],
      ),
    );
  }

  static pw.Widget _mainHeading(String title, PdfColor color) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 10.5,
              fontWeight: pw.FontWeight.bold,
              color: color,
              letterSpacing: 1,
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(child: pw.Container(height: 0.8, color: PdfColors.blueGrey200)),
        ],
      ),
    );
  }

  static Future<String> savePdfToFile(ResumeData data, {String? targetDir}) async {
    final bytes = await generatePdf(data);
    String outDir = targetDir ?? '';

    if (outDir.isEmpty) {
      // Preference: Google Drive Notalis folder if mounted, else Documents
      final gDriveDir = Directory('G:\\My Drive\\Notalis\\Resumes');
      if (gDriveDir.existsSync()) {
        outDir = gDriveDir.path;
      } else {
        final docs = await getApplicationDocumentsDirectory();
        outDir = p.join(docs.path, 'Notalis', 'Resumes');
      }
    }

    final dir = Directory(outDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    final safeName = data.basics.name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final fileName = 'CV_${safeName.isEmpty ? 'Resume' : safeName}.pdf';
    final filePath = p.join(outDir, fileName);

    final file = File(filePath);
    await file.writeAsBytes(bytes);
    return filePath;
  }
}
