# AppleBaseline: 공식 Finder 작업 기준

## 조사 범위와 판정 방식

영문 질의 16개로 support.apple.com/guide/mac-help를 탐색했고 검색, 즐겨찾기·최근 항목, 보기·태그, 공유, 외장·네트워크 위치의 주요 본문을 read로 확인했다. 중요한 출처는 현 환경에 맞는 `/26/mac/26`으로 재조회했다. 기본 `/mac`은 이번 수집에서 macOS 27 Golden Gate를 반환했으므로 최종 근거에는 기본 URL을 사용하지 않는 편이 좋다.

모든 외부 관찰의 observed_at은 2026-10-10, valid_at은 '그 날짜에 조회한 macOS Tahoe 26 공식 문서'다. 문서의 설명을 관찰한 것이며 실제 Finder 실행 결과가 아니다. 제품 코드 관찰의 valid_at은 현 작업 브랜치 HEAD 0970c61이다. 사용자 사용 빈도, Finder 대비 시간 절감, 실제 결함은 측정하지 않았다. 아래 우선순위는 작업 마찰에 대한 판단이다.

관찰 그룹은 A-SEARCH, A-CONTINUITY, A-VIEW, A-SHARE, A-LOCATION, A-CAVEAT, P-CODE, P-DOC, P-HISTORY로 나눴다. A-*는 모두 Apple이라는 단일 발행자이므로 다른 페이지가 같은 주장을 반복해도 독립 증거로 세지 않는다. P-CODE는 실제 코드 구조라는 별도 증거 종류이고 P-DOC는 같은 프로젝트의 의도·계약이므로 코드와 독립된 실행 검증이 아니다. P-HISTORY는 기능 도입 시점을 확인하지만 동작 성공 증거는 아니다.

## 핵심 해석

공식 Finder 기준에서 일상 대체 가능성을 좌우하는 것은 명령 개수보다 '어디 있는지 모르지만 다시 찾기', '내가 자주 쓰는 장소로 바로 돌아가기', '선택한 파일을 다른 사람·앱·기기로 넘기기', '로컬 밖 위치의 상태와 생명주기 다루기'가 이어지는지다. IHateFinder는 현재 폴더의 목록을 조작하는 기준과 Finder의 탐색·재발견·통합 기준을 분리해 평가해야 한다.

현재 폴더 이름 거르기는 이미 구현되어 있다. 따라서 '검색이 없다'보다는 '현재 폴더 이름 거르기는 있으나 위치를 모르는 파일을 찾는 범위 검색과 메타데이터 검색은 다른 작업'이 정확한 대비다. 외장 디스크도 이미 사이드바 구성 코드가 있으므로 '외장 지원이 없다'고 말하면 틀린다. 즐겨찾기는 '기본 위치 제공'과 '사용자 장소 추가·정렬·유지'를 구분해야 한다.

## 공식 출처 레지스트리: URL / 제목 / 짧은 인용 / 작업 의미

### 검색과 재발견: A-SEARCH

S01. Narrow your search results in Finder on Mac
https://support.apple.com/guide/mac-help/narrow-search-results-in-finder-mh15155/26/mac/26
본문 §Add criteria to a search: “you can search for particular kinds of files, or for items created on a particular date.” 또 “choose Name”, “choose Other”, “Any, All, or None”를 명시한다.
관찰: 이름 포함뿐 아니라 종류·날짜·기타 메타데이터 조건과 조건 조합을 제공하며 검색 저장을 Smart Folder로 연결한다. 추론: 저장 위치를 모르는 자료를 종류·날짜·내용 단서로 재발견하는 작업이 현재 목록 거르기와 다르다.

S02. Change Finder settings on Mac
https://support.apple.com/guide/mac-help/change-finder-settings-on-mac-mchlp2803/26/mac/26
본문 §Advanced / When performing a search: “You can search your entire Mac, the folder that’s currently open, or the scope you specified the last time you searched in a Finder window.”
관찰: 검색의 기본 범위를 사용자가 선택한다. 같은 본문의 §General은 새 창 시작 폴더와 탭 설정을, §Sidebar는 Open/Save 대화상자에도 위치가 나타남을 설명한다.

S03. Create or change a Smart Folder on Mac
https://support.apple.com/guide/mac-help/create-or-change-a-smart-folder-on-mac-mchlp2804/26/mac/26
본문 서두: “the type of file, the date a file was opened, or the contents of a file.” / “the list of files in the Smart Folder is updated automatically.”
관찰: Smart Folder는 기준에 맞는 파일의 자동 갱신 목록이며 파일을 실제 폴더로 옮기는 기능과 다르다. §Create a Smart Folder는 검색 조건 추가, Save, Add To Sidebar를 연결한다.

