# A7 ProductAlternatives: 핵심 작업으로 본 제품 방향

## 결론

IHateFinder가 쓰일 이유는 'Finder보다 기능이 많아서'보다 'Windows에서 익숙한 주소 입력 → 상세 목록에서 선택 → 잘라두기/붙여넣기 또는 양쪽 창으로 옮기기를 덜 생각하고 끝낼 수 있어서'로 잡는 편이 현재 구현과 맞다. 다만 이 조합만으로 대안과 독자적으로 구별되지는 않는다. QSpace는 공식적으로 Windows 스타일 키 설정과 자동완성 주소창을 제공하고, Marta와 Nimble Commander는 양쪽 창과 키보드 작업을 제품 원리로 삼는다. 이 앱의 다음 목표는 다른 제품의 기능 목록을 따라잡는 것이 아니라, 선택한 로컬 파일 작업을 시작부터 끝까지 앱 밖으로 나가지 않고 완료하는 것이다.

이 결론은 제품 문서와 현재 소스에 대한 판단이다. 사용자의 작업 빈도, 경쟁 제품의 실제 성능, 현재 앱 GUI의 실패율을 측정한 결과가 아니다. 기존 Quick Look, 실행 취소, 현재 폴더 거르기, 시스템 클립보드, 드래그, 열기/다른 앱으로 열기, 외부 Terminal 열기, 세션 복원, 기본 파일 뷰어 설정 문서는 이미 존재하므로 누락으로 분류하지 않았다.

## 조사 범위와 증거 메타데이터

모든 관측의 observed_at은 2026-10-10이다. 코드 valid_at은 조사 시점 작업 트리이며 기준 HEAD는 0970c61이다. 로컬 문서는 제품 의도, Swift 구현은 정적 구현 관측으로 구분한다. 외부 valid_at은 해당 날짜에 fetch한 공식 문서이며, 명시적으로 버전이 붙지 않은 페이지는 현재 공식 문서일 뿐 특정 배포 바이너리의 실행 증거가 아니다. Nimble Commander의 GitHub main 도움말은 이동 가능한 개발 브랜치 문서이므로 출시 버전 전체에 곧바로 일반화하지 않는다.

관측 그룹: G-IHF(현재 앱의 코드/문서/git), G-Marta(marta.sh), G-QSpace(qspace.awehunt.com), G-ForkLift(binarynights.com), G-Nimble(magnumbytes.com와 제작자 공식 GitHub). 같은 제품의 홈, 매뉴얼, 기능 페이지는 독립 증거가 아니다. 서로 다른 제품 그룹은 각자의 제품 방향에 대한 독립적인 일차 출처이나, 공통 기능이 있다는 사실만으로 이 사용자에게 그 기능이 필수라는 독립적인 사용자 조사 증거가 되지 않는다. 리드의 GUI QA와 테스트는 이 보고서 자체에서 수행한 검증에 포함하지 않는다.

LSP 장치 xd://lsp를 확인했으나 런타임에 탑재되어 있지 않아 find → 실제 범위 read → literal grep으로 확인했다. 관련 검색은 Marta/QSpace/ForkLift/Nimble, tabs/bookmark/favorite, terminal/search, copyToOther/moveToOther, pathField/EntryFilter 등 세 가지 이상 변형을 사용했다. 빌드, 테스트, 설정 변경, 제품 설치, 파일 수정, 자식 생성은 하지 않았고 남은 프로세스는 없다.

## 현재 앱: 구현 / 제한 / 미구현을 분리한 관측 후보

O-I1 [구현·의도] CONTEXT.md:3: '윈도우 탐색기에서 쓰던 경로 입력, 잘라 옮기기, 상세 목록을 기준'. README.md:5도 'path field, a details list, and cut and paste'로 같은 목적을 명시한다. 둘은 G-IHF 내 동일 의도이므로 독립 근거 2개로 세지 않는다.

