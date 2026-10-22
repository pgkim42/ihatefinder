# Intent vs reality
| intent_id | expected truth | observed reality | diff | invariant | source | observations | status | claims |
|---|---|---|---|---|---|---|---|---|
| I1 | 일상 파일 일을 이 앱에서 끝낸다 | 이미 아는 두 폴더의 목록·전송은 넓게 구현, 재발견·개인 장소·추가 자리 제한 | 사용 빈도는 unknown; 기능 차이는 verified | Finder로 반복 복귀하는 개인 원인을 실측한 척하지 않는다 | user: 0.3 Finder | O2-O6, OA1-OA7, GUI1-3 | unknown | CG02-CG11 |
| I2 | 기존 구현을 정확히 판단한다 | undo/Quick Look/filter/open/reveal/restore 구현, 240 tests PASS, GUI3 filter PASS | 과거 메모와 초기 누락 가설을 교정 | 누락 오진 금지 | README.ko.md + actual sources | O1-O6 | true | CG01,CG04,CG09 |
| I3 | 연결·해제된 디스크 목록을 갱신한다 | .default의 mount observer와 NSWorkspace center 계약 불일치 | source-contract violated; 실제 물리 mount는 미실측 | 플랫폼이 지정한 center에 구독 | docs/behavior.md + Apple didMountNotification | O12 | violated | CG12 |
| I4 | 정확한 경로를 몰라도 장소/파일을 재발견한다 | 사용자 핀·주소 후보·범위 검색이 제품 경로에 없음 | 도달성 확장 후보 | 알려진 경로 처리와 재발견을 혼동하지 않는다 | user replacement intent; recommendation, not prior app promise | OA1,OA5,OA7 | unknown | CG02-CG04 |
| I5 | 필요한 작업 자리를 유지한다 | 한 browser와 두 세션, 마지막 path/sort/hidden/dual 복원 | 세 번째 독립 자리와 선택/스크롤 보존 모델 부재 | 복원 자체를 없는 것으로 취급하지 않는다 | WorkspaceStore.swift; user replacement intent | O3,OA5,GUI2 | true for current contract | CG05 |
