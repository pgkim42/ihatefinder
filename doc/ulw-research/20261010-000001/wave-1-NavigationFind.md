# NavigationFind 축 조사

## 결론
현재 앱은 '알고 있는 폴더에 가서 그 안의 파일을 다루는' 흐름을 상당 부분 구현했다. 주소창 직접 입력, 뒤로/앞으로/위, 고정 장소와 마운트 디스크, 현재 폴더 이름 거르기, 외부 요청의 폴더 열기·파일 드러내기가 존재한다. 핵심 차이는 '위치를 정확히 모를 때 찾아 들어가는 방법'이다. 현재 폴더 이름 거르기를 실제 검색으로 계산하면 이 차이를 놓친다. 경로 완성·최근 장소·사용자 장소·계층 바로가기와 하위 폴더 검색은 각각 기억 부담을 줄이는 서로 다른 기능이다.

우선순위는 사용자 빈도 실측이 아니라 작업 마찰에 대한 판단이다. 반복하는 작업 폴더로 돌아가는 흐름이면 장소 저장/최근 장소/주소 완성을 먼저, 파일 위치를 모르는 흐름이면 하위 폴더 이름 검색을 먼저 해야 한다. '검색이 무조건 1순위'라고 결론 내릴 사용자 작업 로그는 없다.

## 조사 범위와 증거의 독립성
observed_at: 2026-10-10. 코드 valid_at: 할당된 현재 HEAD 0970c61의 작업 트리 소스. 외부 valid_at: Apple macOS Tahoe 26 버전 문서를 직접 fetch한 내용. 기본 /mac 페이지가 macOS 27을 선택하는 것을 확인했고, 핵심 외부 근거는 /26/mac/26으로 다시 읽었다.

G-NAV-SOURCE는 현재 구현을 직접 읽은 관찰 그룹이다. G-NAV-TEST는 테스트 소스의 기대값 그룹이며 실행 관찰이 아니다. G-NAV-DOC는 제품 설명/의도 그룹으로 같은 저장소이므로 구현과 독립적인 제품 검증이 아니다. G-APPLE-26은 Apple 공식 문서 그룹으로 앱 소스와 독립적인 기준이지만 Finder 실행 관찰은 아니다. G-GIT-REFLOG는 로컬 reflog 그룹이다. 부모가 알린 240개 테스트 통과는 부모의 실행 증거이며 이 worker가 실행하지 않았다. 실제 GUI 관찰 역시 부모 담당이다. 이 보고서의 runtime failure 주장은 없다.

제품/문서/설정/git 변경, 테스트/빌드/린트 실행, 자식 생성은 하지 않았다. 시작한 프로세스나 남은 소유 리소스도 없다. xd:// 장치 목록에는 LSP와 git/bash 실행 도구가 없어서 LSP 심볼 조사 및 git log -p는 할 수 없었다. 대신 실제 소스와 .git/logs/HEAD 및 main reflog를 읽었다. reflog만으로 기능이 어느 커밋에 도입됐다고 단정하지 않는다.

## 구현됨 / 제한됨 / 미구현

