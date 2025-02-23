//
//  UserAttributeMatcherTests.swift
//  DuckDuckGo
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import XCTest
import Foundation
@testable import BrowserServicesKit

class UserAttributeMatcherTests: XCTestCase {

    var userAttributeMatcher: UserAttributeMatcher!
    var dateYesterday: Date!

    override func setUpWithError() throws {
        let now = Calendar.current.dateComponents(in: .current, from: Date())
        let yesterday = DateComponents(year: now.year, month: now.month, day: now.day! - 1)
        let dateYesterday = Calendar.current.date(from: yesterday)!

        let mockStatisticsStore = MockStatisticsStore()
        mockStatisticsStore.atb = "v105-2"
        mockStatisticsStore.appRetentionAtb = "v105-44"
        mockStatisticsStore.searchRetentionAtb = "v105-88"
        mockStatisticsStore.installDate = dateYesterday

        let manager = MockVariantManager(isSupportedReturns: true,
                                         currentVariant: MockVariant(name: "zo", weight: 44, isIncluded: { return true }, features: [.dummy]))
        let emailManagerStorage = MockEmailManagerStorage()

        // EmailEnabledMatchingAttribute isSignedIn = true
        emailManagerStorage.mockUsername = "username"
        emailManagerStorage.mockToken = "token"

        let emailManager = EmailManager(storage: emailManagerStorage)
        userAttributeMatcher = UserAttributeMatcher(statisticsStore: mockStatisticsStore,
                                                    variantManager: manager,
                                                    emailManager: emailManager,
                                                    bookmarksCount: 44,
                                                    favoritesCount: 88,
                                                    appTheme: "default",
                                                    isWidgetInstalled: true)
    }

    override func tearDownWithError() throws {
        try super.tearDownWithError()

        userAttributeMatcher = nil
    }

    // MARK: - AppTheme

    func testWhenAppThemeMatchesThenReturnMatch() throws {
        XCTAssertEqual(userAttributeMatcher.evaluate(matchingAttribute: AppThemeMatchingAttribute(value: "default", fallback: nil)),
                       .match)
    }

    func testWhenAppThemeDoesNotMatchThenReturnFail() throws {
        XCTAssertEqual(userAttributeMatcher.evaluate(matchingAttribute: AppThemeMatchingAttribute(value: "light", fallback: nil)),
                       .fail)
    }

    // MARK: - Bookmarks

    func testWhenBookmarksMatchesThenReturnMatch() throws {
        XCTAssertEqual(userAttributeMatcher.evaluate(matchingAttribute: BookmarksMatchingAttribute(value: 44, fallback: nil)),
                       .match)
    }

    func testWhenBookmarksDoesNotMatchThenReturnFail() throws {
        XCTAssertEqual(userAttributeMatcher.evaluate(matchingAttribute: BookmarksMatchingAttribute(value: 22, fallback: nil)),
                       .fail)
    }

    func testWhenBookmarksEqualOrLowerThanMaxThenReturnMatch() throws {
        XCTAssertEqual(userAttributeMatcher.evaluate(matchingAttribute: BookmarksMatchingAttribute(max: 44, fallback: nil)),
                       .match)
    }

    func testWhenBookmarksGreaterThanMaxThenReturnFail() throws {
        XCTAssertEqual(userAttributeMatcher.evaluate(matchingAttribute: BookmarksMatchingAttribute(max: 40, fallback: nil)),
                       .fail)
    }

    func testWhenBookmarksLowerThanMinThenReturnFail() throws {
        XCTAssertEqual(userAttributeMatcher.evaluate(matchingAttribute: BookmarksMatchingAttribute(min: 88, fallback: nil)),
                       .fail)
    }

    func testWhenBookmarksInRangeThenReturnMatch() throws {
        XCTAssertEqual(userAttributeMatcher.evaluate(matchingAttribute: BookmarksMatchingAttribute(min: 40, max: 48, fallback: nil)),
                       .match)
    }

    func testWhenBookmarksNotInRangeThenReturnFail() throws {
        XCTAssertEqual(userAttributeMatcher.evaluate(matchingAttribute: BookmarksMatchingAttribute(min: 47, max: 48, fallback: nil)),
                       .fail)
    }

    // MARK: - Favorites

    func testWhenFavoritesMatchesThenReturnMatch() throws {
        XCTAssertEqual(userAttributeMatcher.evaluate(matchingAttribute: FavoritesMatchingAttribute(value: 88, fallback: nil)),
                       .match)
    }

