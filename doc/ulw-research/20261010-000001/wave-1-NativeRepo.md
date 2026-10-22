# NativeRepo: Nimble Commander 실제 구현 조사

## 범위와 고정 상태
- 저장소: https://github.com/mikekazakov/nimble-commander
- shallow clone: `git clone --depth 1 ... /tmp/ihatefinder-NativeRepo-20261010`.
- 고정 HEAD: `c6a6f5dbcb7902d7afe5f7ba0f1a4d01a2f2bd17`. 커밋 날짜 2026-10-04, 제목 `Don't use [NSWorkspace iconForFileType:]. Fixes #729 (#737)`.
- 아래 코드 관측의 observed_at은 모두 2026-10-10, valid_at은 위 SHA다. observation_group은 `NC-source-navigation`, `NC-source-continuity`, `NC-source-search`, `NC-official-docs`, `NC-history`로 나눈다. 서로 다른 파일의 제어 흐름을 확인했지만 모두 같은 프로젝트에서 나온 자료이므로 독립적인 제품 효과 검증으로 세지 않는다. 공식 사이트/도움말은 구현의 의도를 보강할 뿐 실제 실행 증거가 아니다.
- 외부 앱 실행/빌드/테스트 및 IHateFinder 제품 파일 수정은 하지 않았다. LSP 장치 `xd://lsp`는 마운트되어 있지 않아 find → 실제 범위 read → 관련 문자열 변형 grep으로 추적했다. `Favorite/Frecently/Location/QuickList`, `Recurse/Recursive/FindFiles/Content/Archive`, `spawnNewTab/panelWillBeClosed/ClosedPanelsHistory` 등을 대조했다.

## 고정 SHA 소스 anchors
S1 즐겨찾기 모델/최근 방문 점수:
https://github.com/mikekazakov/nimble-commander/blob/c6a6f5dbcb7902d7afe5f7ba0f1a4d01a2f2bd17/Source/NimbleCommander/NimbleCommander/States/FilePanels/FavoritesImpl.cpp#L94-L162

S2 즐겨찾기/최근 방문 직렬화:
https://github.com/mikekazakov/nimble-commander/blob/c6a6f5dbcb7902d7afe5f7ba0f1a4d01a2f2bd17/Source/NimbleCommander/NimbleCommander/States/FilePanels/FavoritesImpl.cpp#L263-L315

S3 장소 선택과 이동 연결:
https://github.com/mikekazakov/nimble-commander/blob/c6a6f5dbcb7902d7afe5f7ba0f1a4d01a2f2bd17/Source/NimbleCommander/NimbleCommander/States/FilePanels/Actions/ShowGoToPopup.mm#L93-L143

S4 Go To 목록과 유형별 quick lists:
https://github.com/mikekazakov/nimble-commander/blob/c6a6f5dbcb7902d7afe5f7ba0f1a4d01a2f2bd17/Source/NimbleCommander/NimbleCommander/States/FilePanels/Actions/ShowGoToPopup.mm#L333-L472

S5 탭 생성과 닫힌 탭 재개:
https://github.com/mikekazakov/nimble-commander/blob/c6a6f5dbcb7902d7afe5f7ba0f1a4d01a2f2bd17/Source/NimbleCommander/NimbleCommander/States/FilePanels/MainWindowFilePanelState%2BTabsSupport.mm#L136-L236

S6 재귀 검색 엔진:
https://github.com/mikekazakov/nimble-commander/blob/c6a6f5dbcb7902d7afe5f7ba0f1a4d01a2f2bd17/Source/VFS/source/SearchForFiles.cpp#L117-L200

S7 검색 결과의 다음 작업 연결:
https://github.com/mikekazakov/nimble-commander/blob/c6a6f5dbcb7902d7afe5f7ba0f1a4d01a2f2bd17/Source/NimbleCommander/NimbleCommander/States/FilePanels/Actions/FindFiles.mm#L66-L95

S8 별도 Spotlight 경로:
https://github.com/mikekazakov/nimble-commander/blob/c6a6f5dbcb7902d7afe5f7ba0f1a4d01a2f2bd17/Source/NimbleCommander/NimbleCommander/States/FilePanels/Actions/SpotlightSearch.mm#L48-L119

