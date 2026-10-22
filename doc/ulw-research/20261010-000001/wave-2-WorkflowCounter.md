## 결론
좁힌 결핍 5개는 현재 앱 전용 구현 범위에서는 지지된다: 사용자 폴더 즐겨찾기 등록, 파일시스템 경로 후보/완성, 앱이 생성·관리하는 추가 browser 창/탭, 하위 폴더 검색, 반대쪽 복사·이동 및 Quick Look의 직접 메뉴 노출. 다만 ‘장소/주소 이동/작업 맥락/찾기/미리보기가 없다’는 넓은 주장은 반례로 기각한다. ‘즐겨찾기+완성+탭을 기본 첫 increment로 구현’은 사실 판정이 아니라 제품 판단이며, 세 기능을 한 번에 묶을 근거는 부족하다.

검증: 지정 소스와 연결 함수의 현재 내용을 직접 읽었으며 Sources 전체에서 관련 API/심볼을 두 검색 파형으로 교차 확인했다. 첫 파형 NavigationFind/WorkspaceContinuity/InteractionSurface 보고서를 재사용하되 그 안의 오래된 범위를 현재 소스로 다시 확인했다. 테스트·앱 실행·제품 수정·설정 변경·git 변경은 하지 않았다. 부모가 관측한 주소 이동 성공, 양쪽 창, README 이름 거르기 2행은 전달받은 실행 증거이지 이 조사자의 직접 실행 증거는 아니다. 현재 런타임 실패를 주장하지 않는다. 코드/동일 저장소 문서/테스트는 독립 사용자 관측으로 합산하지 않았다.

## Claim-by-claim

### 1. 사용자 즐겨찾기 등록이 없다 — PASS, 앱 내부 사용자 장소 모델에 한정
긍정 범위 증거: `Sources/IHateFinder/BrowserWindowController.swift:848-879`의 `loadPlaces()`는 홈·데스크탑·문서·다운로드·응용 프로그램을 직접 만들고 표시 가능한 마운트 볼륨을 추가한 뒤 반환한다. `:546-552`의 sidebar는 data source/delegate와 `openPlace` 클릭 액션만 연결한다. `:523-525`의 refresh는 이 목록을 다시 생성한다. `:765-769`의 클릭은 현재 포커스 pane의 `navigateSidebar`로 이동한다. `Sources/IHateFinderCore/WorkspaceStore.swift:4-19,45-54`의 영속 모델 전체는 pane의 path/sortColumn/ascending/includeHidden과 left/right/dual이며 사용자 장소 필드가 없다. Sources의 favorite/favourite/bookmark/recent 및 대체 저장 API 검색에서도 다른 등록·저장 경로는 확인되지 않았다.
반례/제한: ‘사이드바나 바로 갈 장소가 없다’는 REFUTE. 기본 장소와 동적 디스크가 있고, 마운트/언마운트 알림을 받는다(`BrowserWindowController.swift:79-89`). 마지막 좌우 장소도 저장한다(`:126-127`; `WorkspaceStore.swift:86-94`).
예: `~/projects/client-a`를 세션의 현재 장소로 열고 다음 실행에 돌아오는 것은 가능하지만, 이를 내 장소 목록에 등록해 항상 고르는 제품 액션은 없다. 기본 폴더나 마지막 두 장소만 쓰면 이 결핍의 영향은 작다.

