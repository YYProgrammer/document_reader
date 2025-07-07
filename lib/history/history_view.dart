import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// 《代码文档》
/// 文件历史记录项数据模型
/// 用于存储和管理单个文件的历史记录信息
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

  // 从JSON创建FileHistoryItem实例
  factory FileHistoryItem.fromJson(Map<String, dynamic> json) {
    return FileHistoryItem(
      id: json['id'],
      fileName: json['fileName'],
      filePath: json['filePath'],
      content: json['content'],
      extension: json['extension'],
      lastModified: DateTime.parse(json['lastModified']),
    );
  }

  // 将FileHistoryItem实例转换为JSON
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
}

/// 《代码文档》
/// 文件历史面板组件
/// 负责显示和管理文件历史记录，包括加载、保存、删除等功能
class HistoryView extends StatefulWidget {
  final double width;
  final FileHistoryItem? selectedFile;
  final Function(FileHistoryItem) onFileSelected;
  final Function(FileHistoryItem) onFileAdded;
  final Function(String) onError;

  const HistoryView({
    super.key,
    required this.width,
    this.selectedFile,
    required this.onFileSelected,
    required this.onFileAdded,
    required this.onError,
  });

  @override
  State<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<HistoryView> {
  List<FileHistoryItem> _fileHistory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFileHistory();
  }

  /// 加载文件历史记录
  Future<void> _loadFileHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString('file_history');
      if (historyJson != null) {
        final List<dynamic> historyList = json.decode(historyJson);
        setState(() {
          _fileHistory = historyList.map((item) => FileHistoryItem.fromJson(item)).toList();
          _fileHistory.sort((a, b) => b.lastModified.compareTo(a.lastModified));
          _isLoading = false;
        });

        // 如果有文件历史且没有选中文件，选中第一个
        if (_fileHistory.isNotEmpty && widget.selectedFile == null) {
          widget.onFileSelected(_fileHistory.first);
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      widget.onError('加载文件历史失败：$e');
    }
  }

  /// 保存文件历史记录
  Future<void> _saveFileHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = json.encode(_fileHistory.map((item) => item.toJson()).toList());
      await prefs.setString('file_history', historyJson);
    } catch (e) {
      widget.onError('保存文件历史失败：$e');
    }
  }

  /// 添加文件到历史记录
  void addFileToHistory(FileHistoryItem fileItem) {
    setState(() {
      // 移除已存在的相同文件
      _fileHistory.removeWhere((item) => item.filePath == fileItem.filePath);
      // 添加新文件到最前面
      _fileHistory.insert(0, fileItem);
      // 限制历史记录数量
      if (_fileHistory.length > 50) {
        _fileHistory = _fileHistory.take(50).toList();
      }
    });
    _saveFileHistory();
  }

  /// 删除文件历史记录
  void _removeFileFromHistory(String fileId) {
    setState(() {
      _fileHistory.removeWhere((item) => item.id == fileId);
    });
    _saveFileHistory();

    // 如果删除的是当前选中文件，选中第一个文件
    if (widget.selectedFile?.id == fileId && _fileHistory.isNotEmpty) {
      widget.onFileSelected(_fileHistory.first);
    }
  }

  /// 格式化时间显示
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

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
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
                Text('文档历史', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFFFFFFF))),
              ],
            ),
          ),
          // 文件列表
          Expanded(
            child:
                _isLoading
                    ? const Center(
                      child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0A84FF))),
                    )
                    : _buildFileHistoryList(),
          ),
        ],
      ),
    );
  }

  /// 构建文件历史列表
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
        final isSelected = widget.selectedFile?.id == fileItem.id;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0A84FF).withValues(alpha: 0.2) : Colors.transparent,
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
                color: isSelected ? const Color(0xFF0A84FF).withValues(alpha: 0.8) : const Color(0xFFA0A0A0),
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
              widget.onFileSelected(fileItem);
            },
          ),
        );
      },
    );
  }
}
