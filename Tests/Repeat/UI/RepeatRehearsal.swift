import XCTest

@MainActor
final class RepeatRehearsal: XCTestCase {
    private var app: XCUIApplication!
    private var total: XCUIElement { app.textFields["Total meters (e.g. 6000)"].firstMatch }
    private var reps: XCUIElementQuery { app.textFields.matching(identifier: "reps") }
    private var meters: XCUIElementQuery { app.textFields.matching(identifier: "meters (e.g. 1k)") }
    private var rest: XCUIElementQuery { app.textFields.matching(identifier: "rest (e.g. 2:30r)") }
    private var split: XCUIElementQuery { app.textFields.matching(identifier: "avg split (e.g. 1:59.1)") }
    private var notes: XCUIElement {
        let field = app.textFields["workout-notes"]
        return field.exists ? field : app.textViews["workout-notes"]
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        let name = ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"]
        try XCTSkipUnless(["Meter-Disposable-Repeat-Rehearsal", "Meter-Disposable-Repeat-Delete-Copy"].contains(name))
        app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Workouts"].waitForExistence(timeout: 8), String(app.debugDescription.prefix(2400)))
        app.tabBars.buttons["Workouts"].tap()
    }

    private func phase(_ value: String) throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["METER_REPEAT_PHASE"] == value)
    }

    private func row(_ title: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
    }

    private func scrollTo(_ element: XCUIElement, towardTop: Bool = false) {
        for _ in 0..<8 {
            if element.exists && element.isHittable { return }
            let list = app.collectionViews.firstMatch
            if towardTop { list.swipeDown(velocity: .slow) } else { list.swipeUp(velocity: .slow) }
        }
        XCTAssertTrue(element.isHittable, String(app.debugDescription.prefix(3500)))
    }

    private func openSource(_ title: String) {
        let source = row(title)
        scrollTo(source)
        source.tap()
        let detail = app.navigationBars[title]
        // A tap during list deceleration can stop the scroll before it opens the row.
        if !detail.waitForExistence(timeout: 5) {
            guard app.navigationBars["Workouts"].exists else { return XCTFail(app.debugDescription) }
            scrollTo(source)
            source.tap()
            XCTAssertTrue(detail.waitForExistence(timeout: 5), app.debugDescription)
        }
        app.buttons["Repeat Workout"].tap()
        XCTAssertTrue(app.navigationBars["Repeat Workout"].waitForExistence(timeout: 5))
    }

    private func backToLog(_ title: String) {
        let detail = app.navigationBars[title]
        XCTAssertTrue(detail.waitForExistence(timeout: 4))
        detail.buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Workouts"].exists)
    }

    private func enter(_ text: String, in field: XCUIElement, replacing: Bool = false) {
        if replacing {
            let count = (field.value as? String ?? "").count
            field.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: count))
            blank(field)
        } else {
            field.tap()
        }
        field.typeText(text)
    }

    private func blank(_ field: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let value = field.value as? String ?? ""
        XCTAssertTrue(value.isEmpty || value == field.placeholderValue, value, file: file, line: line)
    }

    private func record(_ name: String, _ start: TimeInterval) {
        let seconds = ProcessInfo.processInfo.systemUptime - start
        let result = String(format: "%@ from Workouts through save and return: %.3f s", name, seconds)
        print(result)
        let item = XCTAttachment(string: result)
        item.name = name
        item.lifetime = .keepAlways
        add(item)
    }

    func testCancelSwipeAndBackground() {
        openSource("Four thousands")
        XCTAssertEqual(total.value as? String, "4000")
        XCTAssertEqual(reps.firstMatch.value as? String, "4")
        XCTAssertEqual(meters.firstMatch.value as? String, "1000")
        XCTAssertEqual(rest.firstMatch.value as? String, "2:30")
        blank(split.firstMatch)
        blank(notes)
        let previous = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Previous results'")).firstMatch
        XCTAssertTrue(previous.exists)
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        XCTAssertTrue(previous.label.lowercased().contains(fmt.string(from: yesterday).lowercased()), previous.label)
        enter("3", in: reps.firstMatch, replacing: true)
        XCTAssertEqual(total.value as? String, "3000")
        enter("3300", in: total, replacing: true)
        enter("2", in: reps.firstMatch, replacing: true)
        XCTAssertEqual(total.value as? String, "3300")
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertEqual(total.value as? String, "3300")
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Four thousands"].exists)
        app.buttons["Repeat Workout"].tap()
        XCTAssertEqual(total.value as? String, "4000")
        scrollTo(app.staticTexts["Average split 1:53.7 /500 m"])
        let bar = app.navigationBars["Repeat Workout"]
        let from = bar.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
        let to = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.94))
        from.press(forDuration: 0.08, thenDragTo: to)
        XCTAssertTrue(app.navigationBars["Four thousands"].waitForExistence(timeout: 4))
        backToLog("Four thousands")
        app.tabBars.buttons["Summary"].tap()
        app.segmentedControls.buttons["D"].tap()
        app.buttons["chevron.left"].firstMatch.tap()
        let old = row("Four thousands")
        XCTAssertTrue(old.waitForExistence(timeout: 4))
        old.tap()
        app.buttons["Repeat Workout"].tap()
        XCTAssertEqual(total.value as? String, "4000")
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Four thousands"].exists)
    }

    func testRepeatVersusManualFromFullTab() throws {
        try phase("timing")
        XCTAssertTrue(row("Four thousands").isHittable)
        let repeatStart = ProcessInfo.processInfo.systemUptime
        openSource("Four thousands")
        app.navigationBars.buttons["Save"].tap()
        backToLog("Four thousands")
        record("Repeat 4x1000", repeatStart)

        let manualStart = ProcessInfo.processInfo.systemUptime
        app.navigationBars["Workouts"].buttons.firstMatch.tap()
        app.buttons["Add Workout"].tap()
        enter("4", in: reps.firstMatch, replacing: true)
        enter("1k", in: meters.firstMatch, replacing: true)
        enter("2:30", in: rest.firstMatch)
        enter("4000", in: total)
        app.navigationBars.buttons["Save"].tap()
        XCTAssertTrue(app.navigationBars["Add Data"].exists)
        app.buttons["Done"].tap()
        XCTAssertTrue(app.navigationBars["Workouts"].exists)
        record("Manual 4x1000", manualStart)
        let saved = app.buttons.matching(NSPredicate(format: "label CONTAINS '4,000m'"))
        XCTAssertEqual(saved.count, 2)
    }

    func testOtherRepeatsAndManualSummaryAdd() throws {
        try phase("examples")
        openSource("Six thousand")
        XCTAssertEqual(total.value as? String, "6000")
        blank(rest.firstMatch)
        blank(split.firstMatch)
        enter("New steady note", in: notes)
        app.navigationBars.buttons["Save"].tap()
        backToLog("Six thousand")

        openSource("Ten short")
        XCTAssertEqual(rest.firstMatch.value as? String, "0:45")
        XCTAssertEqual(total.value as? String, "2500")
        enter("1:40.2", in: split.firstMatch)
        app.navigationBars.buttons["Save"].tap()
        backToLog("Ten short")

        openSource("Mixed set")
        XCTAssertEqual(total.value as? String, "3250")
        XCTAssertEqual(meters.element(boundBy: 0).value as? String, "1000")
        XCTAssertEqual(meters.element(boundBy: 1).value as? String, "750")
        XCTAssertEqual(meters.element(boundBy: 2).value as? String, "250")
        blank(rest.element(boundBy: 0))
        XCTAssertEqual(rest.element(boundBy: 1).value as? String, "0:00")
        app.navigationBars.buttons["Save"].tap()
        backToLog("Mixed set")

        openSource("Meters only")
        XCTAssertEqual(reps.count, 0)
        blank(total)
        XCTAssertFalse(app.navigationBars.buttons["Save"].isEnabled)
        enter("6347", in: total)
        app.navigationBars.buttons["Save"].tap()
        backToLog("Meters only")

        app.tabBars.buttons["Summary"].tap()
        app.segmentedControls.buttons["D"].tap()
        XCTAssertTrue(app.staticTexts["26,097m"].exists)
        app.navigationBars.buttons["Add Workout"].tap()
        XCTAssertTrue(app.buttons["Cancel"].exists)
        XCTAssertEqual(reps.firstMatch.value as? String, "1")
        XCTAssertEqual(meters.firstMatch.value as? String, "2000")
        blank(total)
        blank(rest.firstMatch)
        blank(split.firstMatch)
        enter("2601", in: total)
        app.navigationBars.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["28,698m"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Workouts"].tap()
        let newRow = app.buttons.matching(NSPredicate(format: "label CONTAINS '2,601m'")).firstMatch
        scrollTo(newRow, towardTop: true)
        newRow.tap()
        XCTAssertTrue(app.staticTexts["2,601m"].exists)
    }

    func testWorkoutsAndSummaryAfterRelaunch() throws {
        try phase("verify")
        let mixed = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Rowing' AND label CONTAINS '3,250m'")).firstMatch
        scrollTo(mixed)
        XCTAssertTrue(mixed.label.contains("3 pieces"))
        mixed.tap()
        XCTAssertTrue(app.staticTexts["3,250m"].exists)
        app.tabBars.buttons["Summary"].tap()
        app.segmentedControls.buttons["D"].tap()
        XCTAssertTrue(app.staticTexts["28,698m"].exists)
    }

    func testDeleteOnlyNewMixedWorkoutOnCopy() throws {
        try phase("delete")
        try XCTSkipUnless(ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] == "Meter-Disposable-Repeat-Delete-Copy")
        let newMixed = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Rowing' AND label CONTAINS '3,250m'")).firstMatch
        scrollTo(newMixed)
        XCTAssertTrue(newMixed.label.contains("3 pieces"))
        let from = newMixed.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
        let to = newMixed.coordinate(withNormalizedOffset: CGVector(dx: 0.52, dy: 0.5))
        from.press(forDuration: 0.08, thenDragTo: to)
        app.buttons["Delete"].firstMatch.tap()
        XCTAssertFalse(newMixed.exists)
        app.tabBars.buttons["Summary"].tap()
        app.segmentedControls.buttons["D"].tap()
        XCTAssertTrue(app.staticTexts["25,448m"].exists)
        XCUIDevice.shared.press(.home)
    }
}
