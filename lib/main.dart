import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:cross_file/cross_file.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '文档阅读器',
      theme: ThemeData(primarySwatch: Colors.blue, fontFamily: 'PingFang SC', useMaterial3: true),
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
    });
    _saveFileHistory();
  }

  // 删除文件历史记录
  void _removeFileFromHistory(String fileId) {
    setState(() {
      _fileHistory.removeWhere((item) => item.id == fileId);
      if (_selectedFile?.id == fileId) {
        _selectedFile = _fileHistory.isNotEmpty ? _fileHistory.first : null;
      }
    });
    _saveFileHistory();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Row(
        children: [
          // 左侧文件历史面板
          Container(
            width: 300,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(right: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Column(
              children: [
                // 标题栏
                Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.folder_outlined, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('文档历史', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                    ],
                  ),
                ),
                // 文件列表
                Expanded(child: _buildFileHistoryList()),
              ],
            ),
          ),
          // 右侧内容区域
          Expanded(child: _buildContentArea()),
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
            Icon(Icons.insert_drive_file_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('暂无文档历史', style: TextStyle(fontSize: 16, color: Colors.grey)),
            SizedBox(height: 8),
            Text('拖拽文件到右侧区域开始使用', style: TextStyle(fontSize: 12, color: Colors.grey)),
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
            color: isSelected ? Colors.blue.shade100 : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListTile(
            leading: Icon(
              fileItem.extension == '.md' ? Icons.article : Icons.description,
              color: isSelected ? Colors.blue : Colors.grey.shade600,
            ),
            title: Text(
              fileItem.fileName,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.blue.shade800 : Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              _formatDateTime(fileItem.lastModified),
              style: TextStyle(fontSize: 12, color: isSelected ? Colors.blue.shade600 : Colors.grey.shade600),
            ),
            trailing: PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, size: 16, color: isSelected ? Colors.blue.shade600 : Colors.grey.shade600),
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
              });
            },
          ),
        );
      },
    );
  }

  Widget _buildContentArea() {
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
          border: _isDragging ? Border.all(color: Colors.blue, width: 2) : null,
          color: _isDragging ? Colors.blue.withOpacity(0.1) : Colors.white,
        ),
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
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
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                Icon(_selectedFile!.extension == '.md' ? Icons.article : Icons.description, color: Colors.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_selectedFile!.fileName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        '最后修改：${_formatDateTime(_selectedFile!.lastModified)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
          Icon(Icons.cloud_upload_outlined, size: 100, color: _isDragging ? Colors.blue : Colors.grey),
          const SizedBox(height: 24),
          Text(
            _isDragging ? '松开鼠标放置文件' : '请拖入文件',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _isDragging ? Colors.blue : Colors.grey),
          ),
          const SizedBox(height: 16),
          Text('支持的格式：TXT、MD', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
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
        h1: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
        h2: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
        h3: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
        h4: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
        h5: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
        h6: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
        p: const TextStyle(fontSize: 16, height: 1.7, color: Colors.black87),
        code: TextStyle(
          backgroundColor: Colors.grey.shade200,
          fontFamily: 'Courier',
          fontSize: 14,
          color: Colors.red.shade700,
        ),
        codeblockDecoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        blockquote: const TextStyle(color: Colors.black54, fontStyle: FontStyle.italic),
        blockquoteDecoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(4),
          border: Border(left: BorderSide(color: Colors.blue.shade300, width: 4)),
        ),
        listBullet: const TextStyle(color: Colors.black87),
        tableHead: const TextStyle(fontWeight: FontWeight.bold),
        tableBody: const TextStyle(fontSize: 14),
        tableBorder: TableBorder.all(color: Colors.grey.shade300),
      ),
    );
  }

  Widget _buildTextContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: SelectableText(
        _selectedFile!.content,
        style: const TextStyle(fontSize: 16, height: 1.6, fontFamily: 'Courier', color: Colors.black87),
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
