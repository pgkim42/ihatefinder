# ScaleFeedback 조사 보고서

## 결론과 검증 경계

이 축의 결핍은 ‘파일 작업이 동기식이고 진행 상태나 취소가 없다’가 아니다. 폴더 조회·정렬의 백그라운드 실행, 오래된 탐색 결과 폐기, 외부 변경 감시, 복사·이동의 현재 파일/항목 수/바이트 진행, 취소 및 부분 결과가 구현되어 있다. 확인된 제품 한계는 **한 작업이 진행 중일 때 다음 변경 작업을 대기열에 넣지 않고 거절하는 단일 작업 모델**, **작업 전체가 아니라 현재 파일 단위의 진행 정보**, **대량 목록의 UI 스레드 작업과 취소되지 않는 이전 조회에 대한 성능 검증 근거 부족**이다. 이 사실만으로 현재 앱이 느리거나 멈춘다고 말할 수는 없다.

관측일 observed_at은 모든 항목에서 2026-10-10이다. valid_at은 제공된 HEAD 0970c61의 현재 main 작업 트리에서 읽은 코드·테스트·문서이며, 실제 실행 결과와 구분한다. 본 담당자는 제품 코드, 문서, 설정, git 기록을 수정하지 않았고 앱 실행·빌드·테스트를 하지 않았다. 부모가 전달한 ‘루트 테스트 240개 통과’는 별도의 실행 관측이며 아래 테스트 내용 읽기와 동일한 증거로 세지 않는다. GUI 체감, 프레임 지연, 처리량, 실제 디스크 간 전송은 부모 담당이다. 조사 도중 도구가 표시한 FilePaneController 총 줄 수가 848에서 851로 달라졌으므로 아래 줄 번호는 읽은 시점의 앵커이고 후속 편집본에서는 함수명과 인용문으로 대조해야 한다.

## 증거 목록과 구현/제한/미구현

### SF-O1. 목록 조회와 정렬은 비동기이며 최종 요청만 게시한다 — 구현

- 관측 그룹 G1: 목록 파이프라인. `Sources/IHateFinderCore/BrowserSession.swift:121-145`의 `generation += 1`, `DispatchQueue.global(qos: .userInitiated).async`, `guard let self, ticket == self.generation else { return }`를 직접 읽었다. 조회와 `FileOps.sorted(...)`는 worker에서 실행하고 결과 반영은 main으로 돌린다.
- `BrowserSession.swift:147-181`: 성공한 뒤에만 `url`, `entries`, 이동 이력, `revision`을 갱신한다. 실패는 `:196-199`의 `.failed(request.url, message)`로 노출하며 이미 성공한 목록을 폐기하지 않는다.
- `Sources/IHateFinder/FilePaneController.swift:245-250`: 상태 문구는 `불러오는 중…`, 실패 경로와 이유를 구분한다. 경로·목록은 마지막으로 성공한 snapshot을 유지한다.
- 독립성: `Tests/IHateFinderCoreTests/BrowserSessionTests.swift:6-41`의 `testSlowSupersededReadCannotReplaceNewerDirectory`는 semaphore로 이전 조회를 묶은 상태에서 새 폴더를 게시하고 늦은 결과가 목록·이력에 섞이지 않도록 검사한다. `:44-83`는 실패 시 committed snapshot 보존을 검사한다. 테스트는 구현과 별도의 assertion 증거이나 실행 결과는 이 담당자가 관측하지 않았다. `docs/behavior.md:32-34`는 같은 동작의 제품 의도이므로 세 번째 독립 실증으로 세면 안 된다.
- 제한: generation guard는 **게시 취소**이며 이전 filesystem 작업의 **실행 취소**가 아니다. 이미 시작한 `list`와 `sorted`를 중단시키는 token, 전용 bounded queue, 중간 결과 스트리밍은 이 파이프라인에 없다. 빠르게 여러 폴더를 요청하면 버려질 조회가 계속 실행될 수 있다는 것은 코드상의 자원 사용 가능성이지 측정된 병목이 아니다.
- 사용자 결과: 느린 폴더의 늦은 결과로 위치가 역행하는 문제를 방어한다. 반면 큰 폴더는 목록 전체가 완성되어야 새 위치·항목을 보여준다. ‘첫 일부 항목이라도 먼저 보기’는 구현되지 않았다.

