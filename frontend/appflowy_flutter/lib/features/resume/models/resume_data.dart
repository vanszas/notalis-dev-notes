import 'dart:convert';

class ResumeData {
  ResumeData({
    required this.basics,
    required this.work,
    required this.education,
    required this.skills,
    required this.projects,
    required this.metadata,
  });

  ResumeBasics basics;
  List<ResumeWork> work;
  List<ResumeEducation> education;
  List<ResumeSkill> skills;
  List<ResumeProject> projects;
  ResumeMetadata metadata;

  Map<String, dynamic> toJson() => {
        'basics': basics.toJson(),
        'work': work.map((e) => e.toJson()).toList(),
        'education': education.map((e) => e.toJson()).toList(),
        'skills': skills.map((e) => e.toJson()).toList(),
        'projects': projects.map((e) => e.toJson()).toList(),
        'metadata': metadata.toJson(),
      };

  factory ResumeData.fromJson(Map<String, dynamic> json) {
    return ResumeData(
      basics: json['basics'] != null
          ? ResumeBasics.fromJson(json['basics'] as Map<String, dynamic>)
          : ResumeBasics.empty(),
      work: (json['work'] as List<dynamic>? ?? [])
          .map((e) => ResumeWork.fromJson(e as Map<String, dynamic>))
          .toList(),
      education: (json['education'] as List<dynamic>? ?? [])
          .map((e) => ResumeEducation.fromJson(e as Map<String, dynamic>))
          .toList(),
      skills: (json['skills'] as List<dynamic>? ?? [])
          .map((e) => ResumeSkill.fromJson(e as Map<String, dynamic>))
          .toList(),
      projects: (json['projects'] as List<dynamic>? ?? [])
          .map((e) => ResumeProject.fromJson(e as Map<String, dynamic>))
          .toList(),
      metadata: json['metadata'] != null
          ? ResumeMetadata.fromJson(json['metadata'] as Map<String, dynamic>)
          : ResumeMetadata.defaultMeta(),
    );
  }

  String toJsonString() => const JsonEncoder.withIndent('  ').convert(toJson());

  static ResumeData fromJsonString(String str) =>
      ResumeData.fromJson(jsonDecode(str) as Map<String, dynamic>);

  static ResumeData corporate() => ResumeData(
        basics: ResumeBasics(
          name: 'Adrian Pratama',
          label: 'Senior Operations Director & Tech Executive',
          email: 'adrian.pratama@example.com',
          phone: '+62 812-3456-7890',
          url: 'linkedin.com/in/adrian-pratama',
          location: 'Jakarta, Indonesia',
          picture: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300&auto=format&fit=crop&q=80',
          summary:
              'Executive leader with 8+ years directing cross-functional tech and operations teams. Reduced cycle time by 40% across multi-million dollar portfolios and scaled digital operations for 50+ enterprise clients.',
          profiles: [
            ResumeProfile(network: 'LinkedIn', username: 'adrian-pratama', url: 'https://linkedin.com/in/adrian-pratama'),
            ResumeProfile(network: 'GitHub', username: 'adrian-p', url: 'https://github.com/adrian-p'),
          ],
        ),
        work: [
          ResumeWork(
            id: '1',
            company: 'PT Global Teknologi Nusantara',
            position: 'Director of Digital Operations',
            website: 'https://gt-nusantara.id',
            startDate: 'Jan 2022',
            endDate: 'Present',
            current: true,
            summary: 'Leading digital transformation and operations delivery across 3 regional hubs.',
            highlights: [
              'Managed Rp 15B operational budget delivering 18 high-impact enterprise services.',
              'Accelerated deployment frequency by 300% via automated DevOps & Agile governance.',
              'Mentored 35+ PMs, engineers, and product specialists with 96% retention rate.',
            ],
          ),
          ResumeWork(
            id: '2',
            company: 'Inovasi Cipta Mandiri',
            position: 'Operations & Agile Lead',
            website: 'https://inovasicipta.com',
            startDate: 'Mar 2018',
            endDate: 'Dec 2021',
            current: false,
            summary: 'Managed cross-functional product execution and client engagement.',
            highlights: [
              'Automated internal reporting pipelines saving 140+ engineering hours monthly.',
              'Maintained strategic enterprise SLA compliance at 99.4% over 3 consecutive years.',
            ],
          ),
        ],
        education: [
          ResumeEducation(
            id: '1',
            institution: 'Universitas Indonesia',
            area: 'Business Management & Technology Strategy',
            studyType: 'Master of Management (MM)',
            startDate: '2019',
            endDate: '2021',
            score: '3.88 / 4.00',
            courses: ['Strategic Leadership', 'Digital Supply Chain', 'Enterprise IT Governance'],
          ),
          ResumeEducation(
            id: '2',
            institution: 'Institut Teknologi Bandung',
            area: 'Industrial Engineering',
            studyType: 'Bachelor of Science (B.Sc.)',
            startDate: '2013',
            endDate: '2017',
            score: '3.72 / 4.00',
            courses: ['Operations Research', 'Statistical Process Control'],
          ),
        ],
        skills: [
          ResumeSkill(id: '1', name: 'Strategic Leadership', level: '5', keywords: ['OKRs', 'Budgeting', 'Risk Mitigation']),
          ResumeSkill(id: '2', name: 'Agile & DevOps', level: '5', keywords: ['Scrum', 'CI/CD Pipelines', 'Jira']),
          ResumeSkill(id: '3', name: 'Product Analytics', level: '4', keywords: ['Tableau', 'PowerBI', 'SQL']),
        ],
        projects: [
          ResumeProject(
            id: '1',
            name: 'Enterprise Cloud ERP Transformation',
            description: 'Full-stack enterprise migration to centralized cloud infrastructure with 99.99% uptime.',
            url: 'https://gt-nusantara.id/case-study',
            keywords: ['Cloud Architecture', 'ERP', 'Cost Optimization'],
          ),
        ],
        metadata: ResumeMetadata(template: 'modern', primaryColor: '#1E3A8A'),
      );