O-I2 [구현·정적] Sources/IHateFinder/KeyCommands.swift:40-47의 Cmd/Ctrl-L 및 Cmd/Ctrl-F, :63-78의 Ctrl-C/X/V/A와 생성/숨김 키, :88-89의 copyToOther/moveToOther 분기가 Windows 전환자의 조작을 지원한다. Sources/IHateFinder/BrowserWindowController.swift:689-706은 'let dest = other().session.url'와 runTransfer(moving: false/true)를 실제로 연결한다. 양쪽 창과 반대쪽 전송은 아이디어만 있는 상태가 아니다.

O-I3 [구현·제한·정적] Sources/IHateFinder/FilePaneController.swift:746-750: 'expandingTildeInPath'를 거쳐 입력한 경로로 navigate한다. 주소 입력 자체는 이미 된다. 이번 읽기에서 확인한 제출 경로는 자동완성 UX를 보여주지 않으며, 자동완성/경로 후보 전체 부재 판단은 A1의 범위 검토와 합쳐야 한다.

O-I4 [구현·제한·정적] Sources/IHateFinderCore/EntryFilter.swift:6-9: 'entries.filter { $0.name.localizedStandardContains(trimmed) }'. Sources/IHateFinder/FilePaneController.swift:362-368는 session.entries를 넘기고 남아 있는 선택을 복원한다. 현재 폴더 이름 거르기는 구현되어 있지만 하위 폴더 발견이나 Spotlight 검색의 근거가 아니다. README.md:129도 'does not look in subfolders', :235는 'Search in subfolders'를 이번 버전 제외 항목으로 명시한다.

O-I5 [구현·제한·정적] Sources/IHateFinderCore/WorkspaceStore.swift:4-8의 PaneState는 path/sortColumn/ascending/includeHidden, :45-48의 WorkspaceState는 left/right/dual, :63의 저장 키는 'workspace.v1'이다. BrowserWindowController.swift:47-57은 저장 상태를 두 세션으로 복원한다. '세션 복원이 없다'는 틀리다. 이 관측으로 확인되는 것은 마지막 두 위치와 보기 상태 복원이지, 여러 이름 있는 프로젝트 작업 공간을 선택해 여는 기능은 아니다.

O-I6 [제한·정적] BrowserWindowController.swift:848-858은 홈/데스크탑/문서/다운로드/응용 프로그램을 코드에 고정하고 :859-875는 마운트된 볼륨을 추가한다. 사이드바 자체와 디스크는 구현되어 있다. 확인한 loadPlaces 경로에는 사용자가 프로젝트 장소를 등록하는 목록이 없다. 즐겨찾기 편집 전체 부재는 A5 보고서와 교차 확인 대상이다.

O-I7 [구현·제한·정적] FilePaneController.swift:23-25는 com.apple.Terminal에 폴더 URL을 open하고 :727-731은 단일 선택 폴더 또는 현재 폴더를 넘긴다. Terminal 진입은 있다. 이는 앱 안에서 셸과 목록 경로가 양방향 동기화되는 것과는 다른 계약이다.

O-I8 [제한·정적] BrowserWindowController.swift:535-544의 상단 버튼은 뒤로/앞으로/위/양쪽 창이다. FilePaneController.swift:768-779의 문맥 메뉴는 잘라두기/복사/붙여넣기 등 일반 조작을 제공하지만 '반대쪽으로 복사/이동' 항목을 포함하지 않는다. F5/F6 기능의 발견 가능성이 상대적으로 약할 후보이지, 실제 사용자가 못 찾았다는 실행 관측은 아니다.

O-I9 [미구현·문서 의도] README.md:233-236은 탭, 아이콘/열 보기, 하위 폴더 검색, 파일 작업 다시 실행을 제외 항목으로 적는다. 전체 구현 누락 판단에는 담당 축의 코드 조사가 필요하다. 특히 현재 파일 작업 undo를 redo 부재와 혼동하면 안 된다.

git 이력 관측 G-IHF: git log -12 --format='%h %ad %s' --date=iso-strict -- CONTEXT.md Sources/IHateFinder/KeyCommands.swift Sources/IHateFinder/BrowserWindowController.swift Sources/IHateFinder/FilePaneController.swift Sources/IHateFinderCore/EntryFilter.swift. 22f79b5 'feat: Windows-switcher keys, mouse, undo, Quick Look, filter and menu', fbd98e4 'docs: specify Windows-switcher behavior for stages 1-3', 81ea1c3 'Modernize UI for macOS 14+ visual standards', 0970c61 'Fix PR review findings'를 확인했다. 이력은 기존 기능을 누락으로 진단하지 말아야 하는 보조 근거이며 현재 실행 성공의 대체 증거가 아니다.