### SF-O2. 대량 폴더는 전체 열거·메타데이터 조회·정렬 후 한 번에 반영한다 — 구현상의 제한

- 관측 그룹 G1. `Sources/IHateFinderCore/FileOps.swift:192-220`: `contentsOfDirectory(...)`로 URL 배열을 구한 다음 각 URL에 `resourceValues(forKeys: Set(keys))`를 호출하고 `entries.append(...)`한다. 이름, 폴더/패키지/숨김, 크기, 수정일, 종류를 준비한다. `:374-400`는 배열 전체 `entries.sorted`이다.
- `BrowserSession.swift:172-174`: `self.entries = entries`, `revision += 1`로 완성 snapshot을 교체한다. 항목 수 제한, 페이징, 증분 publish는 이 경로에 없다.
- `Sources/IHateFinder/FilePaneController.swift:163-193`: `show()`는 main에서 `EntryFilter.filter(...)`, `table.reloadData()`, 전체 displayed indices를 이용한 선택 URL 복구를 실행한다. revision 변경이 없어도 onChange가 오면 목록 재구성을 거친다. 따라서 조회 시작 onChange에서도 이전 snapshot을 다시 filter/reload할 수 있다.
- `FilePaneController.swift:361-374` 및 `Sources/IHateFinderCore/EntryFilter.swift:6-10`: 필터 입력마다 현재 배열에 `localizedStandardContains`를 적용하고 `reloadData()`한다. `FilePaneController.swift:125`의 `sendsSearchStringImmediately = true`는 입력 즉시 보내도록 설정되어 있다. 이것은 현재 폴더 이름 거르기이며 재귀/Spotlight 검색이 아니다.
- `FilePaneController.swift:258-263`: 선택 크기 합은 선택한 파일만 더하고 디렉터리는 제외한다. `docs/behavior.md:28`의 ‘하위 전체를 읽지 않기 위해서’라는 의도는 이 구현과 맞는다.
- 독립성: 조회·정렬·필터·UI 재구성은 같은 코드 경로의 연결된 관측이며 여러 독립 병목으로 합산할 수 없다. 실제 latency와 memory는 미측정이다.
- 사용자 결과: 모든 항목 metadata와 정렬이 완료될 때까지 loading 상태가 유지된다. UI filter/selection 재구성 비용은 항목 수에 의존하므로 대량 폴더의 첫 표시·입력 지연·스크롤을 함께 측정할 후보이다. 현 시점에는 ‘대량 폴더가 느리다’ 판정 대신 ‘대량 폴더의 성능 보장이 검증되지 않았다’가 맞다.

### SF-O3. 행 재사용은 있으나 아이콘의 앱 수준 비동기 로더·캐시는 없다 — 제한

- 관측 그룹 G2: 셀 렌더링. `Sources/IHateFinder/FilePaneController.swift:540-549`: table delegate의 name 셀 생성에서 `NSWorkspace.shared.icon(forFile: entry.url.path)`를 직접 호출한다. background icon task, placeholder 교체, 앱의 icon cache lookup은 이 함수에 없다.
- `FilePaneController.swift:797-803`의 `reusedCell`은 `tableView.makeView(withIdentifier:owner:)`를 먼저 사용한다. 전체 항목의 아이콘을 list worker에서 미리 수집하는 구조는 아니다.
- `docs/behavior.md:30`의 짧은 인용: ‘아이콘은 화면에 보이는 행만 읽는다.’ 이것은 AppKit view-based table의 요청 시점에 아이콘을 읽는 의도와 맞지만 ‘스크롤해도 창이 멈춘 채로 남아 있지 않는다’는 문구는 측정·실행 증거가 아니다. AppKit이 생성하는 셀이 문자 그대로 visible row에만 한정되는지까지 소스로 증명하지 않았다.
- `NSCache|cache|async|DispatchQueue|Task|prefetch|placeholder`를 FilePaneController와 FileTableView에서 확인했다. 발견한 `dropVolumeCache`는 드래그 정책용이고 아이콘 캐시가 아니다. NSWorkspace/OS 내부 캐시 존재 여부와 효율은 조사하지 않았으므로 ‘아이콘이 매번 디스크에서 읽힌다’고 말하면 안 된다.
- 사용자 결과: 아이콘 비용이 table cell 생성 경로에 포함되므로 고유 파일 종류, custom icon, 네트워크/provider 파일에서 프레임 지연 여부를 측정할 후보이다. 측정 없이 비동기 캐시를 먼저 추가할 필요가 있다는 주장도 과하다.

