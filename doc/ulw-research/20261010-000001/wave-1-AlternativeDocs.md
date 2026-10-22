# AlternativeDocs: 대안 일차 문서 조사

## 범위와 증거 등급

Marta의 favorites/tabs/actions, QSpace의 workspaces, ForkLift의 quick navigation/search, Nimble Commander의 dual pane/location/selection을 공식 본문으로 조사했다. 웹 검색 20개 query를 사용했고, 핵심 설명은 검색 snippet이 아니라 실제 문서/HTML 본문을 읽었다. 제품 실행, 설치, 성능 측정은 하지 않았다. 따라서 아래의 `문서 확인`은 해당 기능과 사용법이 공식 문서에 명시되어 있다는 관측이며, 경쟁 제품의 현재 바이너리가 실제로 그 동작을 한다는 런타임 검증은 아니다.

공통 observed_at: 2026-10-10. 외부 페이지 valid_at은 개별 문서의 공개 시점 또는 날짜 미표기 현행 웹 문서이며, 로컬 source valid_at은 IHateFinder HEAD 0970c61이다. observation_group은 `ALT-MARTA-DOC`, `ALT-QSPACE-DOC`, `ALT-FORKLIFT-DOC`, `ALT-NIMBLE-DOC`, `LOCAL-STATIC`, `LOCAL-HISTORY`로 구분한다. 서로 다른 회사/프로젝트의 문서는 제품 방향을 비교하는 독립 자료이지만, 한 회사의 landing/manual/changelog는 독립된 실행 증거가 아니다. QSpace 영문/중문 페이지도 같은 문서의 번역이므로 독립 증거로 세지 않는다.

실행 결과로 확인한 것은 읽기 전용 git history뿐이다. 로컬 제품 코드는 관련 저장/거르기/키 입력 경로를 읽었다. build/lint/tests/formatter는 수행하지 않았다. 사용자 설정·파일·제품·journal 수정, 자식 실행, git 기록 변경은 없으며 별도로 정리할 소유 리소스도 없다.

## 핵심 결론

이 네 제품에서 참고할 것은 기능의 총량보다 `다시 찾는 장소`, `동시에 유지하는 작업 맥락`, `찾은 파일을 다음 작업으로 보내는 경로`, `현재 선택과 명령을 분명히 하는 조작 체계`다. Marta는 이름으로 명령과 장소에 접근하는 키보드 체계, QSpace는 여러 폴더와 표시 상태를 하나의 작업으로 복원하는 체계, ForkLift는 빠른 장소/명령 접근과 범위가 구분된 검색, Nimble Commander는 두 패널과 선택의 일관된 조작 체계를 명시한다. 이것은 IHateFinder가 네 제품의 모든 기능을 합쳐야 한다는 근거가 아니다.

IHateFinder에는 이미 좌우 폴더·정렬·숨김·dual 상태 저장과 현재 폴더 거르기가 구현되어 있다. 따라서 `복원 없음`, `검색창 없음`, `dual pane 없음`을 결핍으로 말하면 틀린다. 문서 비교에서 도출할 수 있는 결핍 후보는 `한 번 복원하는 두 위치를 넘는 재사용 가능한 장소/작업 맥락`, `현재 목록 밖에 있는 파일 찾기`, `자주 쓰는 작업을 발견하고 호출하는 통일된 경로`다. 이 우선순위는 사용자의 실제 빈도를 측정한 결과가 아니라 작업 마찰에 대한 판단이며, 최종 미구현 판정은 해당 코드 축 소유자의 전체 경로 조사와 결합해야 한다.

## 제품별 본문 근거

### Marta: 장소와 명령을 이름으로 호출

1. Favorites — https://marta.sh/docs/navigation/favorites/#using-favorites 및 #adding-favorites, #organizing-favorites. 인용: “add locations you visit the most”, “also organize them hierarchically”, “Items on the top can be selected with pressing number keys.” 현행 날짜 미표기 문서, ALT-MARTA-DOC. Favorites 액션 또는 Option+2로 접근하고 숫자로 항목을 선택한다. 현재 폴더를 추가하는 액션, 텍스트 편집기를 통한 그룹·구분선 편집을 구체적으로 설명한다. `기본 Downloads/Desktop 목록`과 `사용자가 추가한 지속적 장소`를 다른 기능으로 다룬다. 사용자 결과에 대한 추론: 프로젝트 폴더를 반복해서 찾아 들어가는 일을 줄일 수 있다. 한계/반증: 관리 UX가 텍스트 DSL이므로 Finder에 익숙한 사람에게 편집 부담이 있을 수 있다. 계층적 즐겨찾기가 무조건 더 편한 것은 아니다.

