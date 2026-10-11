import AppKit
import IHateFinderCore

enum PaneLaunch {
    typealias Completion = (Result<Void, Error>) -> Void

    static func files(_ urls: [URL], completion: @escaping Completion) {
        guard !urls.isEmpty else { completion(.success(())); return }
        var remaining = urls.count
        var failures: [String] = []
        for url in urls {
            NSWorkspace.shared.open(url, configuration: NSWorkspace.OpenConfiguration()) { _, error in
                DispatchQueue.main.async {
                    if let error { failures.append("\(url.path): \(error.localizedDescription)") }
                    remaining -= 1
                    guard remaining == 0 else { return }
                    if failures.isEmpty { completion(.success(())) }
                    else { completion(.failure(FileOpError(failures.joined(separator: "\n")))) }
                }
            }
        }
    }

    static func application(_ urls: [URL], app: URL, completion: @escaping Completion) {
        NSWorkspace.shared.open(urls, withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration()) { _, error in
            DispatchQueue.main.async {
                if let error { completion(.failure(error)) }
                else { completion(.success(())) }
            }
        }
    }

    static func terminal(_ folder: URL, completion: @escaping Completion) {
        guard let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") else {
            completion(.failure(FileOpError("터미널 앱을 찾을 수 없습니다. /System/Applications/Utilities/Terminal.app을 확인해 주세요.")))
            return
        }
        application([folder], app: app, completion: completion)
    }
}
