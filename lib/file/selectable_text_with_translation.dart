import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../translator/floating_translation_popup.dart';

/// 《代码文档》支持文本选择翻译的组件
///
/// 该组件包装SelectableText，支持文本选择时显示翻译悬浮窗
/// 当用户右键选择翻译时，会在鼠标位置显示翻译弹窗
class SelectableTextWithTranslation extends StatefulWidget {
  /// 要显示的文本内容
  final String text;

  /// 文本样式
  final TextStyle? style;

  /// 内边距
  final EdgeInsets? padding;

  const SelectableTextWithTranslation({super.key, required this.text, this.style, this.padding});

  @override
  State<SelectableTextWithTranslation> createState() => _SelectableTextWithTranslationState();
}

class _SelectableTextWithTranslationState extends State<SelectableTextWithTranslation> {
  OverlayEntry? _overlayEntry;
  String _selectedText = '';
  Offset _popupPosition = Offset.zero;
  bool _isPopupVisible = false;
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    // 确保初始状态正确
    _selectedText = '';
    _popupPosition = Offset.zero;
    _isPopupVisible = false;
    _overlayEntry = null;
    _delayTimer = null;
  }

  @override
  void dispose() {
    // 取消待执行的延迟操作
    _delayTimer?.cancel();
    // 直接清理OverlayEntry，不调用setState
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(SelectableTextWithTranslation oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当文件内容变化时，隐藏翻译弹窗并重置状态
    if (oldWidget.text != widget.text) {
      _hideTranslationPopup();
      // 取消之前的延迟操作
      _delayTimer?.cancel();
      _delayTimer = null;
      // 重置状态
      _selectedText = '';
      _popupPosition = Offset.zero;
      _isPopupVisible = false;
    }
  }

  /// 处理文本选择
  void _handleTextSelection(String selectedText, Offset position) {
    // 检查组件是否还在活跃状态
    if (!mounted) return;

    // 取消之前的延迟操作
    _delayTimer?.cancel();

    // 只在组件仍然mounted且没有在dispose过程中时才调用setState
    if (mounted && context.mounted) {
      try {
        setState(() {
          _selectedText = selectedText;
          _popupPosition = position;
        });
      } catch (e) {
        // 忽略setState错误
        return;
      }
    }

    // 延迟显示弹窗，避免在快速选择时频繁显示
    _delayTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted && _selectedText.trim().isNotEmpty && _selectedText == selectedText) {
        _showTranslationPopup();
      }
    });
  }

  /// 显示翻译弹窗
  void _showTranslationPopup() {
    if (!mounted || _selectedText.trim().isEmpty) return;

    _hideTranslationPopup();

    try {
      _overlayEntry = OverlayEntry(
        builder:
            (context) => Positioned(
              left: _popupPosition.dx,
              top: _popupPosition.dy,
              child: FloatingTranslationPopup(
                selectedText: _selectedText,
                position: _popupPosition,
                onClose: _hideTranslationPopup,
              ),
            ),
      );

      Overlay.of(context).insert(_overlayEntry!);

      // 只在组件仍然mounted且没有在dispose过程中时才调用setState
      if (mounted && context.mounted) {
        try {
          setState(() {
            _isPopupVisible = true;
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
          _isPopupVisible = false;
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
      child: Container(
        padding: widget.padding,
        child: SelectableText(
          widget.text,
          style: widget.style,
          onSelectionChanged: (selection, cause) {
            // 当文本选择改变时，检查是否有选中的文本
            if (selection != null && !selection.isCollapsed) {
              final selectedText = selection.textInside(widget.text);
              if (selectedText.trim().isNotEmpty) {
                // 获取当前鼠标位置（使用一个合理的默认位置）
                final renderObject = context.findRenderObject() as RenderBox?;
                if (renderObject != null) {
                  // 使用选择区域的大概位置
                  final size = renderObject.size;
                  final position = renderObject.localToGlobal(Offset(size.width * 0.5, size.height * 0.3));
                  _handleTextSelection(selectedText, position);
                }
              }
            } else {
              // 如果没有选中文本，隐藏弹窗
              _hideTranslationPopup();
            }
          },
          contextMenuBuilder: (context, editableTextState) {
            // 获取选中的文本
            final textEditingValue = editableTextState.textEditingValue;
            final selection = textEditingValue.selection;
            final selectedText = selection.textInside(textEditingValue.text);

            return _buildCustomContextMenu(context, editableTextState, selectedText);
          },
        ),
      ),
    );
  }

  /// 构建自定义右键菜单
  Widget _buildCustomContextMenu(BuildContext context, EditableTextState editableTextState, String selectedText) {
    final List<Widget> menuItems = [];

    // 复制按钮
    menuItems.add(
      _buildMenuItem(
        icon: Icons.copy,
        text: '复制',
        onPressed: () {
          editableTextState.copySelection(SelectionChangedCause.toolbar);
        },
      ),
    );

    // 翻译按钮
    if (selectedText.trim().isNotEmpty) {
      menuItems.add(
        _buildMenuItem(
          icon: Icons.translate,
          text: '翻译',
          onPressed: () {
            // 隐藏右键菜单
            editableTextState.hideToolbar();

            // 获取当前鼠标位置
            final renderObject = context.findRenderObject() as RenderBox?;
            if (renderObject != null) {
              final localPosition = renderObject.globalToLocal(Offset.zero);
              final globalPosition = renderObject.localToGlobal(localPosition);
              _handleTextSelection(selectedText, globalPosition);
            }
          },
        ),
      );
    }

    // 全选按钮
    menuItems.add(
      _buildMenuItem(
        icon: Icons.select_all,
        text: '全选',
        onPressed: () {
          editableTextState.selectAll(SelectionChangedCause.toolbar);
        },
      ),
    );

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2D2D2D),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: IntrinsicWidth(child: Column(mainAxisSize: MainAxisSize.min, children: menuItems)),
      ),
    );
  }

  /// 构建菜单项
  Widget _buildMenuItem({required IconData icon, required String text, required VoidCallback onPressed}) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: const Color(0xFF0A84FF)),
            const SizedBox(width: 8),
            Text(text, style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