2. Actions — https://marta.sh/docs/core/actions/#actions-panel 및 #action-bar. 인용: “Enter a few letters of the action name, and the list will be filtered”, “Press Return to run the action”, “Each action has its range of applicability.” 현행 날짜 미표기 문서, ALT-MARTA-DOC. Command+Shift+P에서 명령 이름을 거르고 실행한다. 액션은 단축키·하단 Action Bar·Actions Panel에 공통으로 연결되며, 하단 버튼에 단축키도 표시한다. `기능 존재`뿐 아니라 `사용자가 명령을 발견하는 경로`가 제품의 설계 항목임을 문서로 확인했다. 추론: 메뉴와 단축키를 외우지 못한 사용자의 실행 마찰을 줄이는 모델이다. 한계: 명령 검색창은 기능 자체의 부재나 위험한 실행 의미를 보완하지 못한다.

3. Tabs — https://marta.sh/blog/tabs/#tabs-support. 인용: “press ⌘T to open the new tab and ⌘W to close the active one”, “tab layout is saved on exit.” valid_at: April 2017, Marta 0.2 발표, ALT-MARTA-DOC. 열린 탭 전환과 종료 시 탭 배치 저장을 역사적으로 명시했다. 2017 문서만으로 최신 복원 정확도를 보장할 수 없다. 현행 landing HTML https://marta.sh/ 의 `Windows and Tabs` 블록을 raw로 읽어 “Open as many windows and tabs as you want.”도 확인했다. 현행 탭 제공 주장과 과거 복원 설명을 분리해야 한다. 탭은 동시 맥락을 유지하고, 즐겨찾기는 나중에 다시 찾는 장소를 유지한다. 같은 결핍으로 뭉개지 않는 것이 좋다.

4. 검색 반례 — https://marta.sh/docs/actions/lookup/. 인용: “Look up ... searches globally”, “Look up here ... limits results to the current folder contents”, “Look up uses the Spotlight caches, which may not be available for some directories (such as ... ~/Library).” 현행 날짜 미표기 문서, ALT-MARTA-DOC. landing의 Quick Search와 전역 Look Up은 다른 기능이다. 전역 검색도 모든 위치를 포괄하지 않으므로 `Spotlight 추가 = 모든 파일 찾기 해결`이라고 주장할 수 없다. 처음 시도한 /docs/actions/look-up/는 404였고 검색으로 실제 /docs/actions/lookup/을 찾아 본문을 확인해 리드를 닫았다.

### QSpace: 폴더가 아니라 작업 묶음을 복원

5. Workspace — https://qspace.awehunt.com/en-us/guide/workspace.html (`Concept`, `Options`, `Hotkeys`). 인용: “encompassing the multi-pane layout, sidebar, the folders opened in each pane, and their display modes”, “each tab is an individual workspace”, “Selecting 'Free style' does not auto-save new workspaces.” 현행 날짜 미표기 문서, ALT-QSPACE-DOC. 저장된 workspace는 sidebar/toolbar/custom hotkeys에서 열며 닫기 전 상태로 돌아간다고 설명한다. 새 작업을 창 또는 탭으로 만들고 복제할 수 있다. 사용자 결과에 대한 추론: 다운로드 분류, 프로젝트 소스/산출물, 사진 원본/정리 폴더처럼 여러 위치와 보기 방식이 결합되는 반복 작업의 재구성 비용을 줄이는 모델이다. 반증: Free style은 자동 저장하지 않는다. “QSpace는 언제나 모든 작업을 자동 복원한다”는 표현은 부정확하다. 영문/중문 https://qspace.awehunt.com/zh-cn/guide/workspace.html 의 의미도 대조했으며 번역은 같은 관측 그룹으로 취급한다.

