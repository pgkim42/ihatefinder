# IHateFinder

[English](README.md)

IHateFinder는 맥용 파일 관리자입니다. 경로를 직접 입력하고, 상세 목록으로 파일을 보고, 잘라두기 다음 붙여넣기로 파일을 옮깁니다.

## 빌드하고 실행하기

macOS 14 이상과 Xcode에 포함된 Swift 도구가 필요합니다.

```bash
make test
make run
```

`make test`는 독립된 임시 폴더·설정·클립보드로 파일 연산, 비동기 탐색, 세션 복원, 클립보드와 선택 동작을 검사합니다. `make run`은 `IHateFinder.app`을 만들고, 이 맥에서 실행되도록 서명한 뒤, 앱을 엽니다.

데스크탑, 문서, 다운로드를 처음 열면 맥이 접근 권한을 묻습니다. 허용해야 그 폴더가 열립니다.

## 매일 쓰는 조작

Command-L은 주소창입니다. Return은 그 경로의 폴더를 엽니다.

Command-X 다음 Command-V는 선택을 옮깁니다. Command-C 다음 Command-V는 복사합니다. 대상에 같은 이름이 있으면 바꾸기, 건너뛰기, 둘 다 유지 중에서 고릅니다. 바꾸기는 기존 항목을 휴지통으로 보냅니다.

fn+Delete 또는 Command-Delete는 선택을 휴지통으로 보냅니다. Backspace 단독은 뒤로 갑니다. 디스크에서 파일을 바로 지우는 명령은 없습니다.

Option-Return은 항목의 정보(이름, 종류, 크기, 날짜, 경로, 권한)를 보여 줍니다. 우클릭 메뉴에는 다른 앱으로 열기, 압축(`이름.zip`, 덮어쓰지 않음, 취소와 실행 취소 가능), 경로 복사, 터미널에서 열기도 있습니다. Space 또는 Command-Y는 선택 항목을 미리 봅니다(Esc로 닫음). Command-F, Control-F, F3는 현재 폴더를 이름으로 거르고 Esc로 거르기를 지웁니다. 여러 항목을 고르고 Return을 누르면 선택한 파일을 모두 엽니다(20개를 넘으면 먼저 묻습니다). 폴더 하나만 골랐으면 그 폴더로 들어갑니다.

글상자 안에서는 Command와 Control 모두 C/X/V/A/Z가 동작하고 Shift-Z는 다시 실행입니다. Control-클릭은 메뉴를 열지 않고 선택에 더하거나 뺍니다. 우클릭과 두 손가락 탭은 그대로 메뉴를 엽니다. 이름 바꾸기는 확장자를 뺀 이름만 선택합니다. 목록에 포커스가 있을 때 편집 > 실행 취소(Command-Z, Control-Z)는 마지막 파일 작업(휴지통, 이름 바꾸기, 옮기기, 복사, 새로 만들기)을 빈 자리로 옮기거나 휴지통으로 보내는 방식으로만 되돌립니다. 그 사이 바뀐 항목은 건너뛰고 알려 줍니다.

같은 디스크 안에서 끌면 옮기고, 다른 디스크로 끌면 복사합니다. Option은 항상 복사, Command는 항상 이동입니다.

Command-Shift-N은 새 폴더입니다. Command-Option-N은 빈 텍스트 파일입니다. 기본 이름은 `새 폴더`와 `새 텍스트 문서.txt`입니다.

**양쪽 창**을 누르면 목록이 하나 더 나옵니다. 목록을 클릭하면 그 목록이 키보드의 대상이 됩니다. F5는 선택을 반대 목록으로 복사합니다. F6는 옮깁니다.

Finder와 시스템 클립보드로 파일 복사를 주고받습니다. Esc는 잘라두기의 이동 의도만 해제하고 일반 복사로 남깁니다. 이전 이동 작업이 끝나도 새로 복사한 클립보드는 지우지 않습니다.

전송 중 현재 파일, 처리 항목 수와 가능한 구간의 전송 바이트를 보여줍니다. **취소**는 큰 파일을 복사하는 도중에도 작동하며 이미 완료한 항목은 유지합니다. 일부만 처리되면 건너뜀·실패·취소·미처리와 필요한 복구 위치를 결과 창에 표시합니다.

폴더는 백그라운드에서 읽고, 외부 변경을 목록에 반영하면서 선택한 파일을 유지합니다. 다시 실행하면 좌우 경로·정렬·숨김 표시·양쪽 창 상태를 복원합니다. 저장된 폴더에 접근할 수 없으면 이유를 표시하고 홈, 임시 폴더 순서로 대체합니다.

## 기본 파일 뷰어로 쓰기

선택 사항입니다. 시스템 전체 설정을 바꾸므로 아래 명령은 직접 실행해야 하고, 앱은 설정을 바꾸지 않습니다. 되돌리는 명령도 아래에 있습니다.

준비: `make build`로 `IHateFinder.app`을 만들고 `/Applications`에 복사한 뒤 한 번 실행합니다.

설정(터미널에서 실행한 다음 로그아웃 후 다시 로그인하거나 재시동합니다):

```bash
defaults write -g NSFileViewer -string study.ihatefinder
defaults write com.apple.LaunchServices/com.apple.launchservices.secure LSHandlers -array-add '{LSHandlerContentType="public.folder";LSHandlerRoleAll="study.ihatefinder";}'
```

그러면 다른 앱의 "Finder에서 보기"와 폴더 열기 요청이 이 앱으로 옵니다. 폴더는 포커스 창에서 열리고, 파일은 그 파일이 든 폴더가 열리면서 파일이 선택됩니다.

되돌리기(그 다음 로그아웃 후 다시 로그인하거나 재시동하면 다시 Finder가 뷰어입니다):

```bash
defaults delete -g NSFileViewer
/usr/libexec/PlistBuddy -c "Print :LSHandlers" ~/Library/Preferences/com.apple.LaunchServices/com.apple.launchservices.secure.plist
/usr/libexec/PlistBuddy -c "Delete :LSHandlers:<index>" ~/Library/Preferences/com.apple.LaunchServices/com.apple.launchservices.secure.plist
```

두 번째 명령으로 `LSHandlerContentType`이 `public.folder`이고 `LSHandlerRoleAll`이 `study.ihatefinder`인 항목을 찾아, 세 번째 명령의 `<index>` 자리에 그 번호를 넣습니다.

한계: 열기/저장 창, 데스크탑, Dock의 Finder 아이콘, Finder를 직접 호출하는 앱은 계속 Finder를 씁니다.

## 이 버전에 없는 것

탭, 아이콘 보기, 열 보기, 하위 폴더까지 찾기, 파일 작업 다시 실행은 아직 없습니다.

## 오른쪽 목록 확인

저장소 루트에서 다음을 실행합니다.

```bash
swift build && .build/debug/IHateFinder --repro-focus
```

프로세스는 `copied=right-only.txt`, `pasteDest=right`, `backspace=goBack`, `forwardDelete=trash`를 출력하고 종료합니다. 오른쪽 목록에 키보드 포커스를 준 뒤 복사 원본과 붙여넣기·Delete·F6의 대상 상태를 확인하며, 실제 삭제·이동은 실행하지 않습니다. 독립된 클립보드를 쓰고 임시 탐색 세션을 저장하지 않습니다.