## 대안별 독자적 작업 강점

### Marta: 두 위치의 파일을 키보드로 골라, 작업과 명령을 같은 맥락에서 이어가기

O-M1 [G-Marta·공식 제품 계약] https://marta.sh/docs/ — 'you can see both source and target directories' 및 'Marta is keyboard-centric'. 작업 원리는 원본/대상을 동시에 보고 active pane에서 inactive pane으로 조작하는 것이다. 파일 관리자 전체를 복제한다는 약속보다 반복 선택·이동의 맥락 유지가 강하다.

O-M2 https://marta.sh/docs/core/actions/#action-bar — 'Actions are displayed together with their hotkeys ... a tiny cheat sheet'. 같은 페이지 #actions-panel은 'find all available actions'와 Cmd-Shift-P의 이름 검색을 설명한다. 배울 때는 보이는 작업 버튼, 익숙해지면 이름/키보드로 같은 명령을 호출한다. 이 앱에 가져올 중요한 아이디어는 플러그인 엔진보다 기존 F5/F6/거르기 같은 유효한 기능을 보이게 만드는 연결이다.

O-M3 https://marta.sh/docs/advanced/terminal/ — 'each pane has its own pty session', 'current directory is two-way synchronized'. 목록에서 고른 장소와 셸 장소를 다시 맞추는 부담을 줄인다. 반례: 같은 문서는 nested shells와 ssh sessions에서 디렉터리가 바뀌지 않는다고 제한한다. 이 앱의 Terminal 열기를 '없음'으로 낮춰 평가해서는 안 된다.

O-M4 https://marta.sh/docs/actions/goto/ — 'Press Tab to show the completion menu'. https://marta.sh/docs/navigation/favorites/ — 'add your own folders ... organize them hierarchically'. https://marta.sh/docs/navigation/recent/ — 최근 위치는 'tab-local'이고 탭을 닫으면 잊는다. 목적지를 다시 찾아가는 비용을 낮추지만 모든 이력을 영구 보존하는 제품은 아니다.

O-M5 https://marta.sh/docs/actions/lookup/ — 'Look up ... searches globally', 'Look up uses the Spotlight caches ... may not be available ... ~/Library'. 검색과 경로 자동완성을 함께 제공하되 인덱스의 범위를 인정한다. 현재 폴더 거르기와 이 기능을 같은 것으로 취급하면 안 된다.

O-M6 https://marta.sh/docs/core/operation-queue/ — 'queued and executed one after another', 'pause or cancel', 'fully accessible with a keyboard'. 백그라운드 작업도 키보드 중심 제품 계약에 맞게 이어진다. 빠른 작업이라는 방향은 단순 초당 처리량 주장보다 탐색·전송·제어의 일관성으로 확인된다.

반증/주의: https://marta.sh/docs/navigation/base/#show-file-information 은 'opens the Finder’s Get Info dialog', #reveal-in-finder도 Finder 창을 연다고 명시한다. 실용적인 대안조차 Finder를 완전히 없애지 않는다. 또 선택과 커서를 분리하는 기본 모델은 Windows 탐색기와 다르므로 그대로 복제하면 익숙함이라는 이 앱의 목적을 해칠 수 있다. https://marta.sh/docs/core/file-operations/ 에서 F5 Copy와 F6 Move는 대상 선택 작업이며, 별도의 Copy/Move to Inactive Pane은 'No dialogs ... starts ... right away'다. 이 앱 F5/F6의 즉시 반대쪽 전송과 기본 키 의미까지 동일하다고 주장하면 부정확하다.

### QSpace: 여러 폴더를 작업 공간으로 저장하고 다시 열어, 수집·정리의 시작 비용을 없애기

