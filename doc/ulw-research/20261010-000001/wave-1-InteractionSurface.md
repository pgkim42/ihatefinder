# InteractionSurface 조사 보고서

## 결론과 조사 경계

현재 구현은 단순한 파일 목록 껍데기가 아니다. 상세 목록, 정렬, 다중 선택, 글상자/파일 작업의 키 분리, Quick Look, 현재 폴더 거르기, 파일 작업 상태와 취소, 우클릭 명령을 갖췄다. 이 축에서 가장 설득력 있는 결핍은 기능의 절대 개수보다 **이미 있는 핵심 조작을 화면에서 발견하고, 어떤 창·선택·상태에 적용되는지 확신하는 연결**이다. 반대쪽 복사/이동은 F5/F6에만 노출되고, Quick Look은 키에만 노출되며, 현재 폴더 거르기는 메뉴에서 ‘찾기’라고 표시된다. 모두 소스에서 확인되는 표면 설계다. 이것이 실제 사용자에게 불편한 정도와 실제 GUI의 가독성은 리드의 앱 관측과 사용자 작업 사례를 거쳐야 한다.

관측 시점(observed_at): 2026-10-10. 유효 범위(valid_at): 현재 main, HEAD 0970c61b2db1f8a1169a82d6a5bf959a89fe6a57. `.git/HEAD:1`은 `ref: refs/heads/main`, `.git/refs/heads/main:1`은 위 해시다. 코드·테스트·문서를 읽었고 앱 실행, 제품 테스트, 빌드, 수정은 하지 않았다. 리드가 전한 ‘루트 테스트 240개 통과’는 별도 실행 관측이며 이 보고서의 자체 검증 결과가 아니다. LSP는 `read xd://lsp`에 ‘No such tool’이 반환되어 사용하지 못했다. 쉘/git 실행 도구도 이 자식의 마운트 목록에 없어 git 이력은 reflog만 확인했다. 실제 commit diff/blame까지 확인했다고 주장하지 않는다.

관측 그룹과 독립성: IS-CODE는 제품 소스의 직접 관측, IS-TEST는 테스트 계약을 읽은 관측(실행 아님), IS-DOC는 같은 저장소 문서의 의도, IS-APPLE은 외부 공식 문서, IS-INFER는 앞의 코드에서 도출한 사용자 결과 추론이다. 같은 저장소의 코드/테스트/README는 독립된 사용자 증거가 아니다. Apple 출처는 독립된 플랫폼 기준이지만 이 앱 사용자의 요구 빈도 증거는 아니다. 아래 우선순위는 빈도 실측이 아니라 작업 마찰·오조작 가능성·구현 범위를 고려한 판단이다.

## 구현된 표면: 누락으로 오진하면 안 되는 것

### 목록과 선택

- `Sources/IHateFinder/FilePaneController.swift:84-110`: `allowsMultipleSelection = true`, `allowsEmptySelection = true`, `headerView = NSTableHeaderView()`, 각 열의 `sortDescriptorPrototype` 설정. 네이티브 상세 목록과 다중 선택·헤더 정렬은 구현됐다. `FilePaneController.swift:845-850`에는 이름 280, 수정한 날짜 160, 종류 120, 크기 90의 네 열이 있다. `FilePaneController.swift:534-561`은 파일 아이콘, 날짜/종류/크기, 폴더 크기 ‘—’ 및 잘라둔 항목의 `cell.alphaValue = cut ? 0.4 : 1`을 그린다. 그룹 IS-CODE, 직접 관측.
- `FilePaneController.swift:162-196`: 갱신 전 `Set(selectedURLs())`를 보존하고 같은 디렉터리에서 URL이 같은 행만 다시 선택한다. 다른 폴더 이동 시 이전 행 번호를 새 파일에 적용하지 않는다. `Tests/IHateFinderTests/FilePaneControllerTests.swift:8-53`의 테스트는 행 밀림에도 선택 유지, 삭제 시 해제, 다른 폴더로 선택 미이월을 계약으로 둔다. 그룹 IS-CODE/IS-TEST, 서로 보강하지만 독립 사용자 관측 아님.
- `FilePaneController.swift:208-223`: 새 항목이 거르기에 가리면 거르기를 지우고 그 항목을 선택·스크롤·선택적 이름 편집한다. `FilePaneController.swift:273-278`은 위로 이동한 뒤 나온 폴더를 다시 선택하려 한다. 파일 만들기 이후 잃어버리는 UI만 있다고 일반화할 수 없다.
- `FileTableView.swift:8-11`: `becomeFirstResponder()`가 성공하면 `pane?.claimFocus()` 호출. `FilePaneController.swift:264-265`, `BrowserWindowController.swift:116-121`을 통해 작업 대상 창을 바꾼다. 목록 클릭 포커스가 전혀 관리되지 않는다는 주장은 틀리다.

