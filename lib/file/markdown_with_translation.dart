import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../translator/floating_translation_popup.dart';

/// 《代码文档》支持文本选择翻译的Markdown组件
///
/// 该组件包装Markdown，支持文本选择时显示翻译悬浮窗
/// 当用户选中文本时，会在选择位置显示翻译弹窗
class MarkdownWithTranslation extends StatefulWidget {
  /// 要显示的Markdown内容
  final String data;

  /// 内边距
  final EdgeInsets? padding;

  /// 样式表
  final MarkdownStyleSheet? styleSheet;

  const MarkdownWithTranslation({super.key, required this.data, this.padding, this.styleSheet});

  @override
  State<MarkdownWithTranslation> createState() => _MarkdownWithTranslationState();
}

class _MarkdownWithTranslationState extends State<MarkdownWithTranslation> {
  OverlayEntry? _overlayEntry;
  String _currentSelectedText = '';

  @override
  void initState() {
    super.initState();
    // 确保初始状态正确
    _overlayEntry = null;
    _currentSelectedText = '';
  }

  @override
  void dispose() {
    // 直接清理OverlayEntry，不调用setState
    if (_overlayEntry != null) {
      try {
        _overlayEntry!.remove();
      } catch (e) {
        // 忽略移除时的错误
      }
      _overlayEntry = null;
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(MarkdownWithTranslation oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当文件内容变化时，隐藏翻译弹窗并重置状态
    if (oldWidget.data != widget.data) {
      _hideTranslationPopup();
      // 重置状态
      _currentSelectedText = '';
    }
  }

  /// 显示翻译弹窗
  void _showTranslationPopup(String selectedText, Offset position) {
    if (!mounted || selectedText.trim().isEmpty) return;

    _hideTranslationPopup();

    try {
      _overlayEntry = OverlayEntry(
        builder:
            (context) => Positioned(
              left: position.dx,
              top: position.dy,
              child: FloatingTranslationPopup(
                selectedText: selectedText,
                position: position,
                onClose: _hideTranslationPopup,
              ),
            ),
      );

      Overlay.of(context).insert(_overlayEntry!);

      // 只在组件仍然mounted且没有在dispose过程中时才调用setState
      if (mounted && context.mounted) {
        try {
          setState(() {
            _currentSelectedText = selectedText;
          });
        } catch (e) {
          // 忽略setState错误
        }
      }
    } catch (e) {
      // 如果创建或插入OverlayEntry失败，清理状态
      _overlayEntry = null;
    }
  }

  /// 隐藏翻译弹窗
  void _hideTranslationPopup() {
    // 先移除OverlayEntry，避免后续回调
    if (_overlayEntry != null) {
      try {
        _overlayEntry!.remove();
      } catch (e) {
        // 忽略移除时的错误
      }
      _overlayEntry = null;
    }

    // 只在组件仍然mounted且没有在dispose过程中时才调用setState
    if (mounted && context.mounted) {
      try {
        setState(() {
          _currentSelectedText = '';
        });
      } catch (e) {
        // 忽略setState错误
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // 点击其他区域时隐藏弹窗
        if (_overlayEntry != null) {
          _hideTranslationPopup();
        }
      },
      child: SelectionArea(
        onSelectionChanged: (selection) {
          // 当文本选择改变时，检查是否有选中的文本
          if (selection != null) {
            final selectedText = selection.plainText;
            if (selectedText.trim().isNotEmpty) {
              // 获取选中文本的实际位置
              final renderObject = context.findRenderObject() as RenderBox?;
              if (renderObject != null) {
                // 计算选中文本的相对位置
                Offset position;
                try {
                  // 通过查找选中文本在原文中的位置来估算
                  final totalLength = widget.data.length;
                  final selectedTextIndex = widget.data.indexOf(selectedText);

                  if (selectedTextIndex != -1) {
                    // 计算相对位置
                    final relativePosition = selectedTextIndex / totalLength;

                    // 估算垂直位置
                    final averageLineHeight = 20.0; // Markdown的平均行高
                    final estimatedLine = (selectedTextIndex / 50).floor(); // 假设每行50个字符
                    final estimatedY = estimatedLine * averageLineHeight;

                    // 计算水平位置
                    final estimatedX = renderObject.size.width * (relativePosition * 0.8 + 0.1);

                    position = renderObject.localToGlobal(Offset(estimatedX, estimatedY - 60));

                    // 确保悬浮窗不会超出屏幕边界
                    final screenSize = MediaQuery.of(context).size;
                    final clampedX = position.dx.clamp(10.0, screenSize.width - 320.0);
                    final clampedY = position.dy.clamp(10.0, screenSize.height - 200.0);

                    position = Offset(clampedX, clampedY);
                  } else {
                    // 如果找不到选中文本，使用中心位置
                    position = renderObject.localToGlobal(
                      Offset(renderObject.size.width * 0.5, renderObject.size.height * 0.3),
                    );
                  }
                } catch (e) {
                  // 如果获取精确位置失败，使用中心位置
                  position = renderObject.localToGlobal(
                    Offset(renderObject.size.width * 0.5, renderObject.size.height * 0.3),
                  );
                }

                _showTranslationPopup(selectedText, position);
              }
            }
          } else {
            // 如果没有选中文本，隐藏弹窗
            _hideTranslationPopup();
          }
        },
        child: Markdown(
          data: widget.data,
          selectable: false, // 让SelectionArea处理选择
          padding: widget.padding ?? const EdgeInsets.all(24),
          styleSheet: widget.styleSheet,
        ),
      ),
    );
  }
}