O-Q1 [G-QSpace·공식 제품 계약] https://qspace.awehunt.com/en-us/guide/workspace.html#concept — 'encompassing the multi-pane layout, sidebar, the folders opened in each pane, and their display modes', 저장 공간은 'exact state before closing'으로 복원. 한 탭이 한 workspace다. 강점은 12개 레이아웃이라는 숫자보다 프로젝트마다 필요한 장소 조합을 다시 열어놓을 필요가 없다는 작업이다.

O-Q2 https://qspace.awehunt.com/en-us/guide/address-bar.html#edit — 'Manually enter a location with support for auto-completion suggestions'. 같은 페이지 #access는 경로의 폴더 이름에 드래그해 복사/이동한다고 설명한다. https://qspace.awehunt.com/en-us/faq/howto-set-windows-keys.html — 'Click Windows style to instantly switch to Windows key bindings'. 따라서 'Windows 키와 주소창이 있으니 우리 앱만의 강점'은 반박된다.

O-Q3 https://qspace.awehunt.com/en-us/guide/search.html — Search in Pane의 'Search in subfolders', Spotlight Search의 'Only supports local files ... Spotlight index ... enabled'. 필터·재귀 검색·인덱스 검색을 분리한다. 세 가지는 같은 '찾기' 버튼 아래에 있을 수 있어도 의미와 실패 조건이 다르다.

O-Q4 https://qspace.awehunt.com/en-us/guide/extension-stash-shelf.html — 'drag local items or web images ... process them together: copy or move ... share via AirDrop, batch rename ...'. 흩어진 여러 출처를 모아 한 번에 정리하는 작업이 단순 양쪽 창과 다른 강점이다. 단, 'extension, available for purchase as needed'이므로 기본판 전체 기능으로 쓰면 틀리다.

O-Q5 https://qspace.awehunt.com/en-us/guide/sidebar.html#customize — New Group, Finder Favorites, Smart Folders, Workspaces, Recent Locations를 사용자 맥락에 연결한다. https://qspace.awehunt.com/en-us/guide/quick-launch.html#new — App/Service/Command Line/Shortcut와 파일 경로 변수를 외부 앱에 넘긴다. 배워야 할 방향은 사이드바 장식보다 반복 목적지와 다른 도구로의 작업 전달이다.

반증/주의: https://qspace.awehunt.com/en-us/guide/qspace-desktop.html 은 QSpace Desktop을 'Only available in QSpace Pro'로 제한하고 바탕화면 폴더를 QSpace 창으로 연다고 설명한다. https://qspace.awehunt.com/en-us/faq/differences-between-mas-and-pro.html 에서 Desktop/Workflow Services/Command-Line Apps와 확장의 판 차이도 확인했다. 'A Better Finder'라는 마케팅 문구만으로 시스템 Open/Save나 모든 Finder 호출을 교체한다고 결론 내리지 않는다. 이 앱의 제한된 두 세션 복원을 아무 복원이 없는 것처럼 비교하지 않는다.

### ForkLift: 로컬과 원격의 반복 배포·동기화를 저장 가능한 작업으로 만들기

O-F1 [G-ForkLift·공식 제품 계약] https://binarynights.com/manual#introduction — 'bridging the gap between your local and remote files'. https://binarynights.com/#remote-connections 의 Remote Connections 문단은 여러 서버 동시 연결과 서버 간 드래그를 설명한다. 이 제품이 강한 이유는 프로토콜 개수가 아니라 서버/클라우드 위치를 파일 작업의 연속선에서 다루는 것이다.

O-F2 https://binarynights.com/manual#sync — 'synchronize between any locations ... folders, drives, and remote connections', 양방향/하위 폴더/숨김/업데이트/삭제 항목 설정, 변경될 추가·갱신·삭제 건수 요약, 'save your configuration as a Synclet'. 반복 배포나 디렉터리 미러링 사용자는 같은 두 폴더를 열고 변경 파일을 매번 골라 복사하는 대신 저장된 비교·동기화 작업을 실행할 수 있다. 이 앱의 단순 copy/move와 다른 작업 계약이다.

