## SourceBrowser 결과

공식 출처 5개 모두 `read`로 가져온 뒤 documented global `browser` API로 실제 렌더했고, 제목과 본문 문구를 DOM 및 화면에서 대조했다. 제품 코드/문서/설정/git 기록은 수정하지 않았고 테스트를 실행하지 않았다. 관측 시각은 2026-10-10 00:07:26 KST(2026-10-09T15:07:26.277Z). 실제 브라우저 backend는 도구가 보고한 `cmux`이다. 요청 viewport는 1440x1000이었으나 실제 관측 viewport는 1159x1320이었다. `fullPage:true`에도 이 backend는 viewport screenshot만 제공하므로 아래 이미지를 전체 페이지 캡처로 취급하면 안 된다.

## 렌더 출처와 screenshot

### SB-O1: Apple Finder 소개
- URL: https://support.apple.com/en-gb/guide/mac-help/mchlp2605/mac
- 실제 document title: `Use the Finder on Mac – Apple Support (UK)`.
- 실제 화면 제목: `Use the Finder on Mac`.
- screenshot: `/var/folders/mz/fkc2n2lj17b_7nzdw81dzkc40000gn/T/omp-sshots-159f9a1892fc7120.webp`.
- 화면에서 확인한 주요 문구: “You can use the Finder to view, access and organise almost everything on your Mac.” 및 “You can customise the sidebar to change or rearrange the items it shows, or add an item you open frequently.”
- 같은 문서의 DOM 본문에서 확인한 문구: “A Smart Folder automatically collects documents based on criteria you set.”
- valid_at: 문서의 기본 선택은 `macOS 27 Golden Gate`였으므로 직접 `macOS Tahoe 26`을 선택해 캡처했다. 이후 DOM `select.value`가 Tahoe 26이며 Smart Folder 링크가 `https://support.apple.com/en-gb/guide/mac-help/create-or-change-a-smart-folder-on-mac-mchlp2804/26/mac/26`, sidebar 링크가 `https://support.apple.com/en-gb/guide/mac-help/customise-the-finder-sidebar-on-mac-mchl83c9e8b8/26/mac/26`으로 바뀐 것을 확인했다. 주소창/canonical은 여전히 위 `/mac`이다. 최종 인용 URL의 버전 고정은 AppleBaseline의 `/26/mac/26` 출처를 사용해야 한다.
- observation_group: Apple-Finder-doc; independence: reader/DOM/screenshot은 같은 Apple 문서의 서로 다른 관측 방식이지 3개의 독립 출처가 아니다.

### SB-O2: Apple Finder 파일 검색
- URL: https://support.apple.com/en-gb/guide/mac-help/mh15155/mac
- 실제 document title: `Narrow your search results in Finder on Mac – Apple Support (UK)`.
- 실제 화면 제목: `Narrow your search results in Finder on Mac`.
- Tahoe 26 screenshot: `/var/folders/mz/fkc2n2lj17b_7nzdw81dzkc40000gn/T/omp-sshots-159f9a25747c7133.webp`.
- metadata/type 검색 추가 screenshot: `/var/folders/mz/fkc2n2lj17b_7nzdw81dzkc40000gn/T/omp-sshots-159f9a5d037c7182.webp`.
- 실제 표시 문구: “You can add criteria to a basic search. For example, you can search for particular kinds of files, or for items created on a particular date.” 화면의 Finder 예제에는 `This Mac`, `Documents`, `Network` 범위와 `Kind is Any` 조건이 보였다.
- DOM 확인 문구: “Your search is saved as a Smart Folder.”, “You can narrow search results using Boolean operators (AND, OR and NOT).” 및 `author:tom`, `kind:images created:16/8/24`, `modified:<=29/7/24` 예제.
- valid_at: 직접 Tahoe 26 선택 후 screenshot과 최종 DOM 값으로 확인. 기본 `/mac` fetch는 27 문서를 반환했으므로 버전 고정 인용은 AppleBaseline과 합쳐야 한다.
- observation_group: Apple-Search-doc; independence: SB-O1과 같은 Apple 문서 집합, 다른 작업 문서. 렌더는 검색 UI 설명의 존재를 확인하며 실제 Finder의 검색 성공률/속도를 측정한 것은 아니다.