S04. Narrow your search results in Spotlight on Mac
https://support.apple.com/guide/mac-help/narrow-search-results-in-spotlight-mchl4d69efd3/26/mac/26
본문 §Filter your search based on where the file is stored: “Type iCloud Drive, then press the Tab key.”
관찰: Spotlight도 위치·종류·앱 등의 단서를 다룬다. Finder 검색과 Spotlight 전체 UI를 동일한 기능으로 계산하면 안 된다. 특히 최신 Spotlight의 앱·행동·클립보드 기능은 이 파일 관리자 과제의 필수 요구로 확대하지 않는다.

### 개인 작업 장소와 최근 항목: A-CONTINUITY

S05. Customize the Finder sidebar on Mac
https://support.apple.com/guide/mac-help/customize-the-finder-sidebar-on-mac-mchl83c9e8b8/26/mac/26
본문 §Add or remove sidebar items: “Add a folder or disk to the sidebar: Drag the item to the Favorites section.” / “the original folder, disk, or file isn’t moved from its original location.”
본문 §Change how the sidebar looks: “Rearrange items in the sidebar: Drag an item to a new location.”
관찰: 사용자 폴더·디스크·파일·앱을 추가할 수 있고 Favorites 항목을 재배열한다. 바로가기를 제거해도 원본을 지우지 않는다. 홈·문서·다운로드를 고정 제공하는 것보다 개인 작업 맥락 범위가 넓다.

S06. Finder sidebar (용어 설명)
https://support.apple.com/guide/mac-help/aside/glos200755a1/26/mac/26
본문: “Recents and Shared always appear above the Favorites section, and can’t be moved.” / “You can reorder items in the Favorites and Tags section, but not in the Locations section.”
관찰: Tahoe 문서에서 Recents와 Shared는 설정으로 표시하는 별도 항목이며 모든 사이드바 항목이 자유롭게 재정렬되는 것은 아니다. Recents의 내부 쿼리나 정확한 날짜 정책은 이 문서가 설명하지 않으므로 단정하지 않는다.

S07. Open recently used items on Mac
https://support.apple.com/guide/mac-help/open-recently-used-items-on-mac-mchlp2724/26/mac/26
본문 서두: “Recently used files and servers are listed in the Apple menu.”
관찰: Apple 메뉴 Recent Items는 앱·문서·서버 재접속 기능이다. Finder 사이드바 Recents, 앱 내부 방문 폴더 이력, 최근 서버 목록과 같은 것으로 취급하지 않는다. 파일 관리자만 새로 만든다고 시스템 Recent Items를 대체해야 하는 것도 아니다.

S08. Ways to quickly see items in the Finder on Mac
https://support.apple.com/guide/mac-help/ways-quickly-items-finder-mac-mh11493/26/mac/26
본문 §Group items: “choose Date Last Opened.”
관찰: 최근 열었던 날짜별 그룹, 사이드바 바로가기, 태그, Smart Folder, alias는 서로 다른 재접근 수단이다. 경로를 기억한 사람만 빠르게 이동할 수 있는 기능과 위치를 기억하지 못한 사람의 재발견 기능을 구분할 근거다.

S09. Change how folders open in the Finder on Mac
https://support.apple.com/guide/mac-help/change-how-folders-open-in-the-finder-on-mac-mchlp1032/26/mac/26
본문 서두: “you can open a folder in a new tab or window.”
관찰: 현재 창 내용을 교체하는 탐색 외에 새 탭·새 창을 선택할 수 있다. 이것은 작업 위치 병렬 유지의 기준이지, 사용자에게 탭이 언제나 양쪽 창보다 필요하다는 증거는 아니다.

### 보기·태그·미리보기: A-VIEW

S10. Change how folders are displayed in the Finder on Mac
https://support.apple.com/guide/mac-help/change-folders-displayed-finder-mac-mchldaafb302/26/mac/26
본문 서두: “Icon, List, Column, or Gallery.”
본문 §Choose a view for a folder / List View: “Control-click any column header, then choose columns to show or hide.”
본문 §Customize the view for a folder: “always use the customized view settings for just that specific folder, or for other folders as well.”
관찰: 보기 방식, 목록 열 선택, 폴더별 보기 유지·기본값이 있다. 이미 상세 목록·정렬이 있는 앱에 '보기 기능 없음'이라고 말하면 안 된다. 사진·디자인 자료의 시각적 선택이 중요할 때만 아이콘·갤러리 부재의 영향이 커진다. 문서 자체도 “Try each view to see which one works best.”라고 선택성을 설명한다.