### 1. 현재 폴더 이름 거르기: 구현됨, 검색 범위는 제한됨
- Sources/IHateFinder/FilePaneController.swift:123-129: placeholder는 '이 폴더에서 이름 거르기', 입력을 즉시 보내며 처음에는 숨겨진다.
- Sources/IHateFinder/FilePaneController.swift:323-335: showFilter는 칸을 드러내고 입력칸으로 포커스를 보낸다.
- Sources/IHateFinder/FilePaneController.swift:363-375: 'EntryFilter.filter(session.entries, query: filterField.stringValue)'로 이미 읽은 현재 목록만 줄인다. 남아 보이는 URL 선택만 유지한다.
- Sources/IHateFinderCore/EntryFilter.swift:6-9: 앞뒤 공백을 지우고 'localizedStandardContains(trimmed)'로 이름 부분 문자열을 맞춘다. 필터는 디스크 조회/재귀 탐색/메타데이터 질의를 하지 않는다.
- Sources/IHateFinderCore/FileOps.swift:192-223: list는 'fm.contentsOfDirectory(at: directory, ...)'로 직접 자식을 읽는다. 숨김 항목은 includeHidden이 false이면 먼저 제외한다. 따라서 거르기 칸에 숨김 파일 이름을 입력해도 기본 숨김 상태에서는 발견하지 못한다. 이것은 구현 계약의 제한이며 결함 주장 아니다.
- Sources/IHateFinder/FilePaneController.swift:179-188: 폴더가 바뀌면 'resetFilter()'; 같은 폴더 갱신에는 현재 문자열로 필터를 다시 적용한다.
- Sources/IHateFinder/FilePaneController.swift:241-247: 'N개 중 M개 표시'로 좁혀진 결과임을 알린다.
- Sources/IHateFinder/FilePaneController.swift:210-223: 새 항목 reveal이 필터에 가려지면 필터를 해제하고 표시한다.
- Sources/IHateFinder/FilePaneController.swift:482-495: 필터 Esc는 해제, Return은 필터를 유지한 채 목록으로 포커스 이동이다.
- Tests/IHateFinderCoreTests/EntryFilterTests.swift:16-40: 대소문자, 한국어 부분 문자열, 악센트, 빈 문자열과 공백의 기대값을 읽었다.
- Tests/IHateFinderTests/PreviewAndFilterTests.swift:162-241: 선택 제거, Escape, 이동 시 해제, 재조회 시 필터/URL 선택 유지, 생성 항목 드러내기의 테스트가 존재한다. 테스트 소스는 보강 근거일 뿐 독립적인 실행 증거가 아니다.

미구현 판단의 긍정 근거: README.md:230-235는 'Search in subfolders'를 버전 제외 항목으로 명시하고 docs/behavior.md:52-56는 '하위 폴더는 찾지 않는다'고 정의한다. 소스의 직접 자식 열거 및 session.entries 필터가 이를 뒷받침한다. Sources 전체의 NSMetadataQuery/MDQuery/Spotlight/enumerator/subpaths 검색과 completion/breadcrumb/recent 변형 검색에서 다른 검색 엔진은 발견하지 못했다. 복사 작업의 하위 폴더 처리나 테스트의 subpathsOfDirectory를 검색 엔진으로 오인하지 않았다.

사용자 결과: 다운로드 폴더 안에서 이름 일부로 파일을 고르는 흐름에는 유용하다. 프로젝트 폴더 아래 어디에 저장했는지 모르거나 날짜·종류·내용으로 찾으려면 이 칸이 답을 주지 않는다. '아무 결과 없음'은 현재 폴더의 현재 표시 대상에 이름 일치가 없다는 뜻이지 컴퓨터에 파일이 없다는 뜻이 아니다.

Apple 비교: https://support.apple.com/guide/mac-help/narrow-search-results-in-finder-mh15155/26/mac/26 — 'search for particular kinds of files, or for items created on a particular date', 'choose Kind ... choose Name', 'Your search is saved as a Smart Folder.' Finder 공식 기준은 이름 포함 외에도 종류·날짜·메타데이터·논리 조건·저장 검색을 갖는다. 모든 고급 조건을 즉시 구현해야 한다는 결론은 아니다. 최소한 거르기와 별도의 검색 범위/결과 모델이 필요하다는 판단의 근거다.

### 2. 주소창: 직접 입력은 구현됨, 폴더 경로 완성은 미구현
- Sources/IHateFinder/FilePaneController.swift:72-82: 주소창은 편집/선택 가능한 NSTextField이고 action은 commitPath다. placeholder '경로를 입력하거나 Command-L을 누르세요'.
- Sources/IHateFinder/FilePaneController.swift:268-270: focusPath는 주소창 전체 선택.
- Sources/IHateFinder/KeyCommands.swift:40-45: Cmd/Ctrl-L은 주소창, Cmd/Ctrl-F는 거르기이며 F3도 거르기다(:46-48).
- Sources/IHateFinder/FilePaneController.swift:746-749: 'URL(fileURLWithPath: (typed as NSString).expandingTildeInPath)'를 navigate로 넘긴다. ~ 확장은 명시적으로 구현되어 있다.
- Sources/IHateFinder/FilePaneController.swift:482-511: 주소창 Esc는 기존 session.url.path를 복구한다. 텍스트 변화에 반응하는 로직은 NSSearchField 필터뿐이다. 주소창의 Tab/후보 탐색/경로 목록 처리는 없다.
- Sources/IHateFinderCore/BrowserSession.swift:83-87: 목적 경로를 standardizedFileURL로 정규화한 뒤 조회한다.