6. Multi-Pane — https://qspace.awehunt.com/en-us/guide/multi-pane.html (`Layout`, `File Actions`, `Options`). 인용: “supports 12 different pane layouts”, “Copy files to the folder opened in a specific pane”, “Current pane Configure the highlight ... of the active pane.” 현행 문서, ALT-QSPACE-DOC. 배치 선택, 특정 pane로 복사/이동, active/inactive pane 표시를 명시한다. 추론: multi-pane의 가치는 분할 개수뿐 아니라 어느 pane가 현재 명령의 출발점/도착점인지 분명히 하는 데 있다. 반증: 12가지 배치는 제품 claim이며 사용자가 12가지 배치가 필요하다는 증거가 아니다. IHateFinder는 기존 두 pane의 전달·초점·복원 품질부터 비교해야 한다.

7. Windows식 경로 입력과 검색 구분 — https://qspace.awehunt.com/en-us/guide/address-bar.html (`Edit`) 인용: “press Command + L to enter address edit mode”, “support for auto-completion suggestions.” https://qspace.awehunt.com/en-us/guide/search.html (`Search in Pane`, `Spotlight Search`) 인용: “Search in subfolders Include subfolders”, “Only supports local files and requires the system's Spotlight index to be enabled.” 현행 문서, ALT-QSPACE-DOC. 경로를 직접 편집하는 제품 방향이 별도로 존재한다. 검색은 현재 pane의 키워드/패턴/정규식, 하위 폴더 포함 여부, Spotlight의 전역/범위/내용/태그로 구분한다. 사용자가 정확한 경로를 아는 경우와 위치를 모르는 경우를 다른 작업으로 다루어야 한다.

### ForkLift: 장소·명령·검색 범위를 빠르게 전환

8. Quick Open — https://blog.binarynights.com/2025/05/27/forklift-4-3-3-is-available/ (`Keyboard Shortcuts in Quick Open and Improved Layout Memory`). 인용: “access favorites and execute menu commands”, “press the Esc key ... start typing the name of the favorite or command”, “displays the keyboard shortcuts next to each result.” valid_at: 4.3.3, 2025-05-27/29, ALT-FORKLIFT-DOC. 장소와 메뉴 명령을 한 검색 목록에서 찾아 실행하고 단축키를 같이 학습하는 모델이다. 이 페이지는 4.3.1부터 single/two-pane 전환 시 second pane 내용을 기억한다고도 명시한다. 추론: 단순히 새 버튼을 더하는 것보다 이미 있는 기능의 발견·호출 경로를 개선할 수 있다. 반증: text field에서 유효한 단축키는 그 텍스트 동작이 우선한다. 또한 같은 changelog는 과거 Quick Open/Go To 활성 중 Command-Delete가 뒤쪽 선택 파일을 삭제하던 문제를 수정했다고 적는다. 기능 존재가 초점 안전성을 보장하는 것은 아니다. 이 과거 버그를 최신 ForkLift 또는 IHateFinder의 현재 런타임 결함으로 옮겨 말하면 안 된다.

9. Search — https://binarynights.com/manual#search. 인용: “offers two search engines”, “brute-force ... scans through all files one by one”, “Search in Subfolders ... all subfolders”, “Spotlights Search only works locally.” 현행 ForkLift 4 quick-start 문서, ALT-FORKLIFT-DOC. 자체 검색은 위치 안의 항목을 훑으며 remote에도 적용하고, 하위 폴더 포함은 명시적 옵션이다. Spotlight는 로컬 파일의 이름/내용을 검색하는 별도 엔진이다. “almost instant”는 공급자 claim이며 내 측정이 아니다. 사용자 결과에 대한 추론: 검색 범위와 방식이 표시되어야 찾지 못한 결과가 진짜 부재인지 범위/인덱스 때문인지 판단할 수 있다.

10. 세부 탐색 의미 — https://blog.binarynights.com/2026/06/16/forklift-4-6-4-is-available-brings-improvements-to-file-navigation/ (`A small update focused on usability improvements and fixes`). 인용: “Quick Select now recognizes accented letters”, “Go to Folder ... aliases and symlinks.” valid_at: 4.6.4, 2026-06-16, ALT-FORKLIFT-DOC. 겉으로 같은 `검색/경로 입력`도 문자 정규화, alias/symlink, 초점 의미 같은 세부에서 일상 조작의 차이가 난다는 설계 근거다. 현재 앱의 같은 문제를 직접 관측했다는 뜻은 아니다.

