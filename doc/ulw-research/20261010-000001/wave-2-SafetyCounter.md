# 신뢰·안전·macOS 연결 주장 경계 재판정

## 결론

상위 답변에서 채택할 결정적 결핍은 **전송 엔진의 기본 안전장치 부재가 아니라, 작업 결과를 다시 확인하고 다음 행동으로 연결하는 제품 흐름의 부족**이다. 여기에 **외부 앱 실행 실패를 앱이 설명하지 않는 경계**, **볼륨 알림 구독 센터의 확인된 계약 불일치**를 붙일 수 있다. 대량 목록 성능 저하나 드문 파일 경쟁은 이 결론의 근거로 승격하지 않는다.

현재 소스를 직접 다시 읽었다. 빌드·테스트·앱 실행·파괴적 경쟁 재현·파일 수정은 하지 않았다. 부모의 notification probe는 실행 산출물과 스크립트를 읽어 별도 증거로 반영했다. 부모 GUI의 주소 이동·양쪽 창·현재 폴더 이름 거르기 성공은 부모 관측이며 이 조사자의 독립 관측으로 중복 계산하지 않는다.

## 1. 채택할 주장과 반증

### A. 작업 결과는 자세한 텍스트이지만 제품 안의 재열기·복구 action으로 이어지지 않는다 — SUPPORTED

근거: `Sources/IHateFinder/BrowserWindowController.swift:437-472`는 문제 상태·경고·recovery가 있을 때만 결과 시트를 만든다. 모든 항목의 상태, 원본·대상 경로, recovery message와 locations를 문자열로 넣고 `확인` 버튼 하나를 만든다. NSTextView는 `isEditable = false`, `isSelectable = true`다. 복구 위치 열기·해당 파일 선택·미처리만 재시도·후처리 재시도 action이나 해당 위치의 URL link를 이 코드에서 만들지 않는다. `:331-348`에서 report는 작업 완료 closure의 지역값으로 쓰이고 결과 뒤에 사용자용 전송 history로 저장되지 않는다. `:21-30`의 마지막 결과 필드는 trash/undo/compress용이며 전송 history가 아니다. `Sources/IHateFinderCore/WorkspaceStore.swift:3-8,45-49`도 pane view state만 저장한다.

정확한 표현: **“결과에 경로와 상태는 나오지만, 시트를 닫은 뒤 같은 결과를 다시 열거나 복구 위치로 이동하고 미처리 항목만 재시도하는 전용 흐름은 없다.”**

반증: 오류 피드백과 경로 자체는 이미 있다. 텍스트 선택·복사는 가능하다. 실패하거나 미처리된 cut 항목은 클립보드에 남아 일반 붙여넣기로 다시 시도할 수 있다(`FileClipboard.swift:83-97`, `BrowserWindowController.swift:343-344`). 따라서 “결과가 전혀 없다”, “어떤 재시도도 불가능”, “경로를 얻을 수 없다”는 기각한다. macOS 일반 텍스트 문맥 메뉴가 제공할 수 있는 기능까지 불가능하다고 주장하지 않는다. 이 재시도 수단은 copy/drag/manual recovery/후처리 경고를 모두 포괄하는 결과 UI의 대체가 아니다.

상위 답변 영향: 전송 축의 첫 개선을 새 엔진이나 무제한 병렬화보다 **최근 작업 결과 + 살아 있는 위치 열기/선택 + 상태별 다음 행동**으로 잡는 근거다. 사용자 작업 빈도 측정은 아니므로 “사용자가 Finder를 다시 켠 실제 원인”이라고 단정하지 않는다.

### B. 실행 취소 거절·부분 성공의 record는 같은 경로로 재시도되지 않는다 — SUPPORTED

근거: `BrowserWindowController.swift:288-310`은 busy이면 먼저 거절하고, 그렇지 않으면 `undoJournal.popLast()`를 실행한 뒤 background undo를 시작한다. 결과는 `lastUndoReport`에 남고 skipped/partial alert가 나오지만 record를 다시 push하지 않는다. `FileUndo.swift:109-114`의 `popLast()`도 단순 제거다.

정확한 표현: **“원래 자리가 차 있어 되돌리기를 거절한 뒤 그 자리를 비워도, 방금 거절된 작업을 다시 실행 취소하는 제품 경로는 없다.”** 이는 전부 undo가 없다는 뜻이 아니다. 일부 복원한 record 전체를 다시 적용하면 위험하므로 무조건 재push를 권고하지 않는다. 남은 reversible 항목과 이미 끝난 항목을 구분하는 후속 결과 모델이 필요하다는 판단이다.

