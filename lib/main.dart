import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:path/path.dart' as path;
import 'package:cross_file/cross_file.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'translator/translator_view.dart';
import 'history/history_view.dart';

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
  bool _isDragging = false;
  String _errorMessage = '';
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
      _errorMessage = '';
    });
  }

  // 处理文件添加
  void _handleFileAdded(FileHistoryItem fileItem) {
    setState(() {
      _selectedFile = fileItem;
      _errorMessage = '';
    });
  }

  // 处理错误消息
  void _handleError(String errorMessage) {
    setState(() {
      _errorMessage = errorMessage;
    });
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
              ? Container(
                width: _centerPanelWidth,
                decoration: const BoxDecoration(color: Color(0xFF1E1E1E)),
                child: Column(
                  children: [
                    // 标题栏
                    Container(
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
                          const Text(
                            '原文',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFFFFFFF)),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.translate, color: Color(0xFF0A84FF)),
                            onPressed: () {
                              setState(() {
                                _isTranslationPanelVisible = !_isTranslationPanelVisible;
                              });
                            },
                            tooltip: '隐藏翻译面板',
                          ),
                        ],
                      ),
                    ),
                    // 原文内容
                    Expanded(child: _buildOriginalContentArea()),
                  ],
                ),
              )
              : Expanded(
                child: Container(
                  decoration: const BoxDecoration(color: Color(0xFF1E1E1E)),
                  child: Column(
                    children: [
                      // 标题栏
                      Container(
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
                            const Text(
                              '原文',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFFFFFFF)),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.translate, color: Color(0xFF0A84FF)),
                              onPressed: () {
                                setState(() {
                                  _isTranslationPanelVisible = !_isTranslationPanelVisible;
                                });
                              },
                              tooltip: '显示翻译面板',
                            ),
                          ],
                        ),
                      ),
                      // 原文内容
                      Expanded(child: _buildOriginalContentArea()),
                    ],
                  ),
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
          color: _isDragging ? const Color(0xFF0A84FF).withOpacity(0.1) : const Color(0xFF1E1E1E),
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

    if (_selectedFile != null) {
      return Column(
        children: [
          // 文件信息栏
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF2D2D2D),
              border: Border(bottom: BorderSide(color: Color(0xFF3D3D3D))),
            ),
            child: Row(
              children: [
                Icon(
                  _selectedFile!.extension == '.md' ? Icons.article : Icons.description,
                  color: const Color(0xFF0A84FF),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedFile!.fileName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFFFFFFF)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '最后修改：${_selectedFile!.lastModified.toString().split('.')[0]}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFFA0A0A0)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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

  Widget _buildFileContentWidget() {
    if (_selectedFile == null) return const SizedBox();

    if (_selectedFile!.extension == '.md') {
      return _buildMarkdownContent();
    } else {
      return _buildTextContent();
    }
  }

  Widget _buildMarkdownContent() {
    return Markdown(
      data: _selectedFile!.content,
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
          color: const Color(0xFF0A84FF).withOpacity(0.1),
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
        _selectedFile!.content,
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

      // 通过GlobalKey引用来添加文件到历史记录
      final historyViewState = _historyViewKey.currentState;
      if (historyViewState != null) {
        (historyViewState as dynamic).addFileToHistory(fileItem);
      }
    } catch (e) {
      setState(() {
        _errorMessage = '读取文件失败：$e';
      });
    }
  }
}
