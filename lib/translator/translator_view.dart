import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../history/history_view.dart';
import 'translation_service.dart';

/// 《代码文档》翻译视图组件
///
/// 该组件负责显示翻译面板，包含翻译功能和翻译结果显示
/// 支持Markdown和纯文本格式的翻译内容渲染
class TranslatorView extends StatefulWidget {
  /// 当前选中的文件项
  final FileHistoryItem? selectedFile;

  /// 翻译面板是否可见
  final bool isVisible;

  /// 翻译面板可见性变化回调
  final VoidCallback onVisibilityToggle;

  const TranslatorView({
    super.key,
    required this.selectedFile,
    required this.isVisible,
    required this.onVisibilityToggle,
  });

  @override
  State<TranslatorView> createState() => _TranslatorViewState();
}

class _TranslatorViewState extends State<TranslatorView> {
  // 翻译相关状态
  String _translatedContent = '';
  bool _isTranslating = false;
  String _translationError = '';

  @override
  void didUpdateWidget(TranslatorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当选中文件变化时，清空翻译内容
    if (oldWidget.selectedFile?.id != widget.selectedFile?.id) {
      setState(() {
        _translatedContent = '';
        _translationError = '';
      });
    }
  }

  /// 翻译文件内容
  Future<void> _translateContent() async {
    if (widget.selectedFile == null) return;

    setState(() {
      _isTranslating = true;
      _translationError = '';
    });

    try {
      final translatedText = await TranslationService.translateText(widget.selectedFile!.content);
      setState(() {
        _translatedContent = translatedText;
        _isTranslating = false;
      });
    } catch (e) {
      setState(() {
        _translationError = e.toString();
        _isTranslating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: const BoxDecoration(color: Color(0xFF1E1E1E)),
      child: Column(
        children: [
          // 标题栏
          _buildTitleBar(),
          // 翻译内容区域
          Expanded(child: _buildTranslationArea()),
        ],
      ),
    );
  }

  /// 构建标题栏
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
          const Icon(Icons.translate, color: Color(0xFF0A84FF)),
          const SizedBox(width: 8),
          const Text('翻译', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFFFFFFF))),
          const Spacer(),
          if (widget.selectedFile != null)
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0A84FF), foregroundColor: Colors.white),
              onPressed: _isTranslating ? null : _translateContent,
              child:
                  _isTranslating
                      ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                      : const Text('翻译'),
            ),
        ],
      ),
    );
  }

  /// 构建翻译内容区域
  Widget _buildTranslationArea() {
    if (_translationError.isNotEmpty) {
      return _buildErrorWidget();
    }

    if (_translatedContent.isNotEmpty) {
      return _buildTranslatedContent();
    }

    if (widget.selectedFile == null) {
      return _buildEmptyStateWidget();
    }

    return _buildReadyToTranslateWidget();
  }

  /// 构建错误显示组件
  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 64),
          const SizedBox(height: 16),
          Text(_translationError, style: const TextStyle(fontSize: 16, color: Colors.red), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0A84FF), foregroundColor: Colors.white),
            onPressed: () {
              setState(() {
                _translationError = '';
              });
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  /// 构建翻译内容显示组件
  Widget _buildTranslatedContent() {
    return Container(
      padding: const EdgeInsets.all(16),
      child:
          widget.selectedFile!.extension == '.md'
              ? Markdown(
                data: _translatedContent,
                selectable: true,
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
              )
              : SingleChildScrollView(
                child: SelectableText(
                  _translatedContent,
                  style: const TextStyle(fontSize: 16, height: 1.6, fontFamily: 'Courier', color: Color(0xFFE5E5E5)),
                ),
              ),
    );
  }

  /// 构建空状态显示组件
  Widget _buildEmptyStateWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.translate, size: 80, color: Color(0xFF8E8E93)),
          SizedBox(height: 16),
          Text('请先选择文件', style: TextStyle(fontSize: 18, color: Color(0xFF8E8E93))),
          SizedBox(height: 8),
          Text('然后点击翻译按钮进行翻译', style: TextStyle(fontSize: 14, color: Color(0xFFA0A0A0))),
        ],
      ),
    );
  }

  /// 构建准备翻译状态显示组件
  Widget _buildReadyToTranslateWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.translate, size: 80, color: Color(0xFF8E8E93)),
          SizedBox(height: 16),
          Text('点击翻译按钮开始翻译', style: TextStyle(fontSize: 18, color: Color(0xFF8E8E93))),
          SizedBox(height: 8),
          Text('翻译结果将在此处显示', style: TextStyle(fontSize: 14, color: Color(0xFFA0A0A0))),
        ],
      ),
    );
  }
}