S9 Finder 즐겨찾기 가져오기:
https://github.com/mikekazakov/nimble-commander/blob/c6a6f5dbcb7902d7afe5f7ba0f1a4d01a2f2bd17/Source/NimbleCommander/NimbleCommander/States/FilePanels/FavoriteComposing.mm#L153-L194

S10 검색 UI와 결과 제한:
https://github.com/mikekazakov/nimble-commander/blob/c6a6f5dbcb7902d7afe5f7ba0f1a4d01a2f2bd17/Source/NimbleCommander/NimbleCommander/States/FilePanels/FindFilesSheetController.mm#L400-L550

S11 도움말:
https://github.com/mikekazakov/nimble-commander/blob/c6a6f5dbcb7902d7afe5f7ba0f1a4d01a2f2bd17/Docs/Help.md#L285-L425

## 구현 관측과 반증

### O-NR1: 사용자 장소와 방문 이력은 별도 데이터다 — 구현됨
Group `NC-source-navigation`. `FavoritesImpl.cpp:46-59`는 중복 footprint를 거른 후 `m_Favorites.emplace_back`과 변경 통지를 수행한다. `:94-112`는 방문 횟수와 마지막 방문 시각을 업데이트한다. S1의 `:134-150`은 즐겨찾기에 이미 있는 위치를 자동 후보에서 제외하고 `frequency + recency`로 정렬한다. 범위는 14일이며, S4 `ShowGoToPopup.mm:397-408`은 사용자 즐겨찾기 아래 `FrecentlyUsed(10)`과 `Frequently Visited` 섹션을 붙인다. S2 `:276,284`는 `manual`과 `automatic`을 분리해 저장하고 `:299-313`은 둘을 다시 읽는다.

사용자 결과에 대한 추론: 다운로드/프로젝트/서버처럼 반복해서 돌아가는 위치를 사용자가 직접 고정할 수 있고, 별도로 최근 자주 방문한 위치를 추천받는다. 고정 시스템 폴더가 몇 개 있다는 것과 사용자 작업 장소가 보존된다는 것은 다른 능력이다.

한계/반증: 이것은 완전한 행동 예측기가 아니라 14일 방문 횟수와 최근성의 간단한 점수다. NC의 추천을 사용자가 좋아한다는 실측도 없다. 저장 호출은 `Bootstrap/AppDelegate.mm:544-546`의 정상 앱 종료 경로에서 확인했고 `:691-696`은 동일 설정 경로로 구성한다. 이 사실만으로 크래시 직전 변경까지 내구성이 보장된다고 주장하지 않는다.

### O-NR2: 장소 선택기는 장식 메뉴가 아니라 이동 실행으로 이어진다 — 구현됨
Group `NC-source-navigation`. S3 `ShowGoToPopup.mm:95-120`은 저장 위치, 네이티브 경로, 네트워크 연결, VFS 경로, listing promise를 구별해 처리한다. 네이티브 경로는 `RequestedDirectory`, `PerformAsynchronous = true`, `InitiatedByUser = true`를 채워 `GoToDirWithContext`에 전달한다. 저장 위치는 `:128-142`에서 VFS를 복원한 뒤 같은 이동 요청으로 연결한다.

S4 `:341-369`의 Go To는 Favorites, Volumes, 설정으로 켜는 Connections, 다른 창의 경로를 포함한다. `:234-248`은 다른 창의 현재 경로에서 현재 창과 겹치는 항목과 중복을 제거한다. `:389-472`는 즐겨찾기/볼륨/태그/상위 폴더/히스토리를 각각 별도 quick list로 만든다. 히스토리는 현재 항목을 제거하고 역순으로 보여준다.

사용자 결과에 대한 추론: 목적지를 알아도 다시 트리를 내려가거나 경로를 재입력해야 하는 마찰을 줄이는 데 초점을 둔다. IHateFinder의 장소 선택 개선을 판단할 때 '어떤 위치를 보여줄까'보다 '선택하면 원하는 패널/작업 맥락으로 정확히 이동하는가'가 좋은 기준이다.

