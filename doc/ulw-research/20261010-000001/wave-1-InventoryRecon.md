# InventoryRecon 축 보고서

## 결론과 조사 범위

현재 구현은 단순 목록 프로토타입보다 훨씬 넓다. 주소 입력, 탐색 이력, 양쪽 창, 시스템 클립보드, 드래그, 충돌 처리, 취소 가능한 전송, 안전한 실행 취소, Quick Look, 외부 변경 감지, 상태 복원이 연결되어 있다. 따라서 '기본 파일 작업이 대부분 없다'는 결론은 소스 반례와 충돌한다. 주요 결핍 후보는 이미 있는 파일 작업을 다시 만드는 것이 아니라 폴더 위치를 모를 때 찾기, 자주 가는 사용자 위치, 세 개 이상의 작업 위치 유지, 시각 중심 탐색, macOS 특수 작업의 진입점이다.

관측 시점 observed_at은 2026-10-10이다. valid_at은 지정된 현재 브랜치 HEAD 0970c61의 읽은 작업 트리다. 소스·문서·테스트를 읽었고 제품 코드/설정/사용자 파일/문서/저널을 수정하지 않았다. 앱 실행·테스트·빌드·포맷은 수행하지 않았다. 부모가 전달한 '루트 테스트 240개 통과'는 부모 관측이며 이 보고서의 독립 실행 증거로 계산하지 않는다. 이 축은 외부 Finder 문서의 소유자가 아니므로 외부 제품 비교를 중복 조사하지 않았다.

분류의 implemented는 실행 경로가 소스에 구현되어 있다는 뜻이며 현재 GUI에서 직접 성공을 관측했다는 뜻은 아니다. limited는 구현되어 있지만 범위가 좁다는 뜻이다. absent는 제품 자체에 해당 진입점/구현이 확인되지 않으며 명시적 범위 제외 또는 소스 구조로 뒷받침되는 경우다. unknown은 macOS/파일 공급자/실제 환경의 도움으로 가능한지 소스만으로 판정할 수 없는 경우다.

관측 그룹: IR-S는 실행 소스, IR-T는 테스트 본문, IR-D는 README/behavior/CONTEXT의 설계 의도, IR-H는 로컬 reflog, IR-P는 부모 전달. 같은 저장소의 문서와 테스트는 서로 다른 표현이지만 독립 제품 실행 관측이 아니다. 특히 주석과 README를 런타임 성공으로 올려 쓰지 않았다.

## 사용자 기능 인벤토리: 22개

각 항목의 observed_at/valid_at은 위 공통 값을 적용한다. 따옴표는 직접 읽은 짧은 코드·문서 인용이다.