### 2. 경로 완성이 없다 — PASS, 파일시스템 폴더 후보 UI에 한정
긍정 범위 증거: `Sources/IHateFinder/FilePaneController.swift:72-82`는 editable NSTextField에 delegate와 `commitPath`를 연결한다. `:746-750`의 commit은 입력 문자열에 `expandingTildeInPath`를 적용하고 URL을 만들어 navigate한다. `:482-500`의 주소 delegate는 Esc 복구 외에는 false를 반환하며, `:503-505`의 텍스트 변경 처리는 거르기 칸만 대상으로 한다. `Sources/IHateFinderCore/BrowserSession.swift:83-87`은 목적 URL을 표준화하여 읽는다. completions/completePath/insertTab/completionsFor/NSPathControl 등 두 API 검색에서 앱 전용 후보 제공·선택 경로는 확인되지 않았다.
반례/제한: ‘주소 이동이 없다’는 REFUTE. Cmd/Ctrl-L 전체 선택(`KeyCommands.swift:40-42`; `FilePaneController.swift:268-270`), 직접 절대 경로 입력, `~` 확장이 있다. AppKit 기본 텍스트 완성까지 모두 없다고 단정하지 않는다. 빈 입력·상대 경로·file:// 문자열·공백·alias 입력의 실제 성공/실패는 실행하지 않았으므로 UNRESOLVED다.
예: 알고 있는 `~/projects/client-a/assets` 전체를 붙여넣는 통로는 있다. `~/projects/cli`까지 입력하고 존재하는 하위 폴더 후보를 고르는 앱 기능은 확인되지 않는다.

### 3. 앱 관리 새 탭/새 창이 없다 — PASS, 추가 작업 자리 생성에 한정
긍정 범위 증거: `Sources/IHateFinder/AppDelegate.swift:3-4`는 단일 `browser`를 보유하고 `:47-55`의 시작 경로에서 하나를 생성한다. Sources의 `BrowserWindowController(` 호출 검색은 launch의 정상/repro 분기만 찾았다. 전체 메뉴 `:77-115`의 파일 메뉴는 새 폴더/텍스트 파일이고 창 메뉴는 닫기뿐이다. `Sources/IHateFinder/BrowserWindowController.swift:5-20,47-60,570-578`은 left/right 두 세션을 생성·배치하며 `WorkspaceStore.swift:45-54`도 두 pane만 모델링한다.
반례/제한: ‘두 장소를 유지하지 못한다’와 ‘복원이 없다’는 REFUTE. 좌우 세션이 별개이고 오른쪽을 끄는 동작은 collapse일 뿐 객체 폐기가 아니다(`BrowserWindowController.swift:511-519`). 저장한 좌우 폴더·정렬·숨김·dual 복원이 있다. AppKit/시스템의 자동 탭 표시 가능성을 전부 실험한 것은 아니므로 ‘OS 어떤 경우에도 탭 표시 불가’는 채택하지 않는다.
예: 원본 A와 목적지 B를 두 pane에 유지할 수 있다. A와 B를 유지한 채 프로젝트 C의 별도 선택·방문 기록을 세 번째 자리로 남기려면 추가 세션 모델이 필요하다. C를 즐겨찾기로 저장하는 것은 C로 빨리 이동하는 해결이지 A/B/C 작업 맥락을 동시에 보존하는 해결이 아니다.

### 4. 재귀 검색이 없다 — PASS, 이름 거르기와 구분
긍정 범위 증거: `Sources/IHateFinder/BrowserWindowController.swift:479`의 메뉴 액션은 `focused.showFilter()`다. `FilePaneController.swift:328-337,361-371`은 칸을 드러내고 `EntryFilter.filter(session.entries, query: ...)`로 이미 읽은 목록만 줄인다. `Sources/IHateFinderCore/EntryFilter.swift:6-9`는 이름 부분 문자열 비교다. `FileOps.swift:193-223`의 목록 공급원은 `contentsOfDirectory(at:)` 직접 자식 열거다. Sources의 NSMetadataQuery/MDQuery/enumerator/subpaths 검색에 별도 검색 경로가 없으며 `README.md:233-235`와 `docs/behavior.md:153`도 하위 폴더 찾기를 범위 밖으로 명시한다. 문서는 코드와 같은 관측 그룹의 보조 근거다.
반례/제한: ‘찾기 기능이 전혀 없다’는 REFUTE. 현재 폴더 이름 거르기는 이미 있고 부모 GUI의 README 2행 결과도 그 범위를 보여 준다. `AppDelegate.swift:98` 메뉴가 ‘찾기’라고 해도 재귀 범위가 생기지는 않는다. 복사 내부 재귀 처리는 검색 반례가 아니다.
예: 현재 폴더의 README는 줄여 볼 수 있지만 `project/subdir/README.md`를 project에서 발견하는 별도 검색 결과 모델은 없다. 구현 후보의 완료 조건은 검색 범위·원래 위치·불완전 탐색·취소·부모 폴더 열기/reveal이며, Spotlight와 자체 재귀 이름 검색은 같은 구현 선택으로 취급하면 안 된다.

