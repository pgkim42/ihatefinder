# A2 TransferTrust 조사 보고서

## 결론

현재 브랜치는 복사·이동·휴지통·실행 취소·충돌·취소를 이미 상당히 보수적으로 구현한다. 이 축을 '안전장치가 없는 파일 관리자'라고 설명하면 틀린다. 새 대상을 먼저 준비하고, 교체 전 대상을 보존하며, 실패 시 복구하거나 살아 있는 위치를 알려 준다. 전송 취소, 부분 성공 결과, 클립보드 세대 보호, 파일 식별자 기반 실행 취소도 있다.

남은 제품 결핍은 **파일을 보존하는 것과 사용자가 다음 행동을 확신하는 것 사이의 간격**이다. 결과는 예외 상황의 일회성 텍스트 시트에 머물고, 복구 위치 열기·미처리만 재시도·거절된 실행 취소 다시 시도 같은 흐름은 연결되지 않는다. 실행 취소는 세션 50개와 확인 가능한 파일 식별자로 제한된다. 충돌 시 원본/대상 비교와 작업 전체 중단, 폴더 병합도 없다. 이는 작업 마찰에 대한 판단이지, 사용자의 실제 작업 빈도나 'Finder를 다시 켠 원인'을 측정한 결과는 아니다.

정적 분석에서 추가 검증할 두 가지 구체적인 후보도 나왔다. 이름 변경이 실제로 완료되고 후처리 경고만 생겨도 예외를 던져 실행 취소 기록이 생기지 않는 경로, 실패·건너뜀까지 진행 중 '완료 N/M'에 포함하는 표현이다. 재현하지 않았으므로 현재 런타임 버그로 확정하지 않는다.

## 조사 범위와 증거 규칙

observed_at: 2026-10-10. 로컬 코드·테스트·문서의 valid_at: 현재 작업 브랜치 HEAD 0970c61. 코드와 테스트 파일을 읽었으며 빌드, 테스트, 앱 실행, 파일 생성, 설정 변경은 수행하지 않았다. 리드가 전달한 '240개 테스트 통과'는 별도의 리드 검증이며 이 보고서의 직접 관측으로 세지 않는다. GUI 관측은 리드 소유다. `xd://lsp`는 'No such tool'을 반환하여 심볼 탐색은 실제 소스 읽기와 검색으로 대체했다. 소유한 프로세스·임시 파일·설정이 없어 정리할 자원이 없다.

관측 그룹:
- G1: 현재 전송 코어. 실제 구현 관측이지만 실행 관측은 아니다.
- G2: 현재 AppKit 호출·피드백. G1과 같은 제품의 구현이므로 독립 실행 증거가 아니다.
- G3: 저장된 테스트 시나리오. 계약과 의도에 대한 반증 자료이며 G1/G2와 독립 런타임 증거가 아니다. 여기서는 실행하지 않았다.
- G4: 현재 프로젝트 문서. 의도·사용 안내이며 실행 증거가 아니다.
- G5: Apple 공식 macOS Tahoe 26 문서. 제품 외부의 독립 기준이지만 Finder 실행 관측은 아니다.
- G6: 로컬 git reflog. 구현 변화의 독립 역사 자료지만 변경 내용이나 현재 동작을 자체 증명하지 않는다.

기본 `/mac` Apple 페이지는 macOS 27 문서를 반환했다. 아래에서 실제 비교에 사용하는 출처는 `/26/mac/26`을 읽어 선택 버전이 'macOS Tahoe 26'인 것을 확인한 URL이다.

## 구현된 안전장치: 누락으로 분류하면 안 되는 항목

### O-TT-01. 배치별 최종 결과와 중단 상태가 이미 있다

구현됨. `Sources/IHateFinderCore/FileOps.swift:54-60`: 상태 열거형은 `completed`, `skipped`, `failed`, `cancelled`, `unprocessed`를 구분한다. `FileOps.swift:263-305`: 첫 실패 또는 취소 후 `stopped`가 설정되고 나머지 입력도 `.unprocessed` 결과로 남는다. 짧은 인용: `stopped = result.status == .failed || result.status == .cancelled`.

사용자 결과: 일부만 옮겨진 배치를 전부 성공으로 오인하지 않게 설계되어 있다. 스킵은 다음 항목을 계속 처리하지만 실패/취소는 나머지를 중단한다. 전체 배치를 원상복구하는 트랜잭션은 아니며, 앞서 완료한 항목은 유지한다.

반증 자료: `Tests/IHateFinderCoreTests/FileOpsTests.swift:189-217`는 `[.completed, .skipped, .failed, .unprocessed]`, 실제 완료한 원본만 `completedSources`에 들어가는 것을 검증하도록 작성되어 있다. G1 + G3, 직접 관측일 2026-10-10, valid_at HEAD 0970c61, 두 자료는 동일 제품의 종속 증거다.

### O-TT-02. 교체는 기존 대상을 먼저 지우지 않는다