| 번호 | 사용자 기능 / 판정 | 소스 근거와 짧은 인용 | 교차 증거·반례 / 사용자 영향 |
|---|---|---|---|
| 1 | 주소 직접 입력·홈 약어 / implemented | `Sources/IHateFinder/FilePaneController.swift:767-771`, `expandingTildeInPath`; `:268-270`, 주소 포커스 | `docs/behavior.md:16-18`는 Cmd/Ctrl-L, Enter 이동을 명시한다. 경로를 아는 작업은 바로 이동 가능하다. 자동 완성·클릭 가능한 경로 조각은 확인되지 않았다. IR-S/IR-D. |
| 2 | 뒤로·앞으로·상위 / implemented | `Sources/IHateFinderCore/BrowserSession.swift:84-113`, `backStack.last`, `forwardStack.last`; `Sources/IHateFinder/FilePaneController.swift:273-286`, 상위 이동 시 `pendingReveal = (origin, false)` | `Tests/IHateFinderTests/PaneDailyTests.swift:42`의 상위 폴더 재선택 테스트를 검색했고 `docs/behavior.md:11-12`와 일치한다. 과거 위치 이동은 있으나 재실행 후 이력은 저장하지 않는다. IR-S/IR-D/IR-T(테스트명 수준). |
| 3 | 고정 장소·마운트된 디스크 / limited | `Sources/IHateFinder/BrowserWindowController.swift:848-876`, `홈`, `데스크탑`, `문서`, `다운로드`, `응용 프로그램`; `mountedVolumeURLs` | `:78-88`의 마운트/언마운트 알림으로 목록 갱신이 구현된다. '디스크 지원 없음'은 틀리다. 사용자 추가 장소·즐겨찾기 편집은 없다. `docs/behavior.md:13`의 고정 목록과 일치. IR-S/IR-D. |
| 4 | 상세 목록·네 열 정렬·숨김 항목 / implemented | `Sources/IHateFinder/FilePaneController.swift:845-850`, 이름/수정일/종류/크기; `:571-574`, `setSort`; `Sources/IHateFinderCore/FileOps.swift:192-223`, `name.hasPrefix(".")`; `:378-400`, 네 정렬 분기 | `docs/behavior.md:22-28`와 일치한다. 아이콘은 이름 행의 작은 파일 아이콘(`FilePaneController.swift:547-549`)이며 아이콘 보기 모드는 아니다. IR-S/IR-D. |
| 5 | 다중 선택·키보드 조작·이름 점프 / limited | `Sources/IHateFinder/FilePaneController.swift:87-88`, `allowsMultipleSelection = true`; `Sources/IHateFinder/FileTableView.swift:25-39`, Ctrl 선택 토글; `Sources/IHateFinder/BrowserWindowController.swift:664-690`, 명령 디스패치 | `docs/behavior.md:38-40`에 Shift/Cmd/Ctrl 선택과 타이핑 점프가 있다. 다중 선택은 직접 구현 확인, 이름 점프는 `NSTableView` 기본 처리에 위임하며 사용자 설정 키맵은 없다. '키보드 친화 기능 없음'이라는 결론은 반례가 많다. IR-S/IR-D. |
| 6 | 파일 열기·여러 파일 열기·다른 앱 / implemented | `Sources/IHateFinder/FilePaneController.swift:294-310`, `OpenPlan.make`; `:17-21`, `urlsForApplications(toOpen:)`, `open(...withApplicationAt:)`; `:724-729`, 선택 파일 전체 전달 | `Tests/IHateFinderTests/ContextMenuTests.swift:77-97` 실제 본문에 공통 앱/기본 앱 우선/선택 앱 전달 assertion이 있다. 대량 열기 확인은 `:314-319`, 파일·폴더 혼합 규칙은 문서 `docs/behavior.md:9-10`. 외부 앱 실행 결과 자체는 이 축에서 미관측. IR-S/IR-T/IR-D. |
| 7 | 복사·잘라두기·붙여넣기·Finder 클립보드 / implemented | `Sources/IHateFinder/BrowserWindowController.swift:481-498`; `Sources/IHateFinder/FileClipboard.swift:52-73`, `.fileURL`만 수용; `:104-123`, 잘라두기 해제와 NSURL 쓰기 | `Tests/IHateFinderTests/FileClipboardTests.swift:7-58` 본문이 외부 NSURL 소비 가능, 외부 입력을 복사로 취급, 텍스트·원격 URL·혼합 입력 거부를 검증한다. 'Finder와 복사 불가'는 틀리며, 외부 앱으로 이동 의도를 내보내는 기능과는 다르다. IR-S/IR-T. |
| 8 | 드래그 복사·이동 / implemented | `Sources/IHateFinder/FilePaneController.swift:591-638`, `validateDrop`, `acceptDrop`, `browser?.drop`; `:640-657` 부근에서 볼륨 기준 정책 사용 | 같은 볼륨/다른 볼륨/Option/Command 규칙은 `Sources/IHateFinderCore/DropPolicy.swift:21-30` 검색 결과 및 `docs/behavior.md:122-124`로 교차 확인. 외부 Finder 드래그의 실제 GUI 이벤트는 부모 QA 대상이다. IR-S/IR-D. |
| 9 | 양쪽 창·반대쪽 복사/이동 / implemented | `Sources/IHateFinder/BrowserWindowController.swift:511-521`, `splitViewItems[1].isCollapsed = !dual`; `:694-708`, `guard dual`, `other().session.url` | `docs/behavior.md:126-130`와 일치한다. 좌우 두 위치 작업은 있으므로 탭 부재를 '한 폴더만 작업 가능'으로 표현하면 틀린다. IR-S/IR-D. |
| 10 | 새 폴더·빈 텍스트 파일·바로 이름 입력 / implemented | `Sources/IHateFinderCore/FileOps.swift:225-239`, `새 폴더`, `새 텍스트 문서.txt`; `Sources/IHateFinder/FilePaneController.swift:433-454`, `revealAfterReload(...rename: true)` | `docs/behavior.md:92`가 즉시 선택·이름 편집을 명시한다. 거르기가 새 파일을 가리면 해제하는 반례도 `FilePaneController.swift:209-218`에 있다. IR-S/IR-D. |
| 11 | 이름 변경 / limited | `Sources/IHateFinder/FilePaneController.swift:419-430`, `let row = table.selectedRow`; `:515-534`, `ops.rename`; `Sources/IHateFinderCore/FileOps.swift:337-374`, 충돌·대소문자만 변경 처리 | 한 항목 이름 변경과 확장자 제외 선택은 구현되었다. 다중 선택에서도 일괄 이름 변경이 아니라 선택 행 하나를 편집한다. '이름 변경 없음'과 '대량 이름 변경 없음'은 구별해야 한다. IR-S. |
| 12 | 휴지통 이동 / implemented | `Sources/IHateFinder/FilePaneController.swift:457-466`; `Sources/IHateFinderCore/FileOps.swift:310-331`, `try moveToTrash(url)`, 첫 실패 이후 미처리 | `docs/behavior.md:88-94`는 직접 삭제를 제공하지 않는다고 명시한다. 영구 삭제 부재는 의도한 안전 경계이지 휴지통 이동 부재가 아니다. IR-S/IR-D. |
| 13 | 충돌 선택·교체 보존·실패 복구 / implemented | `Sources/IHateFinder/BrowserWindowController.swift:739-762`, `바꾸기`, `건너뛰기`, `둘 다 유지`, 남은 항목 적용; `Sources/IHateFinderCore/FileOps.swift:419-460`, 정책 분기; `:490-615`, stage/previous/rollback 및 recovery 위치 | `FileOps.swift:538-559`에는 복구 실패 때 유일한 원본이 든 stage를 삭제하지 않는 실행 코드가 있다. '안전장치 전무'는 틀리다. 다만 실제 모든 디스크·권한 상황의 성공을 증명하지 않는다. IR-S. |
| 14 | 긴 전송 진행·취소·부분 결과 / limited | `Sources/IHateFinder/BrowserWindowController.swift:315-375`, 백그라운드 전송·취소 UI; `:410-472`, 현재 파일/항목/바이트·결과 시트; `Sources/IHateFinderCore/FileOps.swift:264-305`, 실패/취소 후 `.unprocessed` | `Tests/IHateFinderCoreTests/FileTransferProgressTests.swift:23-100` 본문은 중간 바이트 취소 시 원본·기존 대상 보존과 stage 청소를 검증한다. 처리 큐/병렬 작업은 없고 `BrowserWindowController.swift:248-250` 및 `:316-320`의 `busy` 거부가 적용된다. 전체 폴더 총량/ETA/일시정지는 확인되지 않았다. IR-S/IR-T. |
| 15 | 파일 작업 실행 취소 / limited | `Sources/IHateFinder/BrowserWindowController.swift:285-311`, journal pop 후 `ops.undo`; `Sources/IHateFinderCore/FileUndo.swift:43-49`, 생성/복사/이동/이름/휴지통 유형; `:99-114`, `limit = 50`, 메모리 journal | `Tests/IHateFinderTests/UndoWiringTests.swift:115-154,174-213` 본문에서 busy 거부·메뉴·drag 이동 복구·바뀐 항목 건너뜀을 확인했다. `FileUndo.swift:14-26`는 영속 ID 없는 볼륨을 확인 불가로 처리하고 `Tests/IHateFinderCoreTests/FileUndoSafetyTests.swift:75-95` 본문은 `.unverifiable`을 검증한다. 존재하지만 모든 디스크에서 항상 되돌리는 계약은 아니다. IR-S/IR-T. |
| 16 | 파일 작업 다시 실행 / absent | `Sources/IHateFinder/FileTableView.swift:65-66`, `redo(_ sender: Any?) {}`; `:100-102`, `return false` | 반례: `Sources/IHateFinder/KeyCommands.swift:49-50`에는 redo 라우팅이 있고 글상자는 글자 다시 실행을 지원한다. 따라서 '다시 실행 전부 없음'이 아니라 '파일 작업 redo 없음'이 정확하다. `README.ko.md:236`도 명시한다. IR-S/IR-D. |
| 17 | Quick Look / implemented | `Sources/IHateFinder/FilePaneController.swift:376-415`, `QLPreviewPanel.shared`, 선택 URL 데이터 소스, 선택 변화 재로드; `Sources/IHateFinder/FileTableView.swift:108-151`, Space/Cmd-Y 및 panel controller | `Tests/IHateFinderTests/PreviewAndFilterTests.swift:58-94` 본문은 키 규칙·선택 순서·화살표 목록 이동·Esc 위임을 검증한다. Quick Look 부재는 명백한 오진이다. 실제 파일 형식별 렌더 성공은 미관측. IR-S/IR-T. |
| 18 | 현재 폴더 이름 거르기 / implemented | `Sources/IHateFinderCore/EntryFilter.swift:6-9`, `entries.filter { $0.name.localizedStandardContains(trimmed) }`; `Sources/IHateFinder/FilePaneController.swift:361-371`, `session.entries` 재필터 | `Tests/IHateFinderCoreTests/EntryFilterTests.swift:16-40` 본문은 한글/대소문자/악센트/공백을 검증한다. `Tests/IHateFinderTests/PreviewAndFilterTests.swift:161-242`는 선택·Esc·이동 시 해제·재읽기·새 항목 reveal을 검증한다. 검색 칸 부재라고 말하면 틀린다. IR-S/IR-T. |
| 19 | 재귀·Spotlight·내용·속성 검색 / absent | `Sources/IHateFinderCore/FileOps.swift:197-201`, `contentsOfDirectory`; `Sources/IHateFinderCore/EntryFilter.swift:6-9`, 이미 읽은 항목 이름만 검사 | `README.ko.md:129,235`, '하위 폴더는 보지 않습니다', '하위 폴더까지 찾기' 부재와 일치한다. 이름 거르기와 타입 점프는 반례지만 재귀 검색을 제공하지 않는다. `COPYFILE_RECURSIVE`는 파일 복사용이며 검색 반례가 아니다. IR-S/IR-D. |
| 20 | 정보·경로 복사·Terminal·ZIP 압축 / limited | `Sources/IHateFinder/FilePaneController.swift:732-764`, 각 동작; `Sources/IHateFinder/InfoPanel.swift:21-34,40-58`, 읽기 전용 metadata; `Sources/IHateFinderCore/Compress.swift:37-95,104-107`, ditto ZIP·stage·취소·고유 이름 | `Tests/IHateFinderTests/ContextMenuTests.swift:44-74,113-132,171-191` 본문은 압축/정보 단일 선택 제한·Terminal 위치·정보 필드를 검증한다. 다중 항목 묶음 압축/압축 탐색/자체 압축 해제·권한 편집은 확인되지 않았다. 반례: ZIP를 열면 시스템 기본 앱으로 해제될 수 있으므로 'ZIP 해제가 전혀 불가'라고 단정하지 않는다. IR-S/IR-T. |
| 21 | 외부 변경 갱신·상태 복원 / limited | `Sources/IHateFinderCore/DirectoryObserver.swift:51-113,136-173`, vnode+FSEvents; `Sources/IHateFinderCore/BrowserSession.swift:137-180`, generation 검사와 observer; `Sources/IHateFinderCore/WorkspaceStore.swift:4-8,45-49,88-95`, 경로/정렬/숨김/dual 저장 | `Tests/IHateFinderCoreTests/BrowserSessionTests.swift:108-145` 본문은 외부 생성/이름/내용/삭제/폴더 교체 후 갱신을 검증한다. `WorkspaceRestoreTests.swift:10-39,64-138,210-242` 본문은 저장/대체 위치/작업 재실행 안 함을 검증한다. 선택/스크롤/탐색 이력/필터/창 geometry 저장은 schema에 없다. '외부 갱신 없음', '재시작 복원 없음'은 틀리다. IR-S/IR-T. |
| 22 | 외부 open/reveal·기본 파일 뷰어 / limited | `Sources/IHateFinder/AppDelegate.swift:10-25`의 이벤트 등록은 검색으로 확인; `:47-57`, 대기 요청 처리; `Sources/IHateFinder/BrowserWindowController.swift:204-218`, 폴더 이동/파일 선택; `Sources/IHateFinder/OpenRequest.swift:11-35`, 첫 유효 URL | `Tests/IHateFinderTests/OpenHandlingTests.swift:7-48` 본문은 이동·선택·파일 불변을 검증한다. `README.ko.md:174-198`는 사용자가 바꾸는 기본 뷰어 설정이고 `:220-227`는 열기/저장·데스크탑·Dock·직접 Finder 호출 한계를 명시한다. 앱이 시스템 설정을 자동 변경하지 않는 것과 요청 처리 미구현은 다르다. IR-S/IR-T/IR-D. |

