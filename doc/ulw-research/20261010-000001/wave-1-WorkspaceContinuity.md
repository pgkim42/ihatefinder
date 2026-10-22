# WorkspaceContinuity 조사 보고서

## 결론

현재 구현은 **한 네이티브 창 안의 좌우 두 작업 자리와, 마지막으로 읽기에 성공한 폴더·정렬·숨김 표시·양쪽 창 여부를 보존하는 파일 관리자**다. 복원 자체가 없는 앱으로 평가하면 틀린다. 핵심 결핍은 **사용자가 자주 쓰는 임의의 장소를 등록하는 기능과, 두 자리보다 많은 작업 맥락을 서로 덮어쓰지 않고 유지하는 기능**이다. 사이드바는 즐겨찾기 저장소가 아니라 고정 기본 위치와 동적으로 발견한 디스크 목록이다. 정렬은 폴더별 설정이 아니라 세션별 설정이며, 방문 기록은 실행 중의 URL 스택으로만 유지된다.

우선순위 판단은 사용 빈도 측정이 아니라 작업 마찰에 대한 판단이다. 임의의 작업 폴더 즐겨찾기와 최근 장소를 먼저 제공하고, 그다음 현재 자리의 선택·스크롤과 별도 작업 자리 보존을 확장하는 순서가 타당하다. 다중 창과 탭을 모두 한꺼번에 구현해야 한다는 근거는 없다.

## 조사 조건과 증거 독립성

- observed_at: 2026-10-10. 코드 valid_at: 현재 main, 계약 HEAD `0970c61b2db1f8a1169a82d6a5bf959a89fe6a57`. `.git/HEAD:1`의 `ref: refs/heads/main`과 `.git/logs/refs/heads/main:6`의 마지막 이동 해시를 읽었다. 실제 제품 파일과 설정은 수정하지 않았다.
- G-CODE: 실제 Swift 구현. 아래 구현 관측은 모두 이 그룹이다. 같은 구현을 여러 파일에서 읽었다고 독립 증거로 계산하지 않는다.
- G-TEST-SOURCE: 기존 테스트의 코드와 기대값. 구현과 다른 관측 표면이지만 같은 저장소·작성자의 검증 의도이며, 실행 성공의 독립 증거는 아니다. 이 자식은 테스트를 실행하지 않았다. 부모가 240개 테스트 전부 통과했다고 전달했으나 이 보고서에서 직접 관측한 실행 결과로 취급하지 않는다.
- G-DOC: README/behavior/CONTEXT의 제품 의도. 구현과 독립된 실행 증거가 아니다.
- G-APPLE26: Apple의 영어 공식 문서, `/26/mac/26`로 직접 fetch하여 `macOS Tahoe 26` 선택을 확인했다. 현재 IHateFinder 구현과 독립된 비교 기준이며, 이 Mac의 Finder를 직접 조작한 관측은 아니다. 기본 `/mac` URL은 macOS 27을 반환해 최종 기준에서 제외했다.
- G-HISTORY: 로컬 reflog. 브랜치 이동과 일부 메시지만 관측했으며 특정 기능의 도입 커밋이나 diff까지 확인하지는 못했다. 셸/객체 해석 도구가 제공되지 않아 `git log -p`는 실행하지 않았다. `xd://lsp`도 조회했지만 mounted device가 없어 심볼 탐색은 텍스트 검색으로 대체했다.
- 런타임 화면, 종료·재실행, 외장 디스크 재연결은 이 조사에서 직접 수행하지 않았다. 해당 현재 실패를 주장하지 않는다. 부모의 격리된 GUI QA가 실제 표면 증거를 보완한다.

## 관측 및 정확한 구현 범위

### O-WC-01: 사이드바는 고정 기본 위치 + 디스크이며 사용자 즐겨찾기가 아니다

상태: 기본 장소와 디스크는 구현됨. 임의의 사용자 장소 등록·삭제·재배열·지속 저장은 현재 제품 경로에서 미구현.