구현됨. `FileOps.swift:491-525`: 목적지 볼륨의 `.ihatefinder-transfer-UUID/incoming`에 새 항목을 준비한 뒤 기존 대상을 `previous`로 옮기고 새 항목을 공개한다. 인용: `try fm.moveItem(at: target, to: previous)` 다음에 `try fm.moveItem(at: incoming, to: target)`.

`FileOps.swift:526-575`: 공개 실패 시 staged source와 previous destination을 원위치로 이동한다. 복구 실패 시 살아 있는 경로를 `.manualRecoveryRequired`에 넣고 보관한다. 인용: `if recoveryErrors.isEmpty && itemExists(stage)`일 때만 stage 정리.

사용자 결과: 교체 도중 실패해서 이전 파일까지 사라지는 단순 덮어쓰기 구조가 아니다. 외부 앱이 원본 자리를 다시 만든 경우 복구가 그 파일을 덮어쓰지 않고 staged original을 보존한다.

반증 자료: `FileOpsTests.swift:219-241` 복사 실패 시 두 원본 보존, `:243-267` commit 실패 후 원본과 대상 복구, `:269-294` 대상 rollback 실패 위치 보고, `:296-326` 재생성된 원본을 덮어쓰지 않는 시나리오를 실제 테스트 코드로 확인했다. G1 + G3, same-date/current-HEAD, 독립 실행 증거 아님.

### O-TT-03. 다른 볼륨 이동의 원본 정리는 복사·공개 뒤다

구현됨. `FileOps.swift:578-593`: `try moveToTrash(url)`은 새 대상 공개가 끝난 이후 수행된다. 원본 휴지통 이동 실패는 `.failed`, 메시지 '복사본은 만들었지만 원본을 휴지통으로 보내지 못했습니다', 복구 위치 `[url, target]`로 남긴다.

사용자 결과: 복사 실패 때문에 원본이 먼저 제거되지 않는다. 이동의 마지막 단계가 실패하면 양쪽의 완성된 파일을 보존한다. 단, '실패'가 '목적지에 아무것도 생기지 않음'을 뜻하지 않으므로 결과의 의미를 잘 보여 줄 필요가 있다.

반증 자료: `FileOpsTests.swift:328-347` partial destination을 공개하지 않고 원본 보존, `:349-365` 원본 휴지통 실패 시 양쪽 파일과 잘라두기 대상 유지. G1 + G3, HEAD 0970c61. 외장/네트워크 실제 볼륨을 사용한 실행 증거는 아니다.

### O-TT-04. 작업 완료 뒤 기존 대상 휴지통 이동 실패도 보존·보고한다

구현됨. `FileOps.swift:594-620`: `previous`의 휴지통 이동 실패 때 `preservedBackup = true`와 복구 위치를 기록한다. 새 대상은 완료 상태로 남을 수 있지만 경고가 붙는다. 인용: '새 대상은 완성되었지만 기존 대상을 휴지통으로 보내지 못했습니다'.

사용자 결과: 새 파일을 성공적으로 공개한 뒤 정리 실패 때문에 새 대상까지 삭제하지 않는다. 대신 숨김 stage 안의 백업을 사용자가 직접 관리해야 할 수 있다.

반증 자료: `FileOpsTests.swift:367-385`, `Tests/IHateFinderCoreTests/CloneCopyTests.swift:136-151`는 성공 또는 결과 필드와 preserved backup을 구분하도록 작성되어 있다. G1 + G3, HEAD 0970c61. 후처리 경고를 안전 실패와 구분할 제품 표현은 별도 과제다.

### O-TT-05. 취소는 파일 중간에도 가능하며 commit은 안전하게 마친다

구현됨. `Sources/IHateFinderCore/FileTransferProgress.swift:4-24`: lock 기반 취소 토큰. `:123-154`: native copy callback에서 취소 확인. `:174-186`: 1 MiB copy block 및 `COPYFILE_ALL | COPYFILE_RECURSIVE | COPYFILE_NOFOLLOW | COPYFILE_EXCL`, 반환 뒤에도 취소 확인.

`FileOps.swift:500-518`: 복사 전·commit 전 취소 확인. `:517-525` 이후 publish/rollback/source cleanup 구간은 취소로 중단하지 않는다. `Sources/IHateFinder/BrowserWindowController.swift:411-415`: '취소하는 중… 완료된 항목은 유지합니다.'라는 실제 UI 코드가 있다.

사용자 결과: 일반 대용량 바이트 복사는 중간 취소가 가능하고, 이미 commit한 항목을 반쯤 되돌리는 중단은 피한다. 취소는 완료 항목 전체를 되돌리는 명령이 아니다.

한계와 반증: production은 `BrowserWindowController.swift:42`의 `FileOps(cloneOnSameVolume: true)`로 동일 볼륨 clone을 사용한다. `FileTransferProgress.swift:96-103` 및 실제 clone flag `:181`에서 clone 경로는 일반 바이트 복사와 다르다. clone은 중간 바이트 진행 없이 한 번에 끝날 수 있고, 시작 전과 완료 후/commit 전에 취소한다. '모든 복사는 즉시 취소된다'도 틀리고 '취소가 없다'도 틀리다.