O-F3 https://binarynights.com/ — Activity View: 'watch your tasks progress in real-time'; Log View: 활동과 결과를 한 장소에서 조회; Transfers: 'Reorder transfers, set conflict management rules, error handling'; Remote Editing: 저장할 때 원격으로 업로드; Workspaces: 탭/장소와 레이아웃 저장. 이 방향은 오래 걸리고 실패할 수 있는 전송을 시작·감시·재사용 가능한 작업으로 만든다. 이 앱도 진행/취소/결과 보고를 구현했다는 반례를 유지해야 한다.

O-F4 https://binarynights.com/manual#search — 자체 검색은 파일을 하나씩 스캔하고 'Search in Subfolders'로 범위를 넓히며 remote에서도 작동; Spotlight는 local만. 속도와 범위의 서로 다른 계약을 명시한다. 홈의 '20x faster'는 ForkLift 3과의 판매 주장으로만 읽었고 현재 앱과의 성능 수치로 사용하지 않았다.

반증/주의: https://binarynights.com/manual#fileviewer — 'will not replace the system’s open and save dialog windows'. 기본 파일 뷰어 설정은 다른 앱의 Show/Reveal in Finder 진입을 줄여도 완전한 Finder 폐지를 뜻하지 않는다. 같은 매뉴얼 #delete는 원격 볼륨에 휴지통이 없어 Move to Trash가 Delete로 바뀐다고 설명한다. 원격·동기화 기능을 추가하면 이 앱의 '휴지통만 사용' 안전 계약도 재설계해야 한다. 그래서 일반 로컬 정리 앱의 다음 구현으로 SFTP/양방향 sync를 무조건 추천하지 않는다.

### Nimble Commander: 파일·검색 결과·아카이브·셸을 동일한 키보드 작업 공간에서 다루기

O-N1 [G-Nimble·공식 제품 계약] https://magnumbytes.com/#product-focus (페이지 Product Focus 문단) — 'Software developers', 'System administrators', 'IT professionals and enthusiasts'; 'Keyboard-centric', 'Flexibility'. 성능은 판매 문구이며 비교 벤치마크로 읽지 않았다. 핵심 독자는 시스템과 파일을 세밀하게 다루는 사용자다.

O-N2 https://github.com/mikekazakov/nimble-commander/blob/main/Docs/Help.md#searching-for-files (fetch: https://raw.githubusercontent.com/mikekazakov/nimble-commander/main/Docs/Help.md, 원문 410-432행) — 'To recursively search', 이름/내용/크기 조건, 'Reveal all found items in a temporary file panel for further actions'. 중요한 차이는 파일을 찾는 데서 끝나지 않고 결과 집합을 선택·이동 같은 기존 파일 작업의 입력으로 쓰는 것이다.

O-N3 같은 Help.md#virtual-file-systems (원문 591-620행) — 'other resources as if ... normal filesystem', 아카이브/FTP/SFTP/WebDAV/xattrs/process list. 단, archives는 'read-only ... modifications are not allowed'. 지원된다는 한 단어로 모든 파일 조작을 할 수 있다고 확대하지 않는다.

O-N4 같은 Help.md#integrated-terminal (원문 722-747행) — 'without switching to another application', 'synchronization is bi-directional', 전체 창/겹친 모드. Help.md#tools (원문 630-690행)은 선택 경로를 치환해 도구를 실행하지만 'Virtual File Systems ... not supported'라고 제한한다. 이 앱의 외부 Terminal 열기와 비교할 때는 사용자가 실제로 셸과 목록을 왕복하는 작업이 있는지를 전제로 해야 한다.

O-N5 같은 Help.md#tabs, #favorites (원문 369-406행) — 양쪽 각각 여러 장소, 닫은 위치 복원, Finder Favorites 동기화와 VFS 장소 즐겨찾기. https://magnumbytes.com/ 의 File Search 문단은 custom search 또는 Spotlight, 결과를 pane으로 보내 조작한다고 명시한다. 같은 제품 두 문서이므로 독립 검증 2개는 아니다.