### SF-O4. 외부 변경 감시와 연속 쓰기 합치기는 이미 있다 — 구현, 범위 제한

- 관측 그룹 G3: 감시. `Sources/IHateFinderCore/DirectoryObserver.swift:17-40`는 현재 폴더·부모 vnode 감시와 metadata FSEvents를 설치한다. 1초 timer는 감시가 없거나 무효화된 경우 재설치하며 건강한 폴더 전체를 매초 poll하는 루프가 아니다.
- `:60-94`는 rename/delete/revoke와 폴더 교체에서 다시 감시한다. 부모의 이벤트에도 현재 폴더 source를 재설치하고 refresh를 요청한다. 따라서 현재 폴더와 직접 무관한 sibling 변경이 불필요 reload를 만들 가능성은 조사 후보이다.
- `:104-113`의 인용 `guard notification == nil else { return }` 및 `.milliseconds(150)`: 첫 이벤트부터 고정 150ms 창으로 합친다. 이벤트마다 deadline을 뒤로 미루는 debounce가 아니므로 연속 쓰기에도 통지가 전달되는 구조다.
- `:132-136`: `realpath(url.path, nil)`로 canonical path를 만들며 ‘Foundation can shorten /private/var to /var; FSEvents reports real paths’에 대응한다. 과거 /private/var mismatch를 현 결함으로 재사용하면 안 된다.
- `:154-177`: FSEvents는 부모 경로를 watch하지만 사용자 갱신 신호는 현재 경로, 직접 자식, dropped/root-changed 등 rescan flags에서 전달한다. 이것이 하위 폴더 검색 구현이라는 해석은 틀리다.
- `BrowserSession.swift:203-210`: loading 중 이벤트는 `refreshPending = true`로 묶고 완료 후 다시 조회한다. 변경 항목만 patch하지 않고 전체 목록을 다시 읽는다.
- 독립성: `Tests/IHateFinderCoreTests/BrowserSessionTests.swift:109-144`는 외부 create/rename/delete, 기존 파일 내용의 size 변경, 폴더 자체 교체 뒤 재감시를 검사한다. 정확한 이벤트/상태 callback을 작업 전에 설치하는 테스트 경로다. sustained writes, 형제 폴더 폭주, 대량 변경, dropped-event 강제 상황, 감시 불가 mount/provider의 규모 검사는 이 테스트에 없다.
- 사용자 결과: 외부 변경이 보이지 않는 기능 부재는 아니다. 대량 폴더에 continuous writes가 겹칠 때 전체 refresh 빈도와 UI 작업량이 쌓이는지를 확인해야 한다. 숫자 150ms와 1초는 정책 값이며 실측 응답시간이 아니다.

### SF-O5. 긴 전송의 진행·취소·부분 결과는 충분히 구체적으로 구현되어 있다 — 구현