### SB-O3: Marta 공식 docs
- URL/final URL: https://marta.sh/docs/ (입력 `/docs`가 trailing-slash URL로 이동).
- 실제 document title 및 화면 제목: `Docs`.
- screenshot: `/var/folders/mz/fkc2n2lj17b_7nzdw81dzkc40000gn/T/omp-sshots-159f9a2b3efc713c.webp`.
- 화면 문구: “Marta is a dual-pane file manager.”, “you can see both source and target directories”, “The active pane is the source, the other (inactive) pane is usually the target.”, “Marta is keyboard-centric”, “All key bindings are configurable.”
- 실제 링크와 섹션 anchor: https://marta.sh/docs/#core-functionality 에 `Operation Queue`, `File Operations`; https://marta.sh/docs/#panes-and-navigation 에 `Recent Locations`, `Volumes`, `Favorites`; https://marta.sh/docs/#useful-actions 에 `Go To Path`, `Look Up`, `Flatten`.
- valid_at: 관측 시점 공식 웹 문서. footer는 `© Yan Zhulanow, 2016-2024`; 이 footer만으로 현재 제품 개발 종료를 추론할 수 없다.
- observation_group: Marta-doc; independence: Apple과 독립적인 제품 설명. 실제 Marta 앱에서 복사/이동/키보드 동작은 실행하지 않았다.

### SB-O4: QSpace 공식 제품 페이지
- URL: https://qspace.awehunt.com/en-us/index.html
- 실제 document title: `QSpace - A Better Finder`.
- 화면 제목/문구: `QSpace`, “A better Finder, more flexible and has rich features!”, “Switching Between 12 Layouts”, “Easily compare, copy, or move files between folders in one window.”
- 첫 화면 screenshot: `/var/folders/mz/fkc2n2lj17b_7nzdw81dzkc40000gn/T/omp-sshots-159f9a30887c7146.webp`.
- 경로/외부 앱 연결 screenshot: `/var/folders/mz/fkc2n2lj17b_7nzdw81dzkc40000gn/T/omp-sshots-159f9a64f8fc7198.webp`.
- 두 번째 screenshot의 실제 표시 문구: `Instant Access to Any Location`, “Interactive address bar for quick folder navigation. Manual input with auto-completion!”, `Open Terminal & Editor Instantly`, “Switch instantly to a terminal or editor for the current folder. The apps used can be fully customized.”
- DOM 추가 문구: “Switch to Windows Key Bindings Instantly”; `Extension: Enhanced Archiver`, `Extension: Server Connections`, `Extension: Stash Shelf`, `Extension: Advanced Batch Rename`.
- valid_at: 관측 시점 공식 제품 소개. 실제 다운로드 링크는 QSpace Pro V7.0.4였으며 페이지 상단 SHA256은 `4A4461872930BBE73C8FF8361CCC4034A0D723FCEAAA618AD1B65FC6EFBB9FD6`. 검색 결과 snippet의 다른 SHA256보다 현 페이지 값을 우선해야 한다. 설치하거나 파일을 다운로드하지 않았다.
- observation_group: QSpace-product; independence: Apple/Marta와 독립 제품의 자기 설명. UI 이미지와 문구는 해당 작업을 제품 가치로 제시한다는 근거이며 실제 동작 안정성 근거는 아니다.

### SB-O5: ForkLift 공식 제품 페이지
- URL: https://www.binarynights.com/ (DOM canonical은 https://binarynights.com).
- 실제 document title: `ForkLift 4 - Dual Pane File Manager and FTP Client for macOS`.
- 실제 화면 제목/문구: `ForkLift 4`, “The most advanced dual pane file manager and file transfer client for macOS.”
- 첫 화면 screenshot: `/var/folders/mz/fkc2n2lj17b_7nzdw81dzkc40000gn/T/omp-sshots-159f9a35b87c7151.webp`.
- 작업 피드백/전송 정책 screenshot: `/var/folders/mz/fkc2n2lj17b_7nzdw81dzkc40000gn/T/omp-sshots-159f9a6514fc719b.webp`.
- 두 번째 screenshot의 실제 표시 문구: `Activity View` 및 “watch your tasks progress in real-time”; `Log View` 및 “file management activities and their results, all in one easy-to-access place”; `Transfers` 및 “Reorder transfers, set conflict management rules, error handling, limit download and upload bandwidth.”
- DOM 추가 문구: `Workspaces`: “Save different layouts with opened tabs and locations and load what you need at the moment.” `Default File Viewer`: “Set ForkLift as the default file viewer and almost every app will point to ForkLift instead of Finder.”
- valid_at: 관측 시점 공식 제품 소개. 페이지 표시 최신 버전은 `4.7.6 (September 29, 2026)`, 요구 macOS는 `14.6`이다.
- observation_group: ForkLift-product; independence: Apple/Marta/QSpace와 독립 제품의 자기 설명. `most advanced`, `20x faster`는 vendor 주장으로, 이번 연구의 실측 결론으로 사용할 수 없다.