S11. Use tags to organize files on Mac
https://support.apple.com/guide/mac-help/tag-files-and-folders-mchlp15236/26/mac/26
본문 §Tag files and folders: “You can add multiple tags to any file or folder.”
본문 §Find items you tagged: “To see everything with a certain tag, click the tag in the Finder sidebar.”
관찰: 태그는 폴더 위치와 다른 분류 축이며 Finder·Save 대화상자·문서 제목에서 설정하고 검색·그룹·정렬에 사용한다. 태그 사용자가 아니라면 높은 우선순위라고 정당화할 수 없다.

S12. Use the Preview pane in the Finder on Mac
https://support.apple.com/guide/mac-help/use-the-preview-pane-in-the-finder-on-mac-mchl1e4644c2/26/mac/26
본문 서두: “a comprehensive list of all the metadata for the file.”
관찰: 미리보기 pane은 내용의 작은 보기와 파일 종류별 메타데이터, Quick Actions를 결합한다. 이미 구현된 Space/Cmd+Y Quick Look 창과 정보 보기까지 없는 것으로 취급해서는 안 된다. 상시 pane의 가치와 단독 Quick Look의 존재는 별도 평가다.

S13. Perform quick actions in the Finder on Mac
https://support.apple.com/guide/mac-help/perform-quick-actions-in-the-finder-on-mac-mchl97ff9142/26/mac/26
본문 서두: “without opening an app. For example, you can create a PDF or rotate an image.”
관찰: 회전, 마크업, 트리밍, PDF 작성, 이미지 변환, Shortcuts/Automator 확장이 가능하지만 파일 종류와 활성화한 확장에 의존한다. 모든 Quick Actions가 모든 파일에 항상 나타나는 것은 아니다. 문서 변환·이미지 편집이 사용자의 작업이면 이점이고, 코딩 폴더 탐색의 최우선 기능이라는 근거는 아니다.

### 공유와 앱·기기 연결: A-SHARE

S14. Use the Share menu on Mac
https://support.apple.com/guide/mac-help/use-the-share-menu-on-mac-mh40614/26/mac/26
본문 서두: “available in the Finder and in many apps on your Mac” / “using AirDrop or apps such as Mail or Messages.”
본문 §Share items using the Share menu: “select one or more items”와 “Collaborate” / “Send Copy”를 명시한다.
관찰: 기본 앱으로 열기, 다른 앱으로 열기, 클립보드 복사, 파일 드래그와 별도로 선택 파일을 전송 수단에 전달하는 표면이다. 공유 메뉴 항목은 파일 종류와 공유 확장 설정에 따라 달라진다.

S15. Use AirDrop to send items to nearby Apple devices
https://support.apple.com/guide/mac-help/use-airdrop-to-send-items-to-nearby-devices-mh35868/26/mac/26
본문 §Send an item with AirDrop: “Click AirDrop in the sidebar, then drag the item you want to share to the recipient you want to send it to.”
마지막 제한: “AirDrop is best for sharing a small selection of files between devices.”
관찰: Finder AirDrop 표면뿐 아니라 일반 공유 메뉴에서도 사용할 수 있고 다른 앱에서도 가능하다. AirDrop 전용 브라우징을 재구현하지 않더라도 시스템 공유로 작업을 닫을 수 있다는 제품 설계 후보가 나온다. Wi-Fi/Bluetooth, 수신 설정·거리 등의 조건이 있어 전송 성공을 파일 관리자만으로 보장할 수 없다.

S16. Use iCloud to share and collaborate on files and folders
https://support.apple.com/guide/mac-help/share-and-collaborate-on-files-and-folders-mchl91854a7a/26/mac/26
본문 §Invite people to collaborate on files or folders: “it must be in iCloud Drive.”
본문 §View and manage your shared files: “use the Shared folder in the Finder sidebar”.
관찰: 복사본 전달과 협업 초대는 구분되며 접근 대상, 수정 가능 여부, 초대 권한을 관리한다. 로컬 파일 전체에 iCloud 협업이 되는 것은 아니다. Shared는 공유 폴더 경로 단순 목록과도 다르다.