검색 파형은 completions/complete/completion/NSPathControl/breadcrumb/recent 및 경로 관련 find까지 확인했다. 앱 전용 파일시스템 경로 완성 또는 추천 UI는 확인되지 않았다. NSTextField 기본 텍스트 편집 동작의 존재를 파일시스템 폴더 완성으로 세지 않는다. 상대 경로·빈 입력·공백·붙여넣은 file:// URI를 특별 해석하는 앱 코드도 확인되지 않았다. Foundation의 실제 결과를 실행하지 않았으므로 '상대 경로가 현재 폴더 기준으로 동작한다/실패한다'는 주장은 보류한다.

사용자 결과: 정확한 절대 경로나 ~/...를 알고 있거나 복사해 온 경우에는 이미 빠른 통로가 있다. 폴더 이름을 일부만 기억하거나 깊은 경로를 손으로 적을 때는 후보를 통해 기억을 보완할 수 없다. 주소창을 없애기보다 주소창의 폴더 후보와 최근 장소를 붙이는 것이 제품 방향을 보존한다.

Apple 비교: https://support.apple.com/guide/mac-help/go-directly-to-a-specific-folder-on-mac-mchlp1236/26/mac/26 — 'As you type, matching folders appear', 'Press Tab to accept the suggestion', 'Press the Up Arrow or the Down Arrow to scroll through suggested and recent pathnames', 'Suggested pathnames ignore small typing errors.' 단순 경로 입력 존재와 경로 도달성은 같은 수준의 기능이 아니다.

### 3. 위치 계층: 위/뒤로/앞으로는 구현됨, 임의 조상 바로가기는 미구현
- Sources/IHateFinderCore/BrowserSession.swift:90-111: goUp은 deletingLastPathComponent, goBack/goForward는 각 스택의 마지막 목적지를 읽는다.
- Sources/IHateFinder/FilePaneController.swift:273-286: 위로 이동하면 나온 폴더 URL을 pendingReveal로 남겨 부모 목록에서 선택하도록 한다. '위로 이동 후 방금 폴더를 잃는다'는 일반 주장은 틀리다.
- Sources/IHateFinderCore/BrowserSession.swift:157-167: 성공한 이동에서만 backStack/forwardStack이 바뀐다.
- Sources/IHateFinder/BrowserWindowController.swift:535-537: 뒤로/앞으로/위 버튼이 실제 구성 코드에 있다.
- Sources/IHateFinder/AppDelegate.swift:100-104: 이동 메뉴에는 뒤로/앞으로/위가 있다.
- Sources/IHateFinder/KeyCommands.swift:80-83,97: Alt 화살표와 목록 Backspace를 지원한다.

주소창은 전체 경로를 보여주는 텍스트지만 클릭 가능한 계층 분절 UI는 아니다. NSPathControl/breadcrumb/ancestor 관련 구현을 발견하지 못했고 실제 주소창/메뉴 구성을 읽었다. 깊은 위치의 여러 단계 위 조상으로 즉시 가려면 반복 '위' 또는 직접 경로 편집이 필요하다는 것은 코드에서 유도되는 사용자 결과다.

주의할 문서-코드 차이 후보: docs/behavior.md:11은 '볼륨 최상위에서는 그 경로에 머문다'고 말하지만 BrowserSession.swift:91-94는 부모 URL이 자신과 같은지만 검사한다. 외장 볼륨 '/Volumes/Disk'의 경계에 대한 별도 volume 검사 코드는 없다. 문서 표현과 구현의 정합성을 부모가 실제 GUI에서 확인할 후보이지, 이 보고서에서 runtime bug로 확정하지 않는다.

Apple 비교: https://support.apple.com/guide/mac-help/get-file-folder-and-disk-information-on-mac-mchlp1774/26/mac/26 — 'The location and nested folders ... are displayed', 'Click the folder in the path bar.' Finder는 위치 표시를 조상/계층 탐색에도 사용한다. CONTEXT.md:27-29의 'Avoid: 패스바, 브레드크럼'은 용어 지침으로 읽었으며 계층 보조 UI의 구현 금지로 해석하지 않았다.