테스트 코드: `FileTransferProgressTests.swift:22-54` 중간 파일 취소·원본/기존 대상 보존, `:132-146` 충돌 답변 후 취소, `:148-160` 공개 전 취소, `:162-180` commit 도중 취소 요청 후 현재 항목 완료 및 다음 항목 중단. `CloneCopyTests.swift:306-332` clone 후 commit 전 취소. G1 + G2 + G3, HEAD 0970c61, 독립 런타임 증거 아님.

### O-TT-06. 메타데이터와 심볼릭 링크 복사를 의식한 구현이다

구현됨. `FileTransferProgress.swift:180-186`의 native flags는 메타데이터 복사와 링크 비추적을 설정한다. 테스트 `FileTransferProgressTests.swift:56-104`는 권한 0640, 수정 시각, xattr, 파일 내용 동일성을 확인하도록 작성되어 있다. `:106-130`은 nested file과 dangling symlink 보존을 확인한다. clone 경로도 `CloneCopyTests.swift:192-240`에서 메타데이터와 nested/dangling link 시나리오가 있다.

사용자 결과: 단순 데이터만 복사해서 확장 속성·링크를 누락하는 구현으로 설명할 근거가 없다. 반면 테스트가 있다는 이유로 모든 ACL, sparse file, hard link topology, 파일 공급자, 네트워크 볼륨 호환성을 증명했다고 확대해서도 안 된다. 이 특수 환경들은 이번 직접 실행 범위 밖이다. G1 + G3, HEAD 0970c61.

### O-TT-07. 휴지통 실패를 바로 삭제로 우회하지 않는다

구현됨. `FileOps.swift:308-334`: 항목마다 `moveToTrash`, 첫 실패 뒤 `.unprocessed`. `:407-412`: production은 `FileManager.default.trashItem(... resultingItemURL:)`. `:120-133`: 실패 이름, 이유, 이미 휴지통으로 보낸 개수와 남은 개수, 일부 오류의 unsupported-volume 힌트를 만든다.

사용자 결과: 네트워크나 읽기 전용 볼륨에서 휴지통이 실패해도 영구 삭제를 대신 실행하지 않는다. 일부 항목을 보낸 뒤 실패한 배치도 완료된 휴지통 항목의 undo를 기록한다. `FilePaneController.swift:457-465`, `BrowserWindowController.swift:280-283`의 실제 연결을 확인했다.

주의: '아무것도 지우지 않았습니다' 문구만 떼어 보면 배치가 전혀 바뀌지 않았다는 인상을 줄 수 있으나 바로 이어 '휴지통으로 보낸 항목 N개, 그대로 남은 항목 M개'가 있다. 영구 삭제하지 않는 정책과 부분 성공 개수를 함께 읽어야 하며, 이를 즉시 사실 오류로 판정하지 않는다.

반증 자료: `Tests/IHateFinderTests/UndoWiringTests.swift:63-112`의 partial trash → 성공한 첫 항목만 기록 → undo 복원 경로를 읽었다. G1 + G2 + G3, HEAD 0970c61.

### O-TT-08. 실행 취소는 파일 정체성과 빈 자리를 확인한다

구현됨. `Sources/IHateFinderCore/FileUndo.swift:126-144`: 완료하고 실제 경로가 바뀐 항목만 기록한다. `:160-166`: 휴지통 위치를 아는 trashed 항목만 기록. `:181-185`: 역순 undo. `:311-336`: identity 일치, 휴지통 항목 identity, 목적지 빈 자리와 부모 폴더를 확인한다. `:344-351`: missing/stale/occupied/unverifiable/notRestorable/partial 사유를 사용자 문장으로 만든다.

`FileUndo.swift:216-247`은 cross-volume move undo 시 원본을 휴지통에서 꺼낸 뒤 목적지 사본을 휴지통으로 보내며, 사본 정리 실패를 `.partiallyUndone`으로 보고한다. `:285-307`은 교체 전 파일 복원 실패를 부분 성공과 휴지통 위치로 보고한다.

사용자 결과: 같은 경로에 다른 파일이 생겼을 때 그 새 파일을 삭제하는 단순 path-based undo가 아니다. 바꾸기 이전 항목 복원도 있다. 파일 정체성은 '내용이 전혀 수정되지 않았다'와 동일하지 않다. 현재 확인은 persistent identifier이고 내용 digest/mtime 비교는 아니다.

반증 자료: `FileUndoSafetyTests.swift:112-162` 같은 이름의 두 입력이 각각 자기 identity를 유지하는 배치, `:214-320` 부분 undo와 점유 경쟁, `FileUndoTests.swift:413-468` 휴지통 파일 교체/소실의 거절을 읽었다. G1 + G3, HEAD 0970c61.

### O-TT-09. 클립보드의 이동 의도는 세대별로 보호한다

구현됨. `Sources/IHateFinder/FileClipboard.swift:44-73`: 외부 pasteboard changeCount 갱신 시 cut 의도 무효화, 파일 URL만 해석, 외부 파일은 copy. `:83-97`: UUID/changeCount가 일치할 때 완료한 원본만 cut 목록에서 제거. `:102-108`: Escape는 파일 URL을 지우지 않고 이동 의도만 해제.