  static ResumeData gameDev() => ResumeData(
        basics: ResumeBasics(
          name: 'Bima Satria Wijaya',
          label: 'Senior Unreal Engine 5 Gameplay & Core Programmer',
          email: 'bima.gamedev@example.com',
          phone: '+62 821-9876-5432',
          url: 'artstation.com/bima-tech',
          location: 'Bandung, Indonesia',
          picture: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=300&auto=format&fit=crop&q=80',
          summary:
              'Engine & Gameplay Programmer with 6+ years specializing in Unreal Engine 5 (C++/Slate), gameplay systems, network replication, and performance profiling on PC/Consoles.',
          profiles: [
            ResumeProfile(network: 'GitHub', username: 'bima-gamedev', url: 'https://github.com/bima-gamedev'),
            ResumeProfile(network: 'LinkedIn', username: 'bima-wijaya', url: 'https://linkedin.com/in/bima-wijaya'),
          ],
        ),
        work: [
          ResumeWork(
            id: '1',
            company: 'Nusantara Games Studio',
            position: 'Lead Gameplay Programmer',
            website: 'https://nusantaragames.com',
            startDate: 'Feb 2022',
            endDate: 'Present',
            current: true,
            summary: 'Engine programming and combat architecture on an unannounced UE5 action RPG.',
            highlights: [
              'Architected modular combat ability system with 0.2ms tick overhead using custom C++ components.',
              'Optimized Lumen & Nanite scenes on RTX 30/40 series achieving stable 60 FPS in 4K.',
              'Engineered deterministic rollback netcode for 4-player cooperative multiplayer.',
            ],
          ),
        ],
        education: [
          ResumeEducation(
            id: '1',
            institution: 'Institut Teknologi Bandung',
            area: 'Computer Science (Computer Graphics & Games)',
            studyType: 'Bachelor of Science (B.Sc.)',
            startDate: '2016',
            endDate: '2020',
            score: '3.82 / 4.00',
            courses: ['Realtime Rendering', 'Game Engine Architecture', 'Linear Algebra'],
          ),
        ],
        skills: [
          ResumeSkill(id: '1', name: 'Game Engines', level: '5', keywords: ['Unreal Engine 5', 'Unity', 'Custom C++ Engines']),
          ResumeSkill(id: '2', name: 'Languages', level: '5', keywords: ['C++', 'Rust', 'HLSL / Shaders', 'Python']),
          ResumeSkill(id: '3', name: 'Subsystems', level: '4', keywords: ['GAS (Gameplay Ability)', 'Slate UI', 'Network Replication']),
        ],
        projects: [
          ResumeProject(
            id: '1',
            name: 'Project Ksatria (UE5 ARPG)',
            description: 'Shipped PC/Steam title featuring fast-paced melee combat and custom animation warps.',
            url: 'https://store.steampowered.com/app/ksatria',
            keywords: ['UE5.4', 'C++', 'Motion Matching', 'Lumen'],
          ),
        ],
        metadata: ResumeMetadata(template: 'modern', primaryColor: '#0F766E'),
      );