## CLAIMS

- SB-C1 [관찰 확정; SB-O1/SB-O2]: Finder 공식 설명은 단순히 현재 위치의 목록을 표시하는 것보다 넓다. 자주 쓰는 위치, 조건 기반 파일 찾기, 검색 저장까지 하나의 작업 흐름으로 소개한다. 사용자 결과: 경로를 모를 때 찾아내고 다음번에 다시 접근하는 작업이 대체 가능성 판단에 포함된다. 우선순위 후보: 탐색/찾기/작업 맥락 보존을 외형 확대보다 먼저 대조한다. 단, IHateFinder의 구체적 구현/부재는 이번 축에서 판정하지 않았다.
- SB-C2 [관찰 확정; SB-O2]: Finder의 검색은 Kind/Name/metadata/Boolean criteria와 저장 가능한 결과 집합을 가진 공식 기능이다. 현재 폴더 거르기와 동일시해서는 안 된다. IHateFinder의 filter는 이미 존재한다는 계약을 존중하며, 재귀/Spotlight 검색 부재 주장은 NavigationFind의 실제 코드 근거와 결합할 때만 채택한다.
- SB-C3 [관찰 확정 + 제품 판단 후보; SB-O3/SB-O4]: Marta와 QSpace는 모두 출발/도착 위치를 함께 보며 파일을 옮기는 흐름을 명시적으로 가치로 삼지만 UI 방향은 다르다. Marta는 keyboard-centric dual-pane, QSpace는 Finder 유사 조작과 12 layouts/경로 자동완성이다. 이는 Finder의 모든 기능을 복제해야 한다는 주장에 대한 반례이며, 사용자의 Windows 탐색기식 작업 마찰을 줄이는 선택적 강점을 먼저 정해야 한다는 판단을 지원한다. 사용자 빈도를 측정한 우선순위는 아니다.
- SB-C4 [관찰 확정 + 제품 판단 후보; SB-O5]: ForkLift는 Activity View/Log View/Transfers를 서로 다른 가치로 제시한다. 파일 작업이 구현되어 있다는 사실과 작업 진행/결과/오류 정책을 사용자가 이해할 수 있다는 사실을 구분할 근거다. IHateFinder의 undo/clipboard/drag-and-drop 구현이 없는 것으로 확대하지 않는다. 우선순위는 TransferTrust/ScaleFeedback의 관측 한계가 확인될 때에만 정한다.
- SB-C5 [관찰 확정; SB-O5]: ForkLift 자기 설명조차 default viewer 효과를 `almost every app`으로 한정한다. Finder로 돌아가는 모든 외부 호출을 완전히 제거해야만 대체품이라는 절대 기준은 공식 대안 설명과도 맞지 않는다. IHateFinder의 open/reveal/default-viewer 설정이 이미 존재함을 전제로 실제 반환 경로를 별도 관측해야 한다.

## 구현/한계/부재 구분 및 반대 증거

이 축은 공식 웹 문서의 표시 상태만 확정한다. Finder/Marta/QSpace/ForkLift 실제 앱 기능 실행이나 IHateFinder 제품 동작을 조사한 축이 아니므로 제품 기능에 `implemented`/`missing` 판정을 부여하지 않았다. 확인된 것은 공식 설명/문구의 존재, 한계는 실제 실행과 성능 미검증, 부재는 이번 조사의 5개 대상 중 접근 불가 페이지가 없었다는 수준이다.