### 4. 최근 장소/사용자 장소: 세션 방문 이력과 마지막 폴더는 존재, 재사용할 장소 목록은 없음
- Sources/IHateFinderCore/BrowserSession.swift:21-22,70-76: 방문 스택은 private 메모리 상태이고 persistedState는 PaneState만 만든다.
- Sources/IHateFinderCore/WorkspaceStore.swift:4-19,44-53: 저장 대상은 양쪽 폴더 path, sortColumn, ascending, includeHidden, dual이다. 최근 목록·즐겨찾기·방문 스택 필드는 없다.
- Sources/IHateFinder/BrowserWindowController.swift:848-879: 장소는 홈/데스크탑/문서/다운로드/응용 프로그램과 디스크다. 사용자 장소 추가/삭제/정렬 또는 최근 장소 생성 코드가 없다.
- Sources/IHateFinder/BrowserWindowController.swift:100-102,125-127: 상태 갱신과 저장 연결은 존재한다. '실행할 때 항상 홈으로만 시작한다'는 주장은 틀리다.

사용자 결과: 같은 창의 가까운 과거 위치는 뒤로/앞으로로 오갈 수 있고 마지막 양쪽 폴더는 복원된다. 그러나 자주 쓰는 세 번째/네 번째 프로젝트를 목록에서 선택하거나 앱 재실행 후 과거 여러 장소로 돌아가는 기능은 현재 저장 모델이 제공하지 않는다. 뒤로/앞으로, 최근 폴더, 최근 파일은 서로 다른 개념이다.

Apple 비교: 위 Go to Folder 공식 /26 문서 — 'Recent Folders: Choose a folder from the submenu.' 최근 폴더를 재사용 가능한 목록으로 제공한다.

### 5. folder reachability: 읽기 실패의 안전성은 구현됨, 위치 발견 경로는 제한됨
- Sources/IHateFinder/BrowserWindowController.swift:79-88,523-525: 마운트/언마운트 알림에 sidebar를 갱신한다. 디스크가 정적 목록만인 것은 아니다.
- Sources/IHateFinder/BrowserWindowController.swift:859-870: skipHiddenVolumes, 경로 '/' 또는 '/Volumes/...' 및 volumeIsBrowsable로 디스크를 고른다. 앱이 자동 탐색하는 장소 집합에는 전용 iCloud Drive/Shared/CloudStorage 섹션이 없다. 다만 해당 경로가 로컬에서 읽히면 주소창/홈 경유 접근을 원천 차단하는 코드도 없다. '클라우드 폴더를 전혀 못 연다'는 주장 금지.
- Sources/IHateFinderCore/BrowserSession.swift:118-143: 조회는 메인 스레드 밖이고 generation ticket으로 늦은 옛 결과를 버린다.
- Sources/IHateFinderCore/BrowserSession.swift:145-174,184-203: 성공에서만 URL/entries/history를 확정하고 실패에서는 이전 URL/목록을 유지하며 실패 경로와 이유를 보고한다.
- Sources/IHateFinder/FilePaneController.swift:169-175,237-240: 실패 표시는 빨간 loadStatus와 실패 URL/메시지다.
- Sources/IHateFinderCore/BrowserSession.swift:45-58,184-198: 복원 폴더가 읽히지 않으면 홈, 임시 폴더의 중복 없는 후보를 시도하고 복원 실패 안내를 만든다.
- Tests/IHateFinderCoreTests/BrowserSessionTests.swift:44-81 및 WorkspaceRestoreTests.swift:96-174: 실패한 방문 이력 보존, 저장 폴더 없음/권한 거부 시 대체 위치, 모두 실패 시 정지의 기대값이 존재한다.
- Sources/IHateFinder/OpenRequest.swift:11-21: 외부 입력은 심볼릭 링크 해소 후 일반 폴더면 showFolder, 파일/패키지는 부모 폴더에서 reveal로 분류한다.
- Sources/IHateFinder/BrowserWindowController.swift:202-217: handleOpen이 창을 활성화하고 해당 탐색·선택을 실제 연결한다. 외부 open/reveal이 없다는 진단은 잘못이다.

고정 Desktop/Documents/Downloads는 home 아래 이름을 붙여 만든다(:852-856). 현재 사용자의 실제 iCloud 리다이렉션, 심볼릭 링크, 공급자 상태에서 도달하는지 본 worker는 관찰하지 않았다. 이것은 리드가 실제 앱에서 닫아야 할 리드다. 디스크 범위가 좁다는 코드 관찰만으로 네트워크 볼륨 실패를 단정할 수 없다. /Volumes에 마운트된 네트워크 볼륨도 조건에 들어올 수 있다.

