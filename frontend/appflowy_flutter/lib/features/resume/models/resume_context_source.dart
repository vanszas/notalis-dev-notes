class ResumeContextSource {
  ResumeContextSource({
    required this.id,
    required this.title,
    required this.sourceType,
    this.detail = '',
    this.isSelected = true,
    this.content = '',
  });

  final String id;
  final String title;
  final String sourceType; // 'notalis_doc', 'notalis_file', 'notion_db', 'notion_page', 'custom_page', 'custom_db'
  final String detail;
  bool isSelected;
  String content;

  String get typeLabel {
    switch (sourceType) {
      case 'notion_db':
      case 'custom_db':
        return 'Notion DB';
      case 'notion_page':
      case 'custom_page':
        return 'Notion Page';
      case 'notalis_doc':
        return 'Notalis';
      case 'notalis_file':
        return 'File';
      default:
        return 'Notion';
    }
  }
}