S17. Set up file sharing on Mac
https://support.apple.com/guide/mac-help/set-up-file-sharing-on-mac-mh17131/26/mac/26
본문 §Set up file sharing: “System Settings, click General ... then click Sharing.” / “Read & Write”, “Read Only”, “Write Only (Drop Box)”, “No Access”.
관찰: SMB 호스트 공유 설정은 macOS 시스템 설정의 역할이다. 이를 Finder 필수 내장 기능으로 계산해 대체 앱의 결핍 수를 늘리면 안 된다. 원격 공유 접근 UI와 호스트 공유 설정은 별개다.

### 외장·네트워크·클라우드 위치: A-LOCATION

S18. Connect and use other storage devices with Mac
https://support.apple.com/guide/mac-help/connect-storage-devices-mac-mchl027f1d66/26/mac/26
본문 §Move files to or from an external storage device: “listed below Locations in the Finder sidebar.”
본문 §Eject a storage device: “In the Finder sidebar, click [the Eject button] next to the item’s name.”
관찰: 연결된 저장 장치 탐색·전송·추출은 한 사이드바 표면에서 이어진다. 문서는 다른 앱·사용자가 파일을 사용하면 추출이 안 될 수 있다고 명시한다. 항목 접근과 추출·실패 설명을 구분해야 한다. 같은 문서의 디스크 지우기는 존재하지만 일상 대체의 우선 요구로 승격할 필요가 없다.

S19. Connect your Mac to shared computers and servers
https://support.apple.com/guide/mac-help/connect-mac-shared-computers-servers-mchlp1140/26/mac/26
본문 §Connect to a computer or server by browsing: “click Network in the Locations section of the sidebar.”
본문 §Connect to a computer or server by entering its address: “choose Go > Connect to Server.”
본문 §Reconnect to recent servers: “Add a shared computer or server to your list of favorites.”
관찰: 서버 탐색/주소 입력 → 인증 → 볼륨·공유 폴더 선택 → 최근 서버·즐겨찾기로 재접속의 흐름이 있다. 이미 마운트된 `/Volumes/...` 폴더를 읽는 것과 최초 연결·인증·재접속 표면은 다르다. NAS를 사용한다면 후자가 매번 Finder로 돌아갈 후보 경로다. 실제 사용 빈도는 확인되지 않았다.

S20. Servers and shared computers you can connect to on Mac
https://support.apple.com/guide/mac-help/servers-shared-computers-connect-mac-mchlp3015/26/mac/26
본문: “SMB/CIFS, NFS, FTP, and WebDAV services”.
FTP 제한: “With read-only access, you can copy files from the server, but to copy files to the server, you may need another FTP app.”
관찰: Finder 자체도 모든 원격 프로토콜의 완전한 양방향 클라이언트가 아니다. SFTP·클라우드 서비스별 자체 엔진까지 구현해야 Finder 대체라는 추론을 막는 반례다.

S21. Check your iCloud Drive file and folder status on Mac
https://support.apple.com/guide/mac-help/check-icloud-drive-file-folder-status-mac-mchlc994344b/26/mac/26
본문 서두: “a status icon, which indicates if they’re in iCloud, waiting to upload, and more.”
본문 §View / In iCloud: “only in iCloud” / “choose Download Now.”
관찰: Downloaded, Keep Downloaded, Waiting to Upload, Out of Space와 전송 진행 상태를 구분한다. 파일 경로를 읽을 수 있다는 사실만으로 온라인 전용 파일의 오프라인 사용 가능 여부·동기화 상태를 사용자에게 설명하는 것은 아니다. 이 문서는 iCloud 전용이므로 모든 타사 File Provider의 동일 UI를 입증하지 않는다.

### Finder도 갖는 한계: A-CAVEAT

S22. Prevent Spotlight searches in specific folders or disks on Mac
https://support.apple.com/guide/mac-help/prevent-spotlight-searches-specific-folders-mchl1bb43b84/26/mac/26
본문: “You can exclude files in specific folders or disks from Spotlight searches.”
관찰: 검색 결과 완전성은 검색 제외 설정에 영향을 받는다. Spotlight 연결만 하면 모든 파일을 항상 찾는다는 약속은 금물이다.

S23. If searching your Mac returns unexpected results
https://support.apple.com/guide/mac-help/searching-mac-returns-unexpected-results-mchlp2962/26/mac/26
본문 §Check the location you’re searching: “If you began your search in a Finder window, the search results include only files and folders on the internal disk.”
본문 §Check archives and backups: “double-click the archive to open it, then search again.”
관찰: 공식 문제해결 문서는 내부 디스크와 아카이브 열기 제한을 기술한다. S02의 'entire Mac'을 외장·NAS·zip 내부까지 무제한 검색한다는 표현으로 확대해서는 안 된다. 실제 외장 검색 범위·인덱싱 상태는 별도 실기 관찰이 필요하며 이 축에서는 단정하지 않는다.

