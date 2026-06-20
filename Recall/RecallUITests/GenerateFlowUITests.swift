import XCTest

/// End-to-end happy path driven by the MockGenerator (the generator the
/// simulator falls back to): type a topic → stream a deck → flip a card →
/// confirm it persists into the Decks list. Captures screenshots along the way.
final class GenerateFlowUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testGenerateStudyAndPersist() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-useMockGenerator"]   // deterministic content
        app.launch()

        // 1. Go to the Create tab.
        app.buttons["create"].firstMatch.tap()

        // 2. Type a topic.
        let field = app.textFields["topicField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Topic field should appear")
        field.tap()
        field.typeText("Photosynthesis")
        attach(app, name: "01-topic-entered")

        // 3. Create the deck.
        app.buttons["createDeckButton"].tap()

        // 4. Generation completes and we land on the deck detail (the flip
        //    cards carry a "Question." / "Answer." accessibility prefix, which
        //    the plain streaming card does not — so this only matches once
        //    we've navigated past generation).
        let questionPredicate = NSPredicate(format: "label CONTAINS[c] %@", "question. what is photosynthesis")
        let question = app.descendants(matching: .any).matching(questionPredicate).firstMatch
        XCTAssertTrue(question.waitForExistence(timeout: 25), "A generated flip card should appear on the deck detail")
        attach(app, name: "02-deck-detail")

        // 5. Flip the card → its answer becomes readable.
        question.tap()
        let answerPredicate = NSPredicate(format: "label CONTAINS[c] %@", "answer. the process by which plants")
        let answer = app.descendants(matching: .any).matching(answerPredicate).firstMatch
        XCTAssertTrue(answer.waitForExistence(timeout: 5), "Card should flip to reveal the answer")
        attach(app, name: "03-card-flipped")

        // 5b. Enter a study session, reveal a card, and grade it.
        let studyButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "study")).firstMatch
        XCTAssertTrue(studyButton.waitForExistence(timeout: 5), "Study CTA should be present")
        studyButton.tap()

        let revealHint = app.staticTexts["tap the card to reveal"]
        XCTAssertTrue(revealHint.waitForExistence(timeout: 5), "Study session should start on a card front")
        let studyCard = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH[c] %@", "question.")).firstMatch
        studyCard.tap()

        let goodButton = app.buttons["good"]
        XCTAssertTrue(goodButton.waitForExistence(timeout: 5), "Grade bar should appear after revealing")
        attach(app, name: "05-study-graded")
        goodButton.tap()

        // Close the study sheet.
        let close = app.buttons["Close study session"]
        if close.waitForExistence(timeout: 3) { close.tap() }

        // 6. Back out, confirm the deck persisted into the Decks list.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["decks"].firstMatch.tap()
        let deckPredicate = NSPredicate(format: "label CONTAINS[c] %@", "photosynthesis")
        let deckCell = app.descendants(matching: .any).matching(deckPredicate).firstMatch
        XCTAssertTrue(deckCell.waitForExistence(timeout: 5), "The new deck should appear in Decks")
        attach(app, name: "04-decks-list")
    }

    @MainActor
    private func attach(_ app: XCUIApplication, name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
