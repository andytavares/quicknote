import AppKit
import SwiftUI

/// Settings › Permissions (S26): live status for each permission, with the fix.
struct PermissionsPane: View {
    @State private var statuses = Dictionary(
        uniqueKeysWithValues: Permission.allCases.map { ($0, Permissions.status(of: $0)) })

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ForEach(Permission.allCases, id: \.self) { permission in
                row(permission, status: statuses[permission] ?? .notDetermined)
            }
            Text(
                "Each permission is asked the first time a feature needs it. Features without their permission pause; everything else works."
            )
            .font(.caption).foregroundStyle(.secondary)
        }
        .task { await refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await refresh() }
        }
    }

    private func row(_ permission: Permission, status: PermissionStatus) -> some View {
        HStack {
            Circle().fill(color(status)).frame(width: 8, height: 8).accessibilityHidden(true)
            Text(permission.title)
            Spacer()
            trailing(permission, status: status)
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func trailing(_ permission: Permission, status: PermissionStatus) -> some View {
        if status == .allowed {
            Text("Allowed").font(.caption).foregroundStyle(.secondary)
        } else if permission == .systemAudio && status == .notDetermined {
            Text("Checked on first meeting").font(.caption).foregroundStyle(.secondary)
        } else {
            Button(status == .denied ? "Open Settings" : "Allow") {
                Task {
                    await Permissions.fix(permission)
                    await refresh()
                }
            }
            .accessibilityLabel(
                status == .denied ? "Open System Settings for \(permission.title)" : "Allow \(permission.title)")
        }
    }

    private func color(_ status: PermissionStatus) -> Color {
        switch status {
        case .allowed: .green
        case .denied: .red
        case .notDetermined: .gray
        }
    }

    private func refresh() async {
        await Permissions.refreshNotificationStatus()
        for permission in Permission.allCases { statuses[permission] = Permissions.status(of: permission) }
        await PermissionCheck.shared.refresh()
    }
}