`BrowserWindowController.swift:323-347`은 작업 시작에 snapshot을 잡고 실제 `completedSources`만 consume한다. 사용자 결과: 실패/취소/미처리 이동은 재시도할 cut 목록에 남고, 오래된 완료 콜백이 새 클립보드를 덮어쓰지 않는다.

반증 자료: `FileClipboardTests.swift:75-162` 새 local cut, 외부 text, partial move, direct move, Escape 시나리오를 읽었다. G1/G2 + G3, HEAD 0970c61. '클립보드 재시도 자체가 전혀 불가능'이라고 말해서는 안 된다.

### O-TT-10. 작업 도중 추가 파일 변경·정상 종료를 막는다

구현됨. `BrowserWindowController.swift:247-250,287-292,317-320`은 busy 동안 추가 작업과 undo를 거절한다. `:130-140`은 창 닫기 거절, `Sources/IHateFinder/AppDelegate.swift:69-74`는 `canClose() == false ? .terminateCancel : .terminateNow`로 종료를 연결한다. 사용자는 전송을 완료하거나 취소한 뒤 닫도록 안내받는다.

반론: 이는 정상 앱 종료 보호이지 강제 종료·전원 상실·크래시 recovery 보장이 아니다. G2, HEAD 0970c61.

## 제한·미구현: 실제 마찰과 개선 순서

### O-TT-11 / P1. 결과 정보는 있지만 복구 행동과 지속성이 부족하다

제한. `BrowserWindowController.swift:437-472`: 문제 결과가 있을 때만 `NSAlert`를 만든다. 인용: `result.addButton(withTitle: "확인")`, `text.isEditable = false`, `text.isSelectable = true`. 모든 항목 상태와 source/destination/recovery path는 표시하지만 복구 위치 열기, 그 항목 선택, 실패·미처리만 재시도 버튼은 없다. `:438`의 guard는 모두 정상 완료이면 결과 시트 자체를 생략한다. `:340-348`은 record 저장, clipboard consume, pane reload, show result 뒤 report를 사용자용 history로 보관하지 않는다.

사용자 결과의 추론: 실패 뒤 경로를 복사해서 직접 찾아가고 어떤 항목을 다시 처리할지 다시 판단해야 한다. 결과 시트를 닫은 뒤에는 이 흐름의 복구 경로를 다시 꺼내는 제품 표면이 없다. 잘라두기 잔여 목록은 일부 재시도 수단이지만 copy·drag·후처리 경고·manual recovery 전반의 대체가 아니다.

권고: 새 전송 엔진보다 먼저 결과 모델을 최근 작업 목록과 연결하고, 복구 위치/목적지 열기 및 선택, 실패·미처리 재시도와 후처리 재시도를 구분한다. 완료 알림은 매번 modal로 강제하기보다 간단한 완료 표시와 다시 열 수 있는 결과가 적합하다는 제품 판단이다.

반증: 이미 모든 경로와 상태를 보여 주는 selectable text가 있고 undo도 있다. '오류 피드백 없음'은 오진. G2, HEAD 0970c61, 체감 영향은 추론.

### O-TT-12 / P1. 실행 취소를 거절한 항목은 그 기록에서 다시 시도하지 못한다

제한. `BrowserWindowController.swift:292-294`: `undoJournal.popLast()`가 실제 undo 실행 전에 호출된다. `:303-310`은 partial/skipped를 알리지만 record를 다시 쌓지 않는다. `FileUndo.swift:98-118`은 세션 메모리 50개 LIFO이며 redo state가 없다. `Sources/IHateFinder/FileTableView.swift:100-102`: file redo 메뉴는 항상 false.

사용자 결과: 원래 자리가 occupied여서 undo를 거절한 뒤 사용자가 그 자리를 비워도 같은 file operation을 다시 undo할 수 없다. 일부 복원 후 실패한 배치를 재적용해서 더 손상시키지 않으려는 보수적 정책이며 데이터 보존 의도와 재시도 부재는 구분해야 한다.

권고: 같은 record 전체를 그대로 재push하지 말고, 현재 남은 reversible 상태를 사용자가 재검토·재시도할 수 있는 결과 흐름을 설계한다. full redo는 별도 기능으로 현재 보고서에서는 P2 이하이며 'undo 없음'보다 정확한 결핍 설명이다. `docs/behavior.md:98-100`도 '같은 작업을 다시 쌓지 않는다'고 명시한다. G1 + G2 + G4, HEAD 0970c61, 문서는 독립 증거 아님.

### O-TT-13 / P1 조건부. 외장/네트워크 볼륨에서 undo는 확인 가능한 identity로 제한된다

제한. `FileUndo.swift:14-26`: `volumeSupportsPersistentIDs`가 false이면 `FileID.read`는 nil. `:311-316`: nil identity는 `.unverifiable`이고 건드리지 않는다. `:160-166`은 trashedURL unknown이면 휴지통 undo record를 만들지 않는다. 교체 전 항목이나 cross-volume source의 Trash 위치가 없으면 `.notRestorable`을 사용한다 (`:220-224,324-327`).