### 키보드와 이름 편집

- `Sources/IHateFinder/KeyCommands.swift:41-68`: Cmd/Ctrl-L, Cmd/Ctrl-F, F3를 처리하고, `textIsResponder`일 때 Ctrl-C/X/V/A는 글상자 액션으로 보낸다. `FileTableView.swift:72-104`는 이름 편집 중 undo/redo를 테이블이 가로채지 않으며, 목록의 실행 취소 메뉴 제목을 `실행 취소 \(record.title)`로 바꾸고 실행 가능 상태를 검증한다. `Tests/IHateFinderTests/RenameUndoRoutingTests.swift:34-96`은 이 responder-chain 계약을 읽을 수 있다. 파일 undo와 글자 undo는 이미 분리돼 있다.
- `KeyCommands.swift:94-105`: 일반 Backspace는 뒤로, Cmd-Backspace 및 forward-delete는 휴지통, Return은 열기, Option-Return은 정보다. 텍스트 편집일 때 먼저 반환하는 경로가 있어 텍스트 Delete가 파일 휴지통으로 곧장 가는 구현이라고 할 수 없다. `Tests/IHateFinderTests/KeyCommandTests.swift:13-36`이 해당 구분을 계약으로 둔다.
- `FilePaneController.swift:418-431`: 이름 편집 시 `RenameSelection.range(...)`로 확장자를 제외한 이름 범위를 선택한다. `FileTableView.swift:34-56`은 이미 선택한 행의 단일 클릭 뒤 0.7초 지연 편집을 구현한다. `Tests/IHateFinderTests/FileTableViewTests.swift:94-123`은 실제 field editor의 파일/폴더/dotfile 선택 범위를 검사하도록 작성돼 있다. 느린 클릭과 F2, 메뉴 이름 바꾸기 경로가 존재한다.
- `AppDelegate.swift:84-113`: 파일·편집·이동·보기·창 메뉴와 macOS Command 단축키가 있다. Windows식 Ctrl/F키만 있고 macOS 키를 지원하지 않는다는 주장은 틀리다.

### 상태, 거르기, 미리보기

- `FilePaneController.swift:244-261`: 불러오는 중/실패 경로/복원 안내/항목 수/거르기 전후 개수/선택 개수/파일 크기 합이 표시된다. `FilePaneController.swift:164-168,194-195`는 실패를 빨강으로, 상태 전체를 tooltip으로 설정한다. 빈 목록도 `0개 항목`, 거르기 결과 없음도 `N개 중 0개 표시`라는 신호가 있다.
- `FilePaneController.swift:322-371,482-495`: 숨겨진 거르기 칸을 열고 입력에 따라 현재 `session.entries`만 거르며, Enter는 목록으로, Esc는 칸을 지우고 목록으로 보낸다. 현재 폴더 거르기는 구현됐지만 재귀/Spotlight 검색은 아니다. `Tests/IHateFinderTests/PreviewAndFilterTests.swift:157-242`의 계약은 가려진 선택 제거, Esc 복원, 이동 시 거르기 해제, 외부 reload에서 유지, 새 항목 드러내기를 포함한다.
- `FilePaneController.swift:376-415`, `FileTableView.swift:108-147`: 실제 Quartz `QLPreviewPanel`의 선택 기반 data source/delegate, Space/Cmd-Y 토글, 목록 이동에 따른 reload, source-frame 연결이 있다. `BrowserWindowController.swift:118-119`는 창 포커스 변경 시 QL controller도 갱신한다. Quick Look 없음은 명백한 오진이다. `PreviewAndFilterTests.swift:55-109`는 키 판별·행순서 data source·Esc 위임·아래 화살표의 목록 이동·이름 편집 Space를 계약으로 둔다.
- `BrowserWindowController.swift:352-373,407-435`: 복사/이동/압축에 progress bar와 취소, 전송 단계/항목 수/파일명/조건부 byte 진척이 있다. `BrowserWindowController.swift:437-472`: 완료·건너뜀·실패·취소·미처리와 경로/복구 위치를 선택 가능한 스크롤 텍스트 sheet로 보여준다. 작업 상태와 결과 UI가 아예 없다고 해석할 수 없다.
- `FilePaneController.swift:758-799,670-692`: 우클릭 메뉴와 선택별 enablement, 다른 앱으로 열기, 새 폴더·텍스트 파일, cut/copy/paste, rename/trash/compress/path/info/terminal이 있다. `InfoPanel.swift:21-65`에는 비동기 읽기, 선택 가능한 정보 sheet가 있다. 미리보기와 정보 UI는 존재하지만 둘의 역할은 다르다.