  static ResumeData artist() => ResumeData(
        basics: ResumeBasics(
          name: 'Clara Devina',
          label: 'Senior 3D Environment & Lookdev Artist',
          email: 'clara.art@example.com',
          phone: '+62 813-2233-4455',
          url: 'artstation.com/claradevina',
          location: 'Yogyakarta, Indonesia',
          picture: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=300&auto=format&fit=crop&q=80',
          summary:
              'Environment Lookdev Artist with 5+ years crafting AAA photorealistic worlds in Blender, ZBrush, Substance Designer, and Unreal Engine 5. Featured on ArtStation Picks.',
          profiles: [
            ResumeProfile(network: 'ArtStation', username: 'claradevina', url: 'https://artstation.com/claradevina'),
            ResumeProfile(network: 'LinkedIn', username: 'clara-devina', url: 'https://linkedin.com/in/clara-devina'),
          ],
        ),
        work: [
          ResumeWork(
            id: '1',
            company: 'Prism VFX & Interactive',
            position: 'Senior 3D Environment Artist',
            website: 'https://prismvfx.com',
            startDate: 'Jan 2021',
            endDate: 'Present',
            current: true,
            summary: 'Leading environment lookdev and modular kitbash pipeline for cinematic productions.',
            highlights: [
              'Designed 20+ modular architectural kits with Nanite-ready PBR textures.',
              'Created master shader networks saving 30% texture memory while preserving micro-surface detail.',
            ],
          ),
        ],
        education: [
          ResumeEducation(
            id: '1',
            institution: 'Institut Seni Indonesia (ISI) Yogyakarta',
            area: 'Visual Communication & 3D Animation',
            studyType: 'Bachelor of Arts (B.A.)',
            startDate: '2016',
            endDate: '2020',
            score: '3.91 / 4.00',
            courses: ['Digital Sculpting', 'PBR Shading & Lighting', 'Color Theory'],
          ),
        ],
        skills: [
          ResumeSkill(id: '1', name: '3D Modeling', level: '5', keywords: ['Blender', 'ZBrush', 'Maya', 'Marvelous Designer']),
          ResumeSkill(id: '2', name: 'Texturing & Shading', level: '5', keywords: ['Substance Painter', 'Designer', 'MaterialX']),
          ResumeSkill(id: '3', name: 'Realtime Engine', level: '4', keywords: ['Unreal Engine 5', 'Lumen Lighting', 'PCG']),
        ],
        projects: [
          ResumeProject(
            id: '1',
            name: 'Neon Nusantara (Cyberpunk Sci-Fi Scene)',
            description: 'Featured on 80.lv and Unreal Engine Community Spotlight with 25k+ views.',
            url: 'https://artstation.com/artwork/neon-nusantara',
            keywords: ['Blender', 'Substance', 'UE5 Lookdev'],
          ),
        ],
        metadata: ResumeMetadata(template: 'modern', primaryColor: '#7C3AED'),
      );

