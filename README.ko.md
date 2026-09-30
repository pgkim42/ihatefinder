# IHateFinder

[English](README.md)

IHateFinder는 맥용 파일 관리자입니다. 경로를 직접 입력하고, 상세 목록으로 파일을 보고, 잘라두기 다음 붙여넣기로 파일을 옮깁니다.

## 빌드하고 실행하기

macOS 14 이상과 Xcode에 포함된 Swift 도구가 필요합니다.

```bash
make test
make run
```

`make test`는 파일 연산을 임시 폴더에서 검사합니다. `make run`은 `IHateFinder.app`을 만들고, 이 맥에서 실행되도록 서명한 뒤, 앱을 엽니다.

데스크탑, 문서, 다운로드를 처음 열면 맥이 접근 권한을 묻습니다. 허용해야 그 폴더가 열립니다.

## 매일 쓰는 조작

Command-L은 주소창입니다. Return은 그 경로의 폴더를 엽니다.

Command-X 다음 Command-V는 선택을 옮깁니다. Command-C 다음 Command-V는 복사합니다. 대상에 같은 이름이 있으면 바꾸기, 건너뛰기, 둘 다 유지 중에서 고릅니다. 바꾸기는 기존 항목을 휴지통으로 보냅니다.

Delete는 선택을 휴지통으로 보냅니다. 디스크에서 파일을 바로 지우는 명령은 없습니다.

Command-Shift-N은 새 폴더입니다. Command-Option-N은 빈 텍스트 파일입니다. 기본 이름은 `새 폴더`와 `새 텍스트 문서.txt`입니다.

**양쪽 창**을 누르면 목록이 하나 더 나옵니다. 목록을 클릭하면 그 목록이 키보드의 대상이 됩니다. F5는 선택을 반대 목록으로 복사합니다. F6는 옮깁니다.

## 이 버전에 없는 것

탭, 아이콘 보기, 열 보기, 폴더 검색, 스페이스 미리보기, 실행 취소는 아직 없습니다.

## 오른쪽 목록 확인

저장소 루트에서 다음을 실행합니다.

```bash
swift build && .build/debug/IHateFinder --repro-focus
```

프로세스는 `copied=right-only.txt`와 `pasteDest=right`를 출력하고 종료합니다. 이 출력은 오른쪽 목록을 눌렀을 때 복사, 붙여넣기, Delete, F6가 오른쪽 목록을 쓴다는 뜻입니다.