반증: 이 자료는 quick list가 모든 사용자에게 사이드바보다 낫다는 증거가 아니다. NC는 공식 사이트 https://magnumbytes.com/ 에서 `Dual-pane file manager with classic design` 및 `Keyboard-centric`를 명시한다. 이 목표와 IHateFinder의 Windows 탐색기 중심 목표가 동일하다는 가정은 두지 않는다.

### O-NR3: 즐겨찾기는 사용자가 관리할 수 있다 — 구현됨, Finder 동기화는 제한됨
Group `NC-source-navigation`. 실제 읽은 `FavoritesWindowController.mm:113-163`은 편집 가능한 제목과 저장 commit을 연결한다. `:205-249`는 드래그 재정렬과 내부/외부 파일 URL 추가, `:262-271`은 제거를 구현한다. `:347-363`의 `onResetToFinderFavorites`는 가져온 목록으로 `m_Favorites`를 교체한다.

추가 anchor:
https://github.com/mikekazakov/nimble-commander/blob/c6a6f5dbcb7902d7afe5f7ba0f1a4d01a2f2bd17/Source/NimbleCommander/NimbleCommander/States/FilePanels/FavoritesWindowController.mm#L205-L271

S9 `FavoriteComposing.mm:155-172`는 deprecated `LSSharedFileList` API 경고를 국소적으로 비활성화하며 `.cannedSearch`/`.savedSearch`를 제외하고 실제 디렉터리만 가져온다. 즐겨찾기가 비어 있을 때 Finder 가져오기를 먼저 시도하고 실패하면 기본 위치를 구성하는 것은 `FavoritesImpl.cpp:27-32`에서 확인했다.

반증: 도움말 S11 `:398`은 이를 `synchronize`라고 표현하지만, 확인한 실행 경로는 초기 가져오기와 명시적 reset이다. Finder와 실시간 양방향 동기화라는 강한 의미로 해석하면 안 된다. 최신 macOS에서 이 deprecated 경로가 실제로 성공하는지도 실행하지 않았으므로 미확인이다. 이 API나 구현을 IHateFinder에 그대로 붙이라는 제안은 하지 않는다.

### O-NR4: 탭은 위치 보존과 실수 복구를 함께 다룬다 — 구현됨
Group `NC-source-continuity`. S5 `:209-234`는 새 PanelController를 만들고 좌/우 탭에 넣은 뒤 원래 패널의 옵션과 현재 listing을 복사한다. `:136-174`는 최근 닫힌 위치 최대 12개를 선택할 수 있는 메뉴를 구성한다. `:191-206`은 선택한 ListingPromise를 새 탭으로 불러오고 닫힌 목록에서 제거한다. `MainWindowFilePanelState.mm:967-971`은 닫히는 패널의 가장 최근 listing을 history에 넣는다. `MainWindowFilePanelState+TabsSupport.mm:372-381`은 다음/이전 탭 이동, `:384-390`은 복수 탭일 때 탭바를 보여주는 조건을 구현한다.

사용자 결과에 대한 추론: 탭의 가치는 탭바 자체보다 'A에서 B로 이동한 뒤 A를 다시 찾아가지 않기'와 '실수로 닫았던 맥락 재개'에 있다. 지속 장소와 검색보다 복잡한 탭 UI가 무조건 먼저 필요하다는 결론은 나오지 않는다.

한계: 확인한 닫힌 탭 복원은 위치/listing promise 경로다. 전체 앱 재시작 뒤 모든 선택/스크롤/검색 상태까지 동일하게 돌아온다는 주장은 이 조사에서 검증하지 않았다. 문서의 단축키 안내도 런타임 성공 증거로 쓰지 않는다.