  static ResumeData softwareEngineer() => ResumeData(
        basics: ResumeBasics(
          name: 'Dion Hartono',
          label: 'Full-Stack & Systems Software Engineer',
          email: 'dion.hartono@example.com',
          phone: '+62 811-5566-7788',
          url: 'github.com/dionhartono',
          location: 'Jakarta, Indonesia',
          picture: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=300&auto=format&fit=crop&q=80',
          summary:
              'Systems & Software Engineer with deep expertise in Flutter, Rust FFI, distributed backends, and low-latency local-first desktop architectures. Active open-source contributor.',
          profiles: [
            ResumeProfile(network: 'GitHub', username: 'dionhartono', url: 'https://github.com/dionhartono'),
            ResumeProfile(network: 'LinkedIn', username: 'dion-hartono', url: 'https://linkedin.com/in/dion-hartono'),
          ],
        ),
        work: [
          ResumeWork(
            id: '1',
            company: 'Artha Data Systems',
            position: 'Principal Software Engineer',
            website: 'https://arthadata.com',
            startDate: 'Jul 2021',
            endDate: 'Present',
            current: true,
            summary: 'Architecting local-first workspace applications and cryptographic synchronization protocols.',
            highlights: [
              'Built Rust FFI engine bridging native C++ storage with Flutter UI handling 100K+ blocks.',
              'Engineered end-to-end SQLite syncing engine operating completely offline with zero data loss.',
              'Reduced app memory consumption by 45% via custom image caching and tree pruning.',
            ],
          ),
        ],
        education: [
          ResumeEducation(
            id: '1',
            institution: 'Universitas Indonesia',
            area: 'Computer Science',
            studyType: 'Bachelor of Computer Science (B.Comp.Sc.)',
            startDate: '2017',
            endDate: '2021',
            score: '3.94 / 4.00',
            courses: ['Distributed Systems', 'Compilers', 'Operating Systems'],
          ),
        ],
        skills: [
          ResumeSkill(id: '1', name: 'Core Languages', level: '5', keywords: ['Rust', 'Dart / Flutter', 'C++', 'TypeScript']),
          ResumeSkill(id: '2', name: 'Storage & Sync', level: '5', keywords: ['SQLite', 'RocksDB', 'CRDTs', 'Local-First']),
          ResumeSkill(id: '3', name: 'Platform Engineering', level: '4', keywords: ['Windows API', 'Linux C APIs', 'WebSockets']),
        ],
        projects: [
          ResumeProject(
            id: '1',
            name: 'Local-First Synchronized Knowledge Base',
            description: 'Open source decentralized note-taking engine with 4.5k GitHub stars.',
            url: 'https://github.com/dionhartono/local-kb',
            keywords: ['Rust', 'Flutter', 'SQLite', 'Protobuf'],
          ),
        ],
        metadata: ResumeMetadata(template: 'modern', primaryColor: '#1E293B'),
      );

