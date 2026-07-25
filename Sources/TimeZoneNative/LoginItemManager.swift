import Foundation
import ServiceManagement

@MainActor
enum LoginItemManager {
    private static let renamedAppRegistrationKey = "loginItemRegistration.tzc.v1"

    static func enable() {
        guard Bundle.main.bundleURL.pathExtension == "app" else { return }

        let service = SMAppService.mainApp

        if !UserDefaults.standard.bool(forKey: renamedAppRegistrationKey),
           service.status == .enabled {
            do {
                try service.unregister()
            } catch {
                NSLog("Unable to refresh the renamed login item: %@", error.localizedDescription)
            }
        }

        if service.status != .enabled,
           service.status != .requiresApproval {
            do {
                try service.register()
            } catch {
                NSLog("Unable to enable Start at Login: %@", error.localizedDescription)
            }
        }

        if service.status == .enabled {
            UserDefaults.standard.set(true, forKey: renamedAppRegistrationKey)
        }
    }

    static func disable() {
        let service = SMAppService.mainApp
        guard service.status == .enabled else { return }

        do {
            try service.unregister()
        } catch {
            NSLog("Unable to unregister Start at Login: %@", error.localizedDescription)
        }
    }
}
