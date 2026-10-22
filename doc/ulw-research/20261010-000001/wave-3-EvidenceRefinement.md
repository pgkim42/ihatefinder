## 판정

BLOCKERS — CG01-CG10은 아래의 범위 수정/표현 고정 후 합성 가능하고, CG11과 CG12는 현재 문구 그대로는 과장 위험이 있어 반드시 수정해야 한다.

## 주장별 판정

### CG01 — APPROVE (범위 고정)
“파일 작업, undo, Quick Look, 현재 폴더 거르기, refresh, 마지막 상태 복원, 외부 open/reveal의 구현 기반이 존재한다”는 사실은 현재 소스와 `swift test` 240개 통과가 함께 지지한다. `verify-tests.md`에는 실제 open/reveal, Quick Look 키/데이터소스, filter, undo, workspace restore 및 파일 작업 계약을 실행한 테스트가 포함된다. 다만 GUI 실행으로 확인한 것은 주소 이동·양쪽 창·filter뿐이므로 최종 문장은 “모든 기능을 실제 GUI에서 검증했다”가 아니라 “구현과 관련 테스트가 있고, GUI에서는 주소/양쪽 창/filter를 별도로 확인했다”로 유지해야 한다. 안전성 전체나 실제 외장 볼륨까지 보장한다는 확대는 금지한다.

정확한 합성 문구: “기본 파일 작업과 undo, Quick Look, 현재 폴더 거르기, 외부 변경 갱신, 마지막 작업 위치 복원, 외부 open/reveal은 이미 구현되어 있고 관련 테스트가 통과했다. 이번 실제 GUI 확인은 주소 이동·양쪽 창·거르기에 한정된다.”

### CG02 — APPROVE
고정 장소와 디스크 목록은 `BrowserWindowController.loadPlaces`, 사용자 장소의 영속 저장 부재는 장소 생성 경로·액션·`WorkspaceStore` 전체 스키마를 함께 읽어 확인했다. GUI는 사이드바의 실제 존재를 보강하지만 사용자 즐겨찾기 부재의 독립 증거는 아니며, 이 정확한 내부 부재에는 소스 단일권위 예외가 적절하다. “사이드바가 없다”, “장소 기억이 전혀 없다”는 표현은 금지한다.

정확한 합성 문구: “홈·데스크탑·문서·다운로드·응용 프로그램과 마운트된 디스크는 보이지만, 사용자가 임의 폴더를 추가·삭제·재배열해 영속 저장하는 ‘내 장소’ 기능은 없다.”

### CG03 — APPROVE (두 부재를 분리)
직접 절대경로와 `~` 확장은 코드와 GUI 주소 이동으로 확인됐다. 파일시스템 후보는 주소 field delegate/action 경로와 전체 관련 검색에서 없고, 클릭 가능한 조상은 주소 UI가 단일 `NSTextField`이며 `NSPathControl`/breadcrumb 소비 경로가 없다는 별도 정적 근거가 있다. Apple 26 문서는 IHateFinder의 부재 증거가 아니라 비교 기준일 뿐이다. 상대경로, file URL, 오타 입력의 실제 동작은 미측정이다.

정확한 합성 문구: “정확한 경로나 `~/…`를 알면 바로 갈 수 있지만, 입력 중 폴더 후보/최근 경로를 제시하는 앱 전용 완성과 경로의 조상을 클릭해 이동하는 표면은 확인되지 않았다.”

### CG04 — APPROVE
GUI3가 현재 목록의 이름 거르기 성공을 실제로 보여주고, `EntryFilter(session.entries)`와 직접 자식 열거, README의 명시적 제외가 재귀/Spotlight 엔진 부재를 지지한다. “찾기가 전혀 없다”는 넓은 부재는 반증되었다. Finder의 날짜·종류·Smart Folder 기능은 Apple 26 문서상의 비교 기준이지 이 사용자에게 모두 필수라는 증거가 아니다.

정확한 합성 문구: “Cmd-F의 현재 기능은 이미 읽은 현재 폴더 목록의 이름을 줄이는 거르기다. 하위 폴더 재귀 탐색이나 Spotlight/메타데이터 검색과는 다르다.”

### CG05 — APPROVE (runtime 표현 제한)
단일 `browser` 보유, 좌우 두 `BrowserSession`, 추가 창/탭 생성 액션 부재, `WorkspaceStore` 필드가 소스에서 직접 확인된다. GUI2는 실제 좌우 두 장소만 확인했다. 종료·재실행 복원은 코드와 실행된 테스트의 증거이며 이번 GUI 세션에서 직접 재실행해 관측한 것은 아니다. OS가 암묵적으로 제공할 수 있는 자동 tab UI까지 부정해서는 안 된다.

정확한 합성 문구: “앱이 관리하는 작업 자리는 한 창의 좌우 두 pane이고, 마지막 좌우 경로·정렬·숨김·양쪽 창 여부는 저장한다. 앱 자체의 추가 browser 창·탭·named workspace와 선택·스크롤 복원 모델은 없다.”

