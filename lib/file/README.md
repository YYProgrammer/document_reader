# 文档阅读器中的中间原文件内容阅读面板

## 概述

- 中间原文件内容阅读面板的相关功能和 UI
- 从 main.dart 中重构出来，提高代码模块化和可维护性

## 主要功能

### FileView 组件

**《代码文档》** 标记的 FileView 类提供以下功能：

1. **文件内容显示**

   - 支持 TXT 和 MD 格式文件
   - Markdown 文件的渲染和样式化
   - 普通文本文件的显示

2. **拖拽文件支持**

   - 支持从系统中拖拽文件到面板
   - 文件格式验证
   - 拖拽状态的视觉反馈

3. **文件信息展示**

   - 文件名显示
   - 文件类型图标
   - 最后修改时间

4. **错误处理**

   - 文件读取错误提示
   - 不支持格式的错误提示
   - 用户友好的错误界面

5. **翻译面板集成**
   - 翻译面板可见性控制
   - 标题栏翻译按钮
   - 动态工具提示

## 组件参数

- `selectedFile`: 当前选中的文件对象
- `onFileAdded`: 文件添加成功的回调函数
- `onError`: 错误处理的回调函数
- `isTranslationPanelVisible`: 翻译面板是否可见
- `onTranslationToggle`: 翻译面板切换的回调函数

## 重构优势

1. **模块化**: 将文件显示逻辑独立成单个组件
2. **可维护性**: 代码结构清晰，便于后续功能扩展
3. **可复用性**: FileView 组件可以在其他地方复用
4. **职责单一**: 每个组件专注于自己的功能领域
