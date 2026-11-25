import XCTest
@testable import Vexel

final class VexelCompositionDefaultsTests: XCTestCase {
    private func makeDefaults() -> UserDefaults {
        let suite = "VexelCompositionDefaultsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    func testDefaultsLoadWhenNothingHasBeenSaved() {
        let defaults = makeDefaults()
        XCTAssertEqual(VexelCompositionDefaults.load(from: defaults), .default)
    }

    func testSavedCompositionSettingsAreRestored() {
        let defaults = makeDefaults()
        let expected = VexelCompositionDefaults(width: 1440, height: 2560, fps: 60, duration: 24)
        expected.save(to: defaults)

        XCTAssertEqual(VexelCompositionDefaults.load(from: defaults), expected)
    }

    func testInvalidSettingsAreNotPersistedOrLoaded() {
        let defaults = makeDefaults()
        VexelCompositionDefaults(width: 10, height: 9000, fps: 29, duration: .infinity).save(to: defaults)

        XCTAssertEqual(VexelCompositionDefaults.load(from: defaults), .default)
    }

    func testCustomFrameRateSettingsCanBePersisted() {
        let defaults = makeDefaults()
        let expected = VexelCompositionDefaults(width: 1920, height: 1080, fps: 29, duration: 300)
        expected.save(to: defaults)

        XCTAssertEqual(VexelCompositionDefaults.load(from: defaults), expected)
    }

    func testLongCompositionDurationCanBePersisted() {
        let defaults = makeDefaults()
        let expected = VexelCompositionDefaults(width: 1080, height: 1920, fps: 30, duration: 1800)
        expected.save(to: defaults)

        XCTAssertEqual(VexelCompositionDefaults.load(from: defaults), expected)
    }

    func testResetRemovesSavedSettings() {
        let defaults = makeDefaults()
        VexelCompositionDefaults(width: 720, height: 1280, fps: 30, duration: 15).save(to: defaults)

        VexelCompositionDefaults.reset(in: defaults)

        XCTAssertEqual(VexelCompositionDefaults.load(from: defaults), .default)
    }
}