- `Sources/IHateFinder/BrowserWindowController.swift:848-881`: `private static func loadPlaces()`가 `.header("위치")` 다음 홈, 데스크탑, 문서, 다운로드, 응용 프로그램을 직접 생성한다. 짧은 인용: `.place(title: "문서", url: home.appendingPathComponent("Documents"), symbol: "doc.text")`.
- 같은 파일 `:860-875`: `mountedVolumeURLs(... options: [.skipHiddenVolumes])`, `guard path == "/" || inVolumes else { continue }`, `if values?.volumeIsBrowsable == false { continue }`. `/` 또는 `/Volumes` 아래의 표시 가능한 볼륨을 추가한다. 볼륨 존재를 즐겨찾기 기능으로 세지 않는다.
- 같은 파일 `:79-89,:523-525`: mount/unmount 알림에서 `places = Self.loadPlaces(); sidebar.reloadData()`로 목록을 새로 만든다. 디스크 목록이 완전히 정적이라는 주장에 대한 반증이다.
- 같은 파일 `:765-770`: `openPlace()`는 선택한 URL을 `focused.navigateSidebar(url)`로 전달한다. 좌우 각각의 즐겨찾기 목록이 아니라 현재 포커스에 적용하는 공통 위치 목록이다.
- 같은 파일 `:546-573`: sidebar target/action은 `openPlace`; 목록 구성에는 사용자 항목 편집 메뉴나 드롭 등록 경로가 없다.
- `Sources/IHateFinderCore/WorkspaceStore.swift:4-19,:45-54`: 영속 상태의 전 필드는 pane의 `path, sortColumn, ascending, includeHidden`, workspace의 `left, right, dual`이다. 즐겨찾기 데이터 필드가 없다.
- 검색 범위: Sources/Tests의 `favorite/favourite/bookmark/pinned/recent/newWindow/newTab`, 저장소 전체의 `즐겨찾기/고정/최근/탭/새 창`, Sources의 `Codable/UserDefaults/JSONEncoder/autosave/restorable`를 교차 검색했다. 이름 검색의 부재만으로 결론 내리지 않고, 실제 목록 생성·액션·저장 스키마를 읽었다.
- G-DOC 보조: `docs/behavior.md:13`의 “위치는 홈, 데스크탑, 문서, 다운로드, 응용 프로그램이다.”는 실제 구현과 일치한다. `CONTEXT.md:31-33`의 “자주 가는 위치”라는 용어가 사용자 정의 즐겨찾기를 뜻하지는 않는다.

사용자 결과 [추론]: 예컨대 프로젝트 폴더나 NAS의 특정 작업 폴더처럼 기본 다섯 위치 밖의 장소로 반복해서 돌아갈 때, 마지막 두 폴더·실행 중 기록·주소 입력에 의존한다. 기본 폴더와 디스크만 쓰는 사용자에게는 이 결핍이 작다.