사용자 결과: 이동 자체가 성공했어도 연결된 볼륨의 identity/Trash 특성 때문에 undo가 거절될 수 있다. 사용자가 APFS 로컬 파일만 다룬다면 체감 빈도는 낮을 수 있으며, 모든 exFAT/네트워크 작업에서 실제 실패한다고 일반화할 수 없다.

반증: `FileUndoSafetyTests.swift:75-95`는 non-persistent-ID 조건에서 파일을 하나도 건드리지 않음을 검증하도록 작성되어 있다. 이는 알려진 안전 정책이다. `FileUndoTests.swift:345-357,384-396`도 unknown Trash location 거절을 다룬다.

권고: 가능 여부를 작업 후 undo 시점에만 알려 주지 말고, 해당 작업의 복원 가능 범위를 결과에 표시한다. 안전 확인을 없애고 억지로 undo하는 개선은 권고하지 않는다. G1 + G3, HEAD 0970c61, 실제 볼륨 지원 목록은 미측정.

### O-TT-14 / P1. 충돌 선택 전에 비교할 정보와 작업 전체 중단이 없다

미구현. `BrowserWindowController.swift:727-750`: alert informativeText는 `name` 하나, 버튼은 '바꾸기', '건너뛰기', '둘 다 유지', checkbox는 '남은 항목에도 적용'. `FileOps.swift:4-8` enum도 이 세 가지뿐이다. Resolver 계약 `FileOps.swift:257-260`은 이름 문자열만 받는다.

사용자 결과의 추론: 같은 이름 파일의 어느 쪽이 더 최신/큰지, 출처와 전체 경로가 무엇인지, 폴더 내용을 어떻게 처리하는지 충돌 시트만으로 판단하기 어렵다. '남은 항목에도 적용'은 효율을 높이지만 비교 정보 없이 많은 교체를 결정하게 된다. 별도 취소 토큰은 있으나 conflict는 `runModal()`이며 시트 안에 '작업 중단' 선택지가 없다. 버튼 취소가 전혀 없다는 말은 아니고, 충돌 판단 중의 취소 경로가 분명하지 않다는 한계다.

권고: 원본/대상 경로·파일/폴더 구분·크기·수정 시각, 폴더 교체 의미를 충돌 모델에 추가하고 '이 항목 건너뛰기'와 '작업 중단'을 구분한다. modal의 Esc 실제 반응이나 취소 버튼 접근 가능성은 리드 GUI 관측 대상으로 남긴다. G1 + G2, HEAD 0970c61, runtime 사용성 미관측.

### O-TT-15 / P2 조건부. 폴더 병합은 없다

미구현. `FileOps.swift:435-458`은 같은 이름 item에 세 충돌 선택만 적용하고, replace를 선택하면 `:520-524`에서 기존 대상 item 전체를 previous로 옮긴다. 하위 항목별 병합 분기가 아니다. 범용 `merge`/`병합` 검색과 transfer code 전체 읽기로 확인했다.

독립 기준: https://support.apple.com/guide/mac-help/organize-files-with-folders-mh26885/26/mac/26 의 'Merge two folders with the same name': 'The Merge option appears only if one of the folders contains items that are not in the other folder.' 같은 이름 파일의 다른 버전이 있으면 'Stop or Replace'만 가능하다고 명시한다. Finder가 모든 폴더 충돌을 자동 병합한다고 표현해서는 안 된다.

사용자 결과: 기존 폴더에 없는 파일만 보태려는 경우 whole-folder replace/skip/keep-both는 병합 작업의 대체가 아니다. replace가 기존 폴더를 영구 삭제한다는 뜻은 아니다. 기존 폴더는 보존되고 통상 휴지통으로 옮겨져 undo 대상이 된다.

권고: 반복적인 폴더 합치기가 사용자 핵심 업무일 때 우선순위를 높인다. 그렇지 않으면 비교·결과·재시도 흐름 뒤로 둔다. G1/G2와 독립 G5. official valid_at macOS Tahoe 26 문서, observed_at 2026-10-10.

### O-TT-16 / P2 조건부. 정상 종료 방어는 있으나 중단된 전송의 지속 복구는 없다

미구현 범위. `FileOps.swift:493-497` stage 경로는 UUID이고 진행·원본/기존 대상 경로는 해당 호출의 로컬 변수다. `BrowserWindowController.swift:26,45-59`는 새 세션 undo journal과 view state 복원. `Sources/IHateFinderCore/WorkspaceStore.swift:4-8,45-49`의 persisted schema는 pane path/sort/includeHidden/dual뿐이고, transfer 상태·복구 위치·undo record가 없다. `docs/behavior.md:138`은 진행 중 작업을 저장하거나 재실행하지 않는다고 명시한다.

사용자 결과의 추론: 강제 종료가 stage/previous에 유일한 기존 사본이 있던 순간 발생하면 다음 실행에서 작업 자체의 복구 안내를 만들기 어렵다. 실제 크래시나 파일 손실을 관측한 것은 아니다. 정상 취소와 복구 실패 경로는 이미 살아 있는 위치를 보존한다.