S24. If you can’t eject a disk on Mac because an app is using it
https://support.apple.com/guide/mac-help/eject-a-disk-mac-app-mh27076/26/mac/26
본문: “In some cases, a warning message may identify the app that is using the disk.”
관찰: 사용 중 디스크는 추출 실패가 정상적인 시스템 상태일 수 있고, 항상 사용 중 앱 이름까지 식별되는 것도 아니다. 앱 종료·문서 닫기 후 다시 추출하는 복구 절차를 제공한다.

S25. If you can’t eject a disk because another user is using it on Mac
https://support.apple.com/guide/mac-help/eject-a-disk-user-mac-mh27077/26/mac/26
본문: “Log out the users who are using the disk or storage device, then try to eject the item again.”
관찰: 다른 로그인 사용자의 사용 상태도 추출에 영향을 준다. 대체 앱이 추출 버튼을 제공해도 장치 제거가 항상 가능하다고 약속할 수 없다.

## 제품 교차 확인: 구현됨 / 제한됨 / 미확인

P01. 현재 폴더 거르기: 구현됨, 범위 제한됨.
Sources/IHateFinderCore/EntryFilter.swift:6-9: `return entries.filter { $0.name.localizedStandardContains(trimmed) }`.
Sources/IHateFinder/FilePaneController.swift:362-369: `EntryFilter.filter(session.entries, query: filterField.stringValue)`로 현재 세션 목록을 다시 표시한다.
CONTEXT.md:63-65: “하위 폴더는 보지 않는다.”
docs/behavior.md:50: “현재 폴더의 항목 중 이름에 그 글자가 들어간 것만 보인다 ... 하위 폴더는 찾지 않는다.”
관찰 그룹 P-CODE + P-DOC. 검색 API가 안 보인다는 추측이 아니라 이 거르기 함수의 입력·조건이 직접 보여 주는 제한이다. 이를 S01/S02의 범위·조건 검색과 구분할 수 있다. 이 파일을 읽었다는 것만으로 저장소 전체에 다른 검색 기능이 전혀 없다고 증명한 것은 아니며 그 완전성 판정은 NavigationFind 소유 축과 합쳐야 한다.

P02. 기본 위치 및 마운트 볼륨 사이드바: 구현됨, 개인화 표면은 이 구성에서 제한됨.
Sources/IHateFinder/BrowserWindowController.swift:848-858: 홈·데스크탑·문서·다운로드·응용 프로그램을 고정 배열로 만든다.
같은 파일:859-875: `mountedVolumeURLs(... options: [.skipHiddenVolumes])`를 읽고 `/` 또는 `/Volumes` 경로 및 `volumeIsBrowsable` 조건에 맞는 볼륨을 추가한다.
docs/behavior.md:13: 같은 기본 위치·디스크 기준을 명시한다.
관찰 그룹 P-CODE + P-DOC. 외장 디스크 접근은 없다가 아니라 이미 구성되어 있다. 코드가 프로토콜로 NAS 볼륨을 일괄 배제하지 않으므로 이미 `/Volumes` 아래에 마운트된 네트워크 공유도 조건에 따라 보일 수 있다. '네트워크 접근 전체 없음' 역시 잘못된 단정이다. 이 loadPlaces 함수에는 사용자 즐겨찾기·Recents·Shared·Tags를 합치는 로직이 없지만, 사용자 추가/저장의 저장소 전체 부재 판정은 WorkspaceContinuity 결과와 결합한다.

P03. 상세 목록: 제품 문서상 구현 기준 있음; 모든 보기 방식 필요라는 판단은 사용자 작업별 조건부.
docs/behavior.md:22-24: 이름·수정한 날짜·종류·크기와 열 머리 정렬을 명시한다.
docs/behavior.md:153: 탭·아이콘 보기·열 보기·하위 폴더까지 찾기는 앞으로 추가할 동작으로 기재한다.
관찰 그룹 P-DOC. 후자는 계획/계약 근거이지 실제 앱 부재에 대한 단독 실행 증거가 아니다. CONTEXT.md:3은 Windows 탐색기의 경로 입력·잘라 옮기기·상세 목록이 제품 기준임을 명시하므로 Finder의 모든 보기 복제는 제품 방향과 별개로 검토해야 한다.

