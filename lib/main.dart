import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import 'package:cross_file/cross_file.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '文档阅读器',
      theme: ThemeData(primarySwatch: Colors.blue, fontFamily: 'PingFang SC'),
      home: const DocumentReaderScreen(),
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
  String _fileContent = '';
  String _fileName = '';
  String _errorMessage = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('文档阅读器'), backgroundColor: Colors.blue),
      body: DropTarget(
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
            border: Border.all(color: _isDragging ? Colors.blue : Colors.grey, width: 2, style: BorderStyle.solid),
            borderRadius: BorderRadius.circular(8),
            color: _isDragging ? Colors.blue.withOpacity(0.1) : Colors.white,
          ),
          child: _buildContent(),
        ),
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
                  _fileContent = '';
                  _fileName = '';
                });
              },
              child: const Text('重新开始'),
            ),
          ],
        ),
      );
    }

    if (_fileContent.isNotEmpty) {
      return Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                const Icon(Icons.description, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(child: Text(_fileName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _fileContent = '';
                      _fileName = '';
                      _errorMessage = '';
                    });
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SelectableText(_fileContent, style: const TextStyle(fontSize: 14, height: 1.5)),
            ),
          ),
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
      setState(() {
        _fileContent = content;
        _fileName = path.basename(file.path);
        _errorMessage = '';
      });
    } catch (e) {
      setState(() {
        _errorMessage = '读取文件失败：$e';
      });
    }
  }
}