권고: 장시간/외장 작업을 지원 범위로 삼으면 stage의 최소 durable manifest와 시작 시 미완료 작업 안내를 검토한다. 아무 숨김 stage나 자동 삭제하는 정리는 금지해야 한다. 일상 로컬 소규모 작업만 목표라면 P1 결과 UI보다 먼저 대규모 transactional journal을 만들 근거는 약하다. G1 + G2 + G4, HEAD 0970c61.

### O-TT-17 / 정적 후보. 이름 변경은 후처리 경고와 실제 실패를 같은 예외 경로로 취급한다

후속 재현 필요. `FileOps.swift:362-370`: `result.status == .failed || result.message != nil`이면 실제 rename 결과가 `.completed`여도 throw. `:599-610`은 기존 대상 Trash 실패 또는 stage cleanup 실패에 `.completed + message`를 만들 수 있다. `Sources/IHateFinder/FilePaneController.swift:527-536`는 `try ops.rename` 뒤에만 `undoRecord(rename:)`을 만들어 반환한다.

정적 추론: 교체 rename은 실제 파일 이름/위치가 바뀌었지만 후처리 경고가 예외로 전달되면 undo 기록이 생기지 않는다. 경고 alert에는 source/destination/recovery 위치가 포함되므로 아무 설명 없이 성공을 잃는 경로는 아니다. rollback되는 순수 rename 실패는 이미 `FileOpsTests.swift:412-433`으로 별도 시나리오가 있다. 검색에서 후처리 경고 rename의 undo wiring regression은 찾지 못했으며 '전혀 테스트되지 않는다'보다 '이번 검색에서 해당 조합을 확인하지 못했다'가 정확하다.

개선 후보: rename outcome에 완료+경고를 보존해 completion으로 record를 전달하고 경고도 표시할 수 있게 한다. 이 축의 구체적인 신뢰 후보이므로 리드가 정상 테스트 결과와 별개로 정밀 재현할 가치가 있다. G1 + G2, HEAD 0970c61, runtime 실패 주장 아님.

### O-TT-18 / 표현 후보. 진행 중 '완료' 숫자가 성공 개수와 다르다

정적 구현 관측. `FileTransferProgress.swift:89-92`: `.finished`에 `processedItems: index + 1`. `FileOps.swift:301-303`: skip/fail/cancel 결과에도 `.finished` emit. `BrowserWindowController.swift:427`: 이를 `완료 N/M`으로 표시한다.

사용자 결과의 추론: 스킵과 실패도 '완료' 카운트에 포함되는 순간이 있을 수 있다. 최종 결과 시트는 실제 상태별 개수를 다시 계산하므로 최종 결과가 잘못 계산되는 버그는 아니다. '처리 N/M'으로 표현하거나 처리 개수와 성공 개수를 분리하는 작은 개선 후보다. G1 + G2, HEAD 0970c61. 실제 화면의 지속 시간·혼동 여부는 리드 GUI 관측 필요.

## Finder 기준과 과도한 기능 요구를 막는 반론

1. https://support.apple.com/guide/mac-help/delete-files-and-folders-on-mac-mchlp1093/26/mac/26 : 'the items aren’t deleted until you empty the Trash', 그리고 복구는 'choose File > Put Back'. 현재 앱의 Trash-only 정책은 이 기본 안전 개념과 일치한다. 반면 현재 앱의 세션 undo와 Finder의 Trash를 열어서 Put Back하는 제품 경로는 같지 않다. 앱 자체의 Trash browser/Put Back 명령은 `Sources/IHateFinder` 전체의 Trash/restore/Put Back 검색과 메뉴 읽기에서 확인되지 않았다. 이것은 '휴지통 복원 전혀 불가'가 아니라 '세션 undo 이외의 전용 휴지통 복원 표면을 확인하지 못함'이다. Finder로 돌아갈 조건부 업무 리드다.
2. https://support.apple.com/guide/mac-help/if-you-cant-move-or-copy-an-item-on-mac-mchlp1770/26/mac/26 : 'Verify that your destination folder or disk has enough available space', 파일 잠금·권한·외장 드라이브 포맷도 안내한다. 앱은 오류 문자열과 복구 위치를 보여 주지만 부족 공간/읽기 전용/권한 등의 원인별 다음 행동 안내나 space preflight는 transfer 경로에서 확인되지 않았다. Finder가 모든 오류를 자동 해결한다고 확장해서는 안 된다.
3. 현재 native copy 반환을 완료 기준으로 사용하고 내용 checksum 검증은 없다. 이는 신뢰 수준의 범위이지 일반 로컬 복사에 checksum을 의무 기능으로 추가해야 한다는 근거가 아니다. 원본 동시 변경, 원격 연결, 아카이브 검증이 실제 목표인 경우에 별도 검증 모드를 검토할 수 있다.
4. undo, Quick Look, 현재 폴더 filter, 클립보드, drag, open/reveal, default-viewer 설정은 없다고 주장하지 않는다. 이 축은 전송·복구의 제한만 다룬다.