P04. 공유·태그·클라우드 상태·서버 연결/추출: Apple 기준은 본문으로 확인했고 제품의 구현 여부는 이 축에서 최종 미판정.
docs/behavior.md:104의 우클릭 목록에는 열기·다른 앱으로 열기·복사·압축·경로 복사·정보 보기·터미널 열기가 들어 있다. 이것만 보고 Share가 저장소 전체에 없다고 결론내리지는 않는다. DesktopHandoff/InventoryRecon의 실제 메뉴·API 검색과 대조할 후보다. Quick Look, undo, 클립보드, drag, open, reveal, default-viewer 설정은 기존 구현을 없는 기능으로 계산하지 않는다.

P05. 역사: 기능 누락 오진의 반증.
읽기 전용 `git log -n 8 --format='%h %ad %s' --date=iso-strict -- Sources/IHateFinderCore/EntryFilter.swift Sources/IHateFinder/FilePaneController.swift docs/behavior.md CONTEXT.md` 확인.
22f79b5 (2026-10-04): “feat: Windows-switcher keys, mouse, undo, Quick Look, filter and menu”.
bfa817d (2026-10-04): “feat(core): add pure drop, rename, open, filter, menu and info policies”.
0970c61 (2026-10-04): “Fix PR review findings”.
관찰 그룹 P-HISTORY. 오래된 인상으로 해당 기능 부재를 주장할 수 없다. 이력은 성공률·속도 증거가 아니다.

## CLAIMS: 최종 주장 후보와 우선순위

C-APPLE-01 [높은 신뢰, 우선 판단 P1]. '현재 폴더 거르기와 위치를 모르는 파일을 찾는 검색은 다르다.' P01 + S01/S02/S03. 사용자 결과: 어느 하위 폴더인지 모르는 파일은 현재 목록 거르기만으로 못 찾는다. 개선 후보: 범위를 명시한 하위 폴더/Spotlight 검색을 기존 거르기와 구분하고 결과 경로와 해당 폴더로 이동을 제공한다. 전제: 재발견 작업이 사용 목표에 포함된다. 반증/조건: 매번 정확한 폴더를 아는 작업에서는 현재 거르기가 충분히 빠를 수 있고 Spotlight 별도 호출도 가능하다. '검색부터가 무조건 최우선'이라고 사용 빈도 사실로 표현하지 않는다.

C-APPLE-02 [높은 신뢰의 기준 대비, 우선 판단 P1]. '고정 시스템 위치 사이드바는 내 작업 장소 즐겨찾기를 대체하지 못한다.' P02 + S05/S06/S08. 사용자 결과: 매번 같은 프로젝트·공유 폴더를 전체 경로나 탐색으로 찾아야 하면 경로 입력의 장점과 별개로 반복 마찰이 생긴다. 개선 후보: 사용자 장소 추가·제거·재정렬·지속 저장과 최소 최근 위치. 전제: 사용자 개인화가 저장소 다른 경로에도 없다는 WorkspaceContinuity의 확인. 반증: 홈·문서·다운로드·디스크 접근은 이미 있으므로 사이드바가 없다는 주장이 아니다. Apple Recent Items와 Finder Recents와 앱 폴더 이력을 섞지 않는다.

C-APPLE-03 [기준은 확정, 제품 결핍은 조건부, 우선 판단 P2]. '파일을 여는 것과 파일을 보내는 것은 다른 작업이다.' S14/S15/S16 + P04. 사용자 결과: AirDrop·Mail·Messages로 파일을 보낼 때 앱을 바꾸거나 Finder를 다시 켤 수 있다. 개선 후보: 시스템 Share 표면으로 선택 파일 전달; 전용 AirDrop 엔진 자체 구현은 요구하지 않는다. 전제: 해당 표면이 제품에 없다는 DesktopHandoff 확인 및 사용자의 전송 작업 필요. 반증: 다른 앱의 공유 메뉴·드래그·클립보드로 우회 가능하며 공유 수단은 파일 종류·확장 설정에 따라 제한된다.

C-APPLE-04 [높은 신뢰, 우선 판단 사용 조건 P2]. '볼륨 읽기 지원과 외부 위치의 연결·인증·재접속·추출 지원은 다르다.' P02 + S18/S19/S24/S25. 사용자 결과: NAS 첫 연결이나 디스크 추출 단계가 Finder로 돌아갈 지점일 수 있다. 개선 후보: 필요 시 시스템 연결/추출 통합과 실패 이유 표면. 전제: 사용자 작업에 외장/NAS가 포함된다. 반증: 외장 볼륨 목록은 이미 있고 이미 마운트된 네트워크 볼륨도 코드상 가능하다. SMB 호스트 설정을 앱이 대신 구현할 이유는 없다.