같은 공식 blog의 https://blog.binarynights.com/2026/06/16/forklift-4-6-4-is-available-brings-improvements-to-file-navigation/#comment-13545 에서는 Frank가 Windows Explorer식 address bar를 요청하고, #comment-13548 의 로그인 계정 agnesbinary가 2026-06-22에 “No, we don’t plan to add such an address bar.”라고 답했다. raw HTML에서 계정·날짜·comment ID를 확인했다. 계정의 사내 직함은 별도 확인하지 않았으므로 공식 사이트의 지원성 답변으로만 취급한다. 이 자료는 `모든 경쟁 제품의 방향이 사용자의 Windows식 경로 작업과 일치한다`는 가정의 반례다. 기능 개수가 많은 경쟁 앱도 사용자가 원하는 핵심 조작과는 다른 방향일 수 있다.

### Nimble Commander: 두 pane와 cursor/selection의 계약

Nimble 공식 Help를 current main에서 읽고, 마지막 Help 수정 commit API https://api.github.com/repos/mikekazakov/nimble-commander/commits?path=Docs/Help.md&per_page=1 를 확인했다. 최신 Help 변경은 faa0c9715850570ac29e35374eaac39905fc9425, 2026-09-26이다. 해당 commit의 Help도 fetch해 아래 section을 확인했다. current main과 pinned 본문의 전체 동일성은 주장하지 않는다. 유효 버전은 `이 commit의 개발 문서`이며 공개 release 바이너리 확인과 구별한다.

11. Dual pane/location — https://github.com/mikekazakov/nimble-commander/blob/faa0c9715850570ac29e35374eaac39905fc9425/Docs/Help.md#navigation 및 #panel-management. 인용: “Only one panel is active at a time”, “stores location history for each file panel”, “quick access to favorite locations, volumes, connections, and locations of other panels.” ALT-NIMBLE-DOC. Tab으로 pane 초점을 옮기고, 각 pane의 경로 history가 따로 있으며, F1/F2 Go To popup에서 장소를 이름으로 거른다. 별도 Quick Lists는 부모·history·favorites·volumes·connections·tags를 나누고 현재 pane 안에 뜬다. https://github.com/mikekazakov/nimble-commander/blob/faa0c9715850570ac29e35374eaac39905fc9425/Docs/Help.md#quick-lists. 추론: dual-pane 제품은 같은 탐색 수단을 양쪽 맥락에 일관되게 적용하는 것이 중요하다. 반증: 두 pane가 필수라는 뜻은 아니다. 문서는 single-pane collapse/toggle도 설명한다.

12. Selection — https://github.com/mikekazakov/nimble-commander/blob/faa0c9715850570ac29e35374eaac39905fc9425/Docs/Help.md#selection. 인용: “diverges from the typical macOS UX”, “moving the cursor does not change the selection”, “filename matching the specified file mask or regular expression.” ALT-NIMBLE-DOC. cursor와 selection을 분리하고 선택 반전, mask/regex, 확장자별 선택·해제를 제공한다. 추론: 비연속 파일을 여러 번 고르는 keyboard-heavy 작업의 후보 모델이다. 반증: macOS/Finder 또는 Windows Explorer의 표준 선택 기대와 의도적으로 다르다. 사용자 맥락 확인 없이 이를 기본 조작으로 이식하면 오히려 전환 비용을 만든다. 선택의 계약을 명료하게 하라는 근거이지 orthodox selection을 무조건 채택하라는 근거가 아니다.

13. Search 결과의 다음 단계 — https://github.com/mikekazakov/nimble-commander/blob/faa0c9715850570ac29e35374eaac39905fc9425/Docs/Help.md#quick-search 및 #searching-for-files. 인용: Quick Search는 “filter folder items”, Find Files는 “To recursively search”, 결과는 “Reveal all found items in a temporary file panel for further actions.” ALT-NIMBLE-DOC. 거르기와 재귀 탐색을 분리하고, 찾은 결과를 일반 작업 pane으로 보낼 수 있다고 명시한다. 추론: 검색의 가치가 결과를 나열하는 데 끝나지 않고, 원래의 복사/이동/열기 작업으로 이어질 때 커진다. 공식 landing https://magnumbytes.com/ 의 File Search도 “feed search results to a panel and manipulate items as if ... a regular directory.”라고 설명한다. landing와 Help는 같은 프로젝트의 관련 주장이지 런타임 독립 검증이 아니다.