  static ResumeData indonesiaPro() => ResumeData(
        basics: ResumeBasics(
          name: 'NAMA LENGKAP ANDA',
          label: 'Spesialisasi / Posisi Profesional Anda',
          email: 'email@example.com',
          phone: '0812-3456-7890',
          url: 'linkedin.com/in/username',
          location: 'Jakarta, Indonesia',
          picture: '',
          summary:
              'Profesional yang berdedikasi dengan rekam jejak dalam memimpin inisiatif strategis, memecahkan masalah teknis yang kompleks, dan meningkatkan efisiensi operasional. Terbiasa bekerja secara kolaboratif dalam lingkungan lintas disiplin dengan orientasi kuat pada hasil nyata dan standar kualitas tinggi.',
          profiles: [
            ResumeProfile(network: 'LinkedIn', username: 'username', url: 'https://linkedin.com/in/username'),
            ResumeProfile(network: 'Portofolio', username: 'portofolio-anda', url: 'https://portfolio-anda.com'),
          ],
        ),
        work: [
          ResumeWork(
            id: '1',
            company: 'PT Nama Perusahaan Utama',
            position: 'Jabatan / Role Profesional Anda',
            website: 'Jakarta, Indonesia',
            startDate: 'Jan 2023',
            endDate: 'Sekarang',
            current: true,
            summary:
                'Perusahaan teknologi dan layanan terkemuka yang bergerak di bidang solusi digital dan transformasi operasional.',
            highlights: [
              'Memimpin eksekusi proyek strategis yang meningkatkan efisiensi proses tim sebesar 30%.',
              'Merancang dan mengimplementasikan sistem modular yang meningkatkan skalabilitas layanan.',
              'Berkolaborasi aktif dengan tim lintas fungsi untuk memastikan delivery produk tepat waktu.',
            ],
          ),
          ResumeWork(
            id: '2',
            company: 'Organisasi / Perusahaan Sebelumnya',
            position: 'Posisi / Role Sebelumnya',
            website: 'Bandung, Indonesia',
            startDate: 'Agu 2021',
            endDate: 'Des 2022',
            current: false,
            summary:
                'Instansi yang berfokus pada pengembangan produk dan inovasi berbasis teknologi.',
            highlights: [
              'Mengembangkan alur kerja terstruktur yang mengurangi waktu penanganan kendala hingga 25%.',
              'Menyusun dokumentasi teknis dan standar operasional untuk peningkatan kualitas kerja.',
            ],
          ),
        ],
        education: [
          ResumeEducation(
            id: '1',
            institution: 'Nama Universitas / Perguruan Tinggi',
            area: 'Program Studi / Jurusan',
            studyType: 'Gelar Sarjana',
            startDate: '2019',
            endDate: '2023',
            score: '3.80 / 4.00',
            courses: [
              'Organisasi Mahasiswa & Kepanitiaan',
              'Asisten Dosen / Praktikum',
              'Keahlian Utama Bidang Studi',
            ],
          ),
        ],
        skills: [
          ResumeSkill(
            id: '1',
            name: 'Program / Sertifikasi & Pelatihan Utama',
            level: '5',
            keywords: [
              'Manajemen Proyek',
              'Problem Solving',
              'Komunikasi Profesional',
              'Analisis Sistem',
            ],
          ),
          ResumeSkill(
            id: '2',
            name: 'Keahlian Teknis & Alat Kerja',
            level: '5',
            keywords: ['Tools Utama 1', 'Tools Utama 2', 'Framework / Software 1', 'Software 2'],
          ),
        ],
        projects: [
          ResumeProject(
            id: '1',
            name: 'Nama Proyek / Portofolio Unggulan',
            description: 'Inisiatif atau produk yang berhasil dirancang dan diimplementasikan dengan dampak terukur.',
            url: 'https://proyek-anda.com',
            keywords: ['Teknologi 1', 'Teknologi 2', 'Metodologi'],
          ),
        ],
        metadata: ResumeMetadata(
          template: 'indonesia_pro',
          primaryColor: '#000000',
          photoShape: 'square',
          photoSize: 100.0,
          showPhoto: true,
        ),
      );
}

class ResumeBasics {
  ResumeBasics({
    required this.name,
    required this.label,
    required this.email,
    required this.phone,
    required this.url,
    required this.location,
    required this.picture,
    required this.summary,
    required this.profiles,
  });

  String name;
  String label;
  String email;
  String phone;
  String url;
  String location;
  String picture;
  String summary;
  List<ResumeProfile> profiles;

  Map<String, dynamic> toJson() => {
        'name': name,
        'label': label,
        'email': email,
        'phone': phone,
        'url': url,
        'location': location,
        'picture': picture,
        'summary': summary,
        'profiles': profiles.map((e) => e.toJson()).toList(),
      };

