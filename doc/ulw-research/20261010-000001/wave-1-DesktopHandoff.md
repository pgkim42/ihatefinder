# DesktopHandoff 조사 보고서

결론: 현재 앱에는 파일을 기본 앱/다른 앱/Terminal로 넘기는 일상 연결과 외부 폴더 열기·파일 reveal 진입점이 이미 있다. 따라서 'macOS 연동이 없다'는 진단은 틀리다. 다만 기본 파일 뷰어를 선언하고 일부 요청을 처리하는 것과 Finder의 모든 진입점·클라우드·공유·태그·볼륨 수명주기를 대신하는 것은 다르다. 이 축의 개선은 Finder 전체 대체보다 '파일을 찾고 고른 뒤 필요한 앱/공유/디스크 작업까지 이어지는 흐름'의 끊김을 줄이는 방향이 타당하다. 우선순위는 사용자 사용 빈도를 실측한 결과가 아니라 작업 마찰과 코드/플랫폼 계약의 확실성에 대한 판단이다.

## 조사 범위와 증거 상태

observed_at: 2026-10-10. valid_at: 현재 main 작업 트리, 기준 HEAD 0970c61b2db1f8a1169a82d6a5bf959a89fe6a57. .git/HEAD:1은 main, .git/logs/HEAD:13-14는 해당 HEAD로의 fast-forward와 checkout을 보여준다. 코드/지원 plist/빌드된 앱의 plist/문서/외부 공식 페이지를 직접 읽었다. 테스트 파일은 의도와 커버리지만 읽었고 실행하지 않았다. 부모가 240개 테스트 통과를 알려왔으나 이는 본 조사자의 독립 실행 관측이 아니다. 앱 실행, 설정 변경, 설치, 볼륨 연결/해제, 클라우드 다운로드, GUI 조작은 하지 않았다. 자식 세션의 도구 목록에는 shell/git 실행기와 LSP가 없어서 git log/diff 및 LSP 조회는 할 수 없었다. 대신 실제 .git reflog를 읽어 해당 축의 과거 변경 제목을 확인했다. 생성하거나 시작한 파일/프로세스/볼륨이 없어 정리할 소유 자원도 없다.

관측 그룹: DH-SRC는 현재 소스의 정적 관측, DH-TEST는 동일 저장소 테스트의 정적 관측, DH-DOC는 저장소의 의도 문서, DH-BUNDLE는 실제 앱 번들의 plist 정적 관측, DH-APPLE-API는 Apple 개발자 계약, DH-APPLE-26은 Tahoe 26 공식 사용자 문서, DH-HISTORY는 git reflog. 같은 저장소의 구현·테스트·README는 서로 독립된 실행 증거가 아니다. Support/Info.plist와 앱 번들 Info.plist의 일치는 패키징 일치 증거지만 실행/LaunchServices 등록 증거는 아니다. Apple 자료는 저장소와 독립된 플랫폼 계약/기능 증거다. 처음 /mac 주소는 미래 27 버전을 반환했고, 최종 사용자 문서 출처는 /26/mac/26으로 다시 fetch하여 고정했다.

## 1. 외부 요청과 기본 파일 관리자 진입점

### 구현됨