## CLAIMS: 최종 답변에 채택 가능한 후보

### IS-C1. 양쪽 창의 핵심 가치가 앱 표면에서 덜 드러난다 — 제한, 개선 판단 P1

근거(IS-CODE): `BrowserWindowController.swift:532-544`에 toolbar 역할의 `NSStackView`가 있고 ‘뒤로/앞으로/위/양쪽 창’ 네 버튼만 추가한다. `KeyCommands.swift:88-89`에 F5→copyToOther, F6→moveToOther가 있지만 `AppDelegate.swift:84-113`의 전체 앱 메뉴와 `FilePaneController.swift:758-799`의 전체 컨텍스트 메뉴에는 반대쪽으로 복사/이동 명령이 없다. `BrowserWindowController.swift:689-702`는 실제 반대쪽 전송을 구현하며 단일 창이면 `guard dual else { return }`로 종료한다. README에는 `README.ko.md:63-64` ‘F5 ... 반대쪽 목록으로 복사’, ‘F6 ... 옮깁니다’가 설명된다(IS-DOC).

결과(IS-INFER): 문서를 모르는 사람은 양쪽 창을 켜도 두 목록을 보는 용도만 발견하고 전송 가치는 알기 어렵다. 이 사용자에게 익숙한 F키가 있어도 메뉴/버튼으로 경로를 보이고 목적지·키를 같이 제시하면 기억 부담을 줄일 수 있다. 우선 전체 toolbar 커스터마이즈보다 ‘반대쪽으로 복사/이동’의 명시적 명령과 단일 창/무선택 disablement가 작은 범위로 효과를 낸다.

반증: F5/F6와 드래그/클립보드는 이미 동작 경로가 있으며 사용자가 Windows식 탐색기를 선호한다는 `CONTEXT.md:3`의 제품 의도와 맞는다. 따라서 ‘전송 기능 부재’도 ‘무조건 macOS 방식으로 바꿔야 한다’도 아니다. 빈도는 미측정.

### IS-C2. 현재 폴더 거르기의 메뉴 이름이 기능 범위를 과장한다 — 제한, 판단 P1

근거(IS-CODE): `AppDelegate.swift:98`의 인용은 `item("찾기", ...findInFolder, "f", .command)`, 실제 `FilePaneController.swift:123`의 placeholder는 ‘이 폴더에서 이름 거르기’, `FilePaneController.swift:365`는 `EntryFilter.filter(session.entries, query: ...)`다. `CONTEXT.md:63-65`는 ‘거르기 ... 하위 폴더는 보지 않는다. Avoid: 검색, 필터’라는 용어 의도를 갖는다(IS-DOC).

결과(IS-INFER): macOS Cmd-F 경험으로 파일 위치를 찾으려는 기대와 현재 폴더에서 행을 줄이는 실행이 다르다. 새 검색 엔진 이전에 메뉴/버튼을 ‘이 폴더에서 이름 거르기’로 맞추고 현재 범위를 지속 표시하면 이미 구현된 기능의 기대 불일치를 줄일 수 있다. 재귀 검색의 필요/순서는 A1과 합쳐 판단해야 한다.

반증: 열린 거르기 칸 placeholder, `N개 중 M개 표시` 상태와 README는 범위를 이미 설명한다. 따라서 모든 사용자가 검색으로 오인했다고 단언할 수 없다.