독립 제품 3개가 multi-pane을 강조해도 사용자가 dual-pane을 원하는지, 단일-pane 탭/즐겨찾기가 더 필요한지는 밝혀지지 않는다. Apple의 tags/Smart Folder/iPhone sync 존재도 사용자의 다음 구현에 모두 넣어야 한다는 근거가 아니다. 원격/압축/Git 등 ForkLift/QSpace의 전문 기능은 제품 방향의 증거일 뿐 최소 Finder 대체 요건의 증거가 아니다. Quick Look/undo/filter/clipboard/drag/open/reveal/default-viewer 설정의 부재 주장은 만들지 않았다.

## Cleanup receipt

시작 시 `browser.tabs()`는 `[]`. 생성 소유 탭은 `SourceBrowserAppleFinder`, `SourceBrowserAppleSearch`, `SourceBrowserMarta`, `SourceBrowserQSpace`, `SourceBrowserForkLift` 5개이다. 각각 `browser.close({name})`로 순차적으로 닫았고 도구가 모두 `Released managed tab`을 반환했다. 최종 `browser.tabs()`는 `[]`. `all:true`/`kill:true`는 사용하지 않았다. 다른 사용자의 탭/공유 브라우저 프로세스는 닫지 않았다. screenshot 파일은 근거 전달물로 보존했다. 제품/연구 문서 파일은 생성/수정하지 않았다.

## EXPAND

- LEAD [AppleBaseline 소유, 중복 전달]: 일반 `/mac` URL은 미래 macOS 27 문서를 반환한다. 최종 sources ledger는 Tahoe 26 `/26/mac/26` URL로 고정해야 한다. 이번 렌더는 select 값과 실제 링크의 `/26/` 변화를 확인했으며 screenshot도 Tahoe 26이다. 버전 고정 URL 자체의 검증은 이미 AppleBaseline이 진행 중이라는 부모 메시지에 따라 중복 실행하지 않았다.
- LEAD [AlternativeDocs 소유]: https://marta.sh/docs/#core-functionality 의 `Operation Queue`, https://marta.sh/docs/#panes-and-navigation 의 `Recent Locations`/`Favorites`, https://marta.sh/docs/#useful-actions 의 `Go To Path`/`Look Up`는 기본 작업 흐름 판단에 유효한 하위 문서 진입점이다. 공식 문서 링크의 존재까지만 렌더 확정, 세부 동작은 담당 docs 축에서 확인해야 한다.
- LEAD [NavigationFind/AlternativeDocs 소유]: 공식 검색 결과에서 https://qspace.awehunt.com/en-us/guide/search.html 의 `Search in Pane`와 https://qspace.awehunt.com/en-us/guide.html 의 `global search with the Spotlight index`가 확인되었다. 두 기능의 의도적 분리는 filter와 search를 혼동하지 않을 비교 리드다. 이번 5페이지 렌더 대상에는 넣지 않았으므로 검색 snippet을 최종 기능 주장으로 채택하지 말고 담당 축의 fetch와 결합한다.
- LEAD [DesktopHandoff 소유]: ForkLift `Default File Viewer`의 `almost every app` 한정을 외부 진입점의 실용적 목표와 대조할 수 있다. IHateFinder의 실제 default-viewer 상태 및 Finder 반환 여부는 코드/GUI 담당 축에서 판단한다.
- DEAD END [닫힘]: 광범위 검색에 나온 `file-managers/Marta-for-Mac`, `forklift-soft/forklift`, `Forklift-OSX` 같은 GitHub 결과는 공식 제품 출처로 확인되지 않아 사용하지 않았다. `marta.sh`, `qspace.awehunt.com`, `binarynights.com` 공식 출처로 교체했다.
- DEAD END [닫힘]: cmux에서 `fullPage`는 지원되지 않고 `scrollIntoView(text)` 일부 호출은 의도한 heading 대신 다른 위치를 캡처했다. 화면을 직접 확인한 뒤 실제 h2/h3 DOM 요소의 좌표로 `window.scrollTo`하여 QSpace 경로/ForkLift Activity View를 재캡처했고 최종 근거 이미지는 위의 올바른 프레임이다. 사이트/제품 결함으로 해석하지 않는다.
- DEAD END [닫힘]: 같은 cmux realm의 browser evaluate들을 `Promise.all`로 동시 실행하면 `Cannot set run scope while another same-realm JS runtime is running` 오류가 발생했다. 해당 anchor 수집만 순차 실행으로 바꾸어 전부 확보했고 탭 cleanup도 완료했다.