- 관측 그룹 G4: 전송 코어·UI. `Sources/IHateFinder/BrowserWindowController.swift:317-350`: copy/move를 background에서 실행하고 progress 및 종료 처리를 main으로 전달한다. callback은 cancellation token identity를 확인해 다른 작업의 늦은 진행을 무시한다.
- `:355-372`: progress bar와 취소 버튼을 보이고 종료 시 숨긴다. `:405-434`는 ‘취소하는 중… 완료된 항목은 유지합니다’, operation/phase/완료 item count/current file, 현재 파일의 copied/total bytes를 표시한다. current path는 tooltip이다.
- `Sources/IHateFinderCore/FileTransferProgress.swift:27-40`: `preparing`, `copying`, `committing`, `finished`를 구분하고 `bytesCopied`는 currentFile 단위다. 폴더 traversal, metadata, conflict, commit은 전체량을 모르면 nil이다. UI는 nil에서 indeterminate로 돌아가며 가짜 batch percent를 만들지 않는다.
- `FileTransferProgress.swift:80-96` 및 `FileOps.swift:260-262`: 기본 0.1초 byte sample 제한, phase/currentFile/determinate 변경 및 최종 byte sample은 즉시 emit한다. 따라서 ‘모든 이벤트가 초당 10개 이하’는 틀리다. 작은 파일 다수는 파일 변경마다 즉시 UI callback이 생길 수 있다.
- `FileTransferProgress.swift:123-150,164-186`: copyfile callback마다 cancellation을 확인한다. native data block은 `1024 * 1024`로 설정한다. 이것은 ‘1MiB마다 반드시 사용자 취소가 완료된다’거나 취소 latency 상한을 보장하는 수치가 아니다.
- `FileOps.swift:263-305`: top-level 선택 항목은 순차 처리하고 첫 실패/취소 후 나머지는 `.unprocessed`로 남긴다. `BrowserWindowController.swift:437-472`는 완료/건너뜀/실패/취소/미처리 및 원본·목적지·복구 위치를 scrollable 결과 sheet에 보여준다. 정상 완료만 있으면 결과 alert는 생략한다.
- 안전성 반증: `FileOps.swift:477-530`는 destination volume staging 후 commit하고 취소를 확인한다. commit/rollback/source cleanup을 중간에 끊지 않는 것은 작업 안전 계약이다. 취소가 항상 즉시 모든 것을 원상복귀해야 한다는 평가 기준은 부적절하다.
- 독립성: `Tests/IHateFinderCoreTests/FileTransferProgressTests.swift:22-54`는 32MiB 파일의 중간 callback에서 취소하고 원본·기존 target·partial stage 보존/정리를 검사한다. `:56-104`는 intermediate/final bytes와 metadata, `:106-130`는 nested file 및 indeterminate progress, `:148-181`는 commit 전·commit 뒤 취소, `:183-198`는 throttling에도 마지막 sample 보존을 검사한다. 이들은 timing benchmark가 아니라 기능·안전성 검사다.

### SF-O6. 동시 전송·대기열·pause/resume·지속 작업 기록은 제공되지 않는다 — 미구현/제한

- 관측 그룹 G4. `BrowserWindowController.swift:318-321`와 `:377-380`의 인용: `guard !busy else { ... 완료한 뒤 다시 시도하십시오. ... return }`. `runReporting`도 `:248-255`에서 같은 busy gate를 공유한다. undo는 `:288-291`, 이름 바꾸기는 `FilePaneController.swift:419-422`에서 거절한다. 같은 브라우저에서 긴 전송 중 두 번째 변경 작업을 예약하지 못한다.
- `Sources/IHateFinder/AppDelegate.swift:4,47-54`: 현재 production entry는 하나의 BrowserWindowController를 보유한다. UI 메뉴 `:108-110`는 창 닫기이며 새 작업 창 생성 명령이 없다. 따라서 다중 controller를 만들어 우회하는 UI도 현재 entry에서 확인되지 않는다.
- `BrowserWindowController.swift:130-138`, `AppDelegate.swift:69-71`: busy이면 창 닫기·앱 종료를 막는다. background work는 앱을 닫아도 지속되는 서비스 작업이 아니다.
- `Sources/IHateFinderCore/BrowserSession.swift:75-77`와 `WorkspaceStore.swift:86-94`는 pane state만 저장한다. `docs/behavior.md:136`도 ‘진행 중인 파일 작업은 저장하거나 재실행하지 않는다’고 명시한다.
- pause/resume/retry/ETA/throughput 관련 여러 literal 및 OperationQueue/TransferQueue/queueTransfer를 Sources·Tests·docs·README에서 검색했고, 전송 scheduler 또는 UI는 찾지 못했다. progress model과 작업 호출 경로 전체를 직접 읽어 부재 주장의 범위를 보강했다. 결과 sheet는 retry 버튼 없이 확인 버튼만 둔다.
- 사용자 결과: ‘긴 복사 걸어 두고 또 다른 정리 작업을 예약하기’가 막힌다. 항목 수는 보이지만 폴더 하나 속 수천 파일을 복사할 때 top-level 완료 count는 오래 0/1일 수 있으며 batch 총량·남은 시간은 제공하지 않는다. currentFile 변화와 bytes는 보이므로 ‘긴 작업은 아무 피드백도 없다’고 요약하면 잘못이다.
- 개선 판단: 이 한계는 성능 저하의 측정 없이도 기능 차이로 설명 가능하다. 실제 사용자 빈도는 미조사이므로 우선순위는 긴 작업 중 다음 작업을 시작하는 시나리오에 대한 판단이다. 무제한 병렬 복사보다는 우선 대기열과 항목별 상태·완료 기록으로 예약 가능한 작업 모델을 만드는 쪽이 안전성 계약을 유지하기 쉽다는 제안이며 구현 사실이 아니다.

