import Cocoa

let keySenderPIDAttr = AEKeyword(0x73706964) // 'spid'

struct Config {
    var workProfile = "Default"
    var personalProfile = "Profile 1"
    var chromePath = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
    var workDomains: [String] = []
    var workApps: Set<String> = ["com.tinyspeck.slackmacgap"]
}

let configDir = ("~/.config/usher" as NSString).expandingTildeInPath

func readLines(_ name: String) -> [String] {
    let path = (configDir as NSString).appendingPathComponent(name)
    guard let text = try? String(contentsOfFile: path, encoding: .utf8) else { return [] }
    return text
        .split(whereSeparator: \.isNewline)
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty && !$0.hasPrefix("#") }
}

func loadConfig() -> Config {
    var cfg = Config()
    cfg.workDomains = readLines("work-domains.txt").map { $0.lowercased() }
    let apps = readLines("work-apps.txt").map { $0.lowercased() }
    if !apps.isEmpty { cfg.workApps = Set(apps) }
    for line in readLines("config") {
        let parts = line.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2 else { continue }
        switch parts[0].lowercased() {
        case "work_profile": cfg.workProfile = parts[1]
        case "personal_profile": cfg.personalProfile = parts[1]
        case "chrome_path": cfg.chromePath = (parts[1] as NSString).expandingTildeInPath
        default: break
        }
    }
    return cfg
}

func hostMatches(_ host: String, domains: [String]) -> Bool {
    var h = host.lowercased()
    if h.hasPrefix("www.") { h = String(h.dropFirst(4)) }
    for d in domains where h == d || h.hasSuffix("." + d) { return true }
    return false
}

let chromeCandidates = [
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    ("~/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" as NSString).expandingTildeInPath,
    "/Applications/Google Chrome Beta.app/Contents/MacOS/Google Chrome Beta",
    "/Applications/Google Chrome Canary.app/Contents/MacOS/Google Chrome Canary",
    "/Applications/Chromium.app/Contents/MacOS/Chromium",
    "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser",
]

func resolveChrome(_ configured: String) -> String? {
    for path in [configured] + chromeCandidates where !path.isEmpty && FileManager.default.fileExists(atPath: path) {
        return path
    }
    return nil
}

func userDataDir(forBrowser path: String) -> String? {
    let appSupport = FileManager.default.homeDirectoryForCurrentUser.path + "/Library/Application Support"
    switch true {
    case path.contains("Google Chrome Beta"): return appSupport + "/Google/Chrome Beta"
    case path.contains("Google Chrome Canary"): return appSupport + "/Google/Chrome Canary"
    case path.contains("Google Chrome"): return appSupport + "/Google/Chrome"
    case path.contains("Chromium"): return appSupport + "/Chromium"
    case path.contains("Brave Browser"): return appSupport + "/BraveSoftware/Brave-Browser"
    default: return nil
    }
}

// Exact, case-sensitive match against real on-disk profile directories, so a
// wrong-case or misspelled profile name can never trick the browser into
// silently creating a new profile.
func profileExists(_ profile: String, inUserDataDir dir: String) -> Bool {
    guard let entries = try? FileManager.default.contentsOfDirectory(atPath: dir) else { return false }
    return entries.contains(profile)
}

func openInBrowser(profile: String?, url: String, browserPath: String) {
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: browserPath)
    var args: [String] = []
    if let profile { args.append("--profile-directory=\(profile)") }
    args.append(url)
    proc.arguments = args
    do {
        try proc.run()
    } catch {
        log("ERROR launching \(browserPath): \(error.localizedDescription); opening in Safari")
        openInSafari(url)
    }
}

func openInSafari(_ url: String) {
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    proc.arguments = ["-a", "Safari", url]
    try? proc.run()
}

func log(_ message: String) {
    let stateDir = ("~/.local/state/usher" as NSString).expandingTildeInPath
    try? FileManager.default.createDirectory(atPath: stateDir, withIntermediateDirectories: true)
    let path = (stateDir as NSString).appendingPathComponent("log")
    let line = "\(Date()) \(message)\n"
    if let data = line.data(using: .utf8) {
        if let handle = FileHandle(forWritingAtPath: path) {
            handle.seekToEndOfFile()
            handle.write(data)
            handle.closeFile()
        } else {
            try? data.write(to: URL(fileURLWithPath: path))
        }
    }
}

final class Router: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    @objc func handleURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent: NSAppleEventDescriptor) {
        guard let url = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue else { return }

        var sourceBundle: String?
        if let pid = event.attributeDescriptor(forKeyword: keySenderPIDAttr)?.int32Value,
           let app = NSRunningApplication(processIdentifier: pid) {
            sourceBundle = app.bundleIdentifier
        }

        let cfg = loadConfig()
        let host = URLComponents(string: url)?.host ?? ""
        let fromWorkApp = sourceBundle.map { cfg.workApps.contains($0.lowercased()) } ?? false
        let workByDomain = hostMatches(host, domains: cfg.workDomains)
        let toWork = fromWorkApp || workByDomain

        let profile = toWork ? cfg.workProfile : cfg.personalProfile
        let reason = fromWorkApp ? "source=\(sourceBundle ?? "?")" : (workByDomain ? "domain" : "fallback")
        log("[\(profile)] \(reason) src=\(sourceBundle ?? "?") host=\(host) url=\(url)")
        guard let chrome = resolveChrome(cfg.chromePath) else {
            log("ERROR: Chrome not found (configured: \(cfg.chromePath)); opening in Safari. Set chrome_path in ~/.config/usher/config")
            openInSafari(url)
            return
        }
        var effectiveProfile: String? = profile
        if let dir = userDataDir(forBrowser: chrome), !profileExists(profile, inUserDataDir: dir) {
            log("ERROR: profile \"\(profile)\" not found in \(dir); refusing to create it. Opening in the browser's current profile — fix ~/.config/usher/config (run ./list-profiles.sh)")
            effectiveProfile = nil
        }
        openInBrowser(profile: effectiveProfile, url: url, browserPath: chrome)
    }
}

let app = NSApplication.shared
let delegate = Router()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