반증: busy 동안에는 record를 pop하지 않는다. 최근 결과 모델 자체가 전혀 없는 것도 아니다(`lastUndoReport`). 다만 저장된 필드가 재열기 메뉴나 재시도 action이라는 증거는 없다.

### C. undo의 검사는 파일 정체성이지 내용 불변 검사가 아니다 — SUPPORTED / 문구 확대는 REFUTED

근거: `FileUndo.swift:3-26`은 fresh URL에서 persistent `fileResourceIdentifier`를 읽고, `:311-327`은 현재 ID와 기록 ID가 같은지 비교한다. digest, 파일 크기, mtime, 디렉터리 내부 상태를 비교하지 않는다. `README.ko.md:115`의 “작업 뒤에 항목이 바뀌었으면”과 `docs/behavior.md:100`의 비슷한 표현은 내용 편집까지 보호하는 보장으로 읽으면 구현보다 넓다. 소스의 실제 stale 메시지는 `FileUndo.swift:347`의 **“그 사이 다른 항목으로 바뀌어”**다.

상위 답변 권장 표현: **“같은 경로에 다른 항목이 들어섰는지 파일 ID로 확인하고, 다른 항목이거나 확인할 수 없으면 건드리지 않는다. 같은 파일의 내용이 수정되지 않았다는 보장은 아니다.”**

반증과 안전 경계: `FileUndo.swift:204-213`의 copy/create undo는 항목을 영구 삭제하지 않고 Trash로 보낸다. `:216-247`의 cross-volume move undo는 기록된 원본을 Trash에서 복원한 뒤 목적지 사본을 Trash로 보낸다. 동일 ID를 유지하는 목적지 사본의 내용 편집이 있다면 그것을 편집 전 내용과 비교해서 거절하는 코드는 없지만, 이것만으로 편집 내용의 영구 손실을 주장할 수 없다. `:332-336`의 빈 복원 자리 검사와 identity 확인도 외부 프로세스가 동시에 바꾸는 모든 경쟁을 원자적으로 막는 보장은 아니다. “undo는 안전하다”보다 **“다른 항목 덮어쓰기·영구 삭제를 피하는 보수적 undo 정책이 구현되어 있다”**가 정확하다.

### D. 외부 앱 열기는 구현되어 있으나 요청 실패에 대한 IHateFinder 피드백이 없다 — SUPPORTED

근거: `Sources/IHateFinder/FilePaneController.swift:14-25`는 기본 앱 열기의 Bool을 버리고, open-with와 Terminal open은 completionHandler를 전달하지 않는다. Terminal 앱 URL이 없으면 조용히 return한다. `:693-724,731-736`은 해당 seams가 실제 메뉴 action과 연결됨을 확인한다.