### O-NR5: 현재 폴더 거르기, 재귀 검색, Spotlight 검색은 별도 작업이다 — 구현됨
Group `NC-source-search`. S6 `SearchForFiles.cpp:119-145`는 디렉터리 FIFO에서 경로를 꺼내 `IterateDirectoryListing`으로 실제 탐색한다. `:193-200`은 `GoIntoSubDirs`일 때 하위 디렉터리를, `LookInArchives`일 때 열린 archive host를 큐에 넣는다. `:165-187`은 이름/크기/내용 조건을 적용한다. `:203-249`는 파일을 열고 FileWindow/SearchInFile로 내용 검색을 수행하며 인코딩, 대소문자, whole phrase, 포함하지 않음 조건을 처리한다.

S10 `FindFilesSheetController.mm:403-416`은 하위 디렉터리/파일 또는 폴더/아카이브 옵션을 실제 엔진 옵션으로 변환하고 `:464-481`은 이름 마스크 및 내용 조건을 전달한다. 반면 S11 `Docs/Help.md:285-292`의 Quick Search는 `locate a file in a folder`와 `filter folder items`로 설명되는 현재 목록 안의 작업이다. 이는 문서 의도 관측이며 Quick Search의 전체 실행 경로를 이 축에서 다시 검증한 것은 아니다.

S8 `SpotlightSearch.mm:55-75`는 `MDQueryCreate`, `MDQueryExecute(... kMDQuerySynchronous)`로 결과 경로를 얻는다. 이 동기 쿼리는 `:108-115`의 패널 loading task 안에서 실행된다. 그러므로 '동기 API를 사용하니 메인 UI가 반드시 막힌다'고 추론하지 않는다. 커스텀 재귀 검색을 읽고 NC 전체가 Spotlight를 사용하지 않는다고 주장하는 것도 틀리다.

사용자 결과에 대한 추론: 파일 위치를 모를 때 필요한 능력은 현재 폴더에서 이름이 맞는 항목만 보이는 능력과 다르다. IHateFinder에 이미 필터가 있다는 사실을 인정한 채, 검색 범위와 결과 활용을 별도로 평가해야 한다.

### O-NR6: 검색 결과가 정상 파일 작업으로 이어진다 — 구현됨
Group `NC-source-search`. S7 `FindFiles.mm:70-71`은 현재 패널/선택 항목의 디렉터리와 host를 검색 시작점으로 잡는다. `:73-80`의 onPanelize는 검색 결과 경로들을 listing으로 구성해 패널에 로드한다. `:85-92`는 검색 결과 선택 시 결과의 디렉터리로 이동하면서 `RequestFocusedEntry = item->filename`을 전달한다. `:98-145`의 viewer 경로는 내용 검색 위치를 viewer의 초기 selection으로 표시한다. S8 `:85-99,109-115`도 Spotlight 결과를 일반 패널 listing으로 구성한다.

사용자 결과에 대한 추론: '찾음'에서 끝나지 않고 '그 파일을 선택한 채 폴더 열기' 또는 '결과 전체를 옮기기/정리하기'로 이어지는 연결이 실제 작업 대체 가능성에 중요하다. 결과 리스트만 추가하고 다음 파일 작업이 Finder를 요구하면 사용자가 다시 Finder를 켤 이유가 남는다. 이는 작업 흐름에 대한 판단이지 사용자 빈도 측정 결과가 아니다.

### O-NR7: 대안 구현도 검색 완전성과 오류 설명에는 한계가 있다 — 제한됨
Group `NC-source-search`. S6 `:144-145`는 코드 자체가 `Deliberately ignoring the errors here`라며 디렉터리 열거 오류를 버린다. 내용 검색 `:208-219`의 파일 생성/열기/창 연결 실패는 false로 돌아온다. S10 `:499-502`에는 stat 실패를 기본 VFSStat으로 바꾸는 실행 코드가 있고 `:516-517`은 결과 수 기준으로 Stop을 호출한다. 결과 상수는 같은 파일 `:25`의 `262144`다.

반증과 해석: 확인한 것은 소스의 제한이지 권한 없는 폴더에서 NC가 실제로 잘못된 결과를 보여준 재현이 아니다. 결과가 적은 이유를 설명하는 UX가 충분한지도 실행하지 않았다. 'NC는 검증된 검색 완전성을 갖추었으니 그대로 벤치마크하자'는 강한 주장을 배제하는 근거로 사용한다. IHateFinder 검색을 검토한다면 성공 결과뿐 아니라 읽을 수 없는 경로/중단/결과 제한의 관측 가능성까지 요구할 수 있다.

