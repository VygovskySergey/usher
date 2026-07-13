import AppKit

let appURL = URL(fileURLWithPath: ("~/Applications/Usher.app" as NSString).expandingTildeInPath)

guard FileManager.default.fileExists(atPath: appURL.path) else {
    print("Usher.app not found at \(appURL.path) — run ./build.sh first")
    exit(1)
}

// Set schemes sequentially — concurrent calls conflict. https requires a GUI
// confirmation dialog, so this works when run from a normal session.
func setScheme(_ schemes: ArraySlice<String>) {
    guard let scheme = schemes.first else {
        print("\nUsher is now your default browser.")
        exit(0)
    }
    NSWorkspace.shared.setDefaultApplication(at: appURL, toOpenURLsWithScheme: scheme) { error in
        if let error {
            print("Failed to set default for \(scheme): \(error.localizedDescription)")
            print("Set it manually: System Settings > Desktop & Dock > Default web browser > Usher")
            exit(1)
        }
        print("Set Usher as default handler for \(scheme)")
        setScheme(schemes.dropFirst())
    }
}

setScheme(["http", "https"][...])
RunLoop.main.run()