14. 이식 범위의 반례 — pinned Help의 `Version Differences`는 sandbox 배포본에서 integrated terminal/admin mode/network mount 등의 제한을 명시한다. landing https://magnumbytes.com/ 은 “charged for power users”, software developers/system administrators/IT professionals를 대상이라고 명시한다. 기능이 많은 전문 도구의 방향과 사용자에게 필요한 Finder 일상 대체 범위를 동일시하지 않아야 한다. “blazing performance”나 “instantaneous”는 공급자 주장으로만 남긴다.

## IHateFinder 교차 대조

- 구현됨: Sources/IHateFinderCore/WorkspaceStore.swift:4-8 의 PaneState는 path/sortColumn/ascending/includeHidden을 보존한다. :45-54 의 WorkspaceState는 left/right/dual을 가지며 :70-83에서 UserDefaults JSON을 load/save한다. Sources/IHateFinder/BrowserWindowController.swift:47-57은 저장 상태로 양쪽 BrowserSession과 dual을 복원한다. LOCAL-STATIC. 짧은 인용: `public var left: PaneState`, `public var right: PaneState`, `public var dual: Bool`. 따라서 “작업 상태 저장 미구현”은 오진이다.
- 제한됨: 위 저장 schema는 한 쌍의 pane 상태다. QSpace의 이름 있는 여러 workspace와 창/탭별 layout/sidebar/view 묶음, Marta/Nimble의 여러 탭을 설명하는 구조와는 범위가 다르다. 이 schema에서 tab/workspace 목록이 보이지 않는 것은 직접 확인했지만, 앱 전체에 다른 구현이 없다는 최종 부재 판정은 이 부분만으로 확정하지 않는다.
- 구현됨: Sources/IHateFinderCore/EntryFilter.swift:6-9의 `entries.filter { $0.name.localizedStandardContains(trimmed) }`, Sources/IHateFinder/FilePaneController.swift:172-177의 `EntryFilter.filter(session.entries, query: filterField.stringValue)`를 확인했다. LOCAL-STATIC. 현재 로드한 entries의 이름 거르기다. 현재 폴더 밖을 걷거나 Spotlight에 질의하는 기능과 구별된다. :173은 폴더를 바꾸면 filter를 reset한다.
- 구현됨: Sources/IHateFinder/KeyCommands.swift:40-45는 Command/Control+L을 focusPath, Command/Control+F를 find로 해석한다. 따라서 “경로 집중 단축키 없음” 또는 “찾기 키 없음”으로 말하지 않는다. `find` enum 이름이 재귀/전역 검색의 증거는 아니다. 조작 의미는 실제 연결 경로와 비교해야 한다.
- 미확인 결핍 후보: Sources 전체 literal 검색에서 `[Ff]avorite|bookmark|[Cc]ustom.*[Ss]idebar`는 no matches였고 `Spotlight|NSMetadataQuery|recursive|filterQuery|EntryFilter`는 현재 거르기 경로만 반환했다. `tab/workspace/session` 검색은 WorkspaceStore/BrowserSession과 호출부를 반환했다. 이 검색만으로 사용자 장소·탭·전역 검색의 완전 부재를 확정하지 않는다. WorkspaceContinuity/NavigationFind가 sidebar, 메뉴, UI 진입점을 포함한 전체 경로로 닫아야 한다.
- git history: 관련 파일 대상 `git log -6 --format='%h %ad %s' --date=short -- Sources/IHateFinderCore/WorkspaceStore.swift Sources/IHateFinderCore/EntryFilter.swift Sources/IHateFinder/KeyCommands.swift`는 22f79b5 (2026-10-04, Windows-switcher keys/mouse/undo/Quick Look/filter/menu), bfa817d (2026-10-04, pure policies), 7670195 (2026-10-02, operation safety/desktop integration)를 반환했다. LOCAL-HISTORY. 최근 feature history를 보지 않고 오래된 기억으로 undo/Quick Look/filter 부재를 주장할 수 없다.

## CLAIMS 후보

C-ALT-1 [높은 문서 신뢰, 중간 제품 추론]: 경쟁 제품은 `기본 위치 목록`을 넘는 사용자 장소와 맥락 보존을 명시적으로 설계한다. Marta Favorites, QSpace Workspace, Nimble Favorites/Tabs가 근거다. 이들은 서로 다른 제품 관측 그룹이므로 제품 방향의 독립 근거다. IHateFinder의 세션 복원 자체는 이미 있으므로 `복원 확장/반복 장소 접근`으로 결핍을 좁혀야 한다.

