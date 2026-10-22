# Research brief: IHateFinder가 일상적으로 쓸 Finder 대체품이 되지 못하는 이유
Started: 2026-10-09T15:00:58.920Z (host session start; directory name retained as the fixed research identifier).
Run: 01a1212e-83a8-71ba-944b-ca7da32eb09f

## Goal
현재 구현, 실제 앱 표면, Finder 공식 기능, 다른 파일 관리자의 제품 방향을 조사하여 사용자가 말한 '0.3 Finder'를 일상 작업의 대체 가능성으로 해석하고, 이미 구현된 기능을 누락으로 오진하지 않으면서 핵심 결핍과 근거 있는 개선 순서를 한국어로 제시한다. 제품 코드, 사용자 파일, 설정, git 기록은 수정하지 않는다. 연구 산출물만 작성한다.
I'll stop right away when 모든 축이 조사되고 두 확장 라운드의 미확인 리드가 닫히며, 반론 검토를 통과한 주장과 실제 검증 한계가 명시된 한국어 우선순위 답변이 전달 가능한 상태가 된다.

## Sizing and skills
Tier: LIGHT. 이 세션의 변경은 읽기 중심 연구와 보고 산출물뿐이며 제품 구현이나 설계 변경을 수행하지 않는다.
Skills: ulw-research (사용자 명시 요청; 포화 조사와 반론 검증). whiteboard는 브랜치/PR/아키텍처 그림 요청이 없어 적용하지 않는다. ulw-plan/loop/execute는 별도 실행하지 않는다. 연구에서 요구하는 native ledger만 사용한다.
Ideal end state: 사용자가 왜 자기 앱보다 Finder를 다시 켜는지 납득하고, 다음 한 번의 구현에서 뭘 우선할지 결정할 수 있다. '0.3'은 계량 평가가 아니라 사용자의 최소 실용성 표현이다.

## Axes and named owners
A1 NavigationFind: 찾기, 경로 입력, 바로가기, 탐색의 마찰.
A2 TransferTrust: 복사/이동/휴지통/실행 취소의 신뢰와 오류 복구.
A3 InteractionSurface: 창 구성, 목록, 키보드, 시각 피드백, 조작 발견 가능성.
A4 DesktopHandoff: macOS 다른 앱과 연결, Finder 호출 경로, 파일 공급자/볼륨/메뉴.
A5 WorkspaceContinuity: 즐겨찾기, 창/세션, 복원, 작업 맥락 보존.
A6 ScaleFeedback: 대량 목록과 긴 작업의 피드백, 관측 가능한 병목.
A7 ProductAlternatives: 대체 파일 관리자의 선택적 강점과 제품 포지션.
A8 Skeptic: 기능 부족 만능론, 사용자의 작업 가정, 부재 주장/인과 주장 공격.
Auxiliary: InventoryRecon (전체 구현 누락 방지), AppleBaseline (공식 Finder 작업), AlternativeDocs (일차 제품 문서), SourceBrowser (상위 공식 출처 렌더), NativeRepo (Nimble Commander 소스 구조).

## Topology
한 첫 배치에 독립적인 읽기 전용 scout 7개(6개 코드 축 + 인벤토리), 기본 연구 worker 4개(제품, Apple, 대안, 외부 repo), 브라우저 worker 1개, reviewer 1개를 실행한다. 쓰기 권한은 리드만 갖는다. 리드는 실제 앱 QA, 테스트, 교차 대조, 실시간 journal, 그래프, 최종 답변을 맡는다. 새로 발견된 의존 리드는 기존 소유자에게 재전달하고, 첫 배치 종료 뒤 두 확장 라운드와 신선한 refinement 검토를 실행한다. 자식의 빌드/린트/테스트/포맷은 금지하여 루트에서 한 번만 검사한다.