반증/주의: Help.md#selection (원문 207-225행)은 selection과 cursor를 분리하여 macOS의 일반 선택 UX와 다르다고 명시한다. 시스템 관리자에게 유리한 모델이 Windows 전환자 모두에게 더 쉬운 것은 아니다. Help.md#version-differences (원문 76-87행)는 MAS에서 admin mode/integrated terminal/network share mounting 등을 제외한다. '무료·오픈소스'나 기능 수가 일상 정리 작업의 우월함을 입증하지 않는다.

## CLAIMS

C-A7-1 [추론·중요·신뢰 중상]: 네 대안의 제품 방향은 공통 기본 조작 위에 특정 작업을 완주시키는 데 있다. Marta는 키보드 선택/전송/명령, QSpace는 장소 조합 복원과 수집, ForkLift는 원격 변경 비교/동기화, Nimble은 검색 결과와 셸/VFS의 일관된 조작이다. 근거 O-M1~6/O-Q1~5/O-F1~4/O-N1~5. 반론: 제품별 중첩 기능이 많아 독점적 강점이라는 뜻은 아니다. 이 분류는 공식 문서에서 드러나는 강조와 작업 연결을 해석한 것이다.

C-A7-2 [추론·중요·신뢰 높음]: IHateFinder의 Windows 조작/주소/양쪽 창은 사용할 명확한 이유지만, 그것만으로 경쟁 대안에 없는 차별점은 아니다. O-I1~3 + O-Q2 + O-M1. 결과: 기존 강점을 버리지 말고 그 강점으로 파일 정리 한 번을 더 적은 맥락 전환으로 끝내야 한다. 개인 맞춤·작은 표면·한국어 조작의 적합성은 가능한 이유이나 선호 측정 없이 우월성으로 단정하지 않는다.

C-A7-3 [판단·우선순위 높음·조건부]: 로컬 정리 앱이라는 현재 목적에서는 원격 프로토콜보다 '이미 아는 목적지에 빨리 가기'와 '경로를 모르는 파일을 찾아 조작하기'를 먼저 닫는 편이 좋다. 근거 O-I3~6와 O-M4~5/O-Q1~3/O-N2. 제안 순서: (1) 사용자 목적지/최근 위치와 주소 입력 지원으로 장소 도달 비용 낮추기, (2) 현재 폴더 거르기와 구별되는 범위 명시 검색 + 결과 열기/선택/전송, (3) 자주 왕복하는 두 곳 이상의 맥락을 탭 또는 이름 있는 작업 공간으로 보존. 이것은 빈도 실측이 아닌 작업 마찰 판단이다. 사용자가 이름만 기억해 찾는 일이 주 작업이라면 (2)를 (1)보다 앞당긴다. 어떤 방식으로 구현할지는 A1/A5와 실제 GUI 결과를 합친 뒤 정해야 한다.

C-A7-4 [판단·우선순위 높음·신뢰 중간]: 구현된 반대쪽 전송을 제품 표면에 드러내는 작업은 대안의 고급 기능을 새로 늘리는 것보다 범위가 작고 현재 강점을 바로 전달한다. O-I2/O-I8 + O-M2. 예: '오른쪽 [목적지]로 복사 F5 / 이동 F6'를 보이는 명령과 같은 동작으로 연결. 실제 오조작이나 미발견 실패는 관측하지 않았으므로 버그 주장이나 확정 병목으로 쓰면 안 된다. 단순 즉시 전송과 대상 선택 대화상자는 서로 다른 UX 선택이다.

C-A7-5 [판단·보류 기준]: ForkLift식 원격/동기화, Nimble식 admin mode/hex viewer/가상 파일 시스템, QSpace식 Stash Shelf, Marta식 embedded terminal은 사용자가 해당 작업을 실제로 원할 때의 확장이다. 이 기능들이 없어서 '0.3'이라는 인과 주장은 근거가 없다. 특히 원격 sync는 실패 처리·삭제·충돌 계약을 바꾸므로 지금의 안전한 로컬 정리 목표와 별도다. 기존 외부 Terminal/Open With가 연결 비용을 충분히 해결할 수도 있다.

C-A7-6 [반론·신뢰 높음]: Finder를 한 번이라도 열면 실패라는 성공 기준은 제품 비교와 맞지 않는다. Marta의 Get Info/Reveal in Finder와 ForkLift의 Open/Save 제한이 직접 반례다. 판단해야 할 것은 선택한 일상 작업을 이 앱 안에서 끝낼 수 있는지이며, 시스템 표면 전체를 소유하는지는 별도 목표다.