C-ALT-2 [높은 문서/코드 신뢰]: 현재 폴더 거르기와 재귀·전역 검색은 다른 작업이다. 로컬 EntryFilter와 Marta Look Up, QSpace Search, ForkLift 두 검색 엔진, Nimble Quick Search/Find Files가 직접 대조된다. 다음 구현의 기준은 검색창 추가가 아니라 범위 표시, 중지·진행 상태, 찾은 파일의 위치 공개/열기/기존 작업 연결이어야 한다. 세부 acceptance는 설계 제안이지 관측 사실이 아니다.

C-ALT-3 [높은 문서 신뢰, 조건부 우선순위]: 반복 프로젝트에서 장소 접근과 탭/작업 묶음은 폴더 재구성 마찰을 줄일 가능성이 크다. 실제 사용 빈도를 조사하지 않았으므로 “사용자가 가장 많이 하는 일” 또는 “검색보다 반드시 중요”라고 말하지 않는다.

C-ALT-4 [높은 문서 신뢰, 조건부 제안]: 액션 검색과 단축키 표시를 통해 이미 있는 명령을 발견하게 하는 모델이 Marta/ForkLift에 있다. 구현 기능의 개수와 조작 발견 가능성은 별도 평가 대상이다. 현재 IHateFinder에 palette가 없는지는 본 축에서 최종 판정하지 않았다.

C-ALT-5 [반증용]: 경쟁 제품의 전문 기능·선택 체계·검색 방식이 모두 사용자의 목적에 맞는 것은 아니다. Nimble은 비표준 선택을 명시하고, QSpace Free style은 자동 저장을 하지 않으며, Spotlight 기반 기능은 index/local 제약이 있다. ForkLift 공식 사이트 댓글은 Windows식 address bar를 추가하지 않는 방향을 시사한다. 기능 목록을 무조건 베끼는 결론은 근거가 약하다.

C-ALT-6 [기존 기능 오진 차단]: WorkspaceStore와 BrowserWindowController의 복원, EntryFilter와 FilePaneController의 거르기, KeyCommands의 경로/찾기 진입은 구현되어 있다. 이들을 없다고 하지 않는다. Quick Look/undo/clipboard/drag/open/reveal/default-viewer도 부모의 담당 축 근거와 합쳐 기존 구현으로 다룬다. 본 축은 해당 모든 구현을 새로 감사했다고 주장하지 않는다.

## 우선순위 제안과 가정

P1: 사용자 장소 추가/삭제와 빠른 접근을 후보로 우선한다. 반복적인 경로 입력과 고정 기본 폴더로 돌아가는 마찰을 줄일 수 있다는 판단이다. 전제는 사용자가 같은 프로젝트/대상 폴더를 반복 방문한다는 것이다. 위치가 주로 매번 다르면 검색 쪽이 먼저일 수 있다.
P1 병행 후보: 현재 목록 거르기와 구별되는 로컬 재귀 또는 Spotlight 검색 한 경로를 명료한 범위와 결과 handoff로 완성한다. 전제는 위치를 모르는 파일을 찾는 작업이 실제 Finder 복귀 원인이라는 것이다. 두 엔진, 원격 검색, 정규식, 모든 metadata를 한 번에 붙이라는 제안은 아니다.
P2: 이미 있는 한 쌍 복원을 바탕으로 탭 또는 이름 있는 작업 묶음 중 사용 맥락에 맞는 한 모델을 선택한다. QSpace 12배치 전체나 복잡한 multi-window를 그대로 복제할 이유는 없다.
P2: 메뉴/단축키/toolbar의 발견 가능성을 먼저 다듬고, 명령 개수가 늘어날 때 액션 검색을 고려한다. palette를 먼저 만드는 것만으로 일상 작업의 단절이 해결된다고 보지 않는다.
P3 또는 범위 밖: orthodox selection 전체 이식, embedded terminal, remote protocols, 대량 rename DSL, 전문 attribute 편집. 사용자의 핵심 작업 근거가 붙기 전까지 Finder 대체 최소선의 필수 조건으로 두지 않는다.

## 검색 query 기록