## 추가 결핍 후보와 unknown 경계

- 사용자 즐겨찾기 추가/재정렬, 탭, 별도 새 창, 아이콘·열 보기: absent. `BrowserWindowController.swift:848-876`는 고정 목록+마운트 디스크만 생성하고 `WorkspaceStore.swift:45-49`는 두 pane만 저장한다. `AppDelegate.swift:47-53`는 브라우저 하나를 만들고 `:108-110`의 창 메뉴는 닫기뿐이다. `README.ko.md:233-235`와 `docs/behavior.md:153`에는 탭/다른 보기/재귀 찾기가 명시적 제외다. 반례는 양쪽 창, 창 크기 조절, 행 파일 아이콘이며 이들은 해당 기능과 다르다. IR-S/IR-D, observed_at/valid_at 공통.
- 태그 편집·공유/AirDrop 진입점·디스크 꺼내기·서버 접속 UI: 제품 진입점 absent의 중간 신뢰 후보. 메뉴 전체(`AppDelegate.swift:77-113`, `FilePaneController.swift:780-818`)를 읽었고 세 가지 관련 검색 파형에서 해당 구현을 찾지 못했다. 하지만 mountedVolumeURLs·마운트 알림·경로 직접 입력은 이미 마운트된 네트워크 위치를 다룰 수 있는 반례다. 따라서 '네트워크 드라이브 지원 없음'으로 확대하지 않는다. IR-S, observed_at/valid_at 공통.
- iCloud/File Provider placeholder 다운로드 상태·오프라인 파일·원격 볼륨 상세 동작: unknown. 전용 `NSFileProvider`, `NSFileCoordinator`, `downloadUbiquitousItem` 경로는 검색되지 않았지만 일반 URL/FileManager/copyfile 경로가 OS와 공급자의 지원을 받을 수 있다. '클라우드 파일이 안 열린다/복사가 깨진다'는 현재 실행 증거가 없다. IR-S, observed_at/valid_at 공통.
- package contents 탐색: UI 진입점 absent의 후보. `FileOps.swift:208-211`과 `OpenRequest.swift:17-20`는 패키지를 폴더 탐색 대상에서 제외한다. 다만 직접 주소 입력으로 패키지 내부 경로를 열 수 있을 가능성이 있으므로 '내용 접근 불가능'은 금지하고 'Show Package Contents 진입점 없음'으로 한정한다.