G5 세 출처는 observed_at 2026-10-10, valid_at macOS Tahoe 26 문서이고 서로 같은 Apple guide 계열이다. 독립 비교 그룹은 하나로 센다.

## Git 이력 확인

read-only로 `.git/logs/HEAD`를 읽었다. `:3-4`에 `589826e... test: expect a copy in the same folder to duplicate`, `7c1aaa6... fix: duplicate a file copied into its own folder`; `:7`에 `7670195... Improve file operation safety and desktop integration`; `:13`에 HEAD 0970c61으로의 UI branch fast-forward가 있다. 이력은 같은 폴더 복사와 파일 작업 안전성에 대한 과거 수정을 확인하므로 '처음부터 기본 파일 복사가 전혀 없다'는 설명을 반박하는 보조 자료다. reflog만 읽었고 git object diff는 실행 도구 부재로 읽지 않았으므로 개별 안전장치가 어느 커밋에서 도입됐는지까지 귀속하지 않는다. G6, 현재 로컬 reflog, observed_at 2026-10-10.

## CLAIMS

- C-TT-01 [채택 권고, 높은 확신]: 현재 전송 신뢰의 결핍은 기본 undo/취소/복구 부재가 아니라, 이미 있는 안전 결과를 사용자 행동에 연결하는 흐름의 부족이다. O-TT-01~10이 누락 주장의 반증, O-TT-11~14가 제한 근거. 구현 관측 + 제품 판단이며 사용자 빈도·인과 측정 아님.
- C-TT-02 [채택 권고, 높은 확신]: 가장 먼저 결과를 다시 열고, 실제 살아 있는 위치를 열고, 실패/미처리와 후처리를 구분해 재시도할 수 있게 하는 개선이 이 축의 실용성을 높인다. O-TT-03/04/11/12. 우선순위는 복구 때 필요한 의사결정 수를 줄이는 판단이다.
- C-TT-03 [채택 권고, 높은 확신]: 실행 취소는 안전하지만 session 50개, persistent identity, known Trash URL, 빈 복원 자리라는 한계가 있고 거절된 record는 재시도되지 않는다. O-TT-08/12/13. 'undo 불가'라는 전면 부재 표현은 금지.
- C-TT-04 [채택 권고, 중간 확신]: 원본/대상 비교 정보와 명시적 충돌 작업 중단을 먼저 보강하면 파일 바꾸기 결정을 더 신뢰할 수 있다. O-TT-14. modal 실제 사용성은 미관측.
- C-TT-05 [조건부 채택]: 폴더 병합은 Finder가 제공하는 일부 작업의 실제 간격이다. O-TT-15 + Tahoe 공식 URL. 폴더 합치기 빈도가 높다는 사용자 가정이 확인될 때만 우선순위를 올린다.
- C-TT-06 [조건부 채택]: 긴 전송·외장 볼륨을 주요 대상으로 잡으면 지속 작업 결과와 interrupted-stage 안내가 필요해진다. O-TT-13/16. 현재 크래시·파일 손실 주장으로 쓰지 않는다.
- C-TT-07 [재현 후보, 확정 버그 아님]: completed rename + cleanup warning은 undo record가 누락되는 정적 경로다. O-TT-17. 별도 controlled fault scenario로 확인할 가치가 있다.
- C-TT-08 [표현 후보]: 진행 중 완료 카운트는 성공 개수가 아니라 처리된 입력 개수다. O-TT-18. 최종 결과 카운트는 정확한 별도 계산이므로 결과 전체의 신뢰 버그로 과장하지 않는다.
- C-TT-09 [현재 채택하지 않음]: 전송 queue, pause/resume, checksum, 자동 공간 예측이 없어서 일상 대체품이 될 수 없다는 주장은 이번 증거로 입증되지 않는다. 기본 안전 기능과 bounded single-job 정책의 장점이 있고 사용자 작업 요구가 확인되지 않았다.

## EXPAND