## CLAIMS
- C-NR1 / 강한 구현 관측: Nimble Commander는 사용자 고정 장소, 자동 방문 이력, 이동 실행을 분리하되 연결한다. 근거 O-NR1~3. IHateFinder 결핍 판정은 해당 앱의 현재 source/runtime 대조가 필요하며 이 외부 축만으로 미구현을 선언하지 않는다.
- C-NR2 / 강한 구현 관측: 재귀 파일 검색과 Spotlight는 현재 폴더 filtering과 별개 경로이고, 결과를 선택/패널 작업으로 이어준다. 근거 O-NR5~6. 이미 있는 필터/Quick Look/undo/클립보드/drag/open/reveal/default-viewer 설정을 '없다'고 주장하는 데 쓰지 않는다.
- C-NR3 / 제품 판단 후보, 빈도 실측 아님: 다음 개선의 우선순위는 '항목을 조작할 수 있는가'에서 '목적지를 다시 찾지 않고 돌아가는가', '위치를 모르는 파일을 찾아 다음 작업을 끝내는가'로 이동하는 편이 설득력 있다. 사용자 고정 장소/최근 위치를 첫 번째 후보, 범위가 명확한 검색과 결과에서 다음 작업 연결을 같은 핵심 후보로 둔다. 둘 사이의 실제 구현 순서는 IHateFinder 현재 마찰 관측과 사용자의 업무 맥락으로 결정한다. 탭/전체 session 복원은 여러 위치를 병행할 때 가치가 커지므로 그 뒤 후보이며, 단순히 NC가 갖췄다는 이유로 먼저 넣지는 않는다.
- C-NR4 / 범위 제한: NC는 keyboard-centric dual-pane power-user 제품이다. 원격 파일 시스템, archive host, tag query, frecency 알고리즘, GPL 소스 구조를 IHateFinder에 그대로 이식하라는 제안은 성립하지 않는다. 비교에서 가져올 것은 반복 장소 재접근/검색 후 작업/닫힌 맥락 복구라는 완료 조건이다.
- C-NR5 / 반론 후보: 기능 개수나 C++ 구현만으로 NC가 이 사용자에게 더 빠르고 더 좋은 Finder 대체품이라고 판단할 수 없다. 공식 https://magnumbytes.com/ 의 `blazing performance`와 `dozens of windows and tabs`는 제품 주장으로만 기록하며 측정치로 사용하지 않는다. 사이트는 현재 `Version 1.8.0, Build 4282`를 표시하므로 이 페이지의 배포 버전과 고정 개발 HEAD가 같은 바이너리라고 가정하지 않는다.

## Git history 대조
로컬 `git log -- <owned topic paths>`는 depth=1 경계 때문에 HEAD만 출력했다. 변경 시점을 HEAD로 오인하지 않도록 SHA를 지정한 공식 GitHub commits API에서 favorites/quick lists/tabs/search 경로별 이력을 읽었다. 예: https://api.github.com/repos/mikekazakov/nimble-commander/commits?sha=c6a6f5dbcb7902d7afe5f7ba0f1a4d01a2f2bd17&path=Source%2FVFS%2Fsource%2FSearchForFiles.cpp&per_page=3 . 최신 관련 변경 `57a0f8208c8b6b26ad72a73c66e4bd473d2ea920`(2026-09-16)은 clang-format/clang-tidy 작업이므로 기능 도입 증거가 아니다.

탭 이력에서는 https://github.com/mikekazakov/nimble-commander/commit/28901d8a94feb63eefe776d36f98b77e1fc46873 (2026-05-18) `A new Tab Bar control to replace the very old MMTabBarView entirely (#680)` 및 https://github.com/mikekazakov/nimble-commander/commit/6b809eafedd433250a5f71ba69df33dfa07b62ed (2024-10-12) `Fixed a bug with the non-functional Shift+Cmd+R hotkey...`를 확인했다. 이는 과거 변화 기록이며 현재 탭 고장이라는 주장으로 사용하지 않는다. 커밋 메시지와 일부 API 응답은 reader가 길이를 줄였으므로 개별 커밋 전체 diff 검증까지 했다고 주장하지 않는다.