독립 공식 계약: [NSWorkspace.open(_:)](https://developer.apple.com/documentation/appkit/nsworkspace/open(_:).md)는 Bool을 성공 여부로 정의한다. [비동기 open](https://developer.apple.com/documentation/appkit/nsworkspace/open(_:withapplicationat:configuration:completionhandler:).md)은 completion handler의 Error로 실패 이유를 제공하며 concurrent queue에서 callback한다고 명시한다.

정확한 표현: **“기본 앱·다른 앱·Terminal 연결은 있지만, 실행 요청이 실패하는 경우 이 앱이 그 결과와 이유를 표시하는 코드가 없다.”** 기본 앱 open의 Bool만으로 상세 이유까지 얻는다고 쓰지 않는다. 이 앱의 피드백 부재와 macOS 또는 대상 앱이 자체 오류를 보여주는 가능성을 구분한다. 실제 파일 열기 실패, Terminal 실행 실패, 앱 호환 실패는 관측하지 않았으므로 주장하지 않는다.

상위 답변 영향: 새로운 연동 목록을 늘리기 전에 기존 연결의 실패 경계를 설명하는 작은 개선 후보다. 성공 callback도 대상 앱이 파일 내용을 정상적으로 해석·편집했다는 end-to-end 보장은 아니다.

### E. mount/unmount 구독 센터 불일치는 확인됨; 물리 디스크 UI 실패는 관측하지 않음 — SUPPORTED, 범위 한정

현재 `BrowserWindowController.swift:78-89`는 mount/unmount를 `NotificationCenter.default`에 등록한다. Apple [didMountNotification](https://developer.apple.com/documentation/appkit/nsworkspace/didmountnotification.md)와 [didUnmountNotification](https://developer.apple.com/documentation/appkit/nsworkspace/didunmountnotification.md)는 `NSWorkspace.notificationCenter`를 사용해야 하며 다른 center로 등록하면 알림을 받지 못한다고 명시한다.

부모 실행 증거 `doc/ulw-research/20261010-000001/verify-notification.md:6-15` 및 script `verify-notification.swift:4-16`: 실제 stdout은 `same_center=false`, `workspace_received`, `cleanup=both_observers_removed`이고 `default_received`는 없다. workspace center에 synthetic didMount를 post했고 양쪽 observer를 정리했다. 이 조사자는 해당 실행을 재실행하지 않았다.

판정: **현재 소스의 공식 계약 불일치와 이 환경의 두 center 간 synthetic dispatch 분리는 CONFIRMED다.** 새 디스크 연결·해제 시 실제 사이드바가 갱신되지 않았다는 GUI 관측이나 특정 사용자가 겪은 incident는 아니다. unmount의 별도 synthetic probe도 수행했다고 쓰지 않는다. 두 알림의 source-contract mismatch는 각각 공식 계약으로 확인된다.

반증: `BrowserWindowController.swift:853-876`는 처음부터 mountedVolumeURLs를 열거하므로 “볼륨 목록이 없다”, “외장 파일을 전혀 탐색할 수 없다”는 기각한다. 좁은 수정 후보는 subscription center이며 전체 디스크 엔진 재작성의 근거가 아니다.

## 2. incoming open / busy / navigation 방어 교차 확인

`BrowserWindowController.swift:204-220`의 incoming open은 busy guard 없이 focused pane의 탐색과 선택을 바꾼다. 그러나 이것을 **진행 중 작업 대상이 새 경로로 바뀐다**는 경합 버그로 해석하면 틀린다.

- `:317-350`은 작업 시작 시 `urls`, `destination`, `moving`, ops, clipboard snapshot을 capture하고 worker에서 그 값을 사용한다. paste는 `:495-498`에서 현재 URL과 snapshot을 인자로 넘긴다. 도중에 focused pane이 바뀌어도 worker가 매번 새 pane 경로를 읽어 대상을 바꾸는 구조가 아니다.
- `:318-324`는 두 번째 변경 작업을 막고 `beginCancellableJob`에서 busy를 설정한다. undo는 busy 동안 pop되지 않고, rename 시작도 `FilePaneController.swift:419-422`에서 거절한다.
- 진행 callback은 `BrowserWindowController.swift:325-329`에서 cancellation 객체 identity를 확인한다. cut consume은 `FileClipboard.swift:83-97`에서 snapshot identity와 pasteboard changeCount가 맞고 실제 완료한 source만 처리한다. 오래된 작업 결과가 새 cut 의도를 덮어쓰는 부재 가설은 기각한다.
- `BrowserSession.swift:121-145`는 마지막 generation만 게시한다. `:147-199`는 성공한 목록만 경로·entries·revision으로 commit하고 실패한 탐색은 마지막 성공 snapshot을 유지한다.
- `FilePaneController.swift:170-193`은 이름 편집 중 rows 교체를 미루고 주소 편집 중 typed text를 덮어쓰지 않는다. `:199-220`의 pending reveal은 목록을 기다리고 filter가 원하는 항목을 가리면 해제한다.

따라서 **외부 요청이 현재 pane 문맥을 다른 폴더로 바꾸는 UX 정책**은 확인되지만, transfer destination 변조·선택 인덱스 오작동·파일 손실은 입증되지 않았다. pending navigation에 종료 후 reload가 겹치는 모든 시퀀스, rename 편집 중 외부 reveal의 체감은 미관측이다. DH-L6를 안전 결함으로 상위 답변에 올리지 않는다.

## 3. 전송 엔진 신뢰와 성능의 과장 차단

`FileOps.swift:491-620`은 destination volume stage에 새 항목을 준비한 뒤 기존 대상을 previous로 이동하고 새 항목을 공개한다. 공개 실패 시 원본·이전 대상을 복구하며, 복구 실패가 있으면 살아 있는 위치를 보고하고 stage를 무조건 지우지 않는다. cross-volume source Trash는 새 대상 공개 후 수행한다. 그 단계가 실패하면 failed + 양쪽 위치를 보고하고 완성된 목적지 사본을 지우지 않는다. 이전 대상 Trash 실패는 completed + warning + preserved backup으로 남을 수 있다. 이 구조는 “교체 전에 기존 파일을 그냥 삭제한다”는 가설을 반박하지만 전원 상실·모든 볼륨·모든 동시 변경에 대한 무손실 보장은 아니다.

성능에서 확인되는 것은 구조와 확인 범위다. `BrowserSession.swift:121-145`의 조회·정렬은 background이고 오래된 결과는 게시하지 않는다. 이전 filesystem 작업 자체를 취소하는 것은 아니다. `FileOps.swift:192-220,374-400`은 전체 열거·metadata·정렬 후 반영하고 `FilePaneController.swift:163-193,361-374,540-549`는 UI 경로에서 filter/reload/selection 복구와 요청된 행의 icon 조회를 수행한다. 이것들은 **측정 위치**이지 측정된 병목이 아니다.

`FileTransferProgress.swift:85-92`의 phase/file 변경 예외 때문에 0.1초 제한을 “모든 progress callback은 초당 10회 이하”로 해석할 수 없다. `.finished`는 skip/fail/cancel에도 emit되므로 `BrowserWindowController.swift:427`의 “완료 N/M”은 성공 수가 아니라 처리한 입력 수다. 최종 결과 `:460`은 실제 status별 수를 따로 계산한다. 작은 문구 정밀화 후보이지 최종 성공 수 계산 버그가 아니다.

성능 descriptive find가 비어 alternate literal search를 수행했다. `Tests;Sources;Package.swift;Makefile`의 benchmark/performance/stress/latency/throughput/XCT metric/os_signpost/measure 검색과 benchmark/perf 파일명 glob에서 성능 suite 증거를 찾지 못했다. ignored·외부 자산까지 부재를 증명한 것은 아니다. `FileTransferProgressTests.swift:56-104`는 32 MiB byte progress·권한·mtime·사용자 xattr·contents equality assertion을 확인하는 기능 검사이지 latency benchmark가 아니다. 테스트를 이 lane에서 실행하지 않았다.

상위 답변에서 “대량 목록에서 느리다/멈춘다”, “항상 즉시 clone되어 공간 0”, “성능은 이미 충분하다”, “아이콘이 매번 디스크를 읽는다”는 모두 제외한다. **대량 목록·실볼륨·연속 변경의 응답성을 확인한 측정 근거가 부족하다**고 쓰고 실제 측정 뒤 좁게 최적화한다. queue 부재는 busy gate로 직접 확인되는 기능 제한이므로 성능 수치 없이 말할 수 있지만, Finder 공식 queue/pause/ETA 보장과의 비교는 이 자료로 입증되지 않는다.

## 4. 할당 LEAD 폐쇄표

폐쇄는 해당 주장의 종류와 경계를 정했다는 뜻이며, 미관측 시나리오가 성공했다는 뜻이 아니다.

### TransferTrust

- TT-E01 — **UNRESOLVED / 정적 경로 확인.** `FileOps.swift:362-370,594-610`의 completed + cleanup warning은 throw가 되고 `FilePaneController.swift:527-536`은 try 이후에만 undo record를 만든다. 조건부 기록 누락 경로는 지원되지만 해당 후처리 fault의 실제 발생·화면·사용자 영향은 재현하지 않았다. 현재 관측 버그로 올리지 않는다.
- TT-E02 — **CLOSED / SUPPORTED.** 일회성 selectable text 결과와 전용 재열기·recovery action 부재를 §1A로 닫음. 긴 결과 가독성·일반 시스템 문맥 action은 미관측.
- TT-E03 — **CLOSED / SUPPORTED.** pop-before-undo와 재push 부재를 §1B로 닫음. “undo 없음” 기각.
- TT-E04 — **CLOSED 정적 제한 / UNRESOLVED 키보드.** `BrowserWindowController.swift:727-750`은 이름만 받는 비교 정보와 replace/skip/keepBoth 세 선택, apply-remaining checkbox다. 명시적인 작업 중단 버튼은 없다. 실제 Esc 동작·진행 취소 버튼 접근성은 미관측이며 “취소 불가능”을 주장하지 않는다.
- TT-E05 — **UNRESOLVED / 희귀 경쟁 부록.** 공개 후 `FileOps.swift:585-587`에서 source path를 Trash로 보내기 직전에 ID를 다시 확인하지 않는 정적 단서. copy 중 외부 item 교체 시 실제 잘못된 Trash 또는 손실을 재현하지 않았다. top-level 결핍으로 사용하지 않는다.
- TT-E06 — **CLOSED / SUPPORTED 경계.** ID vs content 불변을 §1C로 닫음. 수정 내용 영구 삭제 주장 기각.
- TT-E07 — **UNRESOLVED / 희귀 경쟁 부록.** `FileOps.swift:673-677`은 standardized lexical containment다. symlink 경유 자기 하위 복사에 native API가 어떤 결과를 내는지 확인하지 않았다. 검사 우회로 실제 recursive copy/파일 손실이 발생한다고 주장하지 않는다.
- TT-E08 — **CLOSED 범위 / UNRESOLVED 중단 결과.** stage-local 상태와 view-only persistence(`FileOps.swift:493-497`, `WorkspaceStore.swift:3-8,45-49`)로 durable transfer recovery surface 부재는 확인. 정상 close guard(`BrowserWindowController.swift:130-140`)가 있다. 강제 종료 손실은 미관측. 자동 stage 삭제 권고 금지.
- TT-E09 — **CLOSED 정책 / UNRESOLVED 실제 볼륨 matrix.** persistent ID가 없으면 unverifiable로 거절(`FileUndo.swift:14-26,311-327`); synthetic regression `FileUndoSafetyTests.swift:75-95`를 읽음. 모든 exFAT/네트워크 작업이 실제 실패한다는 일반화 금지.
- TT-E10 — **CLOSED 제한 분류.** 현재 메뉴(`FilePaneController.swift:756-793`)와 wave-1 검색 근거는 별도 Trash browser/Put Back action을 보여주지 않는다. 세션 undo는 있다. 시스템 Trash 복원 자체 불가능이라는 주장은 금지. 장기 복원은 조건부 업무 후보로만 남김.
- TT-E11 — **CLOSED 제한 분류.** localized error·recovery path는 있고 결과 UI는 원인별 action을 만들지 않는다. space/권한 preflight 전체 자동 해결을 필수조건으로 올리지 않는다. 실제 용량 부족·읽기 전용 incident는 미관측.
- TT-E12 — **CLOSED 정적 의미.** 처리 입력 수와 성공 수 표현 차이를 §3으로 닫음. 화면 지속 시간·실제 혼동은 미관측.

### DesktopHandoff

- DH-L1 — **CLOSED / CONFIRMED 좁은 계약 불일치.** §1E의 부모 synthetic dispatch 증거 반영. 물리 디스크 실패는 주장하지 않는다.
- DH-L2 — **UNRESOLVED GUI.** 목록의 명시 Share action은 없으나 Quick Look 시스템 패널의 sharing 노출을 이 lane에서 확인하지 않았다. “공유가 어떤 방법으로도 불가능” 기각.
- DH-L3 — **UNRESOLVED 외부 E2E.** 앱별 reveal/odoc와 기본 파일 뷰어 설정 효과는 코드·test intent만으로 전체 성공/실패를 일반화할 수 없다. Finder direct 호출과 시스템 Open/Save 패널까지 대체한다고 쓰지 않는다.
- DH-L4 — **CLOSED 반증 / UNRESOLVED 특수 metadata.** COPYFILE_ALL flags(`FileTransferProgress.swift:179-185`)와 xattr assertion(`FileTransferProgressTests.swift:56-104`)은 “태그 UI 없음→메타데이터 삭제”를 반박한다. Finder tag 전용 xattr 및 provider별 보존을 실제 실행 검증한 것은 아니다.
- DH-L5 — **UNRESOLVED 조건부 workflow.** wave-1의 URL drop 구현과 provider/file-promise 전용 surface 부재는 실패 증거가 아니다. cloud-only placeholder·메일 attachment drop의 실제 결과는 미관측이며 데이터 손실 주장은 제외한다.
- DH-L6 — **CLOSED 안전 결함 승격 거절 / UNRESOLVED UX.** §2의 source/destination capture, busy gate, clipboard generation, navigation generation, 편집 방어가 반증이다. incoming open이 실제 파일 작업 대상을 바꾼다고 주장하지 않는다. 문맥 전환의 사용성은 별도 미관측.

### ScaleFeedback

- SF-L1 — **UNRESOLVED 측정.** 대량 목록+filter+scroll 지연은 수치·GUI proof 없음. 현재 느리거나 멈춘다는 진단 금지.
- SF-L2 — **CLOSED callback 계약 / UNRESOLVED 비용.** phase/file 변경이 throttle 예외인 것은 확인. 작은 파일 다수의 main callback 밀도가 실제 병목이라는 주장은 금지.
- SF-L3 — **CLOSED 감시 정책 / UNRESOLVED 부하.** `DirectoryObserver.swift:75-113`의 parent 감시와 fixed 150 ms coalescing, `BrowserSession.swift:203-210`의 loading 중 refreshPending을 읽음. rescan/CPU 폭주를 측정하지 않았다.
- SF-L4 — **CLOSED 실행 취소 부재 / UNRESOLVED 비용.** generation은 stale publish 방어이며 worker I/O 실행 취소가 아니다. 이전 조회 낭비가 체감 문제인지 측정하지 않았다.
- SF-L5 — **UNRESOLVED 드문 subprocess 상황.** `Compress.swift:57-65`는 terminate 후 isRunning이 false가 될 때까지 기다리고 별도 timeout/escalation이 없다. 실제 ditto 종료 거부·영구 취소 hang은 관측하지 않았다.
- SF-L6 — **CLOSED 향후 설계 제약.** queue를 넣어도 기존 busy/undo/clipboard snapshot/cancellation identity/충돌 선택 계약을 보존해야 한다. busy guard 제거 자체를 개선으로 권고하지 않는다. 현재 queue가 없다는 제한과 엔진 오류를 구분한다.
- SF-L7 — **UNRESOLVED 공식 비교.** wave-1의 일반 Finder 목적 페이지는 queue/pause/resume/ETA를 입증하지 않는다. 해당 Finder 보장은 이 축의 결론에서 제외한다.

## 5. 상위 답변에 반영할 개선 순서

1. **작업 결과를 다음 행동으로 연결:** 전송 결과 재열기, 목적지·실제 보존 위치 열기/선택, 실패·미처리와 후처리 경고의 분리. 기존 safety 엔진을 없다고 오진하지 않는다.
2. **기존 macOS 연결의 좁은 신뢰 경계 정리:** 확인된 notification center mismatch와 open failure feedback. mount는 source-contract + synthetic proof, open은 정적 feedback 부재로 증거 수준을 각각 명시한다.
3. **충돌 판단과 undo 범위 표현 정밀화:** 이름만 보여주는 충돌 비교를 보강하고, undo는 identity 확인이며 내용 불변 보장이 아님을 설명한다. 중단·재시도는 이미 완료한 상태를 보존하는 모델로 설계한다.
4. **성능은 측정 후, queue는 업무 필요에 따라:** 대량 목록·작은 파일 다수·실볼륨을 측정한다. 긴 전송 중 다음 변경을 예약할 필요가 확인되면 single-job 안전 계약을 유지하는 queue를 검토한다. checksum·pause/resume·전면 provider 지원을 현재 최소 대체성의 필수조건으로 묶지 않는다.

최종 결론용 문장: **“파일을 보존하려는 기반은 이미 상당히 구현되어 있다. 일상 대체성에서 먼저 메워야 할 것은 실패·부분 완료 뒤 결과를 다시 확인하고 복구 위치나 다음 작업으로 이어지는 흐름, 그리고 기존 macOS 연결의 확인 가능한 경계다. 대량 처리의 성능이나 특수 볼륨의 무손실 보장까지 검증된 것은 아니다.”**

## EXPAND

LEAD: 새로운 구현·재현을 이 lane에서 시작할 필요 없음. 결정적인 결과 UI/undo 정책/ID 범위/open 피드백/mount 계약은 닫았다.

UNRESOLVED ANNEX: TT-E01의 실제 fault 발생, TT-E05/TT-E07의 드문 외부 경쟁·링크 경유 시나리오, TT-E08의 비정상 중단 결과, TT-E09의 실제 볼륨 matrix, DH-L2/L3/L5의 GUI·외부 E2E, SF-L1/L2/L3/L4/L5/L7의 실행·측정·공식 비교는 위 폐쇄표의 precise non-assertion으로 남긴다. 이 항목들 때문에 현재 앱의 데이터 손실·영구 hang·물리 mount 실패·대량 성능 불합격을 주장하지 않는다.

DEAD END: 기본 undo/취소/진행/외부 변경 감시/clone/open 연결 부재, 전송 도중 incoming navigation이 worker destination을 바꾼다는 가설, 태그 UI 부재가 metadata 삭제를 의미한다는 가설은 현 구현의 반증 때문에 상위 진단에서 제외한다.