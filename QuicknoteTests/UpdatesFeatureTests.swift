import Testing

@testable import Quicknote

struct UpdatesFeatureTests {
    private let realKey = "Q2xpY2tUb0JlU3VyZVRoaXNJc0Jhc2U2NEVuY29kZWRLZXk9"

    @Test func updatesAreOffForThePlaceholderKey() {
        #expect(!UpdatesFeature.updatesAreEnabled(publicKey: "REPLACE_WITH_SPARKLE_PUBLIC_KEY"))
    }

    @Test func updatesAreOffForAMissingOrBlankKey() {
        #expect(!UpdatesFeature.updatesAreEnabled(publicKey: nil))
        #expect(!UpdatesFeature.updatesAreEnabled(publicKey: ""))
        #expect(!UpdatesFeature.updatesAreEnabled(publicKey: "  \n"))
    }

    @Test func updatesAreOffForTextThatIsNotBase64() {
        #expect(!UpdatesFeature.updatesAreEnabled(publicKey: "not a key!"))
    }

    @Test func updatesAreOnForARealLookingKey() {
        #expect(UpdatesFeature.updatesAreEnabled(publicKey: realKey))
    }
}