## EXPAND

- LEAD A7-L1 → A1: 검색 결과를 '발견'에서 '선택/이동'으로 이어가는 최소 계약을 확인하라. Nimble Help.md#searching-for-files의 temporary file panel은 결과 모음 조작이라는 근거다. 재귀 이름 검색과 Spotlight는 인덱스 범위/권한/결과 갱신이 다르므로 하나의 기능으로 뭉치지 않는다. 문서 측 리드는 조사 완료, 현재 앱에서 어떤 전송 정책을 재사용할지는 다른 축과 합치는 열린 설계 판단이다.
- LEAD A7-L2 → A5: '복원이 없다'가 아니라 '마지막 두 위치 복원'과 '프로젝트별 여러 장소 복원'의 차이를 검토하라. WorkspaceStore.swift:4-8,45-48 및 QSpace workspace Concept으로 근거는 닫혔다. 명명된 작업 공간이 탭보다 먼저 필요한지는 사용자 작업 가정에 의존한다.
- LEAD A7-L3 → A3/리드 GUI: F5/F6의 실제 발견 가능성, 반대쪽 대상 표시, 포커스 이해를 관측하라. 정적 상단/문맥 메뉴와 Marta Action Bar로 후보는 확보했다. 사용자 실패는 이번 축에서 관측하지 않았다.
- LEAD A7-L4 → A4: 기본 뷰어가 되어도 남는 Finder 진입을 작업별로 구분하라. ForkLift manual#fileviewer와 Marta base navigation이 완전 교체 요구의 반례다. QSpace Desktop은 Pro의 추가 바탕화면 표면이지 Open/Save 전체 교체 증거가 아니다. 공식 문서 측 조사는 완료했다.
- LEAD A7-L5 → A2: 원격/양방향 동기화를 장기 후보로 삼을 때 '휴지통만 삭제' 계약과 양립 여부를 분리하라. ForkLift manual#delete에서 원격 휴지통 불가 및 Delete 대체를 확인했다. 현재 로컬 전송 결함이라는 뜻이 아니다.
- LEAD A7-L6 → 제품 판단: 여러 폴더에서 파일을 수집해 한 번에 처리하는 일이 실제로 중요한 경우 QSpace Stash Shelf를 비교 축으로 삼을 수 있다. 공식 기능과 유료 확장 범위를 확인했지만 이 사용자 수요는 확인되지 않았다. 다음 구현 필수로 승격하지 않는다.
- LEAD A7-L7 → A1/A3: Windows 키 프리셋과 선택 모델을 혼동하지 말라. QSpace Windows style은 직접 경쟁 근거, Marta/Nimble의 커서·선택 분리는 다른 UX라는 반례다. Windows 탐색기와 유사한 앱을 만들기 위해 orthodox selection을 통째로 들여올 이유는 확보되지 않았다.
- DEAD END: 제품 인기/별점/기능 수/판매 성능 문구로 현재 앱의 실용성을 점수화하는 경로. 공식 홈의 ForkLift '20x', Nimble 'blazing performance'는 현재 앱 비교 실측이 아니므로 사용하지 않았다.
- DEAD END: Windows 주소창/잘라두기만으로 대안에 없는 고유성을 주장하는 경로. QSpace의 주소 자동완성과 Windows 스타일 설정이 직접 반증한다.
- DEAD END: 'Finder 호출이 남는다 → 대체 파일 관리자로 쓸 수 없다'는 경로. Marta와 ForkLift의 공식 제한으로 반증된다.
- DEAD END: 사이트가 'Better Finder' 또는 'most advanced'라고 부르므로 모든 표면이 구현되었다는 경로. 버전·판·확장과 명시적인 제한을 읽었으며 브랜드 문구는 실행 증거로 쓰지 않았다.
- none (미정리 자원): 이 축은 읽기 전용이었다. 제품 설치, 외부 설정, 임시 프로세스, 사용자 파일 변경이 없고 실행한 git log는 완료되었다.