- Sources/IHateFinder/AppDelegate.swift:10-16: `applicationWillFinishLaunching`에서 `kAEMiscStandards` + `kAEMakeObjectsVisible` Apple Event handler를 등록한다. 19-25는 reveal direct object와 `application(_:open:)` URL 목록을 같은 수신 경로로 연결한다. 33-45, 49-55는 창 생성 전 요청을 큐에 넣고 창 표시 후 한 번 drain한다. 코드에 cold-launch 방어가 있으므로 '앱이 꺼졌을 때 외부 요청을 못 받는다'는 부재 주장은 금지한다. DH-SRC, current branch.
- Sources/IHateFinder/OpenRequest.swift:11-21: `resolvingSymlinksInPath()` 후 존재/리소스를 검사한다. 일반 폴더는 `.showFolder`, 파일·패키지는 `.reveal(parent:select:)`, 없는 경로는 `.failure`. 인용: `values.isDirectory == true, values.isPackage != true`. 외부 요청의 파일은 파일 자체를 실행하는 것이 아니라 부모 폴더에서 선택한다.
- Sources/IHateFinder/BrowserWindowController.swift:204-220: 최소화 해제, 창 표시, activate 후 포커스 창에서 navigate/reveal한다. 인용: `focused.revealAfterReload(item, rename: false)`. Sources/IHateFinder/FilePaneController.swift:199-220는 목록 비동기 완료 뒤 선택/스크롤하며, 거르기에 가려진 항목이면 거르기를 해제하여 드러낸다. 'filter 때문에 reveal이 언제나 실패한다'는 반증 가능 가설은 현재 소스와 맞지 않는다.
- Support/Info.plist:20-32 및 IHateFinder.app/Contents/Info.plist:20-32: `public.folder`, `Viewer`, `Alternate`를 동일하게 선언한다. 폴더 처리자로 선택될 수 있는 메타데이터는 실제 번들에도 포함되어 있다.
- Tests/IHateFinderTests/OpenRequestTests.swift:30-99는 folder/file/package/symlink/missing path/first-existing/list descriptor/queue drain을 검사하도록 작성되어 있다. OpenHandlingTests.swift:7-46는 parent navigation+selection과 focused folder navigation을 검사한다. 이 테스트들의 존재는 코드 의도를 보강하지만 외부 앱→Apple Event→실제 앱의 E2E 증거가 아니다. 두 GUI 처리 테스트는 sleep polling을 사용하므로 정적 읽기만으로 결정적 이벤트 기반 검증이라고 부르지 않는다.

### 제한됨