### 5. F5/F6와 Quick Look의 직접 메뉴 노출이 없다 — PASS; 기능 부재는 REFUTE
긍정 범위 증거: 전체 앱 메뉴 `Sources/IHateFinder/AppDelegate.swift:77-115`, 전체 pane 우클릭 메뉴 `FilePaneController.swift:758-797`, 전체 상단 버튼 구성 `BrowserWindowController.swift:532-544`에 ‘반대쪽으로 복사/이동’ 또는 Quick Look 액션이 없다. 우클릭의 일반 ‘복사/붙여넣기’는 클립보드 명령이며 즉시 반대쪽 전송 명령과 다르다.
명확한 기능 반례: `Sources/IHateFinder/KeyCommands.swift:88-89`가 F5/F6를 copyToOther/moveToOther로 해석하고 `BrowserWindowController.swift:679-680,689-702`가 선택을 반대쪽 현재 URL로 전송한다. dual과 선택이 없으면 실행하지 않는 조건도 있다. `FileTableView.swift:109-135`에는 Space/Cmd-Y, `FilePaneController.swift:376-415`에는 실제 QLPreviewPanel·선택 data source·토글이 있다. 따라서 ‘전송 기능/Quick Look를 구현해야 한다’가 아니라 ‘있는 기능의 명시적 진입점을 더한다’가 정확하다.
예: 문서에서 F5를 배운 사용자는 A→B를 수행할 수 있다. 메뉴로 복사 명령을 찾는 사용자는 반대쪽 즉시 전송과 클립보드 복사의 차이를 앱 메뉴에서 발견하기 어렵다는 추론이 가능하다. 이것이 실제 사용자 실패였다는 관측은 없으며 QL 네이티브 패널 안의 자체 버튼까지 부재라고 확대하지 않는다.

## alias / breadcrumb / third-context 리드 폐쇄

- Alias/bookmark: CLOSED, 정확한 범위로 제한. 현재 영속 pane 위치는 `WorkspaceStore.swift:5,11-19`의 절대 path 문자열이다. 이동·이름 변경을 추적하는 사용자 즐겨찾기 bookmark 모델은 없다. 그러나 `Sources/IHateFinder/OpenRequest.swift:11-21`은 외부 요청의 symlink를 해소하며 `:37-52`는 Apple Event의 file URL/alias descriptor를 fileURLValue 또는 typeFileURL coercion으로 받는다. 따라서 ‘alias/symlink 지원 전체가 없다’는 DEAD END다. Apple Event alias descriptor, Finder alias 파일, 심볼릭 링크, 향후 즐겨찾기의 durable bookmark는 서로 다른 계약이다. 이름 변경 후 즐겨찾기가 따라가야 하는지는 새 요구 판단이고, 지금의 alias 경로 runtime 실패는 미관측이다.
- Breadcrumb/조상 이동: CLOSED, 앱 전용 클릭 계층의 부재는 지지. 주소 구성은 전체 경로 NSTextField이며 NSPathControl/분절 후보 구현이 없다. 반면 `BrowserSession.swift:90-111`에 위/뒤로/앞으로가 있고 `FilePaneController.swift:273-277`은 위로 간 뒤 원래 폴더 reveal을 예약한다. 깊은 경로에서 조상을 여러 번 위로 가거나 경로 편집으로 여는 대체 통로가 있다. ‘계층 이동 불가’는 DEAD END다. 조상 선택은 아직 이름을 모르는 파일 검색과도 다르고, 재방문용 즐겨찾기와도 다른 작은 탐색 개선 후보다.
- Third-context: CLOSED, 장소 기억과 작업 자리 보존을 분리. 두 독립 세션과 오른쪽 collapse 보존이 반례다. ‘세 번째 장소에 접근 불가’는 DEAD END이고 ‘세 번째 독립 작업 자리를 A/B와 함께 유지하는 앱 모델 없음’만 지지된다. 새 창·pane별 탭·명명한 workspace 중 무엇을 고를지는 아직 제품 판단이다.

