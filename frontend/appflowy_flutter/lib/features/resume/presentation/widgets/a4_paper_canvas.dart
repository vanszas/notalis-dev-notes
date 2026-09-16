import 'dart:io';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import '../../models/resume_data.dart';

class A4PaperCanvas extends StatelessWidget {
  const A4PaperCanvas({
    super.key,
    required this.data,
    this.scale = 1.0,
    this.onDataChanged,
    this.onPhotoUpdated,
    this.onPickPhoto,
  });

  final ResumeData data;
  final double scale;
  final VoidCallback? onDataChanged;
  final void Function(String pathOrUrl)? onPhotoUpdated;
  final VoidCallback? onPickPhoto;

  Color _parseHex(String hex, {Color fallback = const Color(0xFF1E3A8A)}) {
    try {
      final clean = hex.replaceAll('#', '').trim();
      if (clean.length == 6) {
        return Color(int.parse('FF$clean', radix: 16));
      } else if (clean.length == 8) {
        return Color(int.parse(clean, radix: 16));
      }
    } catch (_) {}
    return fallback;
  }

  void _notify() => onDataChanged?.call();

  @override
  Widget build(BuildContext context) {
    final primaryColor = _parseHex(data.metadata.primaryColor);
    final template = data.metadata.template.toLowerCase();
    final isIndonesiaPro = template == 'indonesia_pro';
    final isModern = template == 'modern';

    const double baseWidth = 650;
    const double baseHeight = 920;

    return Center(
      child: Container(
        width: baseWidth * scale,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: FittedBox(
          fit: BoxFit.contain,
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: baseWidth, minHeight: baseHeight),
            child: SizedBox(
              width: baseWidth,
              child: isIndonesiaPro
                  ? _buildIndonesiaProLayout(context, primaryColor)
                  : (isModern
                      ? _buildModernLayout(context, primaryColor)
                      : _buildClassicLayout(context, primaryColor)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfilePhoto(Color primaryColor) {
    final size = data.metadata.photoSize.clamp(40.0, 140.0);
    final shape = data.metadata.photoShape.toLowerCase();
    final radius = shape == 'circle'
        ? BorderRadius.circular(size / 2)
        : (shape == 'rounded' ? BorderRadius.circular(12) : BorderRadius.zero);

    Widget imageContent;
    final pic = data.basics.picture.trim();

    if (pic.isNotEmpty) {
      final file = File(pic);
      if (file.existsSync()) {
        imageContent = Image.file(file, fit: BoxFit.cover);
      } else {
        imageContent = Image.network(
          pic,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildMonogram(primaryColor, size, radius),
        );
      }
    } else {
      imageContent = _buildMonogram(primaryColor, size, radius);
    }

    return DropTarget(
      onDragDone: (details) {
        if (details.files.isNotEmpty) {
          final first = details.files.first;
          onPhotoUpdated?.call(first.path);
        }
      },
      child: Tooltip(
        message: 'Klik untuk memilih foto dari file atau Drag & Drop gambar ke sini',
        child: InkWell(
          onTap: onPickPhoto,
          borderRadius: radius,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  borderRadius: radius,
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: imageContent,
              ),
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.65),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt, size: 12, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonogram(Color primaryColor, double size, BorderRadius radius) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: radius,
      ),
      alignment: Alignment.center,
      child: Text(
        data.basics.name.isNotEmpty
            ? data.basics.name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join('')
            : 'CV',
        style: TextStyle(
          color: Colors.white,
          fontSize: (size * 0.32).clamp(14.0, 36.0),
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildModernLayout(BuildContext context, Color primaryColor) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left Column (32%)
          Container(
            width: 215,
            color: primaryColor.withOpacity(0.06),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (data.metadata.showPhoto) ...[
                  Center(child: _buildProfilePhoto(primaryColor)),
                  const SizedBox(height: 18),
                ],

                // Contact Section
                _sidebarSectionHeader('KONTAK & TAUTAN', primaryColor),
                _sidebarInlineRow(Icons.email_outlined, 'Email', data.basics.email, (v) {
                  data.basics.email = v;
                  _notify();
                }, primaryColor),
                _sidebarInlineRow(Icons.phone_outlined, 'Telepon', data.basics.phone, (v) {
                  data.basics.phone = v;
                  _notify();
                }, primaryColor),
                _sidebarInlineRow(Icons.location_on_outlined, 'Lokasi', data.basics.location, (v) {
                  data.basics.location = v;
                  _notify();
                }, primaryColor),
                _sidebarInlineRow(Icons.link_outlined, 'Portofolio', data.basics.url, (v) {
                  data.basics.url = v;
                  _notify();
                }, primaryColor),
                for (final p in data.basics.profiles)
                  _sidebarInlineRow(Icons.public_outlined, p.network, p.username, (v) {
                    p.username = v;
                    _notify();
                  }, primaryColor),
                const SizedBox(height: 18),

                // Skills Section
                _buildSidebarHeaderWithAdd('KEAHLIAN & TOOLS', primaryColor, () {
                  data.skills.add(
                    ResumeSkill(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: 'Kategori Baru',
                      level: '5',
                      keywords: ['Skill 1', 'Skill 2'],
                    ),
                  );
                  _notify();
                }),
                for (int si = 0; si < data.skills.length; si++) ...[
                  _buildSkillInlineItem(data.skills[si], si, primaryColor),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 14),

                // Education Section
                _buildSidebarHeaderWithAdd('PENDIDIKAN', primaryColor, () {
                  data.education.add(
                    ResumeEducation(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      institution: 'Nama Kampus',
                      area: 'Jurusan / Bidang',
                      studyType: 'Gelar',
                      startDate: '2018',
                      endDate: '2022',
                      score: '3.80',
                      courses: [],
                    ),
                  );
                  _notify();
                }),
                for (int ei = 0; ei < data.education.length; ei++) ...[
                  _buildEducationInlineItem(data.education[ei], ei, primaryColor),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),

          // Right Main Column (68%)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name (Click to edit directly on canvas)
                  _InlineText(
                    text: data.basics.name.toUpperCase(),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.blueGrey.shade900,
                      letterSpacing: 1.2,
                    ),
                    onChanged: (v) {
                      data.basics.name = v;
                      _notify();
                    },
                    hint: 'NAMA LENGKAP',
                  ),
                  const SizedBox(height: 4),

                  // Headline / Title (Click to edit)
                  _InlineText(
                    text: data.basics.label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: primaryColor,
                    ),
                    onChanged: (v) {
                      data.basics.label = v;
                      _notify();
                    },
                    hint: 'Gelar / Posisi Profesional',
                  ),
                  const SizedBox(height: 10),
                  Container(height: 2, color: primaryColor),
                  const SizedBox(height: 16),

                  // Executive Summary (Click to edit)
                  _mainSectionHeader('RINGKASAN EKSEKUTIF', primaryColor),
                  _InlineText(
                    text: data.basics.summary,
                    maxLines: null,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: Colors.blueGrey.shade800,
                      height: 1.45,
                    ),
                    onChanged: (v) {
                      data.basics.summary = v;
                      _notify();
                    },
                    hint: 'Tulis ringkasan eksekutif dan dampak profesional Anda di sini...',
                  ),
                  const SizedBox(height: 20),

                  // Work Experience
                  _buildMainHeaderWithAdd('PENGALAMAN KERJA', primaryColor, () {
                    data.work.add(
                      ResumeWork(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        company: 'Perusahaan Baru',
                        position: 'Jabatan / Role',
                        website: '',
                        startDate: '2022',
                        endDate: 'Sekarang',
                        current: true,
                        summary: '',
                        highlights: ['Pencapaian berbasis metrik dan tindakan nyata.'],
                      ),
                    );
                    _notify();
                  }),
                  for (int wi = 0; wi < data.work.length; wi++) ...[
                    _buildWorkInlineItem(data.work[wi], wi, primaryColor),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 8),

                  // Projects
                  _buildMainHeaderWithAdd('PROYEK & PORTOFOLIO', primaryColor, () {
                    data.projects.add(
                      ResumeProject(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        name: 'Judul Proyek Unggulan',
                        description: 'Deskripsi hasil dan dampak proyek.',
                        url: 'https://...',
                        keywords: ['Teknologi 1', 'Teknologi 2'],
                      ),
                    );
                    _notify();
                  }),
                  for (int pi = 0; pi < data.projects.length; pi++) ...[
                    _buildProjectInlineItem(data.projects[pi], pi, primaryColor),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassicLayout(BuildContext context, Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.all(36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Center(
            child: Column(
              children: [
                if (data.metadata.showPhoto) ...[
                  _buildProfilePhoto(primaryColor),
                  const SizedBox(height: 12),
                ],
                _InlineText(
                  text: data.basics.name.toUpperCase(),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.blueGrey.shade900,
                    letterSpacing: 1.4,
                  ),
                  onChanged: (v) {
                    data.basics.name = v;
                    _notify();
                  },
                ),
                const SizedBox(height: 4),
                _InlineText(
                  text: data.basics.label,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: primaryColor),
                  onChanged: (v) {
                    data.basics.label = v;
                    _notify();
                  },
                ),
                const SizedBox(height: 6),
                Text(
                  [
                    if (data.basics.location.isNotEmpty) data.basics.location,
                    if (data.basics.email.isNotEmpty) data.basics.email,
                    if (data.basics.phone.isNotEmpty) data.basics.phone,
                    if (data.basics.url.isNotEmpty) data.basics.url,
                  ].join('  |  '),
                  style: TextStyle(fontSize: 9.5, color: Colors.blueGrey.shade700),
                ),
                const SizedBox(height: 12),
                Container(height: 1.5, color: primaryColor),
                const SizedBox(height: 16),
              ],
            ),
          ),

          // Summary
          _mainSectionHeader('RINGKASAN PROFESIONAL', primaryColor),
          _InlineText(
            text: data.basics.summary,
            maxLines: null,
            style: TextStyle(fontSize: 10.5, color: Colors.blueGrey.shade800, height: 1.4),
            onChanged: (v) {
              data.basics.summary = v;
              _notify();
            },
          ),
          const SizedBox(height: 18),

          // Work Experience
          _buildMainHeaderWithAdd('PENGALAMAN KERJA', primaryColor, () {
            data.work.add(
              ResumeWork(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                company: 'Perusahaan Baru',
                position: 'Jabatan / Posisi',
                website: '',
                startDate: '2022',
                endDate: 'Sekarang',
                current: true,
                summary: '',
                highlights: ['Deskripsi pencapaian metrik...'],
              ),
            );
            _notify();
          }),
          for (int wi = 0; wi < data.work.length; wi++) ...[
            _buildWorkInlineItem(data.work[wi], wi, primaryColor),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _buildIndonesiaProLayout(BuildContext context, Color primaryColor) {
    final contactParts = [
      if (data.basics.phone.isNotEmpty) data.basics.phone,
      if (data.basics.email.isNotEmpty) data.basics.email,
      if (data.basics.url.isNotEmpty) data.basics.url,
      for (final p in data.basics.profiles) if (p.url.isNotEmpty) p.url,
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header (2-Column asymmetric: 3:4 Formal Photo Left + Identity Block Right)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (data.metadata.showPhoto) ...[
                _buildIndonesianPasFoto(primaryColor),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InlineText(
                      text: data.basics.name.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                        letterSpacing: 0.5,
                      ),
                      onChanged: (v) {
                        data.basics.name = v;
                        _notify();
                      },
                      hint: 'NAMA LENGKAP',
                    ),
                    const SizedBox(height: 3),
                    Text(
                      contactParts.join(' | '),
                      style: const TextStyle(
                        fontSize: 8.5,
                        color: Color(0xFF555555),
                        height: 1.3,
                      ),
                    ),
                    if (data.basics.location.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      _InlineText(
                        text: data.basics.location,
                        style: const TextStyle(
                          fontSize: 8.5,
                          color: Color(0xFF666666),
                        ),
                        onChanged: (v) {
                          data.basics.location = v;
                          _notify();
                        },
                        hint: 'Alamat (Dusun, Kecamatan, Kabupaten/Kota)',
                      ),
                    ],
                    const SizedBox(height: 6),
                    _InlineText(
                      text: data.basics.summary,
                      maxLines: null,
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: Colors.black,
                        height: 1.35,
                      ),
                      onChanged: (v) {
                        data.basics.summary = v;
                        _notify();
                      },
                      hint: 'Ringkasan profil, fokus studi, dan ambisi karier...',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 2. Work Experiences
          _buildIndonesianSectionHeader('Work Experiences', () {
            data.work.add(
              ResumeWork(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                company: 'Nama Institusi / Perusahaan',
                position: 'Role / Program',
                website: 'Lokasi',
                startDate: 'Bln YYYY',
                endDate: 'Bln YYYY',
                current: false,
                summary: 'Deskripsi singkat profil instansi...',
                highlights: ['Kompetensi atau pencapaian 1', 'Kompetensi atau pencapaian 2'],
              ),
            );
            _notify();
          }),
          for (int wi = 0; wi < data.work.length; wi++) ...[
            _buildIndonesianWorkItem(data.work[wi], wi),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 6),

          // 3. Education Level
          _buildIndonesianSectionHeader('Education Level', () {
            data.education.add(
              ResumeEducation(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                institution: 'Nama Kampus / Sekolah',
                area: 'Jurusan / Peminatan',
                studyType: 'Gelar (e.g. Bachelor of Informatika)',
                startDate: 'Sep 2022',
                endDate: 'Sekarang',
                score: '3.80 / 4.00',
                courses: ['Aktivitas organisasi atau mata kuliah relevan'],
              ),
            );
            _notify();
          }),
          for (int ei = 0; ei < data.education.length; ei++) ...[
            _buildIndonesianEducationItem(data.education[ei], ei),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 6),

          // 4. Skills, Achievements & Other Experience
          _buildIndonesianSectionHeader('Skills, Achievements & Other Experience', () {
            data.skills.add(
              ResumeSkill(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: 'Nama Program / Instansi (Tahun)',
                level: '5',
                keywords: ['Deskripsi peran, tanggung jawab, dan hasil nyata.'],
              ),
            );
            _notify();
          }),
          for (int si = 0; si < data.skills.length; si++) ...[
            _buildIndonesianAchievementItem(data.skills[si], si),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildIndonesianPasFoto(Color primaryColor) {
    const double width = 100;
    const double height = 133; // 3:4 aspect ratio

    Widget imageContent;
    final pic = data.basics.picture.trim();

    if (pic.isNotEmpty) {
      final file = File(pic);
      if (file.existsSync()) {
        imageContent = Image.file(file, fit: BoxFit.cover, width: width, height: height);
      } else {
        imageContent = Image.network(
          pic,
          fit: BoxFit.cover,
          width: width,
          height: height,
          errorBuilder: (_, __, ___) => _buildIndonesianMonogram(width, height),
        );
      }
    } else {
      imageContent = _buildIndonesianMonogram(width, height);
    }

    return DropTarget(
      onDragDone: (details) {
        if (details.files.isNotEmpty) {
          onPhotoUpdated?.call(details.files.first.path);
        }
      },
      child: Tooltip(
        message: 'Pas Foto Resmi 3:4 (Drag & Drop gambar atau klik untuk pilih file)',
        child: InkWell(
          onTap: onPickPhoto,
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: const Color(0xFFC8102E),
              border: Border.all(color: Colors.black45, width: 0.8),
            ),
            clipBehavior: Clip.antiAlias,
            child: imageContent,
          ),
        ),
      ),
    );
  }

  Widget _buildIndonesianMonogram(double width, double height) {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFFC8102E),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.person, size: 42, color: Colors.white70),
          SizedBox(height: 4),
          Text('PAS FOTO 3:4', style: TextStyle(fontSize: 8, color: Colors.white70, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildIndonesianSectionHeader(String title, VoidCallback onAdd) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              InkWell(
                onTap: onAdd,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.add, size: 11, color: Colors.black87),
                      SizedBox(width: 2),
                      Text('Tambah', style: TextStyle(fontSize: 8.5, color: Colors.black87, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Container(height: 1.5, color: Colors.black),
        ],
      ),
    );
  }

  Widget _buildIndonesianWorkItem(ResumeWork w, int index) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: _InlineText(
                      text: w.company,
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.black),
                      onChanged: (v) {
                        w.company = v;
                        _notify();
                      },
                      hint: 'Nama Perusahaan',
                    ),
                  ),
                  if (w.website.isNotEmpty) ...[
                    const Text(' - ', style: TextStyle(fontSize: 10, color: Color(0xFF666666))),
                    Flexible(
                      child: _InlineText(
                        text: w.website,
                        style: const TextStyle(fontSize: 10, color: Color(0xFF666666)),
                        onChanged: (v) {
                          w.website = v;
                          _notify();
                        },
                        hint: 'Lokasi (DKI Jakarta, Indonesia)',
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _InlineText(
              text: '${w.startDate} - ${w.endDate}',
              style: const TextStyle(fontSize: 10, color: Colors.black),
              onChanged: (v) {
                final parts = v.split('-');
                if (parts.length >= 2) {
                  w.startDate = parts[0].trim();
                  w.endDate = parts[1].trim();
                } else {
                  w.startDate = v.trim();
                }
                _notify();
              },
            ),
            const SizedBox(width: 6),
            InkWell(
              onTap: () {
                data.work.removeAt(index);
                _notify();
              },
              child: const Icon(Icons.close, size: 12, color: Colors.redAccent),
            ),
          ],
        ),
        _InlineText(
          text: w.position,
          style: const TextStyle(fontSize: 9.5, fontStyle: FontStyle.italic, color: Colors.black),
          onChanged: (v) {
            w.position = v;
            _notify();
          },
          hint: 'Role / Posisi',
        ),
        if (w.summary.isNotEmpty) ...[
          const SizedBox(height: 2),
          _InlineText(
            text: w.summary,
            maxLines: null,
            style: const TextStyle(fontSize: 9, color: Color(0xFF71717A)),
            onChanged: (v) {
              w.summary = v;
              _notify();
            },
          ),
        ],
        const SizedBox(height: 3),
        for (int hi = 0; hi < w.highlights.length; hi++)
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(fontSize: 11, color: Colors.black, height: 1.2)),
                Expanded(
                  child: _InlineText(
                    text: w.highlights[hi],
                    maxLines: null,
                    style: const TextStyle(fontSize: 9.5, color: Colors.black, height: 1.3),
                    onChanged: (v) {
                      w.highlights[hi] = v;
                      _notify();
                    },
                  ),
                ),
                InkWell(
                  onTap: () {
                    w.highlights.removeAt(hi);
                    _notify();
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(Icons.close, size: 10, color: Colors.black38),
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 1),
          child: InkWell(
            onTap: () {
              w.highlights.add('Kompetensi atau pencapaian baru...');
              _notify();
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.add, size: 10, color: Colors.blueAccent),
                SizedBox(width: 2),
                Text('Tambah Poin', style: TextStyle(fontSize: 8.5, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIndonesianEducationItem(ResumeEducation edu, int index) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: _InlineText(
                      text: edu.institution,
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.black),
                      onChanged: (v) {
                        edu.institution = v;
                        _notify();
                      },
                      hint: 'Nama Kampus',
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 11,
                    height: 11,
                    decoration: const BoxDecoration(
                      color: Color(0xFF0284C7),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.check, size: 8, color: Colors.white),
                  ),
                  if (edu.area.isNotEmpty) ...[
                    const Text(' - ', style: TextStyle(fontSize: 10, color: Color(0xFF666666))),
                    Flexible(
                      child: _InlineText(
                        text: edu.area,
                        style: const TextStyle(fontSize: 10, color: Color(0xFF666666)),
                        onChanged: (v) {
                          edu.area = v;
                          _notify();
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _InlineText(
              text: '${edu.startDate} - ${edu.endDate}',
              style: const TextStyle(fontSize: 10, color: Colors.black),
              onChanged: (v) {
                final parts = v.split('-');
                if (parts.length >= 2) {
                  edu.startDate = parts[0].trim();
                  edu.endDate = parts[1].trim();
                } else {
                  edu.startDate = v.trim();
                }
                _notify();
              },
            ),
            const SizedBox(width: 6),
            InkWell(
              onTap: () {
                data.education.removeAt(index);
                _notify();
              },
              child: const Icon(Icons.close, size: 12, color: Colors.redAccent),
            ),
          ],
        ),
        _InlineText(
          text: '${edu.studyType}${edu.score.isNotEmpty ? ', ${edu.score}' : ''}',
          style: const TextStyle(fontSize: 9.5, fontStyle: FontStyle.italic, color: Colors.black),
          onChanged: (v) {
            edu.studyType = v;
            _notify();
          },
          hint: 'Degree & GPA',
        ),
        const SizedBox(height: 2),
        for (int ci = 0; ci < edu.courses.length; ci++)
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(fontSize: 11, color: Colors.black, height: 1.2)),
                Expanded(
                  child: _InlineText(
                    text: edu.courses[ci],
                    style: const TextStyle(fontSize: 9.5, color: Colors.black, height: 1.3),
                    onChanged: (v) {
                      edu.courses[ci] = v;
                      _notify();
                    },
                  ),
                ),
                InkWell(
                  onTap: () {
                    edu.courses.removeAt(ci);
                    _notify();
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(Icons.close, size: 10, color: Colors.black38),
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 1),
          child: InkWell(
            onTap: () {
              edu.courses.add('Aktivitas / keahlian baru...');
              _notify();
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.add, size: 10, color: Colors.blueAccent),
                SizedBox(width: 2),
                Text('Tambah Poin', style: TextStyle(fontSize: 8.5, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIndonesianAchievementItem(ResumeSkill skill, int index) {
    final kwText = skill.keywords.join(', ');
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 12, color: Colors.black, height: 1.2)),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 9.5, color: Colors.black, height: 1.35),
                children: [
                  TextSpan(
                    text: skill.name,
                    style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black),
                  ),
                  const TextSpan(text: ': '),
                  TextSpan(text: kwText),
                ],
              ),
            ),
          ),
          InkWell(
            onTap: () {
              data.skills.removeAt(index);
              _notify();
            },
            child: const Icon(Icons.close, size: 12, color: Colors.redAccent),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkInlineItem(ResumeWork w, int index, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InlineText(
                    text: w.position,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.blueGrey.shade900),
                    onChanged: (v) {
                      w.position = v;
                      _notify();
                    },
                    hint: 'Jabatan / Posisi',
                  ),
                  _InlineText(
                    text: w.company,
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: primaryColor),
                    onChanged: (v) {
                      w.company = v;
                      _notify();
                    },
                    hint: 'Nama Perusahaan',
                  ),
                ],
              ),
            ),
            _InlineText(
              text: '${w.startDate} – ${w.endDate}',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.blueGrey.shade600),
              onChanged: (v) {
                final parts = v.split('–');
                if (parts.length >= 2) {
                  w.startDate = parts[0].trim();
                  w.endDate = parts[1].trim();
                } else {
                  w.startDate = v.trim();
                }
                _notify();
              },
            ),
            const SizedBox(width: 6),
            InkWell(
              onTap: () {
                data.work.removeAt(index);
                _notify();
              },
              child: const Icon(Icons.close, size: 14, color: Colors.redAccent),
            ),
          ],
        ),
        if (w.summary.isNotEmpty) ...[
          const SizedBox(height: 2),
          _InlineText(
            text: w.summary,
            style: TextStyle(fontSize: 9.5, fontStyle: FontStyle.italic, color: Colors.blueGrey.shade700),
            onChanged: (v) {
              w.summary = v;
              _notify();
            },
          ),
        ],
        const SizedBox(height: 4),
        for (int hi = 0; hi < w.highlights.length; hi++)
          Padding(
            padding: const EdgeInsets.only(left: 6, bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 4,
                  margin: const EdgeInsets.only(top: 5, right: 6),
                  decoration: BoxDecoration(color: primaryColor, shape: BoxShape.circle),
                ),
                Expanded(
                  child: _InlineText(
                    text: w.highlights[hi],
                    maxLines: null,
                    style: TextStyle(fontSize: 9.8, color: Colors.blueGrey.shade800, height: 1.3),
                    onChanged: (v) {
                      w.highlights[hi] = v;
                      _notify();
                    },
                  ),
                ),
                InkWell(
                  onTap: () {
                    w.highlights.removeAt(hi);
                    _notify();
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(Icons.remove_circle_outline, size: 12, color: Colors.black38),
                  ),
                ),
              ],
            ),
          ),
        // Add bullet button directly on canvas
        Padding(
          padding: const EdgeInsets.only(left: 12, top: 2),
          child: InkWell(
            onTap: () {
              w.highlights.add('Pencapaian atau hasil kerja baru...');
              _notify();
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, size: 12, color: primaryColor),
                const SizedBox(width: 2),
                Text('Tambah Bullet', style: TextStyle(fontSize: 8.5, color: primaryColor, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSkillInlineItem(ResumeSkill skill, int index, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: _InlineText(
                text: skill.name,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.blueGrey.shade900),
                onChanged: (v) {
                  skill.name = v;
                  _notify();
                },
                hint: 'Kategori Skill',
              ),
            ),
            InkWell(
              onTap: () {
                data.skills.removeAt(index);
                _notify();
              },
              child: const Icon(Icons.close, size: 12, color: Colors.redAccent),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (int ki = 0; ki < skill.keywords.length; ki++)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: primaryColor.withOpacity(0.35), width: 0.8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _InlineText(
                      text: skill.keywords[ki],
                      style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w600, color: primaryColor),
                      onChanged: (v) {
                        skill.keywords[ki] = v;
                        _notify();
                      },
                    ),
                    const SizedBox(width: 2),
                    InkWell(
                      onTap: () {
                        skill.keywords.removeAt(ki);
                        _notify();
                      },
                      child: const Icon(Icons.close, size: 10, color: Colors.black45),
                    ),
                  ],
                ),
              ),
            InkWell(
              onTap: () {
                skill.keywords.add('Skill Baru');
                _notify();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 10, color: primaryColor),
                    Text('Tag', style: TextStyle(fontSize: 8.5, color: primaryColor, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEducationInlineItem(ResumeEducation edu, int index, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: _InlineText(
                text: edu.institution,
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.blueGrey.shade900),
                onChanged: (v) {
                  edu.institution = v;
                  _notify();
                },
                hint: 'Nama Kampus',
              ),
            ),
            InkWell(
              onTap: () {
                data.education.removeAt(index);
                _notify();
              },
              child: const Icon(Icons.close, size: 12, color: Colors.redAccent),
            ),
          ],
        ),
        _InlineText(
          text: edu.studyType,
          style: TextStyle(fontSize: 9.5, color: Colors.blueGrey.shade800),
          onChanged: (v) {
            edu.studyType = v;
            _notify();
          },
          hint: 'Gelar / Program',
        ),
        _InlineText(
          text: edu.area,
          style: TextStyle(fontSize: 9, color: Colors.blueGrey.shade600),
          onChanged: (v) {
            edu.area = v;
            _notify();
          },
          hint: 'Jurusan / Bidang Studi',
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _InlineText(
              text: '${edu.startDate} – ${edu.endDate}',
              style: TextStyle(fontSize: 8.5, color: primaryColor, fontWeight: FontWeight.bold),
              onChanged: (v) {
                final parts = v.split('–');
                if (parts.length >= 2) {
                  edu.startDate = parts[0].trim();
                  edu.endDate = parts[1].trim();
                }
                _notify();
              },
            ),
            _InlineText(
              text: 'IPK: ${edu.score}',
              style: TextStyle(fontSize: 8.5, color: Colors.blueGrey.shade700),
              onChanged: (v) {
                edu.score = v.replaceAll('IPK:', '').trim();
                _notify();
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProjectInlineItem(ResumeProject p, int index, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: _InlineText(
                text: p.name,
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.blueGrey.shade900),
                onChanged: (v) {
                  p.name = v;
                  _notify();
                },
                hint: 'Nama Proyek',
              ),
            ),
            _InlineText(
              text: p.url,
              style: TextStyle(fontSize: 8.5, color: primaryColor),
              onChanged: (v) {
                p.url = v;
                _notify();
              },
              hint: 'URL Link',
            ),
            const SizedBox(width: 6),
            InkWell(
              onTap: () {
                data.projects.removeAt(index);
                _notify();
              },
              child: const Icon(Icons.close, size: 14, color: Colors.redAccent),
            ),
          ],
        ),
        _InlineText(
          text: p.description,
          maxLines: null,
          style: TextStyle(fontSize: 9.8, color: Colors.blueGrey.shade800),
          onChanged: (v) {
            p.description = v;
            _notify();
          },
          hint: 'Deskripsi hasil proyek...',
        ),
        const SizedBox(height: 2),
        _InlineText(
          text: 'Tech: ${p.keywords.join(' • ')}',
          style: TextStyle(fontSize: 8.8, fontWeight: FontWeight.w600, color: primaryColor),
          onChanged: (v) {
            final clean = v.replaceAll('Tech:', '').trim();
            p.keywords = clean.split('•').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
            _notify();
          },
          hint: 'Tech stack',
        ),
      ],
    );
  }

  Widget _sidebarSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: color, letterSpacing: 1.1),
          ),
          const SizedBox(height: 2),
          Container(width: 24, height: 1.5, color: color),
        ],
      ),
    );
  }

  Widget _buildSidebarHeaderWithAdd(String title, Color color, VoidCallback onAdd) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: color, letterSpacing: 1.1),
              ),
              const SizedBox(height: 2),
              Container(width: 24, height: 1.5, color: color),
            ],
          ),
          InkWell(
            onTap: onAdd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 10, color: color),
                  Text('Tambah', style: TextStyle(fontSize: 8, color: color, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mainSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: color, letterSpacing: 1),
          ),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 1, color: Colors.blueGrey.shade200)),
        ],
      ),
    );
  }

  Widget _buildMainHeaderWithAdd(String title, Color color, VoidCallback onAdd) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: color, letterSpacing: 1),
          ),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 1, color: Colors.blueGrey.shade200)),
          const SizedBox(width: 8),
          InkWell(
            onTap: onAdd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 11, color: color),
                  const SizedBox(width: 2),
                  Text('Tambah', style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarInlineRow(IconData icon, String label, String value, ValueChanged<String> onChanged, Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 11, color: primaryColor),
          const SizedBox(width: 5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.w700, color: Colors.blueGrey.shade600),
                ),
                _InlineText(
                  text: value,
                  style: TextStyle(fontSize: 8.5, color: Colors.blueGrey.shade900),
                  onChanged: onChanged,
                  hint: 'Ketik $label',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineText extends StatefulWidget {
  const _InlineText({
    required this.text,
    required this.style,
    required this.onChanged,
    this.maxLines,
    this.hint = 'Ketik di sini...',
  });

  final String text;
  final TextStyle style;
  final ValueChanged<String> onChanged;
  final int? maxLines;
  final String hint;

  @override
  State<_InlineText> createState() => _InlineTextState();
}

class _InlineTextState extends State<_InlineText> {
  late TextEditingController _controller;
  bool _isEditing = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.text);
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _isEditing) {
        setState(() => _isEditing = false);
        widget.onChanged(_controller.text);
      }
    });
  }

  @override
  void didUpdateWidget(_InlineText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text && !_focusNode.hasFocus) {
      _controller.text = widget.text;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing) {
      return TextField(
        controller: _controller,
        focusNode: _focusNode,
        autofocus: true,
        style: widget.style,
        maxLines: widget.maxLines ?? 1,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(3),
            borderSide: const BorderSide(color: Colors.blueAccent, width: 1),
          ),
          hintText: widget.hint,
        ),
        onSubmitted: (v) {
          setState(() => _isEditing = false);
          widget.onChanged(v);
        },
      );
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _isEditing = true;
            _controller.text = widget.text;
          });
        },
        child: Tooltip(
          message: 'Klik untuk mengedit langsung di CV',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(2)),
            child: Text(
              widget.text.isNotEmpty ? widget.text : widget.hint,
              style: widget.text.isNotEmpty
                  ? widget.style
                  : widget.style.copyWith(color: Colors.grey, fontStyle: FontStyle.italic),
              maxLines: widget.maxLines,
              softWrap: true,
            ),
          ),
        ),
      ),
    );
  }
}