## CLAIMS

C-NF-01 [확정 가능한 구현 범위 주장; G-NAV-SOURCE + G-NAV-DOC]: '현재 Cmd-F는 현재 폴더 이름 거르기이며 하위 폴더 검색이 아니다.' 핵심 anchor EntryFilter.swift:6-9, FileOps.swift:192-223, README.md:235. 짧은 인용 'entries.filter ... name.localizedStandardContains'. observed_at 2026-10-10, valid_at current HEAD. 반증: 폴더 안 이름 찾기는 이미 구현되어 있어 '찾기 기능이 없다'는 문장은 과장이다.

C-NF-02 [강한 부재 주장, 앱 전용 구현 범위 한정; G-NAV-SOURCE + G-APPLE-26]: '주소 입력은 되지만 폴더 경로 후보/완성은 없다.' anchor FilePaneController.swift:482-511,746-749. 인용 'expandingTildeInPath'. 공식 /26 Go to Folder 인용 'matching folders appear'. 같은 날짜/current HEAD 및 Apple26 문서. 반증: ~ 확장과 경로 붙여넣기로 정확한 경로에 가는 통로는 이미 있다. Foundation/NSTextField 기본 동작을 런타임에서 조사하지 않았으므로 모든 텍스트 자동완성이 없다고 확대하지 않는다.

C-NF-03 [확정 가능한 저장 범위 주장; G-NAV-SOURCE]: '방문 이력과 마지막 양쪽 폴더 복원은 있으나 최근 장소/사용자 장소의 영속 목록은 없다.' anchor BrowserSession.swift:21-22,74-76, WorkspaceStore.swift:4-19,44-53, BrowserWindowController.swift:848-879. 인용 'private var backStack' 및 고정 '.place'. 반증: 뒤로/앞으로 및 재실행 복원이 있으므로 '작업 위치를 전혀 기억하지 못한다'는 주장은 잘못이다. WorkspaceContinuity 축과 중복 결합 필요.

C-NF-04 [제품 영향 추론; G-NAV-SOURCE + G-APPLE-26]: '정확한 위치를 기억하는 작업에는 현재 통로가 충분할 수 있지만 위치를 부분적으로만 기억하는 작업은 Finder보다 수작업을 더 요구한다.' 경로 후보 없음/계층 클릭 없음/최근 목록 없음이 근거. 사용자 실제 이동 횟수나 Finder 복귀 원인 실측은 없다. observed_at 같은 날짜, valid_at 코드/문서 각 기준. 반증: 사용자 작업이 두 폴더 사이 이동과 경로 복사 위주라면 검색보다 다른 축의 신뢰/맥 연동이 더 중요할 수 있다.

C-NF-05 [안전성 반증; G-NAV-SOURCE + G-NAV-TEST]: '읽지 못하는 경로로 이동했을 때 이전 목록/경로를 지키는 구현은 이미 있다.' anchor BrowserSession.swift:145-203, BrowserSessionTests.swift:44-81. 인용 'case .failure ... loadState = .failed'. 런타임에서 특정 권한/볼륨 동작을 확인한 주장이 아니다.

C-NF-06 [UX 개선 후보; G-NAV-SOURCE + G-NAV-DOC]: AppDelegate.swift:98 메뉴 이름은 '찾기'인데 입력칸은 '이 폴더에서 이름 거르기'다. 넓은 검색 기대와 실제 범위 사이 오해 가능성은 추론이다. placeholder와 N개 중 M개 표시가 이미 범위를 설명하므로 'UI가 검색이라고 속인다'고 단정하지 않는다. 별도 실제 검색을 추가할 때 Cmd-F와 현재 거르기의 역할/범위를 명시적으로 분리할 판단이 필요하다.