## Cleanup receipt
최종 명령에서 고정 SHA를 다시 출력했고 `git status --porcelain`은 빈 출력, `git rev-parse --is-shallow-repository`는 `true`였다. 이어 정확히 task-owned `/tmp/ihatefinder-NativeRepo-20261010`만 삭제했다. `test ! -e`가 성공하며 다음 receipt가 출력됐다:
`CLEANUP_RECEIPT: /tmp/ihatefinder-NativeRepo-20261010 absent; only owned clone removed`.
제품 코드/문서/journal/설정/git 기록은 수정하지 않았으며 신규 파일 쓰기는 clone 외에 하지 않았다. 외부 clone은 남아 있지 않고 모든 인용은 SHA permalink로 재접근할 수 있다.

## EXPAND
- LEAD NR-E1 / 조사 완료: 즐겨찾기가 실제 저장되는가 → S2 + `AppDelegate.mm:544-546,691-696`까지 추적. 정상 종료 저장은 확인, crash durability는 미확인으로 한정.
- LEAD NR-E2 / 조사 완료: 자동 후보가 최근 목록인지 사용 빈도인지 → S1의 14일 frequency+recency와 S4의 상위 10개까지 확인. IHateFinder에 같은 점수식을 요구하지 않는다.
- LEAD NR-E3 / 조사 완료: quick list가 실제 이동하는가 → S3의 location restore/DirectoryChangeRequest와 S4의 list 구성까지 연결.
- LEAD NR-E4 / 조사 완료: 탭은 맥락 복구를 다루는가 → S5와 `MainWindowFilePanelState.mm:967-971` 확인. 앱 전체 restart/session 완전 복원은 이 assignment의 범위 밖이며 미확인.
- LEAD NR-E5 / 조사 완료: 검색 결과 후 다음 작업은 무엇인가 → S7의 panelize/폴더 이동+파일 focus/내용 viewer 표시 확인. 리드에게 actionable 비교 시나리오: 이름만 아는 하위 폴더 파일을 찾아 파일을 선택한 채 원래 폴더로 이동하고 복사/이동을 끝내는가.
- LEAD NR-E6 / 조사 완료: 커스텀 재귀 검색이 있으니 Spotlight는 없는가 → S8을 별도로 find/read하여 강한 부재 주장을 폐쇄. tag 목록도 S3 `:162-193`에 별도 query→listing 경로가 있어 파일 검색과 섞지 않는다.
- LEAD NR-E7 / 조사 완료: Finder 즐겨찾기 'synchronize'가 양방향인가 → S9 + reset 액션 확인. 현재 읽은 코드는 가져오기/교체이며 실시간 양방향 동기화로 서술하지 않는다.
- LEAD NR-E8 / 조사 완료: 성숙한 대안 검색이 오류/제한을 완전히 설명하는가 → O-NR7의 소스 한계 확인. 리드에게 actionable 비교 시나리오: 읽을 수 없는 경로가 있을 때 검색 0건과 불완전 탐색을 구분할 수 있는가. 현재 외부 runtime 실패로 단언하지 않는다.
- DEAD END NR-E9: 로컬 shallow log만으로 기능 역사 추론은 불가. 공식 SHA-scoped API를 읽어 최근 유지보수/탭 변경 사실만 확보했고 도입일이나 현재 결함의 인과 주장은 하지 않았다.
- DEAD END NR-E10: LSP 장치는 미마운트. 텍스트 추적과 실제 실행 코드 읽기로 대체했으며 심볼 서버 사용을 주장하지 않는다.
- LEAD NR-E11 / 리드 대조 필요: IHateFinder의 실제 고정 장소/최근 위치/검색 범위/검색 결과→작업 연결 상태는 다른 내부 축과 합쳐야 한다. 외부 소스 자체로 내부 앱의 결핍이나 작업 빈도를 결론내리지 않는다.