### SF-O7. 동일 볼륨 clone 경로는 있으나 ‘항상 즉시/공간 0’은 증명되지 않았다 — 구현과 조건부 최적화

- 관측 그룹 G4. `BrowserWindowController.swift:36-42`: production default가 `FileOps(cloneOnSameVolume: true)`를 쓴다. Core default는 `FileOps.swift:168-177`에서 false다.
- `FileOps.swift:509-515`: clone enabled 및 sameVolume이면 cloneCopy를 선택한다. `FileTransferProgress.swift:179-181`은 `COPYFILE_CLONE` flag를 추가한다. 동일 볼륨 move는 `FileOps.swift:475-480`에서 moveItem을 사용한다.
- `FileTransferProgress.swift:102-105`의 ‘no byte progress, not interruptible’은 clone path 계약 설명이고, fallback data copy는 callback 진행/취소 경로를 가진다. clone 자체와 publish 사이에서 취소를 확인한다.
- 독립성: `Tests/IHateFinderCoreTests/CloneCopyTests.swift:176-189`는 sameVolume false를 주입한 경로의 intermediate bytes를 검사한다. 이는 실제 다른 볼륨 throughput 검사가 아니다. `:192-224`는 clone 지원 volume에서 metadata, no intermediate bytes, 전체 contents equality, available capacity 차이를 검사한다. `:355-362`는 cloning 미지원 시 skip을 허용한다. 전체 volume 여유 공간 관측은 다른 프로세스 쓰기와 독립되지 않아 강한 공간 보장으로 확대할 수 없다. `:306-337`는 clone 뒤 commit 전 취소를 검사한다.
- `docs/behavior.md:80` 및 README의 ‘즉시’, ‘공간을 더 쓰지 않는다’는 제품 설명이다. 본 조사에서는 속도·실제 storage 절감률 수치를 검증하지 않았다. 표현은 ‘동일 볼륨에서 clone을 시도하는 최적화가 있다’가 정확하다.

### SF-O8. 압축과 일반 작업의 피드백은 전송보다 단순하다 — 제한

- 관측 그룹 G5: 비전송 작업. `BrowserWindowController.swift:375-403`: 압축은 background에서 실행하고 indeterminate bar + 취소 버튼을 재사용한다. 파일별 byte/항목 callback은 없다. `:247-267`의 일반 runReporting은 ‘파일 작업 중…’ 상태만 설정한다. 모든 파일 작업이 transfer 수준의 진행률과 취소를 제공한다는 주장은 틀리다.
- `Sources/IHateFinderCore/Compress.swift:57-70`: worker에서 process 상태를 20ms 간격으로 확인하고 취소 시 terminate 뒤 5ms 간격으로 종료를 기다린다. 이것은 UI main의 sleep이 아니다. terminate 뒤 별도 종료 timeout/escalation은 이 루프에 없다. child가 종료 요청에 응하지 않는 상황에서 cancellation이 계속 끝나지 않을 가능성은 코드상의 리드이며 현 runtime failure로 관측하지 않았다.
- `Compress.swift:109-118`: `/usr/bin/ditto`, stderr file, terminationHandler 및 output nullDevice를 사용한다. stderr pipe full로 막히는 구조라고 추정하면 틀리다.
- `Tests/IHateFinderCoreTests/CompressTests.swift:91-111`의 테스트 runner는 terminate 호출 즉시 running을 false로 만든다. 실제 종료 거부/지연은 커버하지 않는다. 0.1초 asyncAfter 취소와 일부 UI 테스트의 polling/sleep은 읽은 시점에 존재한다. 전송 callback 기반 취소 검사는 별개이므로 테스트 전체가 timing luck 기반이라는 일반화는 부정확하다.