C-APPLE-05 [기준은 확정, 제품 결핍은 미판정, 우선 판단 사용 조건 P2/P3]. '클라우드 파일은 존재/크기만으로 사용할 수 있는 상태를 설명할 수 없다.' S21. 사용자 결과: 온라인 전용, 다운로드 유지, 업로드 대기, 저장소 부족 구분이 클라우드 사용자에게 중요하다. 개선 후보: 제공자 상태·동작 표면 또는 해당 작업을 Finder에 의도적으로 넘기는 정책. 전제: iCloud/다른 File Provider가 실제 대상. 반증: 문서는 iCloud 전용이고 실제 제품 런타임의 클라우드 파일 오류는 관찰하지 않았다. 일반 로컬 폴더 중심이라면 뒤로 미룰 수 있다.

C-APPLE-06 [높은 신뢰, 우선 판단 P3]. '보기 네 종류·태그·Quick Actions를 모두 복제해야 일상 대체가 된다는 주장은 과하다.' S10/S11/S13 + CONTEXT.md:3. 사용자 결과: 사진을 시각적으로 고르는 사람과 상세 목록·경로로 프로젝트 파일을 다루는 사람에게 필요한 표면이 다르다. 개선 후보: 작업에 맞는 열/보기 유지부터 평가하고 갤러리·태그·변환 기능은 그 사용 작업에 근거해 선택한다. 반증: 시각 자료·태그를 많이 쓰는 사용자에게는 이것들이 핵심일 수 있으므로 가치가 없다고 제외하면 안 된다.

C-APPLE-07 [높은 신뢰, 우선 판단에서 제외]. 'Finder가 제공하는 시스템 기능 전부가 대체 파일 관리자의 구현 의무는 아니다.' S17/S20/S22/S23. Finder 자체도 FTP 쓰기, 검색 제외, 아카이브 내부 검색 등에 한계가 있고 SMB 호스트 설정은 System Settings의 역할이다. 개발 범위는 가장 자주 되돌아가는 작업의 연결을 닫는 것으로 정해야 한다. 사용자 빈도를 측정하지 않았으므로 그 순서는 명시적 제품 판단으로만 제시한다.

## 질의 기록

1. site:support.apple.com/guide/mac-help Search for files Finder Mac Spotlight folder criteria
2. site:support.apple.com/guide/mac-help Customize Finder sidebar favorites recents Mac
3. site:support.apple.com/guide/mac-help Change how folders displayed Finder icon list column gallery
4. site:support.apple.com/guide/mac-help Use tags organize files Mac Finder
5. site:support.apple.com/guide/mac-help Share files folders Mac Finder share AirDrop
6. site:support.apple.com/guide/mac-help Connect external storage devices Mac Finder eject
7. site:support.apple.com/guide/mac-help Connect Mac shared computers servers Finder smb
8. site:support.apple.com/guide/mac-help See recently used items Mac Finder Recents
9. site:support.apple.com/guide/mac-help Save search Smart Folder Finder Mac
10. site:support.apple.com/guide/mac-help Customize Finder toolbar preview pane quick actions
11. site:support.apple.com/guide/mac-help Sync files iCloud Drive Finder Mac download status
12. site:support.apple.com/guide/mac-help Customize Finder settings default search folder sidebar
13. site:support.apple.com/guide/mac-help "Finder window" "search criteria"
14. site:support.apple.com/guide/mac-help "Search" "This Mac" "Contents"
15. site:support.apple.com/guide/mac-help "Recents" "recently" "Finder"
16. site:support.apple.com/guide/mac-help "Use the Share menu"

코드 관련 실제 find 후 EntryFilter/FilePaneController 및 BrowserWindowController 반환 범위를 읽었다. literal 교차 검색은 filter/filtered/EntryFilter, 하위 폴더/거르기/검색, 사이드바/외장/태그/공유 등 여러 변형으로 했다. `xd://lsp` 조회 결과 No such tool이므로 LSP는 사용할 수 없었다. 테스트·빌드·포맷·제품 실행은 하지 않았다. 파일·설정·git 변경, 브라우저 세션, 소유 임시 자원은 만들지 않았다. 읽기 전용 git 작업은 완료됐다.

## EXPAND