- OpenRequest.swift:25-35: URL 배열을 받아도 첫 유효 요청에서 곧바로 `return request`. Tests/.../OpenRequestTests.swift:59-66가 이 동작을 명시적으로 고정하고 docs/behavior.md:143-152도 '처음으로 찾은 유효한 항목만 처리'라고 설명한다. 여러 파일 reveal은 첫 파일만 선택되며 나머지는 처리되지 않는 제품 제한이다. macOS 쪽 공식 API는 [activateFileViewerSelecting(_:)](https://developer.apple.com/documentation/appkit/nsworkspace/activatefileviewerselecting(_:).md)에 `The files to select and display in the Finder`, `one or more windows`라고 문서화되어 있어 다중 항목 작업과의 차이가 있다. Apple API 호출이 항상 본 앱으로 전달된다는 뜻은 아니다.
- 심볼릭 링크는 항상 target으로 정규화한다(OpenRequest.swift:12). 링크가 놓인 폴더에서 링크 자체를 보고 싶은 reveal 의도와 달라질 수 있으나, 이는 docs/behavior.md:144의 명시적 계약이므로 현재 버그라고 단정할 수 없다.
- 외부 요청은 새 탭/새 창을 만들지 않고 포커스 창을 재사용한다(BrowserWindowController.swift:211-219). 작업 중이던 창의 경로가 바뀔 수 있다는 UX 추론은 가능하다. 문서가 의도한 행동이고 실제 사용자의 불편/데이터 손실 관측은 없다.

### 기본값 설정과 전체 대체의 경계

README.ko.md:173-197, README.md:173-197은 설치/첫 실행 후 사용자가 `NSFileViewer`와 `public.folder` LSHandlers 설정을 바꾸고 재로그인하도록 안내한다. '앱은 이 설정을 바꾸지 않습니다'는 실제 코드 검색에서도 자동 등록/설정 변경 API가 없는 것과 일치한다. 앱 내 원클릭 설정·상태 진단은 보이지 않지만 기본 뷰어로 쓰는 절차 자체가 없는 것은 아니다.

[Apple Info.plist 문서](https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/CoreFoundationKeys.html), CFBundleDocumentTypes 표: Alternate는 `a secondary viewer of files of this type`; 우선순위는 Owner, Default, Alternate. valid_at: archived 2018-06-04. 따라서 plist에 폴더 타입이 있다는 사실만으로 현재 시스템 기본 관리자 등록을 주장하면 안 된다.

README.ko.md:220-227과 docs/behavior.md:152는 데스크탑, Dock Finder 아이콘, 열기/저장 패널, Finder로 직접 요청하는 앱을 대체 범위 밖으로 둔다. 여기서 열기/저장 패널은 별도의 시스템/AppKit 표면이지 'Finder 프로세스를 열어야만 작동'한다고 오독하면 안 된다. 정확한 결론은 '기본 파일 뷰어 설정이 그 패널을 IHateFinder UI로 교체하지 않는다'이다.

Apple의 [activateFileViewerSelecting(_:)](https://developer.apple.com/documentation/appkit/nsworkspace/activatefileviewerselecting(_:).md) 설명도 `Activates the Finder`라고 표현한다. NSFileViewer를 검색했지만 검색 결과와 읽은 공식 문서에서 그 defaults 키로 모든 reveal 호출을 대체한다는 보장은 찾지 못했다. README의 '다른 앱 요청이 온다'는 설치 후 기대 동작이며 이 기기 설정/외부 앱 경로별 검증은 미수행이다. 모든 호출 전환 실패를 주장하는 것도, 모든 호출 전환 성공을 주장하는 것도 근거가 없다.

## 2. 다른 앱으로 이어지는 일상 작업

### 구현됨

Sources/IHateFinder/FilePaneController.swift:14-28: 기본 앱 열기는 `NSWorkspace.shared.open($0)`, 열 수 있는 앱 목록/default 앱은 `urlsForApplications(toOpen:)`/`urlForApplication(toOpen:)`, 다른 앱 선택은 `open(urls, withApplicationAt:configuration:)`, Terminal은 `com.apple.Terminal` 앱 URL로 폴더를 전달한다. 693-724는 여러 선택 항목에 공통인 앱만 제시하고 모두 기본 앱이 같을 때 `(기본)`을 붙인다. 731-736는 선택 또는 현재 폴더로 Terminal을 연결한다. 정보 보기는 Finder 호출이 아니라 앱 자체 InfoPanel이다. 756-793에는 우클릭 메뉴가 실제로 구성되어 있다. 인용: `("경로 복사", ...)`, `("정보 보기", ...)`, `("터미널에서 열기", ...)`.

Sources/IHateFinderCore/OpenPlan.swift:14-21: 파일이 선택에 있으면 모든 파일을 기본 앱으로 연다. 20개 초과 확인 기준은 line 10, FilePaneController.swift:301-306의 confirm 경유가 실제 호출과 연결된다. 외부 reveal의 첫 항목 제한과 내부 다중 파일 실행은 서로 다른 경로다.

Sources/IHateFinder/FileClipboard.swift:51-72,110-128: 로컬 `.fileURL` pasteboard를 읽고 NSURL 목록을 쓴다. 내부 cutSnapshot만 이동 의도를 보유하고 다른 앱에는 일반 파일 URL을 전달한다. 외부 파일 클립보드는 복사로 취급한다. 이는 Finder와 파일 URL 복사 교환이 구현되어 있다는 반증이다. 'Finder에서 잘라내기/이동 의도까지 양방향 호환'이라고 넓히면 안 된다.

FilePaneController.swift:578-653: NSURL drag writer와 URL drop validation/acceptance, 볼륨 및 source-operation mask 기반 DropPolicy 연결이 있다. 파일 URL drag/drop 부재 주장은 틀리다. 검색한 NSFilePromise 계열은 없어 지연 생성 파일 promise를 수신하는 구현까지 있다고 할 수 없다.

### 제한됨: 열기 실패 피드백

FilePaneController.swift:14는 `open(URL) -> Bool` 결과를 버린다. 20-25의 비동기 open-with/Terminal 호출에는 completionHandler 처리가 없다. Terminal 앱을 찾지 못하면 `guard ... else { return }`. 공식 [NSWorkspace](https://developer.apple.com/documentation/appkit/nsworkspace.md)는 open(URL) 반환 Bool 및 비동기 완료 핸들러 계약을 제공한다. 그러므로 '실행 요청 실패 이유를 보여줄 코드가 없다'는 정적 주장은 가능하다. '현재 파일이 안 열린다'는 실행 실패 주장은 관측하지 않았다. 사용자 결과: 실패하는 경우 목록에는 파일이 있지만 실행되지 않은 이유를 이 앱에서 확인하기 어렵다. 우선순위 P1 후보: 기존 연결을 더 추가하기 전에 이 경계의 성공/실패 피드백을 보강.

## 3. 볼륨: 초기 목록은 구현, 수명주기는 계약 불일치 후보

BrowserWindowController.swift:846-876: 고정 위치+`mountedVolumeURLs`, `.skipHiddenVolumes`, browsable 필터, `/` 또는 `/Volumes/` 경로 필터로 초기 디스크 목록을 만든다. `volumeIsEjectable`는 externaldrive/internaldrive 아이콘 선택에만 사용한다. mounted disk/network share가 해당 경로 조건을 만족하면 파일시스템 탐색이 가능하다. '네트워크 파일을 전혀 못 다룬다'는 결론은 틀리다.

중요한 신규 정적 결함 후보: BrowserWindowController.swift:78-89는 `NSWorkspace.didMountNotification`과 `.didUnmountNotification`를 `NotificationCenter.default.addObserver`로 구독한다. Apple [didMountNotification](https://developer.apple.com/documentation/appkit/nsworkspace/didmountnotification.md) 및 [didUnmountNotification](https://developer.apple.com/documentation/appkit/nsworkspace/didunmountnotification.md)는 둘 다 다음을 명시한다: `use ... NSWorkspace/notificationCenter to register ... If you use a different notification center ... you won’t receive the notification.` [notificationCenter](https://developer.apple.com/documentation/appkit/nsworkspace/notificationcenter.md)는 워크스페이스 알림용 별도 센터임을 명시한다. current source vs 독립 공식 계약 불일치다. 앱 실행 중 연결/해제의 사이드바 자동 갱신이 의도대로 되지 않을 가능성이 매우 높지만 실제 mount/unmount 재현을 하지 않았으므로 현재 런타임 실패로 보고하지 않는다. 초기 refreshPlaces는 632, handler는 523-526에 있으므로 시작 시 디스크 목록까지 없는 것으로 확대하면 안 된다. 이 항목을 부모의 실행 검증/차기 버그 수정 대상으로 전달한다.

꺼내기/서버 연결 UI와 action은 소스/메뉴에서 찾지 못했다. eject/unmount/NetFS/connectToServer/smb/afp 등 여러 문자열과 descriptive find 대체 검색을 수행했다. 공식 [NSWorkspace](https://developer.apple.com/documentation/appkit/nsworkspace.md)의 `unmountAndEjectDevice(at:)`는 `Attempts to eject the volume mounted at the given path.` 사용자 결과: 외장 디스크 작업 뒤 안전하게 꺼내거나 새 서버를 연결하는 단계는 다른 앱/시스템 경로로 넘어가야 한다. ejectable 아이콘은 꺼내기 action의 반증이 아니다. 판단: 외장 디스크를 자주 다루는 사용 시 P1, 그렇지 않으면 P2. 빈도 자료는 없다.

## 4. Services·공유·태그·파일 공급자

### Services: 제공/소비 모두 파일 선택 표면은 미구현

AppDelegate.swift:77-111의 app 메뉴는 종료 항목을 만들고 다른 메뉴들을 수동 구성한다. Services submenu 설정이 없다. Support/Info.plist와 번들 plist에는 NSServices 선언이 없다. Sources 전체에서 servicesMenu/registerServices/validRequestor/readSelectionFromPasteboard/writeSelectionToPasteboard 등 여러 변형을 검색했고, descriptive find도 추가 수행했다. [Services Properties](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/SysServices/Articles/properties.html) (valid_at 2016-09-13)는 `Services are advertised through the NSServices property ... Info.plist`라고 설명한다. [Tahoe Services 사용자 문서](https://support.apple.com/guide/mac-help/use-services-in-apps-mchlp1012/26/mac/26)는 `select an item, such as a file` 후 app menu > Services를 안내한다.

구분: 다른 앱에서 'IHateFinder에서 보기'를 Services로 제공하는 진입점과 이 앱 선택 파일에 다른 앱 Services를 실행하는 소비 경로가 모두 발견되지 않았다. 텍스트 입력 컨트롤에 시스템이 제공할 수 있는 일반 텍스트 기능까지 없다고 주장하지 않는다. macOS 일반 Services 문서를 'Finder 전용 기능'으로 표현해서도 안 된다. 사용자 결과: 파일 선택 기반 자동화/서비스 작업을 앱 안에서 발견하고 실행할 수 있는 일관된 경로가 없다. P2 판단.

### 공유: 열기와 다른 별도 흐름이 미구현

FilePaneController.swift:756-793의 전체 context menu에는 공유 항목이 없다. NSSharingService/NSSharingServicePicker/share 등을 검색하고 대체 descriptive find를 했으나 제품 구현은 찾지 못했다. [Tahoe Share menu](https://support.apple.com/guide/mac-help/use-the-share-menu-on-mac-mh40614/26/mac/26): `using AirDrop or apps such as Mail or Messages`, `select one or more items ... click the Share button`.

'다른 앱으로 열기'는 편집/보기 앱 실행이며 AirDrop/메일/메시지 공유 picker와 같지 않다. 반증: 파일 drag/drop과 copy-path, default/open-with가 이미 있어 보내기 작업의 우회 수단은 있다. Quick Look은 이미 구현되어 있고 그 시스템 패널에 추가 sharing 표면이 나타나는지는 GUI에서 별도 확인이 필요하다. 따라서 '앱에서 어떤 방법으로도 공유할 수 없다'보다 '목록 선택→네이티브 공유로 이어지는 명시적 action이 없다'가 안전한 주장이다. P1 또는 P2: 기존 목록 문맥을 유지한 채 다음 작업을 끝내는 작은 개선이라는 판단, 실제 공유 사용 빈도는 미측정.

### 태그: CRUD/표시/검색 표면 미구현, 보존 실패는 주장 불가

FileOps.swift:16-42의 FileEntry 필드는 url/name/isDirectory/size/modified/kind/isHidden뿐이며 192-219의 listing resource keys에 tagNames가 없다. InfoModel.swift:4-16,35-54와 InfoPanel.swift:21-34에는 날짜/종류/크기/경로/권한만 표시한다. AppDelegate와 context menu도 태그 action이 없다. [Tahoe tags](https://support.apple.com/guide/mac-help/tag-files-and-folders-mchlp15236/26/mac/26): `You can add multiple tags`, sidebar tag selection, tag search/group/sort를 안내한다. 사용자 결과: 태그를 작업 분류/검색 단서로 쓰는 사람은 이 앱 목록에서 그 분류를 확인하고 유지하기 어렵다. P2 또는 태그 중심 사용자에게 P1.

반증/제한: NativeFileCopy.perform은 FileTransferProgress.swift:177에서 `COPYFILE_ALL | COPYFILE_RECURSIVE | COPYFILE_NOFOLLOW | COPYFILE_EXCL`을 사용한다. 태그 UI가 없다고 태그/확장속성이 반드시 삭제된다고 말하면 안 된다. 특정 파일시스템/클라우드 공급자에서 실제 태그 보존은 이번 조사 범위의 실행 관측이 없다. 메타데이터 보존 테스트 리드는 TransferTrust 축과 공동 확인 필요.

### 파일 공급자/iCloud: 일반 경로 접근과 공급자 의미 이해는 다르다

FileOps.swift:192-219는 FileManager contentsOfDirectory와 일반 파일 resource values로 목록을 만든다. FileEntry에 다운로드/업로드/충돌/동기화 상태가 없고 InfoModel에도 없다. BrowserWindowController.swift:849-875는 iCloud/provider domain 진입점을 따로 열거하지 않는다. Sources에서 FileProvider/ubiquitous/startDownloading/evict/NSFileCoordinator/cloud 등 변형을 검색하고 descriptive find를 추가했지만 전용 구현을 찾지 못했다.

[Tahoe iCloud workflow](https://support.apple.com/guide/mac-help/work-with-folders-and-files-in-icloud-drive-mchl1a02d711/26/mac/26)는 sidebar iCloud Drive, status indicators, `Download Now`, `Remove Download`, `Keep Downloaded`를 제공한다. [ubiquitousItemDownloadingStatusKey](https://developer.apple.com/documentation/foundation/urlresourcekey/ubiquitousitemdownloadingstatuskey.md)는 `whether a local copy exists and whether that copy is the most current version`라고 설명한다. 그 정보를 지금 목록 모델은 소비하지 않는다.

따라서 정확한 분류는 '로컬 파일시스템 경로로 드러나는 클라우드 폴더를 탐색할 가능성은 있지만 공급자 상태/오프라인 가용성/다운로드 정책 제어 표면은 미구현'이다. 시스템이 일반 file read를 통해 materialize할 수 있으므로 '클라우드 파일이 안 열린다', '복사 중 데이터가 사라진다', 'FileProvider framework를 import하지 않아서 클라우드가 불가능'은 모두 근거 없는 확대다. iCloud용 ubiquitous API가 타사 provider의 전체 상태를 동일하게 제공한다고 추정하지도 않는다. cloud-first 사용자에게 결핍 영향은 크고, 로컬 작업 중심 사용자에게는 우선순위가 낮다.

## 역사와 반론

.git/logs/HEAD:7의 7670195fabb37e9a6daa44f8cf28da1d980204d1 제목은 `Improve file operation safety and desktop integration`. 이것은 외부 연결이 이전부터 의도적으로 개선된 축임을 보여줄 뿐 해당 커밋에서 어느 API가 추가됐는지 입증하지 않는다. commit diff는 실행기 부재로 읽지 않았다. 최신 코드에 있는 것을 과거 기능 목록의 부재로 평가하면 안 된다.

태그/공유/Services/cloud 제어가 없는 것은 제품 결핍 후보이지 자동으로 최우선이라는 뜻이 아니다. 사용자가 로컬 폴더 두 곳에서 정리하고 파일을 에디터로 여는 작업만 한다면 현재 NSWorkspace·클립보드·drag 연결은 이미 상당 부분 충분하다. 반대로 앱에서 선택한 파일을 AirDrop하고 USB를 꺼내는 순간 다른 표면으로 넘어가야 한다면 단순 목록 기능 추가보다 연결 마찰의 영향이 커진다. Finder 호출 전부를 가로채는 것은 이 차이를 해결하는 단일 수단이 아니다.

## CLAIMS

- DH-C1 / 높음 / 구현됨: 외부 open/reveal 수신, cold-launch queue, focused-pane navigation 및 deferred selection은 현재 소스에 있다. 근거 AppDelegate.swift:10-55, OpenRequest.swift:11-35, BrowserWindowController.swift:204-220, FilePaneController.swift:199-220. 그룹 DH-SRC; DH-TEST는 비독립 보강. 실행 성공 주장 아님.
- DH-C2 / 높음 / 제한됨: 외부 다중 reveal은 첫 유효 항목만 처리한다. OpenRequest.swift:25-35 quote `return request`; OpenRequestTests.swift:59-66 및 docs/behavior.md:147-149와 일치. 사용자 영향은 batch reveal 일부만 보임. DH-SRC, 비독립 DH-TEST/DH-DOC, 독립 DH-APPLE-API의 복수 파일 계약 비교.
- DH-C3 / 높음 / 범위 경계: public.folder Alternate 및 수동 기본 뷰어 설정은 Finder 전체 대체를 뜻하지 않는다. Support/Info.plist:20-32 quote `Alternate`; README.ko.md:173-227; 공식 plist/activateFileViewerSelecting 문서. DH-BUNDLE은 메타데이터 일치만 보강. 설정 효과는 실행 미확인.
- DH-C4 / 높음 / 구현됨: 기본 앱/다른 앱/Terminal/파일 URL copy·drag 연결을 없는 것으로 분류하면 안 된다. FilePaneController.swift:14-28,693-793,578-653, FileClipboard.swift:51-72,110-128. DH-SRC. 외부 앱 실제 실행/전송은 미확인.
- DH-C5 / 높음 / 정적 결함 후보: mount/unmount notification 구독 센터가 공식 계약과 다르다. BrowserWindowController.swift:78-89 quote `NotificationCenter.default.addObserver`; didMountNotification/didUnmountNotification 공식 quote `If you use a different notification center ... you won’t receive`. DH-SRC vs 독립 DH-APPLE-API. P1 검증/수정 후보; 현재 실행 실패 주장 금지.
- DH-C6 / 높음 / 미구현: 명시적 꺼내기, 공유 picker, 파일 선택 Services, 태그 조작/표시 및 클라우드 상태·다운로드 정책 surface는 현재 메뉴/모델/plist에서 발견되지 않는다. AppDelegate.swift:77-111, FilePaneController.swift:756-793, BrowserWindowController.swift:846-876, FileOps.swift:16-42,192-219, InfoPanel.swift:21-34. 검색 여러 변형+descriptive alternate 수행. DH-SRC, 독립 DH-APPLE-26 비교. 모든 우회/시스템 기능까지 불가능하다는 주장 아님.
- DH-C7 / 높음 / 제한됨: outbound open 실패에 대한 app feedback가 코드상 없다. FilePaneController.swift:14-25의 Bool 무시/완료 핸들러 부재/Terminal guard return. DH-SRC vs 독립 DH-APPLE-API. P1 후보. 실재 launch 실패는 미관측.
- DH-C8 / 중간 / 제품 판단: 현재 목표는 전체 Finder 제거보다 기존 선택 문맥에서 열기·보내기·꺼내기 및 실패 설명을 끝내도록 하는 편이 구현 비용 대비 일상 마찰을 줄일 가능성이 높다. C3-C7에 기반한 추론이며 사용 빈도/인과 실측이 아니다.

## 개선 순서 제안

1. P1: 기존 연결의 신뢰부터 확인한다. volume notification 센터 불일치를 부모의 재현 대상으로 올리고, NSWorkspace 실행 실패 이유를 surface에 연결한다. 현재 앱의 failure 관측을 꾸며내지 않는다.
2. P1/P2: 목록에서 '공유'와 디스크 '꺼내기'를 넣어 선택 이후 작업을 끝낸다. 복잡한 전체 default-manager 등록 UI보다 작은 독립 작업이다. 사용자 workflow에 해당 동작이 없으면 뒤로 미룬다.
3. P2: file-selection Services 소비 또는 외부 '여기서 보기' Services 제공 중 필요한 방향을 먼저 추가한다. 두 기능은 같은 구현이 아니다.
4. 조건부 P1/P2: 클라우드가 일상 저장소라면 provider 위치·다운로드 상태·오프라인 가용성을 우선 설계한다. cloud가 아닐 때는 태그/공급자 전체 기능을 한꺼번에 복제하지 않는다. 당장 완전 지원 대신 Finder에 명시적으로 넘기는 탈출 경로도 후보지만 현재 context menu에는 그 action이 없다.
5. 후순위: '모든 Finder 호출 대체'와 시스템 데스크탑/Dock/Open-Save UI 교체를 목표로 삼지 않는다. 첫 유효 외부 항목 정책 개선과 default-viewer 설치/진단 편의는 별도 작업으로 분리한다.

## EXPAND

- LEAD DH-L1: mount/unmount 실제 재현. 이미 소스+공식 계약 불일치를 확보했으나 실행 증명은 없다. 부모가 NSWorkspace notification center와 현재 default center를 비교하는 읽기 중심/격리 시나리오 또는 다음 구현의 회귀 검증 대상으로 판단해야 한다. 새 디스크를 위험하게 연결/분리할 필요 없이 정확한 notification dispatch 계약을 검증할 수 있다. 이 자식은 state-changing probe 미실행.
- LEAD DH-L2: GUI Quick Look 패널의 공유 기능. 현재 명시적 목록 Share action은 없지만 시스템 QLPreviewPanel에 공유가 노출될 수 있다. 실제 QA에서 패널 표면을 확인하여 '공유 불가능' 확대 주장을 차단한다. 코드-only 조사로 닫을 수 없다.
- LEAD DH-L3: 실제 외부 앱별 reveal/odoc 전달 경로. 현재 설정을 바꾸지 않은 채 cold/warm routing은 코드와 기존 테스트로 확인했지만 Finder direct AppleScript, NSWorkspace reveal, folder open 각각의 현재 설정 효과는 미확인. 기본 파일 뷰어 절차의 효과를 '모든 앱'으로 일반화하지 말고 리드가 권한/격리 범위에서 판단한다.
- LEAD DH-L4: 태그/xattr 보존. COPYFILE_ALL은 '태그 UI 없음→태그 소실' 주장을 반박하는 코드 단서다. TransferTrust 소유자가 기존 metadata tests/실제 fs 조건을 확인해 보존에 대한 별도 주장을 닫을 수 있다. 클라우드 공급자별 의미와 같다고 간주하지 않는다.
- LEAD DH-L5: provider placeholder 및 외부 file promises. URL file drop은 존재하지만 NSFilePromiseReceiver/ubiquitous/provider 전용 구현은 검색되지 않았다. 사용자가 클라우드-only 파일/메일 attachment drag를 중요하게 여기는 경우에만 확장한다. 현재 런타임 실패나 데이터 손실은 미관측.
- LEAD DH-L6: 외부 요청이 작업 문맥/rename/busy 중 들어오는 시나리오. handleOpen은 busy guard 없이 focused pane을 navigate하고 pending reveal은 edit 상태에 따라 적용이 지연된다. 코드만으로 경합 오류를 단정하지 않았다. WorkspaceContinuity/TransferTrust 축에서 이미 탐색과 operation source snapshot을 고정하는 반증을 확인해야 한다.
- DEAD END DH-D1: 공식 NSFileViewer 전체 대체 보장 찾기. NSFileViewer 영어 검색은 공식 API 본문으로 이어졌지만 키의 전면 리다이렉션 보장을 확보하지 못했다. 따라서 README를 설정 의도, Apple API를 경계 계약으로만 사용한다.
- DEAD END DH-D2: 파일 공급자 기능의 소스 발견. literal variations와 descriptive find 모두 전용 구현을 찾지 못했고 목록 모델/menus/plist를 직접 읽어 surface 부재를 닫았다. '일반 파일 접근도 불가'라는 더 넓은 주장은 닫지 않고 제외한다.
- DEAD END DH-D3: owned-topic commit diff. shell/git 도구와 LSP가 mounted inventory에 없어 diff 조회 불가; 실제 reflog로 제목/HEAD만 확인했다. 과거 커밋의 구현 내용은 미독이며 현재 소스 증거를 대신하지 않는다.