## 성능 테스트 범위

G6은 테스트·설정 인벤토리 그룹이다. `Package.swift:21-30`은 CoreTests와 AppTests 두 target을 등록하고 `Makefile:5-6`은 `swift test`를 실행한다. 성능 전용 target이나 recipe는 없다. repository 전체에서 `benchmark|performance|stress|latency|throughput|XCT.*Metric|os_signpost|measure\(` 검색은 일치가 없었으며 파일명 `**/*bench*`, `**/*perf*`, scripts 검색도 별도 benchmark를 찾지 못했다. find의 성능/stress descriptive 검색이 비어 alternate grep/glob으로 확인했다. 이는 무시된/외부 자료까지 성능 검사가 없다는 증명은 아니다.

확인한 범위는 작은 목록의 selection 보존/탐색, 외부 변경과 폴더 교체, 32MiB 단일 파일 byte progress/취소, 작은 nested directory, clone 지원 여부·metadata·best-effort capacity이다. `Tests/IHateFinderTests/FilePaneControllerTests.swift:7-31`는 2→3 항목 갱신과 삭제 선택 해제를 검사한다. `PreviewAndFilterTests.swift:140-141`의 21개 파일은 다중 열기 확인 기준이지 대량 목록 stress fixture가 아니다. `BrowserSessionTests.swift:6-41`의 slow listing은 인위적으로 막은 조회의 정확성 검사이지 latency benchmark가 아니다.

부족한 확인은 1만/10만 항목의 first display/peak memory, sorting·filter input·select-all UI latency, 고유 아이콘 스크롤 frame stalls, continuous writes의 rescan 수/CPU, 작은 파일 다수의 main progress callback 밀도, 실제 외장·네트워크/provider 전송과 취소 latency, 오랜 작업 완료·복구 UI의 읽기 가능성, child 종료 지연이다. 이것들은 실행할 검사 제안이며 현재 불합격이라는 뜻이 아니다. parents의 240개 테스트 통과와 병행해 해석해야 한다.

## 우선순위 판단

1. **먼저 관측 기준을 정한다.** 비동기 목록·아이콘·감시·전송을 각각 재구현하기보다 첫 목록 표시, 입력 응답, frame stalls, refresh count, UI callback count, peak memory, cancellation completion을 소수의 재현 시나리오에서 측정한다. 로컬 APFS와 외장/네트워크/provider는 별도 조건으로 기록한다. 단일 test pass에 기댄 ‘대량 처리도 문제없다’와 소스만 본 ‘느리다’를 둘 다 피한다.
2. **긴 작업 중 다른 작업을 예약하는 기능을 다음 제품 후보로 둔다.** busy gate를 없애 동시 쓰기부터 허용하기보다 대기열/작업별 상태/취소/완료 기록을 추가하는 제안이다. 근거는 SF-O6의 명시적인 두 번째 작업 거절이다. 사용 빈도를 측정한 순위는 아니다.
3. **실측에서 드러난 대량 UI 작업을 좁게 줄인다.** revision 불변일 때 불필요 filter/reload, superseded 조회 실행, icon 호출, watcher-triggered full rescan은 각기 코드 근거가 있는 후보다. 측정 전 전부 고치는 계획은 과잉이다.
4. **전체 작업 feedback은 정직한 의미를 유지해 확장한다.** 폴더 total pre-scan의 비용·취소·provider 접근을 고려한 뒤 phase, 현재 파일, byte rate 또는 남은 시간의 신뢰 범위를 결정한다. 현재의 unknown 구간 indeterminate를 가짜 0~100%로 바꾸는 개선은 권하지 않는다.

