import 'package:flutter/material.dart';
import 'translator/translator_view.dart';
import 'history/history_view.dart';
import 'file/file_view.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '文档阅读器',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF0A84FF), // macOS蓝色
          secondary: Color(0xFF0A84FF),
          surface: Color(0xFF1E1E1E), // 主背景色
          onSurface: Color(0xFFFFFFFF), // 主文本色
          onSecondary: Color(0xFFA0A0A0), // 次要文本色
        ),
        fontFamily: 'PingFang SC',
        scaffoldBackgroundColor: const Color(0xFF1E1E1E),
      ),
      home: const DocumentReaderScreen(),
    );
  }
}

// 可拖拽分割线组件
class DraggableResizerWidget extends StatefulWidget {
  final double initialWidth;
  final double minWidth;
  final double maxWidth;
  final ValueChanged<double> onWidthChanged;

  const DraggableResizerWidget({
    super.key,
    required this.initialWidth,
    required this.minWidth,
    required this.maxWidth,
    required this.onWidthChanged,
  });

  @override
  State<DraggableResizerWidget> createState() => _DraggableResizerWidgetState();
}

class _DraggableResizerWidgetState extends State<DraggableResizerWidget> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        onHorizontalDragStart: (details) {
          setState(() {
            _isDragging = true;
          });
        },
        onHorizontalDragUpdate: (details) {
          final newWidth = widget.initialWidth + details.delta.dx;
          if (newWidth >= widget.minWidth && newWidth <= widget.maxWidth) {
            widget.onWidthChanged(newWidth);
          }
        },
        onHorizontalDragEnd: (details) {
          setState(() {
            _isDragging = false;
          });
        },
        child: Container(
          width: 8,
          color: _isDragging ? const Color(0xFF0A84FF) : const Color(0xFF3D3D3D),
          child: const Center(child: SizedBox(width: 1, child: ColoredBox(color: Color(0xFF8E8E93)))),
        ),
      ),
    );
  }
}

class DocumentReaderScreen extends StatefulWidget {
  const DocumentReaderScreen({super.key});

  @override
  State<DocumentReaderScreen> createState() => _DocumentReaderScreenState();
}

class _DocumentReaderScreenState extends State<DocumentReaderScreen> {
  FileHistoryItem? _selectedFile;
  final GlobalKey<State<HistoryView>> _historyViewKey = GlobalKey<State<HistoryView>>();

  // 翻译面板可见性状态
  bool _isTranslationPanelVisible = false; // 默认隐藏翻译面板

  // 面板宽度控制
  double _leftPanelWidth = 300.0;
  double _centerPanelWidth = 400.0;
  final double _minPanelWidth = 200.0;
  final double _maxPanelWidth = 800.0;

  // 处理文件选择
  void _handleFileSelected(FileHistoryItem fileItem) {
    setState(() {
      _selectedFile = fileItem;
    });
  }

  // 处理文件添加
  void _handleFileAdded(FileHistoryItem fileItem) {
    setState(() {
      _selectedFile = fileItem;
    });

    // 通过GlobalKey引用来添加文件到历史记录
    final historyViewState = _historyViewKey.currentState;
    if (historyViewState != null) {
      (historyViewState as dynamic).addFileToHistory(fileItem);
    }
  }

  // 处理错误消息
  void _handleError(String errorMessage) {
    // 错误处理现在在 FileView 中处理
    // 这里可以添加全局错误处理逻辑，如果需要的话
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      body: Row(
        children: [
          // 左侧文件历史面板
          HistoryView(
            key: _historyViewKey,
            width: _leftPanelWidth,
            selectedFile: _selectedFile,
            onFileSelected: _handleFileSelected,
            onFileAdded: _handleFileAdded,
            onError: _handleError,
          ),
          // 左侧分割线
          DraggableResizerWidget(
            initialWidth: _leftPanelWidth,
            minWidth: _minPanelWidth,
            maxWidth: _maxPanelWidth,
            onWidthChanged: (newWidth) {
              setState(() {
                _leftPanelWidth = newWidth;
              });
            },
          ),
          // 中间原文件阅读面板
          _isTranslationPanelVisible
              ? SizedBox(
                width: _centerPanelWidth,
                child: FileView(
                  selectedFile: _selectedFile,
                  onFileAdded: _handleFileAdded,
                  onError: _handleError,
                  isTranslationPanelVisible: _isTranslationPanelVisible,
                  onTranslationToggle: () {
                    setState(() {
                      _isTranslationPanelVisible = !_isTranslationPanelVisible;
                    });
                  },
                ),
              )
              : Expanded(
                child: FileView(
                  selectedFile: _selectedFile,
                  onFileAdded: _handleFileAdded,
                  onError: _handleError,
                  isTranslationPanelVisible: _isTranslationPanelVisible,
                  onTranslationToggle: () {
                    setState(() {
                      _isTranslationPanelVisible = !_isTranslationPanelVisible;
                    });
                  },
                ),
              ),
          // 右侧分割线（仅在翻译面板可见时显示）
          if (_isTranslationPanelVisible)
            DraggableResizerWidget(
              initialWidth: _centerPanelWidth,
              minWidth: _minPanelWidth,
              maxWidth: _maxPanelWidth,
              onWidthChanged: (newWidth) {
                setState(() {
                  _centerPanelWidth = newWidth;
                });
              },
            ),
          // 右侧翻译面板（仅在可见时显示）
          if (_isTranslationPanelVisible)
            Expanded(
              child: TranslatorView(
                selectedFile: _selectedFile,
                isVisible: _isTranslationPanelVisible,
                onVisibilityToggle: () {
                  setState(() {
                    _isTranslationPanelVisible = !_isTranslationPanelVisible;
                  });
                },
              ),
            ),
        ],
      ),
    );
  }
}