- LEAD TT-E01: completed rename + warning의 undo 누락. 근거 `FileOps.swift:362-370,599-610`, `FilePaneController.swift:527-536`. 정적 분기 추적은 완료. 남은 것은 리드의 controlled fault 재현이며, 기존 rename 성공/rollback 테스트는 이 조합의 직접 반증이 아니다. 현재 버그라고 단정하지 말 것.
- LEAD TT-E02: 결과 시트 닫은 뒤 recovery path 재열기 및 선택. 근거 `BrowserWindowController.swift:437-472`, `:340-348`. 소스상 일회성 결과 표면은 확인됨. 리드 GUI에서 실제 가독성·경로 복사·긴 목록을 확인하면 제품 우선순위 판단을 강화할 수 있다.
- LEAD TT-E03: 거절된 undo 후 원래 자리를 비워도 같은 record 재시도 없음. 근거 `BrowserWindowController.swift:292-310`, `FileUndo.swift:109-114`. 소스와 문서 정책 확인으로 기능 분류는 닫힘. '남은 항목만 재시도'의 안전 모델은 향후 구현 리드다.
- LEAD TT-E04: 충돌 modal에서 Esc/취소 버튼 접근 및 비교 정보. 근거 `BrowserWindowController.swift:727-750`. 세 버튼/이름만이라는 정적 확인 완료. modal의 키보드 실제 결과는 미관측으로 리드 GUI에 넘긴다.
- LEAD TT-E05: 동일 source path가 cross-volume copy 후 원본 Trash 직전에 다른 item으로 바뀌는 경쟁. 근거 `FileOps.swift:511-515,585-587`: source identity capture/recheck 없이 경로를 Trash로 보냄. 실행 취소 단계의 identity 보호와 rollback의 재생성 원본 보호는 있지만 이 commit 후 source 정리 경쟁을 직접 막는 증거는 찾지 못했다. potential race이며 현재 데이터 손실 주장은 금지. 다른 앱이 원본을 수정/교체하는 작업이 중요하면 정밀 fault 재현 후보.
- LEAD TT-E06: undo는 내용 변경을 확인하지 않고 persistent file identity만 확인. 근거 `FileUndo.swift:311-316`. in-place 수정은 같은 ID일 수 있으므로 README '작업 뒤에 항목이 바뀌었으면'의 범위를 교체와 내용 편집으로 구분해야 한다. 내용이 수정된 새 사본을 undo해도 Trash로 보존하는 반증이 있으므로 영구 삭제 버그로 해석하지 않는다. 선언된 정책과 실제 동작의 간격을 리드가 판단할 후보.
- LEAD TT-E07: alias/symlink를 경유한 자기 하위 폴더 목적지. 근거 `FileOps.swift:673-677`의 lexical standardized path containment이며 realpath 기반은 아님. dangling link copy 보존은 이미 구현된 별도 문제다. underlying FileManager/copyfile이 차단할 수 있으므로 현재 실패를 단정하지 않는다. 자기 내부 copy/move 안전 시나리오 확장 후보.
- LEAD TT-E08: interrupted stage의 최소 durable recovery. 근거 `FileOps.swift:493-497`, `WorkspaceStore.swift:4-8,45-49`, `BrowserWindowController.swift:45-59`. 정상 종료 guard가 있어 즉시 위험을 과장하면 안 된다. 비정상 중단을 지원 범위에 넣을 때 manifest/재시작 안내를 검토하며 현재 실행 실패 증거 없음.
- LEAD TT-E09: unsupported persistent IDs 또는 unknown Trash URL에서 undo 가능 범위 표시. 근거 `FileUndo.swift:14-26,160-166,311-327`. synthetic safety regression은 읽었지만 실제 외장/네트워크 볼륨 matrix는 미측정. volume별 지원성을 추가 조사해야 모든 external drive에 대한 일반화를 피할 수 있다.
- LEAD TT-E10: Finder Trash browser/Put Back와 앱의 세션 undo 차이. Tahoe Trash 공식 문서와 `Sources/IHateFinder` Trash/restore 메뉴 검색으로 전용 표면을 확인하지 못했다. 동일 세션의 최근 항목 undo는 이미 있다. 장기 삭제 항목 복원 업무에 한해 DesktopHandoff 축과 결합할 리드.
- LEAD TT-E11: space/권한/읽기 전용 원인별 다음 행동. Tahoe failure-remedies 공식 문서와 `FileOps.swift:284-289,297-298,590-591`, 결과 시트. 현재 localized error와 복구 경로는 있으나 tailored action/preflight는 확인되지 않았다. 자동 용량 예측보다는 실제 오류의 다음 행동 안내가 먼저라는 조건부 제품 판단.
- LEAD TT-E12: 진행 중 완료 N/M 의미. 근거 `FileTransferProgress.swift:89-92`, `FileOps.swift:301-303`, `BrowserWindowController.swift:427`. 정적 문제 분류는 닫힘. 리드 GUI에서 긴 실패/스킵 배치의 체감 확인 후 작은 문구 개선 여부 판단.
- DEAD END TT-D01: '취소 없음', 'undo 없음', '교체 시 이전 파일 즉시 삭제', 'cross-volume copy 실패 시 원본 삭제', '외부 pasteboard 완료가 새 clipboard 지움'. 실제 소스와 해당 regression scenarios가 반증하여 폐쇄.
- DEAD END TT-D02: '폴더 필터 = recursive search'는 이 축의 범위 밖이면서 상위 계약이 이미 구분한 사안. 전송 안전성 결핍 근거로 사용하지 않음.
- DEAD END TT-D03: checksum/queue/pause-resume을 일상 대체성의 필수조건으로 주장. 전송 결과 모델과 native copy 성공 기준은 읽었지만, 사용자의 무결성 검증/동시 전송 요구·작업 빈도 증거가 없어 필수 우선순위로 승격하지 않음.
- DEAD END TT-D04: git commit별 구현 귀속. reflog로 안전성·같은 폴더 copy 수정 이력은 확인했으나 diff를 읽을 실행 도구가 없고 현재 기능 분류에는 필수적이지 않다. 리드가 git read-only 실행 도구를 쓸 경우 역사 비교만 보강할 수 있다.