독립 비교: [Apple 사이드바, macOS 26](https://support.apple.com/en-in/guide/mac-help/mchl83c9e8b8/26/mac/26). 인용: “Add a folder or disk to the sidebar: Drag the item to the Favourites section.” 및 “Rearrange items in the sidebar: Drag an item to a new location.” Finder는 추가·제거·배열 변경을 제공하며 원본은 이동하지 않는다고 명시한다. 이를 Finder 전체를 복제해야 한다는 요구로 확대하지 않는다.

### O-WC-02: 양쪽 창은 실제 두 세션이며 다중 네이티브 창이나 탭은 아니다

상태: 하나 또는 두 pane, pane별 BrowserSession은 구현됨. 제품이 생성·관리하는 다중 창, 임의 개수의 세션, 탭 컬렉션, 저장된 작업 공간 프리셋은 미구현.

- `Sources/IHateFinder/AppDelegate.swift:3-4,:47-55`: `private var browser: BrowserWindowController?` 하나를 보유하고 launch 시 하나를 생성해 `showWindow(nil)`한다.
- 같은 파일 `:84-122`: 파일 메뉴는 새 폴더/새 텍스트 파일, 창 메뉴는 닫기다. 새 네이티브 창이나 새 탭을 생성하는 제품 액션이 없다.
- 같은 파일 `:65-74`: `applicationShouldTerminateAfterLastWindowClosed`는 `true`; terminate에서 저장한다. 마지막 창 닫기는 창만 버리고 별도 작업 세션을 남기는 모델이 아니다.
- `Sources/IHateFinder/BrowserWindowController.swift:5-20,:47-60`: `left`, `right`, `focused`, `dual`과 좌우 BrowserSession을 구성한다. 두 세션의 폴더와 방문 기록은 별개 객체다.
- 같은 파일 `:574-585,:511-520`: 오른쪽은 `rightItem.isCollapsed = !dual`; 토글은 collapse 상태를 바꾼다. 오른쪽 세션을 폐기하거나 새로 생성하지 않는다. 껐다 켜면 실행 중 우측 작업 자리 자체는 유지되는 설계다.
- 같은 파일 `:515`: dual을 켤 때 `paneSplit.setPosition(paneSplit.bounds.width / 2, ofDividerAt: 0)`. 사용자가 정한 분할 비율을 그대로 재사용하지는 않는다.
- G-DOC: `CONTEXT.md:11-13,:51-53`에서 “세션”은 “한 폴더의 위치, 방문 기록, 정렬, 목록을 가진 자리”, “양쪽 창”은 “한 창 안에 세션이 나란히 둘인 상태”로 정의한다. `README.ko.md:233`, `docs/behavior.md:153`은 탭을 범위 밖으로 둔다.

주의: AppKit의 전역 자동 탭 환경을 실험하지 않았으므로 “macOS가 어떤 상황에서도 창을 탭처럼 표시할 수 없다”는 절대 명제는 채택하지 않는다. 확인된 주장은 앱 자체에 추가 browser를 생성·복원하는 경로나 탭 모델이 없다는 것이다.

사용자 결과 [추론]: 복사 원본과 목적지의 두 장소는 동시에 유지할 수 있다. 세 번째 작업을 별도 자리로 붙잡거나 여러 프로젝트를 나란히 비교하려면 기존 pane의 경로를 바꾸거나 Finder/다른 앱의 창을 사용할 가능성이 있다. 두 장소만 사용하는 반복 전송 작업에는 현재 dual pane이 이미 강점이다.

독립 비교: [Apple 폴더 열기, macOS 26](https://support.apple.com/en-kz/guide/mac-help/mchlp1032/26/mac/26). 인용: “you can open a folder in a new tab or window”, “choose File > New Finder Window or press Command-N.” 단일 폴더 Command-double-click과 탭 추가·닫기도 문서화되어 있다.

### O-WC-03: 재실행 복원은 이미 존재하며 마지막 성공 상태만 저장한다

상태: 좌우 경로·정렬 열/방향·숨김 여부·dual 여부의 자동 복원은 구현됨. 여러 작업 공간 저장, 선택·스크롤·방문 기록·창 배치 복원은 스키마 밖이다.

- `Sources/IHateFinderCore/WorkspaceStore.swift:4-19`: PaneState는 절대 경로, sortColumn, ascending, includeHidden. `:45-54`: WorkspaceState는 left/right/dual.
- 같은 파일 `:63-76`: 기본 키 `workspace.v1`의 JSON을 UserDefaults에서 decode한다. 데이터가 없거나 decode가 실패하면 홈/홈, 이름 오름차순, 숨김 false, dual false로 시작한다. `:21-34`는 절대 경로와 known sort column을 검증한다.
- 같은 파일 `:79-94`: state가 같으면 중복 저장을 건너뛰며 `defaults.set(data, forKey: key)`한다. `if let pane = left.persistedState { state.left = pane }` 방식으로 아직 성공하지 않은 pane은 이전 저장값을 유지한다.
- `Sources/IHateFinderCore/BrowserSession.swift:74-76`: `guard revision > 0 else { return nil }`; 성공한 URL만 persistedState로 만든다.
- `Sources/IHateFinder/BrowserWindowController.swift:107-109,:126-138`: `updateStatus()`마다 `saveWorkspace()`를 호출하고 close 시에도 저장한다. 종료 시에만 저장하는 모델이 아니다.
- `Sources/IHateFinder/AppDelegate.swift:69-74`: 종료 가능 여부를 검사하고 terminate에서 다시 저장한다.
- `Sources/IHateFinderCore/BrowserSession.swift:43-60,:122-143`: 복원 init은 정렬/숨김 상태와 fallback 후보만 설정하며 listing은 background queue에서 실행한다. 성공 commit의 revision 증가와 onChange는 `:169-180`.
- G-TEST-SOURCE: `Tests/IHateFinderCoreTests/WorkspaceRestoreTests.swift:9-40`는 좌우 독립 설정 및 single-pane 상태를 decode/reload하고 `XCTAssertFalse(left.canGoBack)`를 기대한다. `:63-93`는 pending navigation이 기존 저장 폴더를 덮어쓰지 않음을 검증하는 테스트다. `:42-60`은 잘못된 저장값의 안전 기본값을 검증한다. 실행 결과는 이 자식이 관측하지 않았다.
- G-DOC: `docs/behavior.md:134`의 “마지막으로 읽기에 성공한 경로”, `README.ko.md:169`의 “정렬 순서, 숨김 파일 설정, 양쪽 창 설정도 그대로”는 코드와 일치한다.

사용자 결과 [추론]: 단순 종료·재실행마다 매번 시작 폴더를 다시 골라야 한다는 비판은 부정확하다. 다만 마지막 위치에 돌아오는 것과 그곳에서 하던 정확한 작업을 재개하는 것은 다르다.

### O-WC-04: 복원 실패의 fallback은 구현됨; 일시적으로 없던 장소를 나중에 자동 회복하는 기능은 별개다

- `Sources/IHateFinderCore/BrowserSession.swift:52-59`: 홈과 임시 디렉터리를 중복 없는 후보로 준비한다.
- 같은 파일 `:185-200`: saved read 실패 시 home, temporary 순으로 시도한다. 모두 실패하면 “위치를 직접 선택해 주세요.” notice와 failed 상태에서 멈춘다. `:151-155`: 대체 폴더 성공 시 원래 경로/실패 이유/대체 경로를 설명한다.
- `Sources/IHateFinder/FilePaneController.swift:243-250,:194-198`: summary가 restorationNotice를 표시하고 loadStatus 및 tooltip에 넣는다. fallback이 코드 안에만 있고 UI 설명 경로가 없다는 주장은 틀리다.
- `Sources/IHateFinderCore/BrowserSession.swift:83-87,:123-125,:141`: 직접 navigation은 restoration을 끝내며 generation 일치 결과만 publish한다. 오래된 시작 복원 결과가 이후 사용자 선택을 덮지 않는 안전장치다.
- G-TEST-SOURCE: `Tests/IHateFinderCoreTests/WorkspaceRestoreTests.swift:96-139`는 home/temp fallback, 오류 설명, 기록 비오염을 다룬다. `:142-175`는 후보 전부 실패와 중복 후보 처리, `:178-207`은 느린 시작 복원이 사용자 이동에 의해 대체되는 경우를 다룬다.

새 리드 [소스 기반 추론]: fallback 성공 경로는 session.url로 commit되고 `persistedState` 및 `saveWorkspace`의 다음 저장 대상이 된다. 처음의 unavailable 경로를 별도 durable 값으로 유지하지 않는다. `NSWorkspace.didMountNotification`의 액션도 sidebar refresh뿐이다(`BrowserWindowController.swift:79-89,:523-525`). 따라서 외장 디스크가 나중에 연결되더라도 원래 작업 경로로 자동 복귀하는 제품 경로는 보이지 않는다. 이것은 현재 복원 실패 버그를 직접 관측했다는 뜻이 아니다. 일시적 외장/NAS 작업 장소 사용 시에만 개선 후보로 의미가 있다.

### O-WC-05: 방문 기록은 pane별 실행 중 URL 스택이며 최근 장소 목록이나 작업 스냅샷이 아니다

- `Sources/IHateFinderCore/BrowserSession.swift:21-22,:71-72,:99-111`: backStack/forwardStack는 `[URL]`이며 현재 session의 뒤로/앞으로에만 사용된다. 공개 방문 목록·최근 장소 메뉴 데이터는 없다.
- 같은 파일 `:157-167`: navigate 성공 때 기존 url을 back에 추가하고 forward를 지운다. back/forward 성공 때만 스택을 옮긴다. `:185-201` 실패 처리에는 스택 변경이 없다. 실패하거나 superseded된 폴더를 방문 기록에 넣지 않는 구현이다.
- `Sources/IHateFinderCore/WorkspaceStore.swift:4-19,:45-54`: back/forward 값은 저장하지 않는다. 재실행하면 기록은 비어 있다.
- `Sources/IHateFinder/AppDelegate.swift:105-109`: 이동 메뉴는 뒤로, 앞으로, 위 세 가지다. 최근 장소 submenu는 없다.
- G-TEST-SOURCE: `Tests/IHateFinderCoreTests/BrowserSessionTests.swift:5-40`는 slow superseded destination을 history에서 제외하고, `:44-82`는 실패한 back/navigation 이후 committed URL·entries·forward history를 유지하는 테스트다.
- `Sources/IHateFinder/FilePaneController.swift:273-286`: 위로 이동 시 `pendingReveal = (origin, false)`로 부모 목록에서 원래 폴더를 선택·노출한다. 이는 일반 history selection 복원과는 다른 명시적 편의 기능이다.

독립 비교: [Apple 특정 폴더 이동, macOS 26](https://support.apple.com/guide/mac-help/go-directly-to-a-specific-folder-on-mac-mchlp1236/26/mac/26). 인용: “Recent Folders: Choose a folder from the submenu.” Finder의 Recent Folders는 직전 기록을 여러 번 뒤로 눌러야 하는 동작과 구분되는 장소 재방문 표면이다. Finder Recents 파일 뷰와도 같은 기능으로 세지 않는다.

사용자 결과 [추론]: 실행 중 두 자리 안에서 되돌아가기는 가능하다. 여러 번 거쳐 갔던 프로젝트 폴더 하나를 고르거나 지난 실행의 장소로 바로 돌아가는 데는 별도 장소 기억이 부족하다.

### O-WC-06: 정렬은 이름/수정 날짜/종류/크기이며 세션 설정이 다음 폴더로 따라간다

- `Sources/IHateFinderCore/FileOps.swift:9-14`: SortColumn은 `name, modified, kind, size` 네 개다.
- 같은 파일 `:374-401`: 이름 정렬에 한해 폴더를 먼저 둔다. 짧은 인용: `if column == .name, a.isDirectory != b.isDirectory { return a.isDirectory }`; 이름은 `localizedStandardCompare`; 나머지 열의 동률은 이름 비교로 처리한다.
- `Sources/IHateFinder/FilePaneController.swift:104-110,:571-575,:845-850`: 네 열의 sortDescriptor를 구성하고 첫 descriptor를 `session.setSort`로 전달한다.
- `Sources/IHateFinderCore/BrowserSession.swift:18-19,:114-119,:130-138`: 세션당 sortColumn/ascending 하나를 변경하고 reload한다. `navigate(to:)`와 commit은 folder별 설정을 로드하지 않는다. 따라서 같은 session에서 다른 folder로 가도 그 정렬이 따라간다.
- `Sources/IHateFinderCore/WorkspaceStore.swift:4-19,:45-54`: 경로별 sort dictionary가 아니라 마지막 좌우 pane의 값만 저장한다.
- 중요한 반례: 좌우의 sort 값 자체는 독립 저장·복원된다. 반면 사용자 숨김 표시 토글은 `Sources/IHateFinder/BrowserWindowController.swift:504-508`에서 `left.session.includeHidden = hidden; right.session.includeHidden = hidden`로 두 session을 동시에 바꾼다. 저장 스키마의 독립성과 현재 UI 명령의 범위를 혼동하면 안 된다.

독립 비교: [Apple 정렬 및 배열, macOS 26](https://support.apple.com/guide/mac-help/mchlp1745/26/mac/26). 인용: “Your settings for sorting and arranging items in a folder apply until you change them.” 및 Documents를 Date Added로 정렬하면 다음 방문에도 같은 정렬이라는 예시. Finder는 폴더별 설정을 공식 약속한다. IHateFinder가 정렬을 못 한다는 주장이 아니라 설정의 귀속 단위가 다르다는 주장이다.

사용자 결과 [추론]: 다운로드는 최신순, 소스 디렉터리는 이름순처럼 장소마다 다른 규칙을 기대하면 재방문 때 다시 정렬해야 한다. 모든 폴더를 동일한 상세 목록/이름순으로 사용하는 사람에게는 세션별 정렬이 오히려 일관적이다.

### O-WC-07: 같은 폴더 갱신 중 선택과 거르기는 유지되지만 폴더 왕복의 정확한 맥락은 보존하지 않는다

- `Sources/IHateFinder/FilePaneController.swift:162-198`: `let selection = editingSelection ?? Set(selectedURLs())`; `sameDirectory`일 때만 URL 기반으로 선택을 복구한다. `if !sameDirectory { resetFilter() }`이고, 선택 predicate에도 `sameDirectory && selection.contains(...)`가 있다.
- 같은 파일 `:328-368`: filter는 NSSearchField의 문자열과 UI 상태이며 visible entry가 남아 있을 때 선택을 보존한다. 폴더가 바뀌면 문자열과 칸을 지운다. 이것은 재귀/Spotlight 검색이 아니다.
- 같은 파일 `:204-220`: pending reveal은 명시적으로 요청된 URL을 선택하고 `table.scrollRowToVisible(row)`한다. 일반 back/forward의 scroll snapshot을 되살리는 코드와는 다르다.
- `Sources/IHateFinderCore/BrowserSession.swift:21-22`: history가 URL만 담는다. 폴더별 selection/filter/scroll snapshot을 담지 않는다.
- G-TEST-SOURCE: `Tests/IHateFinderTests/PreviewAndFilterTests.swift:192-203`는 navigation 때 filter가 사라질 것을 기대한다. `:207-222`는 같은 폴더 reload 후 filter 및 banana.txt 선택이 유지될 것을 기대한다. `:225-242`는 새 항목 reveal이 filter에 가려지면 filter를 해제하고 보이게 한다.

상태 구분: 같은 폴더 reload/외부 변경의 URL 선택 보존은 구현됨. 이전 폴더로 back했을 때 예전 선택·검색어·스크롤을 그대로 가져오는 작업 snapshot은 미구현. 종료 후에도 이 값들이 보존되는 것으로 설명하면 안 된다. 스크롤의 실제 NSTableView 기본 동작은 측정하지 않았으므로 “모든 reload에서 반드시 맨 위로 튄다”는 현재 버그 주장은 하지 않는다.

### O-WC-08: 창 배치·마지막 포커스와 위험한 작업 의도는 저장하지 않는다

- `Sources/IHateFinder/BrowserWindowController.swift:60-69`: 시작 시 `focused = left`, window frame `1120 × 720`, minimum `800 × 480`, `window.center()`.
- 같은 파일 `:634-644`: 첫 responder를 left.table로 두고 sidebar divider는 `200`, dual divider는 반반으로 설정한다.
- `Sources/IHateFinderCore/WorkspaceStore.swift:4-19,:45-54`: window frame, 분할 폭, column width, focused pane, selection, scroll position은 저장 스키마에 없다. Sources의 frame autosave/restorable API 검색에서도 별도 복원 경로는 발견되지 않았다.
- 위험한 의도 보존은 별개: `Sources/IHateFinder/FileClipboard.swift:13-20,:52-72`의 cutSnapshot은 객체 내 메모리이며 새 init에서 복원하지 않는다. 기존 일반 pasteboard의 file URLs는 snapshot에서 다시 읽을 수 있지만 cutSnapshot이 없으면 `isCut: false`로 해석한다. 따라서 “재시작하면 클립보드 내용까지 전부 사라진다”도 잘못된 주장이다.
- `Sources/IHateFinderCore/FileUndo.swift:97-120`: `FileUndoJournal`은 초기 빈 records와 50개 limit를 가진 메모리 객체다. Undo 자체는 구현되어 있으나 undo journal의 재실행 복원은 없다.
- G-TEST-SOURCE: `Tests/IHateFinderCoreTests/WorkspaceRestoreTests.swift:210-237`는 legacy cut/jobs payload를 decode해도 작업을 실행하지 않고 다음 저장에서 제거하는 테스트다.
- G-DOC: `docs/behavior.md:136`은 “잘라두기 의도와 진행 중인 파일 작업은 저장하거나 재실행하지 않는다.”고 명시한다.

판단: 선택·장소·배치의 복원을 늘리는 것과, 재실행 후 이동/undo/진행 작업을 자동 재개하는 것은 구분해야 한다. 위험한 파일 작업 의도를 저장하지 않는 현재 제한은 결핍으로만 평가하지 않는다.

## CLAIMS

- C-WC-01 [채택 후보, 높음]: “사이드바는 있지만 내 프로젝트 폴더를 넣는 즐겨찾기는 없다.” 근거 O-WC-01, G-CODE; G-APPLE26 독립 비교. 정확한 부재는 현재 제품 액션/스키마 범위다. 반증: 기본 위치/동적 디스크는 이미 제공한다.
- C-WC-02 [채택 후보, 높음]: “양쪽 창과 재실행 복원은 이미 있지만, 작업 자리는 최대 두 pane이며 다중 창·탭·작업 공간 저장은 없다.” 근거 O-WC-02/03. 반증: 오른쪽을 껐다 켜도 session 객체를 폐기하지 않고 좌우 마지막 설정도 저장한다. OS의 자동 탭 모든 경우를 실험한 주장은 아니다.
- C-WC-03 [채택 후보, 높음]: “복원은 마지막 폴더와 표시 설정 복원이지, 선택·스크롤·방문 기록·창 배치까지 되살리는 작업 맥락 복원은 아니다.” 근거 O-WC-03/05/07/08. 반증: 같은 폴더 갱신의 선택 보존, goUp의 원래 폴더 reveal은 구현되어 있다.
- C-WC-04 [채택 후보, 높음]: “정렬은 할 수 있고 좌우 독립 복원도 되지만 폴더별 정렬 기억은 없다.” 근거 O-WC-06, Apple 폴더별 정렬 문서. 반증: 모든 폴더에 같은 정렬을 선호하면 현재 동작이 결핍으로 느껴지지 않을 수 있다.
- C-WC-05 [조건부 채택, 중간]: “임의의 작업 장소로 반복해서 돌아가는 마찰을 낮추는 즐겨찾기/최근 장소가 이 축의 첫 개선이다.” 근거 O-WC-01/05와 공식 비교, 단 실제 빈도/선호를 측정한 결론은 아니다. 사용자 작업이 대부분 홈/다운로드와 두 마지막 폴더라면 우선순위가 내려간다.
- C-WC-06 [확장 후보, 소스 추론]: “시작 복원에서 fallback 성공하면 이전 외장 작업 위치가 새 저장 상태에서 대체되며, 재연결 시 자동 복귀 경로가 없다.” 근거 O-WC-04. 현재 런타임 장애/사용자 피해로 단정하지 말고 부모의 별도 시나리오로 확인한다.
- C-WC-07 [채택 후보, 높음]: “작업 맥락 복원을 보강할 때 cut 의도나 미완료 파일 작업을 자동 재개할 필요는 없다.” 근거 O-WC-08와 복원 테스트. 제품 방향 판단이며 현재 안전 제한을 보존하는 권고다.

## 개선 순서와 가정

1. **임의의 작업 장소 등록과 최근 장소로 바로 이동.** 기본 다섯 위치를 늘리는 것보다 사용자 자신의 몇 개 폴더를 저장·삭제·재배열할 수 있게 하는 것이 반복 경로 입력을 줄인다. 첫 범위는 폴더 shortcut이면 충분하며 Finder의 파일/앱 sidebar alias까지 처음부터 복제할 이유는 없다. 기존 좌우 포커스 적용 모델을 유지할 수 있다.
2. **현재 자리의 맥락 보존을 명확히 확장.** back/forward 시 선택·스크롤을 복원하고, 종료 후 최소한 마지막 포커스·창 배치·분할 폭을 유지하는 편의는 “같은 폴더 열기”보다 실제 재개에 가까워진다. 필터를 history에 보존할지는 제품 결정이다. 폴더 변경 시 지우는 현재 동작은 의도와 테스트가 일치하므로 버그 수정으로 포장하지 않는다.
3. **두 자리보다 많은 작업을 유지할 한 가지 표면을 선택.** 새 네이티브 창이나 pane별 탭 중 하나를 먼저 선택한다. 둘 다, 그리고 named workspace까지 동시 구현하는 것은 이 조사로 정당화되지 않는다. 일상 전송에는 현재 dual pane이 이미 유효하다는 반증을 유지한다.
4. **폴더별 정렬 기억은 선택적 개선.** 장소별로 최신순/이름순을 바꾸는 사람에게 가치가 있고, 동일한 정렬을 고수하면 급하지 않다. session 기본값과 folder override의 관계를 먼저 정해야 한다.
5. **외장/NAS 장소의 일시적 부재 복구는 해당 작업을 실제로 쓸 때 보강.** fallback 안내는 이미 존재한다. 원래 위치 유지/재연결 후 돌아가기의 별도 정책이 개선 후보이며, 자동 파일 작업 재개로 확장하지 않는다.

## 역사와 검증 한계

`.git/logs/refs/heads/main:1-6`에는 최초 파일 관리자, “Improve file operation safety and desktop integration”, `merge feat/windows-switcher`, 문서 재작성, UI modernization merge가 있다. 브랜치 이름의 windows-switcher만 보고 다중 창 기능이 있다고 추론해서는 안 된다. 현재 launch/menu/window/pane 코드를 읽은 결과는 하나의 네이티브 browser와 좌우 두 자리다. 복원·즐겨찾기의 실제 도입 커밋은 reflog만으로 판별하지 않았다.

제품 빌드·린트·테스트·포맷터·설정 변경·git 변경을 수행하지 않았다. 자식 프로세스나 임시 사용자 자료를 만들지 않아 정리할 owned resource도 없다. Current runtime failure로 채택한 항목은 없다.

## EXPAND

- LEAD WC-L1 — **외장 디스크 복원 실패 후 원래 장소의 지속 보존**. O-WC-04에서 fallback 성공이 저장 경로를 바꾸고 mount handler는 사이드바만 갱신함을 확인했다. 부모가 격리 설정과 임시 가상 경로로 재실행/재연결 시나리오를 검증하면 C-WC-06을 runtime 관측과 분리해 확정할 수 있다. 제품 수정 없이 재현해야 한다.
- LEAD WC-L2 — **폴더 왕복의 선택·스크롤과 종료 후 배치 체감**. 소스상 snapshot과 durable 필드는 없다(O-WC-07/08). 부모 GUI QA에서 긴 목록 선택 → 다른 폴더 → back, 오른쪽 포커스/분할 변경 → 종료·재실행을 각각 관측하라. “항상 맨 위”나 “선택이 반드시 사라진다” 같은 runtime 표현은 그 전에는 쓰지 않는다.
- LEAD WC-L3 — **추가 작업 자리의 실제 필요**. 세 번째 작업 장소를 열 때 두 기존 장소를 유지하려는 작업이 다중 창/탭의 근거다(O-WC-02). 이 사용자의 빈도는 미측정이다. 현재 dual pane을 무시한 보편적 탭 우선론보다 작업 시나리오를 비교하는 판단이 필요하다. ProductAlternatives 축과 중복 연결 가능.
- LEAD WC-L4 — **장소 모델과 alias/bookmark 안정성**. 현재 저장값은 절대 path 문자열(O-WC-03), sidebar도 고정 경로(O-WC-01)다. 사용자 즐겨찾기를 구현한다면 폴더 이름 변경·이동·볼륨 재마운트에 어떤 계약을 줄지가 새 결정이다. 지금 이름 변경된 saved folder가 실제로 실패했다고 관측한 것은 아니다. DesktopHandoff 축의 볼륨/파일 공급자 조사와 연결하라.
- LEAD WC-L5 — **숨김 설정의 스키마와 UI 범위 차이**. pane마다 독립 저장/복원하지만 toggleHidden은 양쪽을 동기화한다(O-WC-06). 이는 현재 코드의 정확한 차이이며 독립 숨김 토글을 요구할지는 별도 UX 판단이다. InteractionSurface 보고서에 전달할 만한 리드다.
- LEAD WC-L6 — **정렬 비교자의 동치 처리**. `Sources/IHateFinderCore/FileOps.swift:382-399`에서 동치 비교도 `ascending ? ordered : !ordered`로 뒤집는 구현을 읽었다. 동일한 sort key와 localized name 비교가 orderedSame인 두 항목의 내림차순 strict-order 성질은 별도 코드 검토 후보다. 현재 목록 실패/불안정 정렬을 직접 관측하지 않았고 이 축에서 버그로 채택하지 않는다. ScaleFeedback 또는 core 담당에게 범위외 발견으로 반환한다.
- DEAD END WC-D1 — **“복원 없음”, “history 없음”, “정렬 없음”**. O-WC-03/05/06의 구현 및 기존 테스트 소스가 직접 반박한다. 새 구현 대상으로 제안하지 않는다.
- DEAD END WC-D2 — **“클립보드·undo까지 모두 복원해야 작업 지속성이 생김”**. O-WC-08은 일반 pasteboard 내용과 앱의 move intent를 구분한다. 위험 의도 자동 재개 없이 장소·선택·창 배치만 보완할 수 있다.
- DEAD END WC-D3 — **브랜치명 windows-switcher = 다중 네이티브 창**. reflog 메시지는 구현 증거가 아니며 실제 AppDelegate/menu/WorkspaceState는 단일 browser와 두 pane이다.
- DEAD END WC-D4 — **기본 Apple URL을 현재 OS 기준으로 인용**. 기본 URL은 27 선택을 반환했다. 최종 비교는 직접 fetch한 26 URL들로 교체 완료했다.
- DEAD END WC-D5 — **LSP 또는 상세 git diff 실행**. mounted `xd://lsp`가 없고 제공된 도구에 셸/git 실행 기기가 없다. 실제 파일·reflog 읽기를 완료했지만 기능 도입 커밋의 세부 diff는 검증 한계로 남긴다.