## Success criteria and concrete scenarios
C1 A1: find/read + 담당 보고서에 '검색과 현재 폴더 거르기'를 구분하고 최소 한 현재 구현 anchor와 한 Finder 공식 anchor가 있는가. evidence wave-1-NavigationFind.md.
C2 A2: 담당 보고서와 swift test 출력으로 이미 구현된 안전장치를 누락으로 오진하지 않으며 결핍/한계와 버그를 구분하는가. evidence wave-1-TransferTrust.md, verify-tests.md.
C3 A3: 실제 앱을 osascript로 activate하고 System Events UI를 읽고 screencapture -x로 창 화면을 저장한다. UI 접근 가능 여부와 관측 결과/한계가 기록되고 코드와 대조되는가. evidence verify-desktop.md, wave-1-InteractionSurface.md.
C4 A4: 앱의 진입점/Info.plist와 Apple 공식 문서를 대조하여 외부에서 Finder로 돌아가게 되는 경로를 구현/미구현/불확실로 분류하는가. evidence wave-1-DesktopHandoff.md.
C5 A5: 저장 상태와 사이드바 구현을 직접 읽어 고정 위치, 사용자 장소, 복원 범위를 구분하는가. evidence wave-1-WorkspaceContinuity.md.
C6 A6: 테스트/구현을 읽고 규모/속도 수치를 실측 없이 단언하지 않는가. evidence wave-1-ScaleFeedback.md.
C7 A7: Apple과 대안 공식 출처를 fetch/render하고 제품 목록이 아니라 이 사용자에게 필요한 작업 기준으로 비교하는가. evidence wave-1-ProductAlternatives.md, sources-ledger.md, browser screenshots.
C8 A8: 모든 최종 주장에 graph node/출처가 존재하고 최소 한 skeptic/refinement 검토를 통과하며, 두 확장 라운드의 리드가 조사/중복/범위외로 명시 폐쇄되는가. evidence debate-log.md, expansion-log.md, SYNTHESIS.md.
C9 Delivery: 한국어 채팅 답변(post)의 static gate + render가 통과하고 outcome verify 및 native final state validator가 통과하는가. evidence post.md, report.html, outcome.json, quality-gate.json.

## Deliverable
lane: no-format (answered_by: request)
state: none (answered_by: default)
formats: post (answered_by: request; 질문의 답변이 목적)
destination: 이 대화 (answered_by: request)
audience: 앱을 직접 만들고 쓰려는 개발자, 짧은 핵심 답변 + 자세한 근거 dossier 링크 (answered_by: request)
template: 구체적이고 자연스러운 한국어 엔지니어 답변 (answered_by: default)
format description: 결론, 핵심 결핍, 개선 순서, 제외할 것, 검증 범위. PDF/DOCX는 만들지 않는다. 다른 형태가 필요하면 사용자 steering을 반영한다.

## Scope classification
Codebase: yes. External: yes. Browsing: yes (공식 문서 provenance + 답변 렌더). Verification: yes. X/social: no (제품 적합성을 소셜 인기로 추정하지 않는다).
Scale: 하나의 제품 질문, both-source single topic, 13 workers. 8 axes이므로 collection 종료 후 신선한 refinement team.
Debate: 검색 우선인가, 즐겨찾기/탭 우선인가, 네이티브 통합 필요 범위, '없음' 주장, 신뢰성의 구현과 체감 차이.

## Initial findings
README.ko.md:108-129: 실행 취소, Quick Look, 현재 폴더 거르기는 이미 존재한다. 과거 메모만 따라 기능 누락을 말하면 틀린다.
docs/behavior.md:13,32-34: 고정 사이드바, 비동기 목록, 외부 갱신을 명시한다.
CONTEXT.md:3,63-65: Windows 탐색기 경로 입력/잘라 옮기기/상세 목록 중심, 거르기는 검색이 아니다.
Git: clean worktree at discovery; HEAD 0970c61, recent UI modernization and undo/Quick Look/filter changes.
Memory: 기존 FSEvents /private/var 경로 불일치 발견 이력이 있다. 현재 결함으로 단언하지 않는다.