## CLAIMS

- SF-C1 / 채택 후보: ‘비동기 목록·정렬, 마지막 요청만 게시하는 보호, 외부 변경 감시, 전송 byte progress와 취소는 이미 구현되어 있다.’ 관측 SF-O1/O4/O5, 그룹 G1/G3/G4. 구현·테스트 assertion은 별개지만 현재 실행 확인은 부모 증거와 연결해야 한다.
- SF-C2 / 채택 후보: ‘긴 작업 도중 두 번째 파일 변경을 대기열에 예약하지 못하는 단일 작업 모델이다.’ SF-O6, G4, `BrowserWindowController.swift:318-321` 인용으로 직접 입증. 실제 사용자에게 잦은 불편인지는 가정이다.
- SF-C3 / 채택 후보: ‘진행 상태는 현재 파일 기준이며 폴더/배치 총량·ETA는 없다.’ SF-O5/O6, G4. 현재 파일·처리 count·취소를 제공한다는 반증을 항상 함께 쓴다.
- SF-C4 / 조건부 후보: ‘아이콘과 filter/reload/selection 재구성은 UI 경로에 있어 대량 목록의 관측 대상이다.’ SF-O2/O3, G1/G2. ‘현재 느리다/멈춘다’로 확대하지 않는다.
- SF-C5 / 채택 후보: ‘32MiB 진행·취소 기능 검사는 있으나 대량 폴더/스크롤/감시 폭주/장시간 실볼륨 성능을 검증한 근거는 확인되지 않았다.’ SF-O7 및 G6 인벤토리. 테스트 통과를 부정하지 않는다.
- SF-C6 / 기각: ‘외부 변경을 못 감지한다’, ‘취소가 없다’, ‘동일 볼륨 복사도 무조건 전체 bytes copy다’, ‘current-folder filter가 검색 전체를 대신한다’. 직접 코드와 기능 assertion이 반박한다.
- SF-C7 / 기각: ‘동일 디스크 복사는 항상 즉시, 항상 추가 공간 0’ 또는 ‘프로그램이 대량 목록에서 멈춘다’. 전자는 조건부 clone 경로를 성능/공간 보장으로 확대하고 후자는 실측이 없다.

## 역사·외부 문서와 독립성

`.git/HEAD:1`은 main을 가리킨다. `.git/logs/HEAD:7`의 `7670195 ... Improve file operation safety and desktop integration`, `:13`의 `0970c61 ... merge origin/cursor/modernize-macos-ui-bb03: Fast-forward`를 읽었다. reflog는 최근 안전성/통합·UI 변경 유입의 증거이지 각 기능의 최초 구현 commit 또는 성능 회귀 원인 증거가 아니다. mounted tool에 bash/git/LSP device가 노출되지 않아 특정 path의 `git log -p` 및 LSP caller 검사는 수행하지 못했다. 이 한계를 source read로 숨기지 않는다.