## 누락 주장에 대한 반례와 역사

IR-H: `.git/logs/HEAD:3-4`에는 같은 폴더 복사 관련 `test: expect a copy in the same folder to duplicate`, `fix: duplicate a file copied into its own folder`가 남아 있다. 현재 `FileOps.swift:429-451`은 같은 경로 이동 no-op, 같은 경로 복사 replace skip, keepBoth 이름 생성으로 연결된다. 과거 결함을 현재 결함으로 옮겨 적지 않는다.

IR-H: `.git/logs/refs/heads/main:3`에는 7670195의 `Improve file operation safety and desktop integration`, `:6`에는 0970c61로 UI 현대화 브랜치 fast-forward가 기록된다. reflog는 이동/메시지 증거이며 커밋 diff 증거가 아니다. 이 세션에는 셸·git history 도구가 노출되지 않아 각 기능 도입 커밋 diff까지는 확인하지 못했다. 실행 취소/Quick Look/filter가 언제 도입됐는지는 이 역사만으로 특정하지 않는다.

IR-S 반례: `DirectoryObserver.swift:136-141`는 `realpath` 후 `canonicalPath = String(cString: resolved)`를 사용한다. 과거 `/private/var` 불일치가 지금도 남았다는 추정에 반대되는 현재 코드다. 이 축은 당시 실패 재현이나 현재 런타임 실패를 관측하지 않았다.

