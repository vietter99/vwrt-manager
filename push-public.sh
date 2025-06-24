#!/bin/sh

VERSION=$(cat VERSION)
TMP=/tmp/vwrt-public-push

echo "[+] Obfuscating..."
javascript-obfuscator vwrtdev.js \
  --output vwrtfinal.js \
  --compact true \
  --control-flow-flattening true

echo "[+] Tạo zip..."
zip -rq vwrt.zip vwrtfinal.js VERSION

echo "[+] Chuẩn bị thư mục đẩy public..."
rm -rf "$TMP"
mkdir -p "$TMP"
cp -r . "$TMP"

cd "$TMP"
rm -f vwrtdev.js        # Xoá file không muốn public
rm -rf .git             # Xoá git repo gốc
git init
git checkout -b main
git remote add origin https://github.com/vietter99/vwrt-manager.git
git config user.name "vietter99"
git config user.email "famkuokviet@gmail.com"
git add .
git commit -m "Push public build v$VERSION"
git push -f origin main
cd -
rm -rf "$TMP"

echo "✅ Đã push public lên: https://vietter99.github.io/vwrt-manager/"
