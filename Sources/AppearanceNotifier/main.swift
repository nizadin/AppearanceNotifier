import AppKit
import Foundation
import ShellOut

private let kAppleInterfaceThemeChangedNotification = "AppleInterfaceThemeChangedNotification"

enum Theme {
    case light
    case dark
}

class ThemeChangeObserver {
    func observe() {
        print("Observing")

        DistributedNotificationCenter.default.addObserver(
            forName: Notification.Name(kAppleInterfaceThemeChangedNotification),
            object: nil,
            queue: nil,
            using: interfaceModeChanged(notification:)
        )
    }

    func interfaceModeChanged(notification _: Notification) {
        let themeRaw = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") ?? "Light"

        let theme = notificationToTheme(themeRaw: themeRaw)!

        notify(theme: theme)

        respond(theme: theme)
    }
}

func notificationToTheme(themeRaw: String) -> Theme? {
    return {
        switch themeRaw {
        case "Light":
            return Theme.light
        case "Dark":
            return Theme.dark
        default:
            return nil
        }
    }()
}

func notify(theme: Theme) {
    print("\(Date()) Theme changed: \(theme)")
}

func respond(theme: Theme) {
    do {
        let output = try shellOut(to: "nvr", arguments: ["--serverlist"])
        let servers = output.split(whereSeparator: \.isNewline)

        if servers.isEmpty {
            print("\(Date()) neovim: no servers")
        } else {
            servers.forEach { server in
                let server = String(server)

                print("\(Date()) neovim server (\(String(server))): sending command")

                let arguments = buildNvimBackgroundArguments(server: server, theme: theme)

                DispatchQueue.global().async {
                    do {
                        try shellOut(to: "nvr", arguments: arguments)
                    } catch {
                        print("\(Date()) neovim server \(String(server)): command failed with arguments - \(arguments)")

                        let error = error as! ShellOutError
                        print(error.message) // Prints STDERR
                        print(error.output) // Prints STDOUT
                    }
                }
            }
        }
    } catch {
        let error = error as! ShellOutError
        print(error.message) // Prints STDERR
        print(error.output) // Prints STDOUT
    }
}

func buildNvimBackgroundArguments(server: String, theme: Theme) -> [String] {
    return ["--servername", server, "-c", "\"lua vim.o.background = '\(theme)'\""]
}

let app = NSApplication.shared

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_: Notification) {
        let observer = ThemeChangeObserver()
        observer.observe()
    }
}

let delegate = AppDelegate()
app.delegate = delegate
app.run()