    func testWhenFavoritesDoesNotMatchThenReturnFail() throws {
        XCTAssertEqual(userAttributeMatcher.evaluate(matchingAttribute: FavoritesMatchingAttribute(value: 22, fallback: nil)),
                       .fail)
    }

    func testWhenFavoritesEqualOrLowerThanMaxThenReturnMatch() throws {
        XCTAssertEqual(userAttributeMatcher.evaluate(matchingAttribute: FavoritesMatchingAttribute(max: 88, fallback: nil)),
                       .match)
    }

    func testWhenFavoritesGreaterThanMaxThenReturnFail() throws {
        XCTAssertEqual(userAttributeMatcher.evaluate(matchingAttribute: FavoritesMatchingAttribute(max: 40, fallback: nil)),
                       .fail)
    }

    func testWhenFavoritesLowerThanMinThenReturnFail() throws {
        XCTAssertEqual(userAttributeMatcher.evaluate(matchingAttribute: FavoritesMatchingAttribute(min: 100, fallback: nil)),
                       .fail)
    }

    func testWhenFavoritesInRangeThenReturnMatch() throws {
        XCTAssertEqual(userAttributeMatcher.evaluate(matchingAttribute: FavoritesMatchingAttribute(min: 40, max: 98, fallback: nil)),
                       .match)
    }

    func testWhenFavoritesNotInRangeThenReturnFail() throws {
        XCTAssertEqual(userAttributeMatcher.evaluate(matchingAttribute: FavoritesMatchingAttribute(min: 89, max: 98, fallback: nil)),
                       .fail)
    }

    // MARK: - DaysSinceInstalled

    func testWhenDaysSinceInstalledEqualOrLowerThanMaxThenReturnMatch() throws {
        XCTAssertEqual(userAttributeMatcher.evaluate(matchingAttribute: DaysSinceInstalledMatchingAttribute(max: 1, fallback: nil)),
                       .match)
    }

    func testWhenDaysSinceInstalledGreaterThanMaxThenReturnFail() throws {
        XCTAssertEqual(userAttributeMatcher.evaluate(matchingAttribute: DaysSinceInstalledMatchingAttribute(max: 0, fallback: nil)),
                       .fail)
    }

    func testWhenDaysSinceInstalledEqualOrGreaterThanMinThenReturnMatch() throws {
        XCTAssertEqual(userAttributeMatcher.evaluate(matchingAttribute: DaysSinceInstalledMatchingAttribute(min: 1, fallback: nil)),
                       .match)
    }

    func testWhenDaysSinceInstalledLowerThanMinThenReturnFail() throws {
        XCTAssertEqual(userAttributeMatcher.evaluate(matchingAttribute: DaysSinceInstalledMatchingAttribute(min: 2, fallback: nil)),
                       .fail)
    }

    func testWhenDaysSinceInstalledInRangeThenReturnMatch() throws {
        XCTAssertEqual(userAttributeMatcher.evaluate(matchingAttribute: DaysSinceInstalledMatchingAttribute(min: 0, max: 1, fallback: nil)),
                       .match)
    }

    func testWhenDaysSinceInstalledNotInRangeThenReturnFail() throws {
        XCTAssertEqual(userAttributeMatcher.evaluate(matchingAttribute: DaysSinceInstalledMatchingAttribute(min: 2, max: 44, fallback: nil)),
                       .fail)
    }

    // MARK: - EmailEnabled
    func testWhenEmailEnabledMatchesThenReturnMatch() throws {
        XCTAssertEqual(userAttributeMatcher.evaluate(matchingAttribute: EmailEnabledMatchingAttribute(value: true, fallback: nil)),
                       .match)
    }

    func testWhenEmailEnabledDoesNotMatchThenReturnFail() throws {
        XCTAssertEqual(userAttributeMatcher.evaluate(matchingAttribute: EmailEnabledMatchingAttribute(value: false, fallback: nil)),
                       .fail)
    }

    // MARK: - WidgetAdded
    func testWhenWidgetAddedMatchesThenReturnMatch() throws {
        XCTAssertEqual(userAttributeMatcher.evaluate(matchingAttribute: WidgetAddedMatchingAttribute(value: true, fallback: nil)),
                       .match)
    }

    func testWhenWidgetAddedDoesNotMatchThenReturnFail() throws {
        XCTAssertEqual(userAttributeMatcher.evaluate(matchingAttribute: WidgetAddedMatchingAttribute(value: false, fallback: nil)),
                       .fail)
    }

}