### IS-C3. macOS와 Windows식 규칙이 공존하며 일부는 직접 충돌한다 — 구현된 선택 정책, 판단 P1/P2

근거(IS-CODE): `FileTableView.swift:16-22,34-39`는 Ctrl-left-click을 선택 toggle로 소비하고 메뉴를 반환하지 않는다. `FileTableViewTests.swift:54-87`은 이 정책을 명시적으로 검사하도록 작성됐다. Apple의 [Right-click on Mac](https://support.apple.com/guide/mac-help/right-click-mh35853/26/mac/26)은 ‘To open shortcut menus, Control-click an item’이라고 설명한다(IS-APPLE, observed_at 2026-10-10, valid_at macOS Tahoe 26 공식 문서).

결과(IS-INFER): Ctrl-click으로 메뉴를 여는 macOS 근육 기억은 이 앱에서 선택 변경을 만든다. F2 이름 편집/Return 열기 자체는 Windows 지향 사용자에게 이점이지만 메뉴를 못 여는 충돌은 별도 문제다. 사용자의 Windows식 preference를 보존하면서 macOS 기본 Ctrl-click을 유지할지, 명시적 선택 모드/설정을 둘지 결정할 후보다. 이미 Cmd-click 추가 선택이 있으므로 Ctrl-click override의 추가 가치와 macOS 메뉴 손실을 비교해야 한다.

반증: 우클릭과 두 손가락 tap 메뉴는 유지되고 README도 차이를 적는다. 이 사용자가 Ctrl-click toggle을 원했다면 의도된 차이이며 일반 사용자 전체의 실패로 확대하지 않는다.

### IS-C4. 기본 명령이 존재해도 visible entry가 균등하지 않다 — 제한, 판단 P2

근거(IS-CODE): toolbar 네 버튼만 있는 `BrowserWindowController.swift:532-544`, Quick Look 키 전용 경로 `FileTableView.swift:108-136`, 앱 메뉴에 Quick Look가 없는 `AppDelegate.swift:84-113`, 컨텍스트 메뉴에도 없는 `FilePaneController.swift:758-799`. 이름 바꾸기 메뉴는 `AppDelegate.swift:97`에 있지만 keyEquivalent가 빈 문자열이라 F2가 메뉴에 보이지 않는다. toolbar 생성은 `BrowserWindowController.swift:749-756`의 `imageOnly`, tooltip, SF Symbol accessibilityDescription을 쓴다.

결과(IS-INFER): 실제 지원되는 미리보기/거르기/새로 만들기/양쪽 전송을 익히려면 키 설명을 외부 README에서 읽어야 하는 부분이 많다. 메뉴 명령과 키 표시, 필요한 곳의 몇 개 visible action부터 늘리는 것이 ‘예쁘게 다시 그리기’보다 구체적이다. Apple [Customize toolbar](https://support.apple.com/guide/mac-help/customize-the-finder-toolbar-on-mac-mchlp3011/26/mac/26)의 ‘choose whether to show text with the icons’는 발견 가능성을 조절하는 공식 수단의 예이며, 이를 그대로 전부 복제할 의무는 없다.

반증: macOS 사용자에게 Space/Cmd-Y는 익숙하고, 아이콘 tooltip 및 accessibilityDescription도 이미 있다. ‘버튼 무라벨=접근 불가’는 소스로 입증하지 못한다. 실제 VoiceOver/AX 관측은 필요하다.

### IS-C5. 미리보기는 구현됐지만 시각 파일 판별 표면은 상세 목록 중심이다 — 제한, 조건부 P2

근거(IS-CODE): `FilePaneController.swift:845-850`의 네 고정 열, `FilePaneController.swift:534-561`의 파일 icon/텍스트 cell, `AppDelegate.swift:104-107`의 보기 메뉴는 숨김/양쪽 창뿐이다. 읽은 UI 구현 전체에는 icon/gallery/column view, 상시 내용 preview pane, 열 표시/숨김 메뉴가 없다. literal `thumbnail/grid/gallery/NSToolbar/preview` 검색과 전체 pane/window/menu 구성 대조로 범위를 확인했다.

독립 기준(IS-APPLE): [Change how folders are displayed](https://support.apple.com/guide/mac-help/change-folders-displayed-finder-mac-mchldaafb302/26/mac/26)는 ‘Icon, List, Column, or Gallery’, list header Control-click으로 열 show/hide를 설명한다. [Use the Preview pane](https://support.apple.com/guide/mac-help/use-the-preview-pane-in-the-finder-on-mac-mchl1e4644c2/26/mac/26)는 ‘small view of what a document contains or an image looks like’와 metadata/Quick Actions를 설명한다. 모두 observed_at 2026-10-10, valid_at Tahoe 26 문서.

결과(IS-INFER): 이름을 알고 파일을 옮기는 작업에는 현재 목록이 적합하다. 비슷한 이미지/PDF/영상 중 내용을 보고 고르는 작업에는 별도 Quick Look를 여는 단계가 추가된다. 실제 사용자가 해당 작업을 반복한다면 전체 네 view보다 작은 상시 미리보기/thumbnail 선택부터 검토할 수 있다.

반증: `CONTEXT.md:3,19-20`은 상세 목록을 제품 기준으로 삼고 Quick Look도 이미 해결 수단이다. ‘Finder 4가지 view가 없으므로 0.3 미달’은 근거가 약하다. 시각 중심 작업의 빈도를 확인하기 전에는 조건부 개선이다.

### IS-C6. 상태는 풍부하지만 표현의 의미/지속성과 행·창 상태의 통일이 남아 있다 — 제한, 판단 P2

근거(IS-CODE): `FilePaneController.swift:258-261`의 인용 `entry.isDirectory ? partial : partial + entry.size` 뒤 결과 문자열은 ‘선택 N개, X바이트’다. 폴더만 선택해도 계산은 0이므로 ‘선택 파일 합계(폴더 제외)’라는 범위가 UI 문구에 없다. 문서 `docs/behavior.md:28`은 의도적으로 폴더를 제외한다고 설명한다(IS-DOC). `BrowserWindowController.swift:437-438`은 완전 성공 작업에 결과 sheet를 내지 않는다. `updateStatus`의 평시 값은 `focused.summary()`이며 작업 완료 후 상태는 목록 요약으로 돌아간다.

결과(IS-INFER): 선택 폴더의 실제 용량이 0이라는 인상, 성공/이동 목적지의 확인 신호가 빨리 사라지는 인상이 생길 수 있다. 이를 폴더 크기 재귀 계산 추가 요구로 연결하기보다 계산 범위 명시 및 짧은 명시적 완료 요약으로 먼저 줄일 수 있다.

반증: 문서에 계산 정책이 명시되고 표의 폴더 크기는 ‘—’이며, 성공 뒤 목록 갱신/잘라두기 소진/새 항목 선택도 피드백이다. 성공 sheet를 매번 띄우는 것이 더 좋은 UI라는 근거도 없다.

## 추가 직접 관측과 구현 추론

- 토글 및 navigation 상태: `BrowserWindowController.swift:504-520`의 숨김/양쪽 창 토글은 내부 bool/session을 변경한다. toolbar 생성 `749-756`은 `.state`나 `isEnabled`를 갱신하지 않고 앱 보기 메뉴 `AppDelegate.swift:104-107`도 checked 상태를 설정하지 않는다. 코드 전체 literal `.state =`, `isEnabled`, `validateMenuItem` 검색에서 undo 및 컨텍스트 일부/취소 버튼 외의 상태 연결이 발견되지 않았다. **관측**은 명시적 상태 바인딩 부재이며, **추론**은 뒤로/앞으로가 이력 끝에서도 누를 수 있어 무반응처럼 보이거나 숨김 상태를 메뉴에서 읽기 어렵다는 것이다. 실제 AppKit의 표현은 리드 화면 관측이 필요하다.
- 좁은 양쪽 창: 기본 창 `BrowserWindowController.swift:62`은 1120×720, 최소 `:68`은 800×480, sidebar 기본 200(`:643-645`), 양 pane 최소 260(`:571-573`)이다. 네 열 기본 폭은 합계 650이며 pane 내부 여백 24도 있다. `FilePaneController.swift:114-116`에는 가로 스크롤러가 있으므로 **‘겹침/잘림 버그’가 아니라 좁은 pane에서 가로 스크롤이 자주 필요할 가능성**이라는 시각 추론만 가능하다. 이름 열 자동 크기 조정과 가로 스크롤이 반증이다. 최소/기본/넓은 창에서 실제 가독성을 확인해야 한다.
- 열/보기 지속성: `WorkspaceStore.swift:4-8,19,45-48`은 path/sortColumn/ascending/includeHidden 및 left/right/dual만 저장한다. 열 너비·scroll·selection·divider·focused pane 저장을 이 타입은 하지 않는다. 저장된 위치·정렬 복원이 이미 있으므로 ‘세션 복원 없음’은 아니다. 열 너비/보이는 열/초점 복원 요구는 A5와 중복 후보다.
- sidebar highlight: `BrowserWindowController.swift:766-770`은 클릭 위치로 navigate하며, 읽은 `updateStatus`/pane navigation 경로에는 현재 URL에 맞춰 sidebar selection을 동기화하는 코드가 없다. 수동 경로/뒤로/다른 pane 클릭 뒤 sidebar highlight 의미가 현재 폴더와 일치하는지 리드 관측 후보. AppKit selection은 기본적으로 클릭 상태이고 breadcrumb가 아니라는 반론을 유지해야 한다.

## 구현 오류로 단정하지 않은 고가치 관측 후보

1. **작업 중 포커스 테두리 갱신**. `BrowserWindowController.swift:107-113`은 `guard !busy else { return }`를 status만이 아니라 `setFocusedLook`보다 먼저 실행한다. `:116-121`은 busy 중에도 `focused = pane`를 바꿀 수 있다. `FilePaneController.swift:226-236`은 active pane을 1px accent border로 표시한다. 코드 추론상 파일 작업 중 다른 pane을 클릭하면 내부 대상은 바뀌어도 테두리는 이전 대상에 남을 가능성이 있다. P1 관측 리드: 격리 파일로 충분히 관측 가능한 전송/압축 중 반대 pane 클릭 후 테두리/창 제목/초점/키 대상을 비교. 이 자식은 실제 실패를 보지 않았다.
2. **양쪽 창의 우클릭 대상과 copy/cut/paste 대상**. `FilePaneController.swift:660-667`은 clickedRow를 선택하지만 `claimFocus`/`browser.focus`를 직접 호출하지 않는다. 메뉴 `:776-795`의 pane-local actions는 해당 pane을 target으로 잡고 cut/copy/paste는 responder-chain BrowserWindowController의 `focused`를 사용한다(`BrowserWindowController.swift:481-498`). `FileTableView.swift`에는 rightMouseDown override가 없다. AppKit이 우클릭 시 first responder를 어떻게 바꾸는지가 결정하므로 잘못된 pane 복사라고 단정 불가. P1 관측 리드: 왼쪽 focus/selection 유지, 오른쪽 다른 파일 우클릭→복사/경로 복사 비교, paste 대상과 menu action 일관성 관측. 현재 context tests는 왼쪽 pane의 직접 호출 중심이고 이 상호작용을 증명하지 않는다.
3. **Esc의 cut와 filter 우선순위**. `KeyCommands.swift:91`은 Esc를 `.clearCut`, `BrowserWindowController.swift:682`은 `return clearCut()`, `:709-712`는 cut 존재 시 true로 consume한다. filter Esc는 `FileTableView.swift:127` 또는 `FilePaneController.swift:484-486`에 후순위로 있다. 코드 추론상 cut+filter 동시 상태에서 첫 Esc가 filter를 닫지 않고 cut만 취소할 수 있다. 개별 기능 테스트는 두 상태 동시 조합이 아니다. P1 관측 리드: cut→filter 열기→Esc를 field/list 양쪽에서 비교. 문서 `docs/behavior.md:52,58`의 각각의 Esc 설명을 하나의 일관된 규칙으로 재정의할 후보다.
4. **Quick Look의 모든 non-Esc 키 위임**. `FilePaneController.swift:398-401`은 non-Esc keyDown을 모두 `table.keyDown`으로 보내 true 반환한다. Apple [Quick Look Tahoe 26](https://support.apple.com/guide/mac-help/preview-a-file-mh14119/26/mac/26)은 Cmd-Plus/Minus zoom, Left/Right 다중 선택 순회, Cmd-Return index sheet를 명시한다. 구현은 Space/Up/Down 목록 제어를 편하게 하지만 native QL 키를 가로챌 가능성이 있다. P1/P2 관측 리드: 이미지 zoom, 다중 선택 좌우/Index Sheet, Cmd-F/Ctrl-C/Return 등을 QL key window에서 관측. `BrowserWindowController.swift:647-649`는 이벤트 window가 browser와 다르면 local monitor를 통과시키므로 browser/QL 동일 단축키 계약도 실제 이벤트 경로 대조가 필요하다. native panel 버튼과 컨트롤이 제공하는 능력은 소스만으로 부재 처리하면 안 된다.
5. **키 입력 선택과 느린 rename의 경합**. `FileTableView.swift:49-55`의 0.7초 callback은 generation/selectedRow/firstResponder를 검사하나 table keyDown에서 renameGeneration을 늘리지는 않는다. 그 사이 선택을 바꾸지 않는 키 입력·preview 전환 때 늦은 이름 편집이 생기는지 관측할 후보다. double click/drag/navigation/revision 변경에서는 취소되는 명시적 방어가 있어 현재 결함으로 단정하지 않는다.

## 우선순위 제안

P1은 기능 추가보다 현재 대상·현재 범위·명령 경로를 명시하는 단계다. 위 관측 후보에서 실제 문제가 확인되는 포커스/우클릭/Esc/QL 이벤트 경로를 먼저 정리하고, 양쪽 전송·미리보기·거르기를 명시적 메뉴/작은 visible action으로 연결한다. 현재 폴더 거르기를 ‘찾기’라고 부르는 label도 맞춘다. 이 판단은 잦은 조작에서 추가 탐색/기억/오대상 가능성을 줄이는 범위가 작다는 이유이며 사용 빈도 실측 결과가 아니다.

P2는 피드백 일관성이다. navigation disablement, 숨김/양쪽 창 토글 상태, 선택 크기 합의 계산 범위, 성공 작업의 가벼운 완료 요약, 좁은 양쪽 창의 열 가독성을 관측에 맞춰 개선한다. Quick Look가 충분하지 않은 시각 파일 판별 작업이 실제 핵심이라면 상시 preview/thumbnail 하나를 검토한다.

P3는 icon/gallery/column 모든 view, toolbar 완전 커스터마이즈, 모든 Finder 메타데이터/Quick Actions 복제다. 공식 Finder는 제공하지만 이 사용자의 Windows식 상세 목록+이동 작업과 직접 연결되는 근거가 없다. 우선순위를 기능 수로 정하지 않는다.

## 이력과 검증 한계

`.git/logs/HEAD:13`은 `merge origin/cursor/modernize-macos-ui-bb03: Fast-forward`로 현재 HEAD 진입을 기록하고 `:6`은 ‘Improve file operation safety and desktop integration’을 기록한다. 이는 UI modernization이 현재 브랜치에 병합된 이력이며 특정 기능을 어느 commit이 추가했는지, 어떤 문제가 고쳐졌는지는 증명하지 않는다. 이전 버전 기준으로 ‘UI가 예전 그대로’라는 주장을 피하는 정도의 근거다. diff/blame 검증은 리드 git 도구로 보완 가능하다.

기존 테스트에는 polling + Task.sleep을 쓰는 fixture가 있다(`PreviewAndFilterTests.swift:37-40`, `FileTableViewTests.swift:35-38` 등). 이 보고서는 테스트 신뢰도 전반을 평가하지 않았고 테스트 코드를 바꾸지 않았다. 테스트 작성 의도는 UI 시각 가독성·접근성·실제 파일 공급자 상태나 실제 native Quick Look의 모든 키 동작을 증명하지 않는다.

Apple 기본 `/mac` 응답이 미래 macOS 27 표기를 반환하는 것을 직접 읽었고, 최종 기준 출처는 모두 `/26/mac/26`로 다시 fetch하여 Tahoe 26 선택을 확인했다. 외부 사실은 위 pinned URL만 기준으로 삼았다.

## EXPAND

- LEAD IS-E1 → 리드 실제 GUI QA / A2: busy 중 반대 pane 클릭 시 focus border/창 제목/동작 대상 불일치 여부. anchors `BrowserWindowController.swift:107-121`, `FilePaneController.swift:226-236`. 코드 추론을 런타임 관측으로 닫아야 하며 현재 실패 판정 금지.
- LEAD IS-E2 → 리드 GUI QA: 비포커스 pane 우클릭 copy/cut/paste와 pane-local path/info 액션의 대상 일치. anchors `FilePaneController.swift:660-692,776-795`, `BrowserWindowController.swift:481-498`. AppKit responder 전환 확인이 필요하다.
- LEAD IS-E3 → 리드 GUI QA / A1+A2: cut+filter 동시 상태에서 첫 Esc 효과와 기대 규칙. anchors `KeyCommands.swift:91`, `BrowserWindowController.swift:682,709-712`, `FileTableView.swift:127`, `FilePaneController.swift:484-486`. 현재 각 개별 기능이 구현됐다는 점을 보존하면서 조합을 검사.
- LEAD IS-E4 → 리드 GUI QA: QL Cmd-+/-, Left/Right 다중 선택 순회, Cmd-Return index sheet 및 browser shortcut 연속성. anchors `FilePaneController.swift:398-401`, `BrowserWindowController.swift:647-659`, 공식 https://support.apple.com/guide/mac-help/preview-a-file-mh14119/26/mac/26 . native panel의 키와 이 앱 list forwarding 경합을 분리.
- LEAD IS-E5 → 리드 screenshot/AX: 기본 1120, 최소 800, 넓은 창의 양쪽 목록, 긴 경로/긴 이름/긴 오류, progress footer 가독성. anchors `BrowserWindowController.swift:62,68,571-573,595-626`, `FilePaneController.swift:845-850`. 가로 스크롤은 구현돼 있으므로 clipping bug라 선결론하지 않는다.
- LEAD IS-E6 → 리드 AX/keyboard: toolbar SF Symbol accessibilityDescription이 실제 버튼 AXLabel로 전달되는지, path/filter labels, Tab/Shift-Tab의 양쪽 목록 이동. anchors `BrowserWindowController.swift:749-756`, `FilePaneController.swift:72-82,123-129`, `FileTableView.swift:8-11`. 명시적 custom accessibility/nextKeyView 부재는 네이티브 접근성 부재 증거가 아니다.
- LEAD IS-E7 → A5: 열 너비/divider/focused pane/scroll의 복원 필요성 및 sidebar highlight 동기화 의미. anchors `WorkspaceStore.swift:4-8,45-48`, `BrowserWindowController.swift:766-770,107-113`. path/sort/hidden/dual 복원은 이미 구현돼 있으므로 세션 부재 주장으로 전환 금지.
- LEAD IS-E8 → 리드 GUI QA: 선택 후 느린 rename 타이머 중 키/미리보기 전환에 편집이 뒤늦게 시작되는지. anchors `FileTableView.swift:34-56,122-128,154-156`. cancellation 방어가 있으므로 재현 안 되면 DEAD END으로 폐쇄.
- LEAD IS-E9 → 리드 git 수단: UI modernization commit diff/blame로 toolbar/상태/선택 동작 도입·변경의 실제 이력 확인. 이 자식은 reflog만 읽어 소유 topic의 이력 접근 한계를 명시했다.
- DEAD END IS-D1: ‘Quick Look/undo/current-folder filter/context menu/clipboard/drag가 없다’는 가설. 해당 구현과 테스트 계약을 직접 읽어 반증했다. 새 기능 목록에 넣지 않는다.
- DEAD END IS-D2: ‘일반 Backspace나 글상자 Delete가 곧 파일 삭제’라는 가설. context 분리와 표준 trash 키 구현이 반증한다. 이 보고서에서는 더 추적할 근거 없음.
- DEAD END IS-D3: ‘toolbar 아이콘이라 접근성이 없다/선택은 전부 행 번호 기반’ 가설. SF Symbol accessibilityDescription와 URL 재선택 구현이 반증한다. 실제 AX 품질만 IS-E6으로 남긴다.
- DEAD END IS-D4: ‘사진 파일에 native Quick Look 편집/공유 기능이 없다’라는 가설. QLPreviewPanel을 사용하므로 버튼 제공 여부는 플랫폼 surface 관측 대상이다. 소스 전용 판단으로 제품 부재 판정하지 않는다.