## 첫 increment에 대한 공격과 판단

`CONTEXT.md:3`의 제품 기준은 Windows 탐색기의 경로 입력·잘라 옮기기·상세 목록이다. 이 기준은 주소 완성과 사용자 장소 등록에 직접 연결되지만 탭을 필수로 만들지는 않는다. `CONTEXT.md:13,29`의 Avoid: 탭/브레드크럼은 용어 지침이지 기능 구현 금지로 읽을 근거도 없다.

**판단:** 반복하는 임의 프로젝트 폴더를 주로 오가는 사용자를 잠정 기본으로 잡는다면, 첫 increment는 ‘사용자 폴더 등록/삭제와 주소창 폴더 후보’라는 장소 도달성 개선이 합리적이다. 장소를 빠르게 다시 찾는 두 기능은 같은 기억 부담을 줄인다. 하지만 탭을 같은 첫 increment에 넣으면 별도 세션 수명, 활성 자리, 전송 목적지, 저장·복원 계약까지 넓어진다. 이번 조사에서 세 번째 독립 맥락의 실제 빈도는 확인되지 않았으므로 기본 묶음에서 빼는 편이 근거에 맞다. 다중 창과 탭도 동시에 요구하지 않는다.

반대 시나리오도 명시해야 한다. A/B 두 폴더와 정확한 경로 붙여넣기만 쓰면 즐겨찾기·완성보다 F5/F6·Quick Look 메뉴 노출과 대상 표시가 작은 개선으로 더 유효할 수 있다. 저장 위치를 모르는 파일 때문에 Finder로 돌아간다면 즐겨찾기·완성·탭 어느 것도 재귀 검색을 대체하지 못한다. A/B를 유지한 채 C에서 별도 선택·기록을 보존하는 일이 빈번하다면 추가 자리 하나가 장소 등록보다 먼저일 수 있다. 따라서 이 우선순위는 사용자 이탈 로그가 증명한 인과 결론이 아니라 관찰된 구현 범위와 작업 시나리오에 근거한 조건부 제안이다.

## EXPAND
- LEAD favorites registration: 조사 완료. 고정/동적 목록 생성, 클릭 액션, 영속 전체 스키마와 대체 검색을 대조해 닫았다.
- LEAD completion/breadcrumb: 조사 완료. NSTextField 입력/delegate/commit과 기존 위·기록·직접 입력 반례로 닫았다.
- LEAD alias/bookmark: 조사 완료. 외부 symlink·Apple Event alias 수용과 path 저장을 분리했다. Finder alias 파일의 실제 동작과 이름 변경 추적은 미관측으로 제한하고 다음 increment 필수 계약으로 확정하지 않았다.
- LEAD tabs/windows/third context: 조사 완료. 단일 launch browser, 전체 메뉴, 두 session 생성·collapse·저장 모델로 닫았다. OS 자동 탭의 모든 경우는 주장 범위에서 제외했다.
- LEAD recursive search / direct menu exposure: 조사 완료. 실제 데이터 공급·필터 액션 및 전체 앱/문맥/상단 메뉴를 읽고 구현된 키 경로 반례로 닫았다.
- LEAD first-increment ranking: 코드 조사는 완료. 남은 변수는 사용자의 반복 목적지·위치 미상 파일 찾기·세 번째 독립 맥락의 실제 빈도다. 이 배정에서 얻을 수 없는 사용자 관측이며 미구현 사실과 구별하여 판단으로 반환한다.
- DEAD END: 고정 places=사용자 즐겨찾기, `~` 확장=경로 후보, dual pane=임의 탭, 현재 목록 거르기=재귀 검색, 클립보드 복사 메뉴=반대쪽 즉시 전송, Quick Look 메뉴 없음=Quick Look 기능 없음, 외부 alias descriptor 수용=durable favorite bookmark, Windows 지향=탭 우선 필수.
- none: 추가 코드 조사 리드와 정리할 소유 자원은 없다. 배정된 부재 주장별 긍정 범위 증거와 반례를 모두 확보했다.