## CLAIMS

- IR-C1, 높은 소스 신뢰: '이 앱은 기본 파일 이동·복구 작업과 Quick Look·현재 폴더 거르기를 이미 가진다.' 관측 후보 IR-O1~O3: `BrowserWindowController.swift:285-375`, `FilePaneController.swift:376-415`, `EntryFilter.swift:6-9`. IR-S, 같은 저장소 구현 묶음으로 독립 실행 관측은 아니다. 부모 실제 GUI QA가 성공/한계 증거를 추가해야 한다.
- IR-C2, 높은 신뢰: '폴더 위치를 모르는 탐색에서 현재 이름 거르기는 재귀/속성 검색의 대안이 아니다.' IR-O4: `FileOps.swift:197-201`, `EntryFilter.swift:6-9`; IR-D 반례 검토 `README.ko.md:129,235`. 사용자 영향은 하위 폴더 탐색을 직접 반복하거나 다른 검색 도구를 여는 마찰이다. 실제 빈도는 측정하지 않았다.
- IR-C3, 높은 신뢰: '기억해 둔 작업 위치는 좌우 두 경로와 정렬/숨김/dual에 한정된다.' IR-O5: `WorkspaceStore.swift:4-8,45-49`, `BrowserWindowController.swift:848-876`. 반례는 경로 복원/방문 이력/양쪽 창이 이미 존재한다는 점이다. 즐겨찾기나 탭을 추가할 때 해당 기능을 '맥락 보존 최초 구현'으로 표현하면 안 된다.
- IR-C4, 높은 신뢰: 'undo 존재와 redo 부재, 안전상 undo 거부는 서로 다른 사실이다.' IR-O6: `FileTableView.swift:65-66,100-102`, `FileUndo.swift:14-26,99-114`, `FileUndoSafetyTests.swift:75-95`. FAT/exFAT/일부 네트워크 환경에서 체감 제약이 될 수 있지만 특정 실제 볼륨 실패는 미관측이다.
- IR-C5, 중간 신뢰: '전송은 안전·피드백 기능이 있지만 여러 작업을 줄 세워 운영하는 UI는 없다.' IR-O7: `BrowserWindowController.swift:248-250,316-320,410-472`. 반례는 취소/결과/복구 위치/백그라운드 수행이 이미 있다는 것이다. 현재 앱이 전송 때문에 멈춘다는 주장은 지지하지 않는다.
- IR-C6, 높은 신뢰: '외부 show/reveal 처리는 구현됐고 기본 뷰어 설정도 문서화돼 있지만 macOS 전체 Finder를 대체하는 범위는 아니다.' IR-O8: `OpenRequest.swift:11-35`, `BrowserWindowController.swift:204-218`, `README.ko.md:220-227`. 실제 LaunchServices 선택 여부는 이 축에서 unknown이다.