### CG06 — APPROVE (인과 금지)
F5/F6 dispatch와 Quick Look 구현은 코드·테스트가 확인하고, toolbar 네 버튼·앱 메뉴·context menu 전체 구성에는 해당 명령이 없다. GUI2는 네 버튼 toolbar를 보강한다. 발견 실패나 사용자 혼란을 실제 관측하지 않았으므로 “숨겨져 있어서 사용자가 못 쓴다”는 인과 표현은 금지한다.

정확한 합성 문구: “반대쪽 복사/이동(F5/F6)과 Quick Look은 동작하지만 현재 네 버튼 toolbar와 앱/context menu에서는 명령으로 노출되지 않는다. 이를 보이게 하는 것은 새 엔진보다 작은 발견 가능성 개선 후보다.”

### CG07 — APPROVE (수동 재시도 반례 명시)
결과 sheet가 상태·경로·recovery location을 selectable text로 보여주지만 확인 버튼 하나뿐이고 전송 history 저장소나 위치 열기/선택/상태별 재시도 action이 없다는 소비 경로까지 추적됐다. 미처리 cut 항목은 clipboard에 남아 일반 붙여넣기로 다시 시도할 수 있으므로 “재시도 불가능”은 틀리다.

정확한 합성 문구: “오류·부분 완료 결과와 복구 경로는 자세한 일회성 텍스트로 나오지만, 닫은 뒤 다시 열 기록이나 복구 위치 열기·선택, 미처리 항목만 다시 실행하는 결과-연결 action은 없다. 남은 cut 항목의 일반 붙여넣기 재시도는 가능하다.”

### CG08 — APPROVE (엄격한 scoped absence)
목록/context/app menu와 모델을 읽어 직접 Share, tag CRUD/display/search, eject, provider 상태/download policy 표면 부재를 확인했다. 그러나 QLPreviewPanel의 native 공유 표면, 일반 URL/FileManager를 통한 mounted/provider 파일 접근, OS materialization은 미측정 또는 반례다. 이 주장은 추천 우선순위의 핵심 근거로 일반화하면 안 된다.

정확한 합성 문구: “목록 선택에서 시작하는 명시적 Share, 태그 조작/표시, 디스크 꺼내기, 파일 공급자 상태·다운로드 제어 UI는 확인되지 않았다. Quick Look이나 OS의 일반 파일 경로를 통한 우회 가능성과 실제 provider 동작은 이번 조사에서 측정하지 않았다.”

### CG09 — APPROVE
clipboard, URL drag/drop, 기본 앱/다른 앱/Terminal open, 외부 open/reveal, Alternate viewer 등록 및 수동 설정 가이드는 코드·plist·문서에 있다. Apple 계약과 Marta/ForkLift의 공식 제한은 “대체 관리자가 시스템의 모든 Finder 표면을 소유해야 한다”는 기준을 반박한다. 실제 기본 뷰어 설정 효과나 모든 외부 앱 routing 성공은 검증하지 않았다.

정확한 합성 문구: “IHateFinder는 여러 macOS 연결을 이미 갖췄지만, 기본 파일 뷰어 설정이 Desktop, Dock Finder, Open/Save panel, Finder를 직접 부르는 모든 경로까지 교체한다고 보장할 수는 없다. 최소 목표를 ‘Finder 프로세스가 한 번도 나타나지 않음’으로 잡을 근거도 없다.”

### CG10 — APPROVE
비동기 listing, generation stale-result 방어, observer, progress/cancel 구조와 240개 테스트 통과는 확인됐지만 benchmark, 대량 GUI 측정, 물리 볼륨 matrix는 없다. static race/alias/interruption 후보는 runtime incident가 아니다. “빠르다”, “느리다”, “멈춘다”, “데이터를 잃는다” 모두 현재 증거를 넘는다.

정확한 합성 문구: “비동기 목록·외부 변경 감시·진행·취소는 구현되어 있지만, 대량 목록이나 실제 볼륨에서의 속도·응답성·무손실을 이번 조사로 측정하지 않았다. 정적 위험 후보를 현재 장애로 소개하지 않는다.”

### CG11 — BLOCKER: 무조건적인 순서 표현
현재 graph의 “Prioritize personal place access and existing action exposure, then more context and scope search”는 뒤의 counter-evidence와 충돌한다. 사용자 빈도/diary가 없고, `wave-1-NavigationFind`, `WorkspaceContinuity`, `ProductAlternatives`, `wave-2-summary` 모두 위치를 모르는 작업이면 검색이 먼저이며 세 번째 작업 자리는 실제 workflow에 따라 달라진다고 명시한다. “then”은 판단임을 밝혀도 단일 고정 순서로 읽힌다.

필수 수정:
“Default first increment: personal places/recent-path suggestions plus exposure of existing F5/F6/Quick Look actions. If the dominant task starts with an unknown file location, scoped recursive name search moves ahead of place access; if preserving three or more simultaneous locations is dominant, an additional independent work context moves ahead. This is a product judgment, not measured user frequency.”

