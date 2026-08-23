import ServiceManagement

struct LaunchAtLoginService {
    private var service: SMAppService { .mainApp }

    var isRegistered: Bool {
        service.status == .enabled || service.status == .requiresApproval
    }

    var requiresApproval: Bool {
        service.status == .requiresApproval
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            guard service.status == .notRegistered || service.status == .notFound else { return }
            try service.register()
        } else {
            guard service.status == .enabled || service.status == .requiresApproval else { return }
            try service.unregister()
        }
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
