import Foundation
import Testing

@testable import Quicknote

struct PermissionStepTests {
    @Test func firstTimeExplainsThenRequests() {
        #expect(PermissionStep.next(status: .notDetermined, hasExplained: false) == .explainThenRequest)
    }

    @Test func alreadyExplainedGoesStraightToTheSystemPrompt() {
        #expect(PermissionStep.next(status: .notDetermined, hasExplained: true) == .request)
    }

    @Test func deniedExplainsAndOpensSystemSettingsEvenAfterAnEarlierExplainer() {
        #expect(PermissionStep.next(status: .denied, hasExplained: true) == .explainThenOpenSettings)
        #expect(PermissionStep.next(status: .denied, hasExplained: false) == .explainThenOpenSettings)
    }

    @Test func allowedNeverShowsTheExplainer() {
        #expect(PermissionStep.next(status: .allowed, hasExplained: false) == .proceed)
    }
}

struct PermissionSettingsURLTests {
    @Test func everyPermissionOpensItsPrivacyPane() {
        let urls = Permission.allCases.map { $0.systemSettingsURL.absoluteString }
        #expect(
            urls == [
                "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone",
                "x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition",
                "x-apple.systempreferences:com.apple.preference.security?Privacy_AudioCapture",
                "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture",
                "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
                "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars",
                "x-apple.systempreferences:com.apple.Notifications-Settings.extension",
            ])
    }
}

struct DataSummaryTests {
    @Test func deleteConfirmationNeedsTheExactWord() {
        #expect(DeleteConfirmation.isConfirmed("DELETE"))
        for typed in ["", "delete", "DELETE ", "DELET", " DELETE", "DELETEE"] {
            #expect(!DeleteConfirmation.isConfirmed(typed))
        }
    }

    @Test func summaryReadsLikeTheDesign() {
        let summary = DataSummary(noteCount: 412, meetingCount: 9, byteCount: 1_300_000_000)
        #expect(summary.text == "412 notes · 9 meetings · 1.3 GB")
    }

    @Test func summaryUsesSingularForOne() {
        #expect(DataSummary(noteCount: 1, meetingCount: 1, byteCount: 0).text == "1 note · 1 meeting · Zero KB")
    }

    @Test func folderSizeCountsFilesInsideSubfolders() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let inner = folder.appending(path: "Attachments")
        try FileManager.default.createDirectory(at: inner, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try Data(count: 10_000).write(to: inner.appending(path: "a.bin"))
        #expect(DataSummary.folderSize(folder) >= 10_000)
        #expect(DataSummary.folderSize(folder.appending(path: "missing")) == 0)
    }
}

struct WelcomeTests {
    @Test func shownOnceThenNeverAgain() throws {
        let defaults = try #require(UserDefaults(suiteName: UUID().uuidString))
        #expect(WelcomeFeature.shouldShow(defaults: defaults))
        defaults.set(true, forKey: WelcomeFeature.shownKey)
        #expect(!WelcomeFeature.shouldShow(defaults: defaults))
    }
}

struct MissingPermissionsTests {
    private func statuses(_ status: PermissionStatus) -> [Permission: PermissionStatus] {
        Dictionary(uniqueKeysWithValues: Permission.allCases.map { ($0, status) })
    }

    @Test func nothingIsMissingWhenEverythingIsAllowed() {
        #expect(PermissionCheck.missing(in: statuses(.allowed)).isEmpty)
    }

    @Test func refusedAndNeverAskedPermissionsAreMissingInSettingsOrder() {
        var statuses = statuses(.allowed)
        statuses[.calendar] = .denied
        statuses[.microphone] = .notDetermined
        #expect(PermissionCheck.missing(in: statuses) == [.microphone, .calendar])
    }

    @Test func macAudioIsMissingOnlyAfterAMeetingGotNoAudio() {
        var statuses = statuses(.allowed)
        statuses[.systemAudio] = .notDetermined
        #expect(PermissionCheck.missing(in: statuses).isEmpty)
        statuses[.systemAudio] = .denied
        #expect(PermissionCheck.missing(in: statuses) == [.systemAudio])
    }

    @Test func summaryNamesEachMissingPermission() {
        #expect(PermissionCheck.summary(of: [.microphone]) == "Permission needed: Microphone")
        #expect(
            PermissionCheck.summary(of: [.microphone, .calendar])
                == "2 permissions needed: Microphone, Calendar")
    }
}
