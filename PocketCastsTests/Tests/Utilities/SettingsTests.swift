import XCTest
@testable import podcasts
@testable import PocketCastsServer
import PocketCastsDataModel
import PocketCastsUtils

final class SettingsTests: XCTestCase {

    private let userDefaultsSuiteName = "PocketCasts-SettingsTests"

    private lazy var defaultPlayerActions: [PlayerAction] = {
        var actions: [PlayerAction] = [
            .markPlayed,
            .effects,
            .sleepTimer,
            .routePicker,
            .shareEpisode,
            .addToPlaylist,
            .download,
            .goToPodcast,
            .starEpisode,
            .chromecast,
            .archive,
            .videoToggle
        ]
        return actions
    }()

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removePersistentDomain(forName: userDefaultsSuiteName)
    }

    func testPlayerActionsDiscardRetiredButtonsAndPreserveOtherCustomization() throws {
        let previousActions = UserDefaults.standard.object(forKey: "PlayerActions")
        defer { UserDefaults.standard.set(previousActions, forKey: "PlayerActions") }
        Settings.updatePlayerActions(PlayerAction.defaultActions.filter { $0.isAvailable }) // Set defaults
        Settings.updatePlayerActions([.addBookmark, .markPlayed, .transcript])

        XCTAssertEqual(defaultPlayerActions, Settings.playerActions(), "Player actions should include changes from update")
    }

    func testSavedBookmarkHeadphoneActionsFallBackToSkipControls() {
        let keys = ["headphones.previousAction", "headphones.nextAction"]
        let previousValues = keys.map { UserDefaults.standard.object(forKey: $0) }
        defer {
            for (key, value) in zip(keys, previousValues) {
                UserDefaults.standard.set(value, forKey: key)
            }
        }
        let retiredAction = Data(#"{"addBookmark":{}}"#.utf8)
        keys.forEach { UserDefaults.standard.set(retiredAction, forKey: $0) }

        XCTAssertEqual(Settings.headphonesPreviousAction, .skipBack)
        XCTAssertEqual(Settings.headphonesNextAction, .skipForward)
    }

    // MARK: - Encourage Account Creation cadence

    private let eacInterval: TimeInterval = Settings.encourageAccountCreationInterval
    private let eacNow = Date(timeIntervalSince1970: 1_700_000_000)

    func testEncourageAccountCreationIntervalIsSixtyDays() {
        // Pins the shipped cadence; the cadence tests below read the constant, so on their own
        // they'd silently follow a bad value.
        XCTAssertEqual(Settings.encourageAccountCreationInterval, 60 * 24 * 60 * 60)
    }

    func testEncourageAccountCreationWaitsWhenNotEligible() {
        // Even with an elapsed clock, an ineligible user is never shown the modal.
        XCTAssertFalse(Settings.shouldShowEncourageAccountCreationModal(
            now: eacNow,
            isEligible: false,
            referenceDate: eacNow.addingTimeInterval(-eacInterval * 2),
            interval: eacInterval
        ))
    }

    func testEncourageAccountCreationShowsOnFirstEligibleLaunch() {
        // First eligible launch (no reference date yet) shows immediately, then the clock starts.
        XCTAssertTrue(Settings.shouldShowEncourageAccountCreationModal(
            now: eacNow,
            isEligible: true,
            referenceDate: nil,
            interval: eacInterval
        ))
    }

    func testEncourageAccountCreationWaitsBeforeIntervalElapses() {
        // One second short of the interval should not show yet.
        XCTAssertFalse(Settings.shouldShowEncourageAccountCreationModal(
            now: eacNow,
            isEligible: true,
            referenceDate: eacNow.addingTimeInterval(-(eacInterval - 1)),
            interval: eacInterval
        ))
    }

    func testEncourageAccountCreationShowsWhenIntervalElapsed() {
        // Exactly at the interval boundary should show.
        XCTAssertTrue(Settings.shouldShowEncourageAccountCreationModal(
            now: eacNow,
            isEligible: true,
            referenceDate: eacNow.addingTimeInterval(-eacInterval),
            interval: eacInterval
        ))
    }

    func testEncourageAccountCreationShowsWhenIntervalWellExceeded() {
        XCTAssertTrue(Settings.shouldShowEncourageAccountCreationModal(
            now: eacNow,
            isEligible: true,
            referenceDate: eacNow.addingTimeInterval(-eacInterval * 3),
            interval: eacInterval
        ))
    }

    func testEncourageAccountCreationShowsWhenReferenceIsInTheFuture() {
        // A future reference date (a restore carrying a future anchor) shows rather than
        // suppressing the modal indefinitely.
        XCTAssertTrue(Settings.shouldShowEncourageAccountCreationModal(
            now: eacNow,
            isEligible: true,
            referenceDate: eacNow.addingTimeInterval(eacInterval),
            interval: eacInterval
        ))
    }
}
