import XCTest

final class gatoUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testBreedsListDisplaysOnLaunch() throws {
        let app = launchApp()

        XCTAssertTrue(app.navigationBars["Breeds"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.scrollViews["breeds_list"].waitForExistence(timeout: 5)
            || app.collectionViews["breeds_list"].waitForExistence(timeout: 5)
            || app.tables["breeds_list"].waitForExistence(timeout: 5)
        )
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

        XCTAssertTrue(
            app.scrollViews["favorites_list"].waitForExistence(timeout: 5)
            || app.collectionViews["favorites_list"].waitForExistence(timeout: 5)
            || app.tables["favorites_list"].waitForExistence(timeout: 5)
        )
        XCTAssertTrue(app.staticTexts["Abyssinian"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["favorites_average_lifespan"].exists)
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
    func testBreedDetailFavoriteStateRefreshesAfterRemovingInFavoritesTab() throws {
        let app = launchApp([
            "UI_TEST_PRELOAD_CACHE": "1",
            "UI_TEST_PRELOAD_FAVORITE_ID": "abys"
        ])

        XCTAssertTrue(app.staticTexts["Abyssinian"].waitForExistence(timeout: 5))
        app.staticTexts["Abyssinian"].tap()

        let detailFavoriteButton = app.buttons["detail_favorite_button"]
        XCTAssertTrue(detailFavoriteButton.waitForExistence(timeout: 5))
        XCTAssertEqual(detailFavoriteButton.label, "Remove from Favorites")

        app.tabBars.buttons["Favorites"].tap()

        let removeButton = app.buttons.matching(identifier: "remove_favorite_abys").firstMatch
        XCTAssertTrue(removeButton.waitForExistence(timeout: 5))
        removeButton.tap()

        let removedFromFavoritesPredicate = NSPredicate(format: "exists == false")
        expectation(for: removedFromFavoritesPredicate, evaluatedWith: removeButton)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(app.staticTexts["No favorites yet"].waitForExistence(timeout: 5))

        app.tabBars.buttons["Breeds"].tap()
        XCTAssertTrue(detailFavoriteButton.waitForExistence(timeout: 5))

        let addToFavoritesPredicate = NSPredicate(format: "label == %@", "Add to Favorites")
        expectation(for: addToFavoritesPredicate, evaluatedWith: detailFavoriteButton)
        waitForExpectations(timeout: 5)
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
