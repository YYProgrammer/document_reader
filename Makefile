SHELL := /bin/bash
HIDE ?= @

export HOMEBREW_NO_AUTO_UPDATE=true

gen:
	$(HIDE)flutter pub get

build-mac:
	$(HIDE)echo "开始构建Mac应用..."
	$(HIDE)flutter build macos --release
	$(HIDE)echo "创建分发目录..."
	$(HIDE)mkdir -p dist
	$(HIDE)echo "生成DMG安装包..."
	$(HIDE)hdiutil create -volname "Document Reader" -srcfolder "build/macos/Build/Products/Release/Document Reader.app" -ov -format UDZO "dist/document_reader_mac.dmg"
	$(HIDE)echo "✅ Mac DMG包已生成: dist/document_reader_mac.dmg"
	$(HIDE)ls -la dist/document_reader_mac.dmg