한국어 합성 문구: “기본 첫 increment는 ‘내 장소/최근·주소 후보 + 이미 있는 F5/F6·Quick Look 노출’이 가장 작고 현재 방향과 맞는다. 다만 파일 위치를 모르는 일이 주작업이면 범위 검색을 먼저, 세 곳 이상을 동시에 붙잡는 일이 주작업이면 추가 작업 자리를 먼저 올린다. 이는 사용 로그로 측정한 순위가 아니다.”

### CG12 — BLOCKER: “executed code” 표현의 증거 수준 오염
계약 불일치는 확정적이다. 현재 앱 소스가 `NotificationCenter.default`에 등록하고 Apple 문서는 `NSWorkspace.notificationCenter`가 아니면 알림을 받지 못한다고 명시한다. `verify-notification.swift`는 현재 OS에서 두 center가 다르고 workspace center에 synthetic post한 알림이 workspace observer에만 도달함을 실행 확인했다. 그러나 이 probe는 IHateFinder의 실제 observer/handler를 실행한 것이 아니며, 물리 mount/unmount도 실행하지 않았다. 따라서 graph의 type/끝 표현인 “executed code”는 실제 앱 경로가 실행 검증된 것으로 오해될 수 있다.

필수 수정:
“.default mount/unmount subscription violates the documented NSWorkspace notification-center contract; source-contract mismatch plus synthetic platform dispatch proof, not an executed IHateFinder handler or physical mount incident.”

한국어 합성 문구: “좁게 확인된 실제 코드 결함은 mount/unmount observer가 `NotificationCenter.default`를 쓰는 점이다. Apple 계약은 `NSWorkspace.notificationCenter`를 요구하고, synthetic probe에서도 두 center의 전달이 분리됐다. 실제 외장 디스크를 연결해 사이드바 실패를 관측한 것은 아니다.”

추가 정밀화: unmount를 별도 synthetic post했다고 쓰지 않는다. 소스 계약은 mount와 unmount 모두에 적용되지만 실행 stdout은 mount synthetic dispatch만 증명한다.

## 독립성·버전·현실성 총평

- 내부 구현/부재는 소비 경로, 메뉴, 모델, 저장 스키마를 읽은 repo-code 단일권위 예외가 타당하다. 같은 저장소의 README·테스트 소스를 별도 독립 출처로 세지 않은 처리는 정확하다.
- `swift test` 실행은 정적 소스와 다른 modality지만 실제 GUI/외장 디스크/파일 공급자 E2E를 대신하지 않는다. graph와 최종 답변에서 이 경계를 유지해야 한다.
- GUI 증거는 주소 이동, 좌우 두 pane, 현재 폴더 filter에 한정된다. Quick Look, 파일 작업, 재실행 복원, 외부 앱 open, 기본 뷰어 routing, physical mount를 GUI에서 봤다고 쓰면 안 된다.
- Apple 사용자 문서는 `/26/mac/26`으로 고정되어 미래 macOS 27 contamination을 제거했다. 기본 `/mac` 결과나 27 문구를 최종 근거로 다시 섞지 않는다.
- 외부 제품 자료는 각 vendor의 feature contract와 제품 방향 비교에는 적합하지만 실제 효과·성능·이 사용자 수요의 독립 증거는 아니다. 같은 vendor의 여러 페이지를 독립 표로 세지 않은 처리는 정확하다.
- native helper 가능성을 제대로 남긴 항목은 Quick Look sharing, AppKit text behavior/type-select, 일반 FileManager/provider materialization, OS tab behavior다. 해당 표면을 앱 자체 부재에서 시스템 전체 불가능으로 확대하지 않는다.
- static 위험과 runtime incident 분리는 대체로 정확하다. 최종 답변에서 실제 결함으로 좁게 소개 가능한 것은 CG12의 source-contract mismatch이며, 그것도 물리 mount incident가 아니라는 단서를 같은 문단에 둬야 한다.

## 합성 진입 조건

CG11의 고정 순서를 조건부 default로 바꾸고 CG12의 “executed code”를 “source-contract mismatch + synthetic platform dispatch proof”로 바꾸면 CG01-CG12는 합성에 들어갈 수 있다. 그 외 주장은 위 정확한 문구와 non-assertion을 유지하는 조건으로 APPROVE한다.

## EXPAND

- 새 조사 리드 없음. 현재 bounded claim set 밖의 물리 mount, Quick Look native sharing, 실제 default-viewer routing, File Provider/cloud placeholder, 대량 성능, 선택·스크롤 복원 체감은 모두 이미 ‘unknown/unmeasured’로 정확히 격리되어 있으며 이번 합성을 막지 않는다.
- 합성 시 추가해야 할 것은 새 사실이 아니라 두 provenance 표지다: CG01 주변의 “GUI 확인 범위는 주소/dual/filter”와 CG12 주변의 “synthetic dispatch, not physical incident.”
- 사용자 diary 부재는 blocker가 아니다. CG11을 조건부 판단으로 쓰고 실제 workflow에 따라 search/tabs/cloud/photo 우선순위가 바뀐다고 밝히면 충분하다.