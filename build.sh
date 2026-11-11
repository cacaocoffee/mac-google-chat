#!/bin/bash
# ChatLamp.app을 build/ 아래에 만든다. Xcode 없이 Command Line Tools만 있으면 된다.
#
#   ./build.sh                       # 이 맥의 CPU용
#   ARCHS="arm64 x86_64" ./build.sh  # 애플 실리콘·인텔 겸용 (배포용)
#   ./build.sh zip                   # 위에 더해 build/ChatLamp.zip도 만든다
set -euo pipefail
cd "$(dirname "$0")"

ARCHS="${ARCHS:-$(uname -m)}"
APP=build/ChatLamp.app

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# compile <실행 파일 이름> <소스...>
compile() {
  local name=$1; shift
  local parts=()
  for arch in $ARCHS; do
    swiftc -O -swift-version 5 -target "$arch-apple-macos13.0" -o "build/$name-$arch" "$@"
    parts+=("build/$name-$arch")
  done
  lipo -create -output "$APP/Contents/MacOS/$name" "${parts[@]}"
  rm -f "${parts[@]}"
}

compile ChatLamp app/ChatLamp/*.swift

cp app/Info.plist "$APP/Contents/"
cp app/AppIcon.icns "$APP/Contents/Resources/"

# 인증서 없이 이 맥에서만 통하는 서명(ad-hoc). 로그인 항목 등록에 서명이 필요하다.
# 서명이 빌드마다 달라지므로, 다시 빌드하면 손쉬운 사용 권한을 다시 켜야 한다.
codesign --force --sign - "$APP"

echo "만들었습니다: $APP ($ARCHS)"

if [[ "${1:-}" == "zip" ]]; then
  rm -f build/ChatLamp.zip
  ditto -c -k --keepParent "$APP" build/ChatLamp.zip
  echo "압축했습니다: build/ChatLamp.zip"
fi