모든 CLAIMS의 observed_at=2026-10-10, valid_at=0970c61 현재 작업 트리. IR-T가 붙은 주장은 테스트 계약을 읽었다는 뜻이다. 테스트 자체는 실행하지 않았으므로 관측 독립성 표에서 run 증거를 별도로 요구한다.

## 개선 순서 판단

1. P1: 폴더를 알고 다시 방문하는 작업의 마찰을 줄이는 사용자 장소/즐겨찾기, 폴더를 모르는 작업의 마찰을 줄이는 실제 검색을 우선 후보로 둔다. 둘 중 선후는 사용자의 구체적 최근 시나리오에 따라 결정해야 하며 이 인벤토리만으로 '검색이 반드시 1순위'라고 고정할 수 없다.
2. P2: 세 위치 이상 오가는 작업에서 탭/복수 창 또는 명시적 작업 위치 전환을 추가한다. 기존 두 pane 복원 위에 쌓는다. 사용자가 사진·이미지 중심이면 아이콘/썸네일 보기의 우선순위가 올라간다.
3. P2~P3: 전송 큐·재시도·과거 결과 재접근, 일괄 이름 변경, 여러 항목 압축은 실제 운영 작업이 확인될 때 올린다. 현재 오류 모달과 per-job 결과만으로 부족하다는 판단은 작업 마찰 추론이지 현재 데이터 손실 관측이 아니다.
4. P3: 태그·공유·꺼내기·클라우드 상태·서버 접속은 macOS 생활 작업에서 반복되는 경로인지 확인 후 선택한다. Finder의 모든 기능 체크리스트를 복제하려고 우선순위를 부풀리지 않는다.

이 순위는 빈도 측정이 아니라 구현 결핍이 만드는 작업 마찰에 대한 명시적 판단이다. redo·영구 삭제·뷰 모드 등을 모두 같은 급의 blocker로 묶지 않는다.

## 검증 한계와 보조 발견

