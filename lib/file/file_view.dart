import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:path/path.dart' as path;
import 'package:cross_file/cross_file.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../history/history_view.dart';

/*《代码文档》
 * FileView - 文档阅读器中的中间原文件内容阅读面板
 * 
 * 主要功能：
 * 1. 显示选中文件的内容（支持 TXT 和 MD 格式）
 * 2. 支持拖拽文件到面板
 * 3. Markdown 渲染和普通文本显示
 * 4. 文件信息展示
 * 5. 错误处理和状态管理
 */
class FileView extends StatefulWidget {
  final FileHistoryItem? selectedFile;
  final Function(FileHistoryItem) onFileAdded;
  final Function(String) onError;
  final bool isTranslationPanelVisible;
  final VoidCallback onTranslationToggle;

  const FileView({
    super.key,
    this.selectedFile,
    required this.onFileAdded,
    required this.onError,
    required this.isTranslationPanelVisible,
    required this.onTranslationToggle,
  });

  @override
  State<FileView> createState() => _FileViewState();
}

class _FileViewState extends State<FileView> {
  bool _isDragging = false;
  String _errorMessage = '';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Color(0xFF1E1E1E)),
      child: Column(
        children: [
          // 标题栏
          _buildTitleBar(),
          // 原文内容
          Expanded(child: _buildOriginalContentArea()),
        ],
      ),
    );
  }

  Widget _buildTitleBar() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF2D2D2D),
        border: Border(bottom: BorderSide(color: Color(0xFF3D3D3D))),
      ),
      child: Row(
        children: [
          const Icon(Icons.article_outlined, color: Color(0xFF0A84FF)),
          const SizedBox(width: 8),
          const Text('原文', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFFFFFFF))),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.translate, color: Color(0xFF0A84FF)),
            onPressed: widget.onTranslationToggle,
            tooltip: widget.isTranslationPanelVisible ? '隐藏翻译面板' : '显示翻译面板',
          ),
        ],
      ),
    );
  }

  Widget _buildOriginalContentArea() {
    return DropTarget(
      onDragDone: (detail) {
        _handleDroppedFiles(detail.files);
      },
      onDragEntered: (detail) {
        setState(() {
          _isDragging = true;
        });
      },
      onDragExited: (detail) {
        setState(() {
          _isDragging = false;
        });
      },
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          border: _isDragging ? Border.all(color: const Color(0xFF0A84FF), width: 2) : null,
          color: _isDragging ? const Color(0xFF0A84FF).withValues(alpha: 0.1) : const Color(0xFF1E1E1E),
        ),
        child: _buildOriginalContent(),
      ),
    );
  }

  Widget _buildOriginalContent() {
    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Text(
              '错误：$_errorMessage',
              style: const TextStyle(fontSize: 16, color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0A84FF), foregroundColor: Colors.white),
              onPressed: () {
                setState(() {
                  _errorMessage = '';
                });
              },
              child: const Text('确定'),
            ),
          ],
        ),
      );
    }

    if (widget.selectedFile != null) {
      return Column(
        children: [
          // 文件信息栏
          _buildFileInfoBar(),
          // 文件内容
          Expanded(child: _buildFileContentWidget()),
        ],
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_upload_outlined,
            size: 100,
            color: _isDragging ? const Color(0xFF0A84FF) : const Color(0xFF8E8E93),
          ),
          const SizedBox(height: 24),
          Text(
            _isDragging ? '松开鼠标放置文件' : '请拖入文件',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _isDragging ? const Color(0xFF0A84FF) : const Color(0xFF8E8E93),
            ),
          ),
          const SizedBox(height: 16),
          const Text('支持的格式：TXT、MD', style: TextStyle(fontSize: 16, color: Color(0xFFA0A0A0))),
        ],
      ),
    );
  }

  Widget _buildFileInfoBar() {
    if (widget.selectedFile == null) return const SizedBox();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF2D2D2D),
        border: Border(bottom: BorderSide(color: Color(0xFF3D3D3D))),
      ),
      child: Row(
        children: [
          Icon(
            widget.selectedFile!.extension == '.md' ? Icons.article : Icons.description,
            color: const Color(0xFF0A84FF),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.selectedFile!.fileName,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFFFFFFF)),
                ),
                const SizedBox(height: 4),
                Text(
                  '最后修改：${widget.selectedFile!.lastModified.toString().split('.')[0]}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFFA0A0A0)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileContentWidget() {
    if (widget.selectedFile == null) return const SizedBox();

    if (widget.selectedFile!.extension == '.md') {
      return _buildMarkdownContent();
    } else {
      return _buildTextContent();
    }
  }

  Widget _buildMarkdownContent() {
    return Markdown(
      data: widget.selectedFile!.content,
      selectable: true,
      padding: const EdgeInsets.all(24),
      styleSheet: MarkdownStyleSheet(
        h1: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFFFFFFFF)),
        h2: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFFFFFFF)),
        h3: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFFFFFFF)),
        h4: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFFFFFFF)),
        h5: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFFFFFFF)),
        h6: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFFFFFFF)),
        p: const TextStyle(fontSize: 16, height: 1.7, color: Color(0xFFE5E5E5)),
        code: const TextStyle(
          backgroundColor: Color(0xFF3D3D3D),
          fontFamily: 'Courier',
          fontSize: 14,
          color: Color(0xFFFF6B6B),
        ),
        codeblockDecoration: const BoxDecoration(
          color: Color(0xFF2D2D2D),
          borderRadius: BorderRadius.all(Radius.circular(8)),
          border: Border.fromBorderSide(BorderSide(color: Color(0xFF3D3D3D))),
        ),
        blockquote: const TextStyle(color: Color(0xFFA0A0A0), fontStyle: FontStyle.italic),
        blockquoteDecoration: BoxDecoration(
          color: const Color(0xFF0A84FF).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
          border: const Border(left: BorderSide(color: Color(0xFF0A84FF), width: 4)),
        ),
        listBullet: const TextStyle(color: Color(0xFFE5E5E5)),
        tableHead: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFFFFFF)),
        tableBody: const TextStyle(fontSize: 14, color: Color(0xFFE5E5E5)),
        tableBorder: const TableBorder(
          top: BorderSide(color: Color(0xFF3D3D3D)),
          bottom: BorderSide(color: Color(0xFF3D3D3D)),
          left: BorderSide(color: Color(0xFF3D3D3D)),
          right: BorderSide(color: Color(0xFF3D3D3D)),
          horizontalInside: BorderSide(color: Color(0xFF3D3D3D)),
          verticalInside: BorderSide(color: Color(0xFF3D3D3D)),
        ),
      ),
    );
  }

  Widget _buildTextContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: SelectableText(
        widget.selectedFile!.content,
        style: const TextStyle(fontSize: 16, height: 1.6, fontFamily: 'Courier', color: Color(0xFFE5E5E5)),
      ),
    );
  }

  void _handleDroppedFiles(List<XFile> files) {
    setState(() {
      _isDragging = false;
      _errorMessage = '';
    });

    if (files.isEmpty) {
      setState(() {
        _errorMessage = '没有检测到文件';
      });
      return;
    }

    final file = files.first;
    final extension = path.extension(file.path).toLowerCase();

    if (extension != '.txt' && extension != '.md') {
      setState(() {
        _errorMessage = '不支持的文件格式。请拖入 TXT 或 MD 文件。';
      });
      return;
    }

    _readFile(file);
  }

  Future<void> _readFile(XFile file) async {
    try {
      final content = await file.readAsString();
      final fileName = path.basename(file.path);
      final extension = path.extension(file.path).toLowerCase();

      final fileItem = FileHistoryItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        fileName: fileName,
        filePath: file.path,
        content: content,
        extension: extension,
        lastModified: DateTime.now(),
      );

      widget.onFileAdded(fileItem);
    } catch (e) {
      setState(() {
        _errorMessage = '读取文件失败：$e';
      });
    }
  }
}