사용한 20개 query: (1) Marta file manager official documentation favorites tabs actions, (2) Marta file manager favorites documentation, (3) Marta file manager tabs documentation, (4) Marta file manager action palette documentation, (5) QSpace official workspaces file manager documentation, (6) QSpace workspace save restore layouts official, (7) ForkLift official user manual quick navigation favorites, (8) ForkLift official search file content recursive search manual, (9) Nimble Commander official dual pane documentation, (10) Nimble Commander location navigation documentation, (11) Nimble Commander file selection documentation, (12) Nimble Commander quick search official manual, (13) site:binarynights.com "Quick Open", (14) site:binarynights.com "Quick Select", (15) site:binarynights.com "Go to Folder", (16) site:marta.sh tabs "0.8", (17) site:qspace.awehunt.com workspace "save", (18) site:marta.sh/docs "Look Up", (19) site:binarynights.com "Quick Open" "favorites" "commands", (20) site:magnumbytes.com "Selection" "Nimble Commander". 무관한 forklift 차량 매뉴얼, QSpace 동명 GitHub 프로젝트, Nimble CRM, mirror 도메인은 근거에서 제외했다.

## EXPAND

LEAD A: 사용자 favorites와 여러 작업 맥락의 정확한 미구현 범위를 WorkspaceContinuity의 sidebar/메뉴/AppDelegate 감사와 결합해서 닫을 것. 이 축은 WorkspaceStore의 기존 복원과 범위 제한을 확인했으므로 `복원 없음`으로 확장하지 말 것.
LEAD B: NavigationFind의 실제 `find` 명령 연결과 검색 범위를 본 축의 EntryFilter/공식 검색 구분과 합칠 것. 결과를 원래 pane에 reveal/open하고 copy/move로 이어가는 경로도 검토 후보다. 검색 엔진의 선택은 새 요구사항으로 확정하지 않았다.
LEAD C: InteractionSurface와 TransferTrust의 초점 계약에 액션/경로/검색 팝업 중 뒤쪽 파일 명령이 실행되지 않는지 검토 후보를 연결할 것. ForkLift의 2025 수정 내역이 리드의 근거이며 IHateFinder의 재현된 결함은 아니다.
LEAD D: Nimble Favorites의 Finder Favorites 동기화 설명은 기존 사용자 장소를 옮겨오기 위한 추가 조사 후보다. https://github.com/mikekazakov/nimble-commander/blob/faa0c9715850570ac29e35374eaac39905fc9425/Docs/Help.md#favorites 에 명시되어 있으나 구현 방식, 접근 권한, 최신 macOS 호환성을 본 축은 확인하지 않았다. 핵심 favorites 추가보다 먼저 필요하다는 뜻은 아니다.
LEAD E: 문자·경로 의미(악센트, alias/symlink, 자동완성)의 현재 구현 품질을 NavigationFind와 대조할 것. ForkLift 4.6.4와 QSpace Address Bar가 문서 근거다. 현재 앱 오류 단정 없이 범위와 acceptance 후보로만 사용해야 한다.
DEAD END F: Marta tabs 복원은 2017 블로그의 역사적 설명까지만 확인했다. 현행 landing의 탭 claim은 확인했지만 최신 바이너리의 종료/복원 정확성을 이 보고서에서 검증하지 않았고, 설치·설정 변경은 담당 scope 밖이다. 현재 런타임 보장 근거로 쓰지 않는 것으로 닫는다.
DEAD END G: QSpace 서버/압축/stash shelf, Nimble terminal/admin/remote, ForkLift sync/remote의 상세 동작은 공식 guide/landing에서 연결을 발견했으나 이번 지정축의 favorites/tabs/actions/workspaces/navigation/search/selection 밖이다. 핵심 Finder 일상 대체 근거 없이 비교 목록을 부풀리지 않는 것으로 닫는다.
DEAD END H: 공급자의 instant/blazing/20x 같은 성능·효율 문구, 사용자 댓글의 crash/slow 주장, 별점/인기도는 실행 관측이 아니다. 성능 결론이나 현재 runtime 실패의 증거로 채택하지 않는 것으로 닫는다.
DEAD END I: 무관 동명 제품/mirror 검색 결과와 잘못된 Marta lookup URL은 공식 원문으로 대체했고, 중요한 본문은 모두 실제 fetch로 확인했다. 추가 미해결 외부 URL 리드는 없다.