## 개선 순서의 판단 기준
1. 반복 장소 접근이 주작업이면 사용자 장소/최근 장소와 주소창 후보를 묶어 최소 도달 경로를 만든다. 기존 주소창·뒤로/앞으로·마지막 위치 복원을 보존한다. 조상 선택 보조는 전체 경로를 다시 적는 부담을 줄이는 작은 후속 기능이다.
2. 위치를 모르는 파일을 찾는 작업이면 현재 폴더 거르기는 유지하고 별도로 하위 폴더 이름 검색을 제공한다. 검색 범위, 결과의 원래 위치, 진행/취소, 읽지 못한 폴더의 처리, 결과에서 부모 열기·항목 reveal이 핵심 완료 조건이다. 현재 외부 reveal과 pendingReveal은 일부 재사용 가능한 동작 근거지만 검색 구현 설계까지 확정하지 않았다.
3. 전역 Spotlight, 내용/태그/날짜·종류 조건, 저장 검색은 실제 필요를 확인한 뒤 확장한다. 현재 인덱스 연동이 없는 사실이 당장 완전한 Finder 검색 복제품을 요구하지는 않는다. 비인덱스 폴더/네트워크/클라우드 검색 범위의 차이는 후속 설계 판단이다.

## EXPAND
- LEAD NF-L1: 외장 볼륨 최상위에서 '위' — docs/behavior.md:11과 BrowserSession.swift:91-94의 volume 경계 해석 차이. 현재 소스로 명세-구현 차이 후보까지 닫았으며 부모 GUI QA에서 '/Volumes/<disk>'의 부모 동작 확인이 필요하다. 소스만으로 현재 runtime failure 선언하지 않는다.
- LEAD NF-L2: Desktop/Documents의 실제 도달성 — BrowserWindowController.swift:852-856의 home 하위 경로 조립. 현재 사용자 iCloud/파일 공급자/리다이렉션에서 잘 열리는지 DesktopHandoff 또는 부모 실제 앱 관찰로 확인. 전용 sidebar 항목 부재와 폴더 접근 실패를 구분해야 한다.
- LEAD NF-L3: 주소창 입력 경계 — 상대 경로, 빈 입력, file:// URI, trailing/leading whitespace, 심볼릭 링크 경로를 부모가 비파괴 탐색으로 확인. 명시 코드는 tilde expansion과 URL 표준화뿐이다. 외부 OpenRequest에는 symlink 해소가 있어 진입 경로별 해석 차이 후보가 된다. 버그 확정 아님.
- LEAD NF-L4: 목록 타이핑 점프 — docs/behavior.md:40의 시작 이름 점프는 의도다. FileTableView.swift:122-128은 특수 키 외에 super.keyDown으로 넘기고 FilePaneController.swift:541-549는 이름을 cell.textField에 표시한다. typeSelect/TypeSelect/objectValueFor 계열 검색 및 descriptive find에서 앱 전용 구현을 못 찾았다. AppKit 기본 제공 가능성이 있어 '타이핑 점프 미구현'이라고 쓰지 않고 부모 GUI에서 문자 입력 선택 결과를 확인할 대상으로 전달한다.
- LEAD NF-L5: 개선 순서 선택 — 사용자 이동 빈도는 미측정. '이미 아는 3개 프로젝트를 오간다'와 '다운로드/프로젝트 트리에서 위치를 모른다' 중 실제 작업 흐름에 따라 장소 도달성과 검색 순서를 달리해야 한다. Skeptic/WorkspaceContinuity 축에 중복 전달 가능한 판단 후보다.
- DEAD END NF-D1: 현재 폴더 필터를 재귀 검색으로 해석 — EntryFilter.swift:6-9 + FileOps.swift:192-223 + README.md:235로 닫힘. 이름 거르기는 이미 있고 검색 확장은 없다.
- DEAD END NF-D2: '방문 이력/복원/외부 reveal 없음' — BrowserSession.swift:90-111, WorkspaceStore.swift:4-53, BrowserWindowController.swift:202-217의 긍정 구현으로 닫힘.
- DEAD END NF-D3: 기본 Apple /mac 문서의 미래 버전 혼입 — 핵심 세 출처를 /26/mac/26으로 다시 fetch해서 닫음. 위 보고서의 Finder 기능 기준은 Tahoe26 문서다.
- DEAD END NF-D4: 정확한 기능 도입 커밋 추적 — .git/logs/HEAD와 .git/logs/refs/heads/main을 직접 읽어 0970c61 UI 브랜치 fast-forward, 이전 desktop integration/doc rewrite 기록을 확인했다. git 실행 도구가 없는 이 worker에서는 topic diff를 확인할 수 없다. reflog 제목을 기능 도입 증거로 사용하지 않으며 현재 소스 기준 주장에는 영향 없다. 부모에게 git log -p의 추가 가치가 있을 경우만 넘긴다.