- LEAD L-APPLE-01 → NavigationFind: 현재 거르기와 별도 범위 검색 API/UI의 저장소 전체 유무를 확정한다. P01은 거르기의 제한만 확정하며 다른 경로의 검색 부재를 단독 증명하지 않는다. S01/S02는 비교 기준. 실제 외장/NAS 검색은 S23의 제한 문구 때문에 보편적 지원으로 단언하지 않는다.
- LEAD L-APPLE-02 → WorkspaceContinuity: 고정 loadPlaces 외에 사용자 장소 저장·추가·정렬 및 Recents가 존재하는지 확정한다. S05/S06/S07을 사용해 즐겨찾기, Finder Recents, Apple Recent Items, 앱 방문 이력을 분리한다. 시스템 Open/Save에 나타나는 Finder 장소와 제품 내부 즐겨찾기 공유 여부는 별도 통합 리드다(S02 §Sidebar).
- LEAD L-APPLE-03 → DesktopHandoff/InventoryRecon: 시스템 Share 호출, iCloud 협업 표면, 선택 파일 AirDrop 전달 존재 여부를 API/메뉴로 확인한다. S14는 open/open-with와 다른 기능이며 기존 클립보드·드래그를 부재로 오진하지 않는다.
- LEAD L-APPLE-04 → DesktopHandoff: 볼륨 mount/unmount 변경 반영, 추출 API, 서버 주소/인증/최근 서버 연결을 읽는다. P02 때문에 외장 또는 이미 마운트된 NAS 접근 '전체 없음'은 폐기한다. S18/S19/S24/S25는 생명주기 및 실패 설명의 기준이다.
- LEAD L-APPLE-05 → DesktopHandoff/ScaleFeedback: iCloud/타사 File Provider의 온라인 전용·동기화 상태 표시/다운로드 유지 동작 여부를 확인한다. S21은 iCloud 공식 기준일 뿐 모든 제공자의 동일 구현을 입증하지 않는다. 실제 클라우드 오류를 관찰하기 전에는 현재 런타임 실패로 쓰지 않는다.
- LEAD L-APPLE-06 → InteractionSurface: 목록 열 선택·폴더별 보기 유지, 상시 Preview pane의 필요를 기존 Quick Look/정보 보기와 분리한다. S10/S12. Finder 보기 네 종류를 전부 우선 구현해야 한다는 것은 사용자 작업 전제 없이는 불성립.
- LEAD L-APPLE-07 → Skeptic/ProductAlternatives: 태그·Smart Folder·Quick Actions 가치가 이 사용자 작업인지 검토한다(S03/S11/S13). 기존 문서의 Windows 상세 목록 목표가 반대 근거다. 사용자 사용 빈도를 측정하지 않았으므로 '자주 쓰니 우선' 대신 '이 작업을 한다면 해당 마찰이 남는다'로 적는다.
- DEAD END L-APPLE-08: 기본 /mac 문서만을 최신 현 기기 근거로 사용하는 경로. 실제 fetch에서 macOS 27을 반환했으므로 중요 페이지 모두 /26/mac/26으로 재조회하여 닫음. 최신 문서의 기능을 현재 브랜치 미구현으로 기계적으로 합산하지 않는다.
- DEAD END L-APPLE-09: Finder는 모든 원격 저장소·검색 범위를 완전하게 다룬다는 가정. S20의 FTP read-only, S22의 제외 설정, S23의 내부 디스크·아카이브 제한을 확인해 닫음.
- DEAD END L-APPLE-10: 네트워크 공유 설정 자체를 Finder 대체 앱의 누락 기능으로 계산하는 경로. S17에서 System Settings의 역할임을 확인해 닫음. 접속·재접속 표면만 비교 대상으로 남긴다.
- DEAD END L-APPLE-11: Recents의 정확한 시간 범위·내부 쿼리를 공식 문서에서 확정하려는 경로. S06은 존재/배치/정렬 제한만 설명하며 S07은 Apple 메뉴의 다른 개념이다. 정확한 내부 정책은 공식 출처로 확정하지 않았고 최종 주장에도 쓰지 않는다.
- DEAD END L-APPLE-12: 디스크 지우기, iPhone 전체 동기화, 최신 Spotlight 앱/행동/클립보드를 일상 파일 탐색 대체의 필수 작업으로 확장하는 경로. 공식 문서에서 존재는 확인되지만 현재 과제의 경로·이동·상세 목록 목표와 직접 연결되지 않아 우선순위 대상에서 제외한다.