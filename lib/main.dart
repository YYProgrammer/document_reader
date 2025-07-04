import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:cross_file/cross_file.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

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

// 文件历史记录数据结构
class FileHistoryItem {
  final String id;
  final String fileName;
  final String filePath;
  final String content;
  final String extension;
  final DateTime lastModified;

  FileHistoryItem({
    required this.id,
    required this.fileName,
    required this.filePath,
    required this.content,
    required this.extension,
    required this.lastModified,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fileName': fileName,
      'filePath': filePath,
      'content': content,
      'extension': extension,
      'lastModified': lastModified.toIso8601String(),
    };
  }

  static FileHistoryItem fromJson(Map<String, dynamic> json) {
    return FileHistoryItem(
      id: json['id'],
      fileName: json['fileName'],
      filePath: json['filePath'],
      content: json['content'],
      extension: json['extension'],
      lastModified: DateTime.parse(json['lastModified']),
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
  List<FileHistoryItem> _fileHistory = [];
  FileHistoryItem? _selectedFile;
  bool _isLoading = true;

  // 翻译相关状态
  String _translatedContent = '';
  bool _isTranslating = false;
  String _translationError = '';

  // 面板宽度控制
  double _leftPanelWidth = 300.0;
  double _centerPanelWidth = 400.0;
  final double _minPanelWidth = 200.0;
  final double _maxPanelWidth = 800.0;

  @override
  void initState() {
    super.initState();
    _loadFileHistory();
  }

  // 加载文件历史记录
  Future<void> _loadFileHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString('file_history');
      if (historyJson != null) {
        final List<dynamic> historyList = json.decode(historyJson);
        setState(() {
          _fileHistory = historyList.map((item) => FileHistoryItem.fromJson(item)).toList();
          _fileHistory.sort((a, b) => b.lastModified.compareTo(a.lastModified));
          if (_fileHistory.isNotEmpty) {
            _selectedFile = _fileHistory.first;
          }
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '加载文件历史失败：$e';
        _isLoading = false;
      });
    }
  }

  // 保存文件历史记录
  Future<void> _saveFileHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = json.encode(_fileHistory.map((item) => item.toJson()).toList());
      await prefs.setString('file_history', historyJson);
    } catch (e) {
      setState(() {
        _errorMessage = '保存文件历史失败：$e';
      });
    }
  }

  // 添加文件到历史记录
  void _addFileToHistory(FileHistoryItem fileItem) {
    setState(() {
      // 移除已存在的相同文件
      _fileHistory.removeWhere((item) => item.filePath == fileItem.filePath);
      // 添加新文件到最前面
      _fileHistory.insert(0, fileItem);
      // 限制历史记录数量
      if (_fileHistory.length > 50) {
        _fileHistory = _fileHistory.take(50).toList();
      }
      _selectedFile = fileItem;
      _errorMessage = '';
      _translatedContent = '';
      _translationError = '';
    });
    _saveFileHistory();
  }

  // 删除文件历史记录
  void _removeFileFromHistory(String fileId) {
    setState(() {
      _fileHistory.removeWhere((item) => item.id == fileId);
      if (_selectedFile?.id == fileId) {
        _selectedFile = _fileHistory.isNotEmpty ? _fileHistory.first : null;
        _translatedContent = '';
        _translationError = '';
      }
    });
    _saveFileHistory();
  }

  // 翻译文件内容
  Future<void> _translateContent() async {
    if (_selectedFile == null) return;

    setState(() {
      _isTranslating = true;
      _translationError = '';
    });

    try {
      final response = await http
          .post(
            Uri.parse('https://cerebras-proxy.brain.loocaa.com:1443/v1/chat/completions'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer DlJYSkMVj1x4zoe8jZnjvxfHG6z5yGxK',
            },
            body: json.encode({
              "model": "llama-3.3-70b",
              "messages": [
                {
                  "role": "system",
                  "content": "你是一个资深的中英文翻译官，你非常擅长把英文内容翻译为优雅的中文表达。\n现在，你需要根据用户发送的内容，进行翻译，只翻译用户发的内容，不要增加任何额外的文字",
                },
                {"role": "user", "content": _selectedFile!.content},
              ],
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final translatedText = data['choices'][0]['message']['content'];
        setState(() {
          _translatedContent = translatedText;
          _isTranslating = false;
        });
      } else {
        setState(() {
          _translationError = '翻译失败：HTTP ${response.statusCode}';
          _isTranslating = false;
        });
      }
    } catch (e) {
      setState(() {
        if (e.toString().contains('SocketException') || e.toString().contains('Connection failed')) {
          _translationError = '网络连接失败，请检查网络设置和防火墙配置';
        } else if (e.toString().contains('TimeoutException')) {
          _translationError = '请求超时，请稍后重试';
        } else {
          _translationError = '翻译失败：$e';
        }
        _isTranslating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF1E1E1E),
        body: Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0A84FF)))),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final rightPanelWidth = screenWidth - _leftPanelWidth - _centerPanelWidth - 16; // 16 for dividers

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      body: Row(
        children: [
          // 左侧文件历史面板
          Container(
            width: _leftPanelWidth,
            decoration: const BoxDecoration(
              color: Color(0xFF2D2D2D),
              border: Border(right: BorderSide(color: Color(0xFF3D3D3D))),
            ),
            child: Column(
              children: [
                // 标题栏
                Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: const BoxDecoration(
                    color: Color(0xFF323232),
                    border: Border(bottom: BorderSide(color: Color(0xFF3D3D3D))),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.folder_outlined, color: Color(0xFF0A84FF)),
                      SizedBox(width: 8),
                      Text(
                        '文档历史',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFFFFFFF)),
                      ),
                    ],
                  ),
                ),
                // 文件列表
                Expanded(child: _buildFileHistoryList()),
              ],
            ),
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
          Container(
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
                  child: const Row(
                    children: [
                      Icon(Icons.article_outlined, color: Color(0xFF0A84FF)),
                      SizedBox(width: 8),
                      Text('原文', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFFFFFFF))),
                    ],
                  ),
                ),
                // 原文内容
                Expanded(child: _buildOriginalContentArea()),
              ],
            ),
          ),
          // 右侧分割线
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
          // 右侧翻译面板
          Expanded(
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
                        const Icon(Icons.translate, color: Color(0xFF0A84FF)),
                        const SizedBox(width: 8),
                        const Text(
                          '翻译',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFFFFFFF)),
                        ),
                        const Spacer(),
                        if (_selectedFile != null)
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0A84FF),
                              foregroundColor: Colors.white,
                            ),
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
                  ),
                  // 翻译内容
                  Expanded(child: _buildTranslationArea()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileHistoryList() {
    if (_fileHistory.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.insert_drive_file_outlined, size: 48, color: Color(0xFF8E8E93)),
            SizedBox(height: 16),
            Text('暂无文档历史', style: TextStyle(fontSize: 16, color: Color(0xFF8E8E93))),
            SizedBox(height: 8),
            Text('拖拽文件到中间区域开始使用', style: TextStyle(fontSize: 12, color: Color(0xFF8E8E93))),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _fileHistory.length,
      itemBuilder: (context, index) {
        final fileItem = _fileHistory[index];
        final isSelected = _selectedFile?.id == fileItem.id;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0A84FF).withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListTile(
            leading: Icon(
              fileItem.extension == '.md' ? Icons.article : Icons.description,
              color: isSelected ? const Color(0xFF0A84FF) : const Color(0xFF8E8E93),
            ),
            title: Text(
              fileItem.fileName,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? const Color(0xFF0A84FF) : const Color(0xFFFFFFFF),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              _formatDateTime(fileItem.lastModified),
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? const Color(0xFF0A84FF).withOpacity(0.8) : const Color(0xFFA0A0A0),
              ),
            ),
            trailing: PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert,
                size: 16,
                color: isSelected ? const Color(0xFF0A84FF) : const Color(0xFF8E8E93),
              ),
              color: const Color(0xFF2D2D2D),
              onSelected: (value) {
                if (value == 'delete') {
                  _removeFileFromHistory(fileItem.id);
                }
              },
              itemBuilder:
                  (context) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 16, color: Colors.red),
                          SizedBox(width: 8),
                          Text('删除', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
            ),
            onTap: () {
              setState(() {
                _selectedFile = fileItem;
                _errorMessage = '';
                _translatedContent = '';
                _translationError = '';
              });
            },
          ),
        );
      },
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
                        '最后修改：${_formatDateTime(_selectedFile!.lastModified)}',
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

  Widget _buildTranslationArea() {
    if (_translationError.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Text(
              _translationError,
              style: const TextStyle(fontSize: 16, color: Colors.red),
              textAlign: TextAlign.center,
            ),
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

    if (_translatedContent.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        child:
            _selectedFile!.extension == '.md'
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
                )
                : SingleChildScrollView(
                  child: SelectableText(
                    _translatedContent,
                    style: const TextStyle(fontSize: 16, height: 1.6, fontFamily: 'Courier', color: Color(0xFFE5E5E5)),
                  ),
                ),
      );
    }

    if (_selectedFile == null) {
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

      _addFileToHistory(fileItem);
    } catch (e) {
      setState(() {
        _errorMessage = '读取文件失败：$e';
      });
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}天前';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}小时前';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}分钟前';
    } else {
      return '刚刚';
    }
  }
}
