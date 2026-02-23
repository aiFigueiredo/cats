import XCTest

final class gatoUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testBreedsListDisplaysOnLaunch() throws {
        let app = launchApp()

        XCTAssertTrue(app.navigationBars["Breeds"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.collectionViews["breeds_list"].waitForExistence(timeout: 5) || app.tables["breeds_list"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Abyssinian"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSearchFiltersBreeds() throws {
        let app = launchApp()

        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("birm")

        XCTAssertTrue(app.staticTexts["Birman"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Abyssinian"].exists)
    }

    @MainActor
    func testFavoriteFlowUpdatesFavoritesAverage() throws {
        let app = launchApp()

        let favoriteButton = app.buttons["favorite_abys"]
        XCTAssertTrue(favoriteButton.waitForExistence(timeout: 5))
        favoriteButton.tap()

        app.tabBars.buttons["Favorites"].tap()

        XCTAssertTrue(app.tables["favorites_list"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Abyssinian"].exists)
        XCTAssertTrue(app.otherElements["favorites_average_lifespan"].exists)
    }

    @MainActor
    func testOfflineCachedBrowsing() throws {
        let app = launchApp([
            "UI_TEST_PRELOAD_CACHE": "1",
            "UI_TEST_OFFLINE": "1"
        ])

        XCTAssertTrue(app.staticTexts["Abyssinian"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "identifier == 'breeds_error_banner' OR label CONTAINS[c] 'No internet connection'")).firstMatch.exists)
    }

    @MainActor
    private func launchApp(_ extraEnvironment: [String: String] = [:]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["UI_TEST_MODE"] = "1"
        extraEnvironment.forEach { key, value in
            app.launchEnvironment[key] = value
        }
        app.launch()
        return app
    }
}
