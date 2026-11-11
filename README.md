# ChatLamp

Google Chat에 안 읽은 메시지가 있으면 맥 메뉴 막대 아이콘이 초록색으로 바뀌고 옆에 개수가 나옵니다. 카카오톡 메뉴 막대 아이콘처럼 동작합니다.

![메뉴 막대의 ChatLamp: 초록 말풍선과 안 읽은 수 1](docs/menubar.png)

| 메뉴 막대 아이콘 | 뜻 |
| --- | --- |
| 초록 말풍선 + 숫자 | 안 읽은 메시지 있음. 숫자는 Dock의 Google Chat 아이콘에 적힌 숫자 |
| 테두리만 있는 말풍선 | 안 읽은 메시지 없음 |
| 흐린 말풍선 | Google Chat 앱이 꺼져 있거나 손쉬운 사용 권한이 없음 |

아이콘을 누르면 지금 상태, **Google Chat 열기**, **아이콘 옆에 개수 표시**, **로그인 시 열기** 메뉴가 나옵니다.

> Google과 관계없는 개인 프로젝트입니다. Google Chat은 Google LLC의 상표입니다.

## 동작 방식

Google Chat을 크롬 앱으로 설치해 쓰면, 안 읽은 메시지가 있을 때 Dock의 Google Chat 아이콘에 빨간 숫자(배지)가 달립니다. ChatLamp는 2초마다 이 숫자를 읽어 메뉴 막대 아이콘에 똑같이 표시합니다.

다른 앱의 Dock 배지를 읽는 공개 API가 macOS에 없어서, 손쉬운 사용 API로 Dock 항목에 적힌 배지 값을 읽습니다. 그래서 ChatLamp에 **손쉬운 사용 권한**이 필요합니다. ChatLamp는 Dock에서 Google Chat 아이콘의 배지 값만 읽고, 다른 앱이나 화면 내용은 읽지 않습니다.

## 준비

- macOS 13 이상
- **Google Chat을 크롬 앱으로 설치**해 두어야 합니다. 크롬에서 `chat.google.com`을 열고 주소창 오른쪽의 설치 아이콘을 눌러 앱으로 설치합니다. 크롬 탭으로만 열어 두면 Dock 배지가 없어서 ChatLamp가 읽을 것이 없습니다. Edge·Brave 같은 크롬 계열 브라우저로 설치한 앱도 됩니다.
- Dock의 Google Chat 아이콘에 빨간 숫자가 뜨는지 확인합니다. 안 뜨면 시스템 설정 → 알림 → Google Chat에서 배지 표시를 켭니다.

## 설치

Xcode Command Line Tools가 있으면 됩니다 (`xcode-select --install`).

```bash
git clone https://github.com/cacaocoffee/mac-google-chat.git
cd mac-google-chat
./build.sh
cp -R build/ChatLamp.app /Applications/
open /Applications/ChatLamp.app
```

처음 실행하면 다음 두 가지가 일어납니다.

1. **손쉬운 사용 권한 요청 창**이 뜹니다. **시스템 설정 열기**를 누르고 개인정보 보호 및 보안 → 손쉬운 사용에서 ChatLamp를 켭니다. 창을 닫았다면 메뉴 막대 아이콘 → **손쉬운 사용 권한 허용…**으로 다시 열 수 있습니다.
2. **로그인 항목에 자기를 넣습니다.** 맥을 켤 때마다 자동으로 실행됩니다. 원하지 않으면 메뉴에서 **로그인 시 열기**를 끕니다.

## 안 될 때

| 메뉴에 나오는 상태 | 할 일 |
| --- | --- |
| 손쉬운 사용 권한이 필요함 | 시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용에서 ChatLamp를 켭니다. 이미 켜져 있는데도 이렇게 나오면 목록에서 ChatLamp를 지우고(−) 앱을 다시 실행해 다시 허용합니다 |
| Google Chat이 열려 있지 않음 | Google Chat 크롬 앱을 실행합니다. 창은 가려져 있거나 최소화돼 있어도 됩니다 |
| 새 메시지가 있는지 알 수 없음 | Google Chat 앱은 실행 중인데 Dock에서 그 아이콘을 찾지 못한 경우입니다. 이슈로 알려 주세요 |
| 새 메시지 없음인데 Dock에는 숫자가 있음 | 이슈로 알려 주세요 |

직접 빌드한 앱을 **다시 빌드하면 손쉬운 사용 권한을 다시 줘야 합니다.** Apple 인증서 없이 서명해서, 빌드할 때마다 macOS가 다른 앱으로 보기 때문입니다. 위 표의 첫 줄처럼 목록에서 지우고 다시 허용하면 됩니다.

## 제거

1. 메뉴에서 **로그인 시 열기**를 끄고 **ChatLamp 종료**를 누릅니다.
2. `/Applications/ChatLamp.app`을 지웁니다.
3. 시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용 목록에서 ChatLamp를 지웁니다.

## 개발

```bash
./build.sh                          # 이 맥의 CPU용으로 build/ChatLamp.app 생성
ARCHS="arm64 x86_64" ./build.sh zip # 애플 실리콘·인텔 겸용 + build/ChatLamp.zip
swift scripts/make-icons.swift      # 앱 아이콘 다시 그리기
```

- Dock 배지 읽기: [`app/ChatLamp/DockBadgeReader.swift`](app/ChatLamp/DockBadgeReader.swift)
- 앱 기록 보기: `/usr/bin/log stream --level info --predicate 'subsystem == "io.github.cacaocoffee.chatlamp"'`

## 라이선스

[MIT](LICENSE)