Apple 공식 비교를 위해 영어 우선으로 copy/progress/resume 관련 두 검색을 수행했으나 이 축의 pause/resume·ETA를 입증할 정확한 official text는 확보하지 못했다. 처음 읽은 기본 `/mac` 문서는 macOS 27을 선택했으므로 부모 안내에 따라 [macOS 26 고정 URL](https://support.apple.com/guide/mac-help/organize-your-files-in-the-finder-mchlp2605/26/mac/26)을 읽었다. 짧은 인용은 ‘You can use the Finder to view, access, and organize almost everything on your Mac.’ 이 페이지는 일반 Finder 목적·sidebar·정렬·Smart Folder를 다루며 transfer queue·pause/resume를 설명하지 않는다. valid_at은 공식 문서 macOS Tahoe 26, observed_at은 2026-10-10, 관측 그룹 G7, 저장소와 독립된 외부 문서이나 **ScaleFeedback의 기능 차이를 직접 뒷받침하지 않는다**. 이를 사용해 ‘Finder는 전송 대기열/남은 시간을 공식 보장한다’고 주장하지 않는다.

## EXPAND

- LEAD SF-L1 — 대량 목록+입력+스크롤의 실제 GUI 측정. 근거 SF-O2/O3. 부모 GUI 조사에 ‘아이콘을 읽는 동안/필터 입력 중 main responsiveness’를 구체 시나리오로 전달한다. 기존 자료에서 닫을 수 없는 runtime 관측이다. 현재 실패 주장 없음.
- LEAD SF-L2 — 작은 파일 다수의 callback 밀도. `FileTransferProgress.swift:85-87`의 phase/file 변경 예외로 기본 0.1초 throttle이 파일당 이벤트를 합치지 않는다. progress callback/UI refresh 수를 계측하기 전 병목 판정 금지.
- LEAD SF-L3 — continuous writes 및 sibling writes에서 전체 rescan 수. `DirectoryObserver.swift:75-94,104-113`와 `BrowserSession.swift:203-210`. 전체 reload 정책, 부모 이벤트 재감시, fixed-window 합치기는 확인했지만 높은 작업량에서의 비용은 미측정이다.
- LEAD SF-L4 — 이전 조회의 실행 취소/동시 조회 상한. `BrowserSession.swift:121-145`. stale publish 차단은 이미 검사되므로 후속 논점은 정확성이 아니라 낭비되는 worker 작업과 metadata I/O이다.
- LEAD SF-L5 — 압축 child 종료 지연 시 취소가 끝나는 계약. `Compress.swift:61-64`. mock는 즉시 종료하며 timeout/escalation은 없다. 실제 ditto가 멈춘다고 단정하지 않는다. 긴 작업 피드백·회복성 담당과 겹치므로 부모가 TransferTrust 축에 교차 전달할 수 있다.
- LEAD SF-L6 — queued jobs와 undo/clipboard/staging 충돌 계약. 단일 busy gate 제거는 undo 및 cut completion snapshot, conflict rememberedChoice, 동일 destination staging과 연결된다. 기존 clipboard/undo/drag를 없는 기능으로 평가하지 말고 향후 queue가 이 안전성을 유지해야 한다는 설계 제약으로 다룬다.
- LEAD SF-L7 — 공식 Finder 긴 전송 feedback 비교. 현재 확보한 Apple page는 queue/pause/resume/ETA 근거를 제공하지 않는다. 부모 AppleBaseline이 정확한 문서 또는 실제 Finder UI 관측을 추가할 때만 비교 주장을 채택한다.
- DEAD END SF-D1 — 과거 /private/var FSEvents mismatch. `DirectoryObserver.swift:132-136`의 realpath canonicalization을 확인했으므로 현 버그 후보에서 제외한다.
- DEAD END SF-D2 — 매초 전체 폴더 polling 또는 매 이벤트 deadline 연장 debounce라는 해석. 건강한 감시는 timer에서 poll하지 않으며 fixed 150ms coalescing이다. 소스로 해소했다.
- DEAD END SF-D3 — progress/cancel/외부 변경/clone 기능 부재 주장. 각 실제 구현과 기능 assertion을 확인해 폐쇄했다.
- DEAD END SF-D4 — 상태 업데이트마다 UserDefaults write라는 추정. `WorkspaceStore.swift:78-83`의 `guard state != lastSavedState else { return }`를 확인했다. updateStatus에서 saveWorkspace를 호출해도 상태 불변이면 JSON encode/write가 생략된다.
- DEAD END SF-D5 — 추가 benchmark가 scripts 또는 별도 target에 숨어 있다는 추정. broad find 뒤 repository grep/filename glob과 Package.swift/Makefile을 확인했으며 별도 성능 suite 근거를 찾지 못했다. 외부·ignored 자산의 존재 여부는 이 부재 판정 범위 밖이다.

소유한 background job, process, 임시 파일, 변경 파일은 없다. 정리할 자원을 생성하지 않았다.