  factory ResumeBasics.fromJson(Map<String, dynamic> json) => ResumeBasics(
        name: json['name'] as String? ?? '',
        label: json['label'] as String? ?? '',
        email: json['email'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        url: json['url'] as String? ?? '',
        location: json['location'] as String? ?? '',
        picture: json['picture'] as String? ?? '',
        summary: json['summary'] as String? ?? '',
        profiles: (json['profiles'] as List<dynamic>? ?? [])
            .map((e) => ResumeProfile.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  static ResumeBasics empty() => ResumeBasics(
        name: '',
        label: '',
        email: '',
        phone: '',
        url: '',
        location: '',
        picture: '',
        summary: '',
        profiles: [],
      );
}

class ResumeProfile {
  ResumeProfile({
    required this.network,
    required this.username,
    required this.url,
  });

  String network;
  String username;
  String url;

  Map<String, dynamic> toJson() => {
        'network': network,
        'username': username,
        'url': url,
      };

  factory ResumeProfile.fromJson(Map<String, dynamic> json) => ResumeProfile(
        network: json['network'] as String? ?? '',
        username: json['username'] as String? ?? '',
        url: json['url'] as String? ?? '',
      );
}

class ResumeWork {
  ResumeWork({
    required this.id,
    required this.company,
    required this.position,
    required this.website,
    required this.startDate,
    required this.endDate,
    required this.current,
    required this.summary,
    required this.highlights,
  });

  String id;
  String company;
  String position;
  String website;
  String startDate;
  String endDate;
  bool current;
  String summary;
  List<String> highlights;

  Map<String, dynamic> toJson() => {
        'id': id,
        'company': company,
        'position': position,
        'website': website,
        'startDate': startDate,
        'endDate': endDate,
        'current': current,
        'summary': summary,
        'highlights': highlights,
      };

  factory ResumeWork.fromJson(Map<String, dynamic> json) => ResumeWork(
        id: json['id'] as String? ?? '',
        company: json['company'] as String? ?? '',
        position: json['position'] as String? ?? '',
        website: json['website'] as String? ?? '',
        startDate: json['startDate'] as String? ?? '',
        endDate: json['endDate'] as String? ?? '',
        current: json['current'] as bool? ?? false,
        summary: json['summary'] as String? ?? '',
        highlights: (json['highlights'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
      );
}

class ResumeEducation {
  ResumeEducation({
    required this.id,
    required this.institution,
    required this.area,
    required this.studyType,
    required this.startDate,
    required this.endDate,
    required this.score,
    required this.courses,
  });

  String id;
  String institution;
  String area;
  String studyType;
  String startDate;
  String endDate;
  String score;
  List<String> courses;

  Map<String, dynamic> toJson() => {
        'id': id,
        'institution': institution,
        'area': area,
        'studyType': studyType,
        'startDate': startDate,
        'endDate': endDate,
        'score': score,
        'courses': courses,
      };

  factory ResumeEducation.fromJson(Map<String, dynamic> json) =>
      ResumeEducation(
        id: json['id'] as String? ?? '',
        institution: json['institution'] as String? ?? '',
        area: json['area'] as String? ?? '',
        studyType: json['studyType'] as String? ?? '',
        startDate: json['startDate'] as String? ?? '',
        endDate: json['endDate'] as String? ?? '',
        score: json['score'] as String? ?? '',
        courses: (json['courses'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
      );
}

class ResumeSkill {
  ResumeSkill({
    required this.id,
    required this.name,
    required this.level,
    required this.keywords,
  });

  String id;
  String name;
  String level;
  List<String> keywords;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'level': level,
        'keywords': keywords,
      };

  factory ResumeSkill.fromJson(Map<String, dynamic> json) => ResumeSkill(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        level: json['level'] as String? ?? '5',
        keywords: (json['keywords'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
      );
}

class ResumeProject {
  ResumeProject({
    required this.id,
    required this.name,
    required this.description,
    required this.url,
    required this.keywords,
  });

  String id;
  String name;
  String description;
  String url;
  List<String> keywords;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'url': url,
        'keywords': keywords,
      };

  factory ResumeProject.fromJson(Map<String, dynamic> json) => ResumeProject(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        url: json['url'] as String? ?? '',
        keywords: (json['keywords'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
      );
}

class ResumeMetadata {
  ResumeMetadata({
    required this.template,
    required this.primaryColor,
    this.fontFamily = 'Inter',
    this.photoShape = 'circle',
    this.photoSize = 80.0,
    this.showPhoto = true,
  });

  String template; // 'modern' or 'classic'
  String primaryColor; // e.g. '#1E3A8A'
  String fontFamily;
  String photoShape; // 'circle', 'square', 'rounded'
  double photoSize; // e.g. 50.0 to 130.0
  bool showPhoto;

  Map<String, dynamic> toJson() => {
        'template': template,
        'primaryColor': primaryColor,
        'fontFamily': fontFamily,
        'photoShape': photoShape,
        'photoSize': photoSize,
        'showPhoto': showPhoto,
      };

  factory ResumeMetadata.fromJson(Map<String, dynamic> json) => ResumeMetadata(
        template: json['template'] as String? ?? 'modern',
        primaryColor: json['primaryColor'] as String? ?? '#1E3A8A',
        fontFamily: json['fontFamily'] as String? ?? 'Inter',
        photoShape: json['photoShape'] as String? ?? 'circle',
        photoSize: (json['photoSize'] as num?)?.toDouble() ?? 80.0,
        showPhoto: json['showPhoto'] as bool? ?? true,
      );

  static ResumeMetadata defaultMeta() => ResumeMetadata(
        template: 'modern',
        primaryColor: '#1E3A8A',
      );
}
