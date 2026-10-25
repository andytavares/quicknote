import Foundation
import OSLog
import QuicknoteKit
import UserNotifications

/// Schedules local notifications for the alerts `ReminderPlanner` plans, and tells the edge when one is due.
final class ReminderScheduler: NSObject {
    static let shared = ReminderScheduler()
    private static let requestPrefix = "app.quicknote.reminder."
    private static let categoryId = "app.quicknote.reminder"
    private static let maximumPending = 60

    /// Called with the notes whose alert is due now, or whose notification the user opened.
    var onFire: (([Int64]) -> Void)?
    private var repository: NoteRepository?
    private var alerts: [PlannedAlert] = []
    private var timer: Task<Void, Never>?
    private var scheduling: Task<Void, Never>?
    private let logger = Logger(subsystem: "app.quicknote.Quicknote", category: "Reminders")

    func start(repository: NoteRepository) {
        self.repository = repository
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        let done = UNNotificationAction(identifier: ReminderAction.done.rawValue, title: "Done")
        let snooze = UNNotificationAction(identifier: ReminderAction.snoozeOneHour.rawValue, title: "Snooze 1 hour")
        center.setNotificationCategories([
            UNNotificationCategory(identifier: Self.categoryId, actions: [done, snooze], intentIdentifiers: [])
        ])
    }

    /// Replaces every pending Quicknote notification with the plan for `notes`.
    func update(notes: [Note]) {
        alerts = ReminderPlanner.plannedAlerts(for: notes, now: Date())
        armTimer()
        scheduling?.cancel()
        let planned = alerts
        scheduling = Task { await schedule(planned) }
    }

    private func schedule(_ planned: [PlannedAlert]) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests().map(\.identifier)
        center.removePendingNotificationRequests(withIdentifiers: pending.filter { $0.hasPrefix(Self.requestPrefix) })
        guard !planned.isEmpty, await Permissions.ensure(.notifications), !Task.isCancelled else { return }
        for alert in planned.prefix(Self.maximumPending) {
            do { try await center.add(request(for: alert)) } catch { logger.error("Scheduling failed: \(error)") }
        }
    }

    private func request(for alert: PlannedAlert) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = alert.title
        content.body = alert.body
        content.sound = .default
        content.categoryIdentifier = Self.categoryId
        content.userInfo = ["noteId": alert.noteId]
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, alert.fireAt.timeIntervalSinceNow), repeats: false)
        return UNNotificationRequest(
            identifier: Self.requestPrefix + "\(alert.noteId)", content: content, trigger: trigger)
    }

    private func armTimer() {
        timer?.cancel()
        guard let next = alerts.first else { return }
        timer = Task {
            try? await Task.sleep(for: .seconds(max(0, next.fireAt.timeIntervalSinceNow)))
            guard !Task.isCancelled else { return }
            fireDueAlerts()
        }
    }

    private func fireDueAlerts() {
        let due = alerts.filter { $0.fireAt <= Date() }
        alerts.removeAll { alert in due.contains(alert) }
        armTimer()
        onFire?(due.map(\.noteId))
    }

    fileprivate func handle(actionIdentifier: String, noteId: Int64) {
        guard let action = ReminderAction(rawValue: actionIdentifier) else {
            if actionIdentifier == UNNotificationDefaultActionIdentifier { onFire?([noteId]) }
            return
        }
        guard let repository, var note = try? repository.note(id: noteId) else { return }
        note = action.apply(to: note, now: Date(), calendar: .current)
        do { try repository.save(&note, now: Date()) } catch {
            logger.error("Saving after \(action.rawValue) failed: \(error)")
        }
    }
}

extension ReminderScheduler: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse
    ) async {
        let identifier = response.actionIdentifier
        guard let noteId = response.notification.request.content.userInfo["noteId"] as? Int else { return }
        await MainActor.run { handle(actionIdentifier: identifier, noteId: Int64(noteId)) }
    }
}