부모의 실제 GUI QA가 필수인 항목은 Quick Look 실제 패널, 외부 app open, Finder 드래그, 기본 뷰어 라우팅, 실제 디스크·공급자 동작이다. 소스 읽기만으로 실행 실패를 선언할 수 없다.

테스트 품질의 별도 보조 발견: `Tests/IHateFinderTests/PreviewAndFilterTests.swift:36-39`, `Tests/IHateFinderTests/OpenHandlingTests.swift:20-23,41-44`, `Tests/IHateFinderTests/BrowserTestSupport.swift:47-56`는 고정 지연 polling을 사용한다. `Tests/IHateFinderCoreTests/CompressTests.swift:106`은 0.1초 후 취소를 예약한다. 반례로 `Tests/IHateFinderCoreTests/BrowserSessionTests.swift:122-130,158-168`은 변경 구독을 먼저 설치하고 bounded expectation을 기다린다. 전자는 현재 flaky 실패 관측이 아니라 비결정성 위험 후보다. 이번 연구에서는 테스트를 수정하지 않았다.

## EXPAND

- LEAD -> NavigationFind: 즐겨찾기/자동 완성/재귀 검색 중 어느 작업이 Finder 복귀를 줄이는지 최종 작업 시나리오에 연결. 코드에서 고정 장소와 직접 경로 입력은 반례가 확실하다. 신규 조사로 기능 전체를 다시 열 필요는 없다.
- LEAD -> WorkspaceContinuity: `WorkspaceStore.swift:4-8,45-49` schema에 없는 선택·스크롤·창 크기·열 너비·포커스·방문 이력 보존을 정확히 구별. 이미 두 pane 경로/정렬/숨김/dual은 저장한다. 사용자 즐겨찾기와 탭은 후보이지 사용자가 실제 원하는 방식으로 확정된 것은 아니다.
- LEAD -> DesktopHandoff: 공유/태그/꺼내기/서버 접속 진입점 absence와 mounted/network URL의 일반 파일 작업 가능성을 분리. iCloud/File Provider는 unknown 유지 후 부모가 실제 안전한 read-only surface를 관측할 때만 좁힌다.
- LEAD -> TransferTrust: 영속 ID 없는 볼륨의 `.unverifiable`, undo 50개/메모리 한계, busy 동안 큐 없음, 부분 undo 뒤 기록 재적재 없음이 체감에 미치는 영향 확인. 안전 거부를 버그로 표현하지 않는다.
- LEAD -> InteractionSurface: 아이콘 보기 없음과 행 아이콘 있음, 탭 없음과 양쪽 창 있음, 다중 이름 변경 없음과 단일 이름 변경 있음의 반례를 최종 문구에 유지. package contents 진입점 없는 후보도 일반 직접 경로 접근과 구별한다.
- LEAD -> ScaleFeedback/부모 검증: 앞서 읽은 polling 테스트/시간 기반 취소는 비결정성 위험으로만 기록. 이번 240개 통과를 부정하는 실패 근거가 아니다. 연구 범위 밖 코드 수정은 하지 않는다.
- DEAD END: 'undo/Quick Look/filter/외부 변경 갱신/클립보드/Finder reveal이 없다'는 리드. 실행 소스와 테스트 본문이 각각 반박한다.
- DEAD END: 'COPYFILE_RECURSIVE가 있으므로 재귀 검색이 있다'는 리드. `FileTransferProgress.swift:179`의 복사 플래그이며 검색 모델과 무관하다.
- DEAD END: 'unzip 테스트가 있으므로 앱의 자체 압축 해제가 있다'는 리드. `CompressTests.swift:127-136`은 ZIP 내용을 검사하는 테스트 프로세스이며 사용자 명령이 아니다. 대신 기본 앱으로 여는 간접 해제 가능성은 unknown/OS handoff 반례로 남긴다.
- DEAD END: 과거 `/private/var` 이슈를 현재 버그로 단정하는 리드. `DirectoryObserver.swift:136-141`에 canonical realpath 처리 코드가 존재한다.
- LEAD -> 부모 history 도구: reflog 이상으로 기능 도입 커밋을 인용하려면 read-only git log/show를 부모가 수행해야 한다. 이 축은 커밋 메시지와 현재 구현의 관련성만 확인했고 diff를 읽었다고 주장하지 않는다.

소유 자원: 읽기 전용 도구 호출만 수행했다. 생성한 프로세스/파일/창/설정이 없어 정리할 자원이 없다.