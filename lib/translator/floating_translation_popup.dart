import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'translation_service.dart';

/// 《代码文档》悬浮翻译弹窗组件
///
/// 该组件负责显示选中文本的翻译结果
/// 仿照百度翻译网页的悬浮窗效果
class FloatingTranslationPopup extends StatefulWidget {
  /// 要翻译的文本
  final String selectedText;

  /// 弹窗显示位置
  final Offset position;

  /// 关闭弹窗回调
  final VoidCallback onClose;

  const FloatingTranslationPopup({
    super.key,
    required this.selectedText,
    required this.position,
    required this.onClose,
  });

  @override
  State<FloatingTranslationPopup> createState() => _FloatingTranslationPopupState();
}

class _FloatingTranslationPopupState extends State<FloatingTranslationPopup> with SingleTickerProviderStateMixin {
  String _translatedText = '';
  bool _isTranslating = false;
  String _errorMessage = '';
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late FlutterTts _flutterTts;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(duration: const Duration(milliseconds: 200), vsync: this);
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack));
    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));

    _animationController.forward();
    _translateText();
    _initializeTts();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  /// 初始化TTS
  void _initializeTts() {
    _flutterTts = FlutterTts();
    _flutterTts.setStartHandler(() {
      setState(() {
        _isPlaying = true;
      });
    });
    _flutterTts.setCompletionHandler(() {
      setState(() {
        _isPlaying = false;
      });
    });
    _flutterTts.setErrorHandler((message) {
      setState(() {
        _isPlaying = false;
      });
    });
    _flutterTts.setCancelHandler(() {
      setState(() {
        _isPlaying = false;
      });
    });
    // 设置语言
    _flutterTts.setLanguage('zh-CN');
    // 设置语速
    _flutterTts.setSpeechRate(0.6);
    // 设置音量
    _flutterTts.setVolume(1.0);
    // 设置音调
    _flutterTts.setPitch(1.0);
  }

  /// 翻译选中的文本
  Future<void> _translateText() async {
    if (widget.selectedText.trim().isEmpty) return;

    setState(() {
      _isTranslating = true;
      _errorMessage = '';
    });

    try {
      final result = await TranslationService.translateText(widget.selectedText);
      // 检查组件是否还在活跃状态
      if (mounted) {
        setState(() {
          _translatedText = result;
          _isTranslating = false;
        });
      }
    } catch (e) {
      // 检查组件是否还在活跃状态
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isTranslating = false;
        });
      }
    }
  }

  /// 播放选中的文本
  void _playSelectedText() async {
    if (_isPlaying) {
      await _flutterTts.stop();
    } else {
      await _flutterTts.speak(widget.selectedText);
    }
  }

  /// 复制翻译结果
  void _copyTranslation() {
    if (_translatedText.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: _translatedText));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('翻译结果已复制'), duration: Duration(seconds: 2)));
      }
    }
  }

  /// 关闭弹窗
  void _closePopup() {
    _animationController.reverse().then((_) {
      if (mounted) {
        widget.onClose();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.scale(scale: _scaleAnimation.value, child: _buildPopupContent()),
        );
      },
    );
  }

  Widget _buildPopupContent() {
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300, maxHeight: 400),
        decoration: BoxDecoration(
          color: const Color(0xFF2D2D2D),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4)),
          ],
          border: Border.all(color: const Color(0xFF3D3D3D), width: 1),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [_buildHeader(), _buildContent()]),
      ),
    );
  }

  /// 构建头部
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF3D3D3D),
        borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
      ),
      child: Row(
        children: [
          const Icon(Icons.translate, color: Color(0xFF0A84FF), size: 18),
          const SizedBox(width: 8),
          const Text('翻译', style: TextStyle(color: Color(0xFFFFFFFF), fontSize: 14, fontWeight: FontWeight.bold)),
          const Spacer(),
          // 播放按钮
          IconButton(
            onPressed: _playSelectedText,
            icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow, color: const Color(0xFF0A84FF), size: 16),
            tooltip: _isPlaying ? '停止播放' : '播放原文',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          ),
          const SizedBox(width: 4),
          if (_translatedText.isNotEmpty)
            IconButton(
              onPressed: _copyTranslation,
              icon: const Icon(Icons.copy, color: Color(0xFF0A84FF), size: 16),
              tooltip: '复制翻译结果',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: _closePopup,
            icon: const Icon(Icons.close, color: Color(0xFFA0A0A0), size: 16),
            tooltip: '关闭',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          ),
        ],
      ),
    );
  }

  /// 构建内容区域
  Widget _buildContent() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 原文
          _buildOriginalText(),
          const SizedBox(height: 12),
          // 翻译结果
          _buildTranslationResult(),
        ],
      ),
    );
  }

  /// 构建原文显示
  Widget _buildOriginalText() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF3D3D3D), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('原文', style: TextStyle(color: Color(0xFFA0A0A0), fontSize: 12)),
          const SizedBox(height: 4),
          Text(widget.selectedText, style: const TextStyle(color: Color(0xFFE5E5E5), fontSize: 14, height: 1.4)),
        ],
      ),
    );
  }

  /// 构建翻译结果显示
  Widget _buildTranslationResult() {
    if (_isTranslating) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF3D3D3D), width: 1),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0A84FF)),
              ),
            ),
            SizedBox(width: 8),
            Text('翻译中...', style: TextStyle(color: Color(0xFFA0A0A0), fontSize: 14)),
          ],
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF3D3D3D), width: 1),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(_errorMessage, style: const TextStyle(color: Colors.red, fontSize: 14))),
          ],
        ),
      );
    }

    if (_translatedText.isNotEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF3D3D3D), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('翻译结果', style: TextStyle(color: Color(0xFFA0A0A0), fontSize: 12)),
            const SizedBox(height: 4),
            SelectableText(
              _translatedText,
              style: const TextStyle(color: Color(0xFFE5E5E5), fontSize: 14, height: 1.4),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
