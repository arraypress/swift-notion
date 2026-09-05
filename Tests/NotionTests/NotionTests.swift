//
//  NotionTests.swift
//  NotionTests
//
//  Created by David Sherlock on 2026.
//
//  The property model is the whole difficulty of this API, and all of it is
//  testable without an account: every shape below is Notion's documented
//  response shape for that property type.
//

import Foundation
import XCTest
@testable import Notion

final class NotionTests: XCTestCase {

    private func value(_ json: String) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
    }

    private func properties(_ json: String) throws -> [String: JSONValue] {
        try JSONDecoder().decode([String: JSONValue].self, from: Data(json.utf8))
    }

    // MARK: - Identifiers

    /// The id a caller has to hand is almost always a URL.
    func testAnIdIsReadFromEveryFormPeopleActuallyPaste() {
        let dashed = "2f8e1c0d-1234-5678-9abc-def012345678"
        XCTAssertEqual(Identifier.parse(dashed), dashed)
        XCTAssertEqual(Identifier.parse("2f8e1c0d123456789abcdef012345678"), dashed,
                       "undashed, as copied out of a URL")
        XCTAssertEqual(Identifier.parse("https://notion.so/My-Page-2f8e1c0d123456789abcdef012345678"),
                       dashed, "a share link with a title slug")
        XCTAssertEqual(Identifier.parse("https://www.notion.so/team/2f8e1c0d123456789abcdef012345678?v=x"),
                       dashed, "and one with a query")
        XCTAssertNil(Identifier.parse("not-an-id"))
        XCTAssertNil(Identifier.parse(""))
        XCTAssertNil(Identifier.parse("2f8e1c0d"), "too short to be a UUID")
    }

    // MARK: - Rich text

    /// Notion splits a sentence into runs at every formatting change, so the
    /// first entry is not the text — the concatenation is.
    func testRichTextRunsAreJoinedNotTruncated() throws {
        let text = Properties.richText(try value("""
        [ {"plain_text": "Hello "}, {"plain_text": "bold"}, {"plain_text": " world"} ]
        """))
        XCTAssertEqual(text, "Hello bold world")
        XCTAssertEqual(Properties.richText(try value("[]")), "")
        XCTAssertEqual(Properties.richText(nil), "")
    }

    // MARK: - The title

    /// The title column can be named anything, so it is found by TYPE.
    func testTheTitleIsFoundByTypeNotByKey() throws {
        let named = try properties("""
        { "Task name": { "type": "title", "title": [{"plain_text": "Ship the thing"}] },
          "Notes": { "type": "rich_text", "rich_text": [{"plain_text": "later"}] } }
        """)
        XCTAssertEqual(Properties.title(named), "Ship the thing",
                       "the column is called 'Task name', not 'title'")

        let odd = try properties("""
        { "Aa": { "type": "title", "title": [{"plain_text": "Untitled-ish"}] } }
        """)
        XCTAssertEqual(Properties.title(odd), "Untitled-ish")

        let none = try properties("""
        { "Notes": { "type": "rich_text", "rich_text": [{"plain_text": "x"}] } }
        """)
        XCTAssertNil(Properties.title(none))
    }

    // MARK: - Every property type

    func testEachPropertyTypeFlattensToSomethingPrintable() throws {
        let raw = try properties("""
        {
          "Name":     { "type": "title", "title": [{"plain_text": "Alpha"}] },
          "Notes":    { "type": "rich_text", "rich_text": [{"plain_text": "some text"}] },
          "Score":    { "type": "number", "number": 42 },
          "Rate":     { "type": "number", "number": 2.5 },
          "Done":     { "type": "checkbox", "checkbox": true },
          "Stage":    { "type": "select", "select": {"name": "In progress"} },
          "State":    { "type": "status", "status": {"name": "Blocked"} },
          "Tags":     { "type": "multi_select", "multi_select": [{"name": "a"}, {"name": "b"}] },
          "Due":      { "type": "date", "date": {"start": "2026-09-05"} },
          "Window":   { "type": "date", "date": {"start": "2026-09-01", "end": "2026-09-30"} },
          "Owner":    { "type": "people", "people": [{"name": "Ada"}, {"name": "Grace"}] },
          "Site":     { "type": "url", "url": "https://example.com" },
          "Mail":     { "type": "email", "email": "a@example.com" },
          "Linked":   { "type": "relation", "relation": [{"id": "1"}, {"id": "2"}] },
          "Ticket":   { "type": "unique_id", "unique_id": {"prefix": "ENG", "number": 17} },
          "Files":    { "type": "files", "files": [{"name": "spec.pdf"}] }
        }
        """)
        let flat = Properties.flatten(raw)

        XCTAssertEqual(flat["Name"]?.text, "Alpha")
        XCTAssertEqual(flat["Notes"]?.text, "some text")
        XCTAssertEqual(flat["Score"]?.text, "42", "a whole number prints without a decimal point")
        XCTAssertEqual(flat["Score"]?.number, 42)
        XCTAssertEqual(flat["Rate"]?.text, "2.5")
        XCTAssertEqual(flat["Done"]?.checkbox, true)
        XCTAssertEqual(flat["Done"]?.text, "yes")
        XCTAssertEqual(flat["Stage"]?.text, "In progress")
        XCTAssertEqual(flat["State"]?.text, "Blocked")
        XCTAssertEqual(flat["Tags"]?.text, "a, b")
        XCTAssertEqual(flat["Tags"]?.values, ["a", "b"])
        XCTAssertEqual(flat["Due"]?.text, "2026-09-05")
        XCTAssertEqual(flat["Window"]?.text, "2026-09-01 → 2026-09-30", "a range shows both ends")
        XCTAssertEqual(flat["Owner"]?.text, "Ada, Grace")
        XCTAssertEqual(flat["Site"]?.text, "https://example.com")
        XCTAssertEqual(flat["Mail"]?.text, "a@example.com")
        XCTAssertEqual(flat["Linked"]?.text, "2 linked")
        XCTAssertEqual(flat["Ticket"]?.text, "ENG-17")
        XCTAssertEqual(flat["Files"]?.text, "spec.pdf")
    }

    /// A formula or rollup wraps another typed value one level deeper.
    func testAFormulaIsUnwrappedButKeepsItsOwnType() throws {
        let raw = try properties("""
        { "Total": { "type": "formula", "formula": { "type": "number", "number": 99 } },
          "Flag":  { "type": "formula", "formula": { "type": "boolean", "boolean": true } },
          "Roll":  { "type": "rollup", "rollup": { "type": "number", "number": 7 } } }
        """)
        let flat = Properties.flatten(raw)

        XCTAssertEqual(flat["Total"]?.number, 99)
        XCTAssertEqual(flat["Total"]?.text, "99")
        XCTAssertEqual(flat["Total"]?.type, "formula",
                       "the outer type survives, so a caller can tell a formula from a number")
        XCTAssertEqual(flat["Roll"]?.number, 7)
        XCTAssertEqual(flat["Roll"]?.type, "rollup")
    }

    func testAnEmptyPropertyIsEmptyNotMissing() throws {
        let raw = try properties("""
        { "Notes": { "type": "rich_text", "rich_text": [] },
          "Due":   { "type": "date", "date": null } }
        """)
        let flat = Properties.flatten(raw)
        XCTAssertEqual(flat["Notes"]?.text, "")
        XCTAssertTrue(flat["Notes"]?.isEmpty ?? false)
        XCTAssertEqual(flat["Due"]?.text, "")
    }

    func testAnUnknownPropertyTypeDoesNotLoseTheRow() throws {
        let raw = try properties("""
        { "Future": { "type": "something_new", "something_new": "hello" } }
        """)
        let flat = Properties.flatten(raw)
        XCTAssertEqual(flat["Future"]?.type, "something_new",
                       "a type this library predates must still appear")
    }

    // MARK: - Page

    func testAPageReadsItsTitleParentAndIcon() throws {
        let page = try JSONDecoder().decode(Page.self, from: Data("""
        { "object": "page", "id": "2f8e1c0d-1234-5678-9abc-def012345678",
          "created_time": "2026-09-05T10:00:00.000Z",
          "last_edited_time": "2026-09-05T11:30:00.000Z",
          "archived": false,
          "icon": { "type": "emoji", "emoji": "📌" },
          "parent": { "type": "database_id", "database_id": "aaaa1111-2222-3333-4444-555566667777" },
          "url": "https://notion.so/Ship-it-2f8e",
          "properties": { "Task": { "type": "title", "title": [{"plain_text": "Ship it"}] },
                          "Done": { "type": "checkbox", "checkbox": false } } }
        """.utf8))

        XCTAssertEqual(page.title, "Ship it")
        XCTAssertEqual(page.icon, "📌")
        XCTAssertEqual(page.parentType, "database_id")
        XCTAssertTrue(page.isDatabaseRow)
        XCTAssertEqual(page.properties["Done"]?.checkbox, false)
        XCTAssertFalse(page.archived)
        XCTAssertNotNil(page.createdTime, "a fractional-second timestamp must parse")
    }

    /// `archived` was renamed `in_trash`; responses carry either.
    func testBothSpellingsOfArchivedAreUnderstood() throws {
        func page(_ body: String) throws -> Page {
            try JSONDecoder().decode(Page.self, from: Data(body.utf8))
        }
        XCTAssertTrue(try page(#"{"id":"a","archived":true}"#).archived)
        XCTAssertTrue(try page(#"{"id":"a","in_trash":true}"#).archived)
        XCTAssertFalse(try page(#"{"id":"a"}"#).archived)
    }

    // MARK: - Database

    /// A database's title is a top-level rich-text array, not a property.
    func testADatabaseTitleAndSchemaAreReadFromTheirOwnShape() throws {
        let database = try JSONDecoder().decode(Database.self, from: Data("""
        { "object": "database", "id": "aaaa1111-2222-3333-4444-555566667777",
          "title": [{"plain_text": "Tasks"}],
          "description": [{"plain_text": "Everything to do"}],
          "properties": { "Task": {"type": "title"}, "Done": {"type": "checkbox"},
                          "Due": {"type": "date"} } }
        """.utf8))

        XCTAssertEqual(database.title, "Tasks")
        XCTAssertEqual(database.description, "Everything to do")
        XCTAssertEqual(database.schema["Done"], "checkbox")
        XCTAssertEqual(database.titleColumn, "Task", "found by type, whatever it is called")
    }

    // MARK: - Blocks

    func testBlocksRenderAsMarkdown() throws {
        func block(_ body: String) throws -> Block {
            try JSONDecoder().decode(Block.self, from: Data(body.utf8))
        }
        let heading = try block("""
        {"id":"1","type":"heading_1","heading_1":{"rich_text":[{"plain_text":"Title"}]}}
        """)
        XCTAssertEqual(heading.markdown, "# Title")

        let todo = try block("""
        {"id":"2","type":"to_do","to_do":{"rich_text":[{"plain_text":"buy milk"}],"checked":true}}
        """)
        XCTAssertEqual(todo.markdown, "- [x] buy milk")
        XCTAssertEqual(todo.checked, true)

        let code = try block("""
        {"id":"3","type":"code","code":{"rich_text":[{"plain_text":"print(1)"}],"language":"swift"}}
        """)
        XCTAssertEqual(code.markdown, "```swift\nprint(1)\n```")

        let bullet = try block("""
        {"id":"4","type":"bulleted_list_item","bulleted_list_item":{"rich_text":[{"plain_text":"one"}]},
         "has_children":true}
        """)
        XCTAssertEqual(bullet.markdown, "- one")
        XCTAssertTrue(bullet.hasChildren, "nesting is reported, not silently fetched")
    }

    // MARK: - Requests

    private final class Recorder: @unchecked Sendable {
        var requests: [URLRequest] = []
        let body: String
        let status: Int
        init(_ body: String, status: Int = 200) { self.body = body; self.status = status }
        var transport: Notion.Transport {
            { [self] request in
                requests.append(request)
                let response = HTTPURLResponse(url: request.url!, statusCode: status,
                                               httpVersion: nil, headerFields: [:])!
                return (Data(body.utf8), response)
            }
        }

        var lastMethod: String? { requests.last?.httpMethod }
        var lastPath: String? { requests.last?.url?.path }
        /// What actually went over the wire, so a request's SHAPE can be
        /// asserted rather than only its effect.
        var lastBodyJSON: [String: Any]? {
            guard let data = requests.last?.httpBody else { return nil }
            return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        }
    }

    func testEveryRequestCarriesTheVersionHeaderNotionDemands() async throws {
        let recorder = Recorder(#"{"id":"x","name":"Test"}"#)
        _ = try await Notion(token: "ntn_secret", transport: recorder.transport).me()

        let request = try XCTUnwrap(recorder.requests.first)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Notion-Version"), "2022-06-28",
                       "Notion refuses a request without it")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer ntn_secret")
        XCTAssertFalse(request.url!.absoluteString.contains("ntn_secret"),
                       "a token in a URL leaks into logs")
    }

    /// A valid token that has been shared nothing looks like an empty
    /// workspace. Saying so is the difference between a fix and a bug report.
    /// Only an UNFILTERED search can make that claim.
    func testAnEmptyUnfilteredSearchIsReportedAsNotShared() async {
        let recorder = Recorder(#"{"object":"list","results":[]}"#)
        do {
            _ = try await Notion(token: "t", transport: recorder.transport).search()
            XCTFail("an empty result should be explained")
        } catch let error as NotionError {
            guard case .notShared = error else {
                return XCTFail("expected .notShared, got \(error)")
            }
        } catch { XCTFail("unexpected \(error)") }
    }

    /// Verified live: Notion answers a query that matches nothing with HTTP 200
    /// and `results: []`. That is an answer. Calling it "nothing is shared"
    /// sends the caller off to re-share pages that were never the problem.
    func testAQueryThatMatchesNothingReturnsEmptyRatherThanThrowing() async throws {
        let recorder = Recorder(#"{"object":"list","results":[]}"#)
        let results = try await Notion(token: "t", transport: recorder.transport)
            .search("zzqqxxnonexistentterm")
        XCTAssertTrue(results.isEmpty)
        XCTAssertEqual(results.count, 0)
    }

    /// The same holds when only a kind was named.
    func testAKindFilterThatMatchesNothingAlsoReturnsEmpty() async throws {
        let recorder = Recorder(#"{"object":"list","results":[]}"#)
        let results = try await Notion(token: "t", transport: recorder.transport)
            .search("", kind: .database)
        XCTAssertTrue(results.isEmpty)
    }

    // MARK: - Markdown

    /// The real shape, captured live from `GET /v1/pages/{id}/markdown`.
    /// Notion's own renderer keeps the inline formatting a block walk drops:
    /// bold, italics, strikethrough, code, links and colour all survive.
    func testMarkdownComesFromNotionsRendererWithFormattingIntact() async throws {
        let body = #"""
        {"object":"page_markdown","id":"2f8e1c0d-1234-5678-9abc-def012345678",
         "markdown":"\ud83d\udc4b Welcome to Notion!\n<empty-block/>\nHere are the basics:\n- [ ] Highlight any text, and use the menu that pops up to **style** *your* ~~writing~~ `however` [you](https://www.notion.so/product) <span color=\"yellow_bg\">like</span>\n<details>\n<summary>This is a toggle block.</summary>\n\t- more\n</details>",
         "truncated":false,"unknown_block_ids":[]}
        """#
        let recorder = Recorder(body)
        let page = try await Notion(token: "t", transport: recorder.transport)
            .pageMarkdown("2f8e1c0d123456789abcdef012345678")

        XCTAssertTrue(page.isComplete)
        XCTAssertFalse(page.truncated)
        for kept in ["**style**", "*your*", "~~writing~~", "`however`",
                     "[you](https://www.notion.so/product)", "<details>",
                     #"<span color="yellow_bg">"#] {
            XCTAssertTrue(page.markdown.contains(kept), "the renderer's \(kept) was lost")
        }
    }

    /// `truncated` and `unknown_block_ids` are how the endpoint admits the
    /// Markdown is incomplete. Ignoring them loses content silently.
    func testAnIncompleteRenderIsNotReportedAsComplete() async throws {
        // NB: ##"…"## — a `"#` inside would close a single-hash raw string.
        let body = ##"{"object":"page_markdown","id":"x","markdown":"# Part one","truncated":true,"unknown_block_ids":["b1","b2"]}"##
        let recorder = Recorder(body)
        let page = try await Notion(token: "t", transport: recorder.transport)
            .pageMarkdown("2f8e1c0d123456789abcdef012345678")

        XCTAssertFalse(page.isComplete)
        XCTAssertTrue(page.truncated)
        XCTAssertEqual(page.unknownBlockIDs, ["b1", "b2"])
    }

    /// An empty page renders to an empty string, not to a failure.
    func testAnEmptyPageRendersToEmptyMarkdown() async throws {
        let body = #"{"object":"page_markdown","id":"x","markdown":"","truncated":false,"unknown_block_ids":[]}"#
        let recorder = Recorder(body)
        let text = try await Notion(token: "t", transport: recorder.transport)
            .markdown("2f8e1c0d123456789abcdef012345678")
        XCTAssertEqual(text, "")
    }

    // MARK: - Writing Markdown

    /// The write must go out as `replace_content`, and must NOT permit
    /// deleting a subpage unless the caller said so. Getting that default
    /// wrong loses a child page with no warning.
    func testWriteSendsReplaceContentAndRefusesToDeleteByDefault() async throws {
        // ##"…"## — a `"#` inside would close a single-hash raw string.
        let recorder = Recorder(##"{"object":"page_markdown","id":"p1","markdown":"# Hi","truncated":false,"unknown_block_ids":[]}"##)
        _ = try await Notion(token: "t", transport: recorder.transport)
            .write("2f8e1c0d123456789abcdef012345678", markdown: "# Hi")

        let sent = try XCTUnwrap(recorder.lastBodyJSON)
        XCTAssertEqual(recorder.lastMethod, "PATCH")
        XCTAssertTrue(recorder.lastPath?.hasSuffix("/markdown") ?? false)
        XCTAssertEqual(sent["type"] as? String, "replace_content")
        let replace = try XCTUnwrap(sent["replace_content"] as? [String: Any])
        XCTAssertEqual(replace["new_str"] as? String, "# Hi")
        XCTAssertEqual(replace["allow_deleting_content"] as? Bool, false,
                       "a subpage must not vanish by default")
    }

    func testWriteCanBeToldToAllowDeleting() async throws {
        let recorder = Recorder(#"{"object":"page_markdown","id":"p1","markdown":"x","truncated":false,"unknown_block_ids":[]}"#)
        _ = try await Notion(token: "t", transport: recorder.transport)
            .write("2f8e1c0d123456789abcdef012345678", markdown: "x",
                   allowDeletingContent: true)

        let replace = try XCTUnwrap(
            (recorder.lastBodyJSON?["replace_content"]) as? [String: Any])
        XCTAssertEqual(replace["allow_deleting_content"] as? Bool, true)
    }

    /// Markdown must reach Notion byte for byte — escaping or re-wrapping it
    /// would turn fenced code into prose.
    func testMarkdownIsSentVerbatim() async throws {
        let body = "# T\n\n- a\n- b\n\n```swift\nlet x = 1\n```\n\n> quote"
        let recorder = Recorder(#"{"object":"page_markdown","id":"p1","markdown":"x","truncated":false,"unknown_block_ids":[]}"#)
        _ = try await Notion(token: "t", transport: recorder.transport)
            .write("2f8e1c0d123456789abcdef012345678", markdown: body)

        let replace = try XCTUnwrap(
            (recorder.lastBodyJSON?["replace_content"]) as? [String: Any])
        XCTAssertEqual(replace["new_str"] as? String, body)
    }

    /// Notion answers 404 for "gone" and for "not shared with you" alike.
    func testA404SaysBothThingsItCouldMean() async {
        let recorder = Recorder(#"{"message":"Could not find page"}"#, status: 404)
        do {
            _ = try await Notion(token: "t", transport: recorder.transport)
                .page("2f8e1c0d123456789abcdef012345678")
            XCTFail("404 must not pass")
        } catch let error as NotionError {
            guard case .notShared = error else { return XCTFail("got \(error)") }
            XCTAssertTrue(error.errorDescription?.contains("share") ?? false,
                          "the message must name the likely cause")
        } catch { XCTFail("unexpected \(error)") }
    }

    func testSearchSplitsPagesFromDatabases() async throws {
        let recorder = Recorder("""
        { "results": [
            { "object": "page", "id": "p1",
              "properties": { "N": {"type":"title","title":[{"plain_text":"A page"}]} } },
            { "object": "database", "id": "d1", "title": [{"plain_text": "A database"}] } ] }
        """)
        let results = try await Notion(token: "t", transport: recorder.transport).search()

        XCTAssertEqual(results.pages.count, 1)
        XCTAssertEqual(results.databases.count, 1)
        XCTAssertEqual(results.pages.first?.title, "A page")
        XCTAssertEqual(results.databases.first?.title, "A database")
        XCTAssertEqual(results.count, 2)
    }

    func testABadIdentifierIsRefusedBeforeARequest() async {
        let recorder = Recorder("{}")
        do {
            _ = try await Notion(token: "t", transport: recorder.transport).page("nonsense")
            XCTFail("that is not an id")
        } catch let error as NotionError {
            guard case .badIdentifier = error else { return XCTFail("got \(error)") }
        } catch { XCTFail("unexpected \(error)") }
        XCTAssertTrue(recorder.requests.isEmpty)
    }

    func testRateLimitingCarriesItsRetryAfter() async {
        let recorder = Recorder("", status: 429)
        do {
            _ = try await Notion(token: "t", transport: recorder.transport).me()
            XCTFail("429 must not pass")
        } catch let error as NotionError {
            XCTAssertEqual(error, .rateLimited(retryAfter: nil))
        } catch { XCTFail("unexpected \(error)") }
    }

    // MARK: - Encoding

    func testAPageEncodesFlatNotInNotionsShape() throws {
        let page = try JSONDecoder().decode(Page.self, from: Data("""
        { "id": "p1", "properties": { "Task": {"type":"title","title":[{"plain_text":"Ship"}]},
                                      "Score": {"type":"number","number":5} } }
        """.utf8))
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: try JSONEncoder().encode(page)) as? [String: Any]
        )
        XCTAssertEqual(object["title"] as? String, "Ship", "a string, not a rich-text array")
        let properties = try XCTUnwrap(object["properties"] as? [String: Any])
        let score = try XCTUnwrap(properties["Score"] as? [String: Any])
        XCTAssertEqual(score["text"] as? String, "5")
        XCTAssertEqual(score["number"] as? Double, 5)
    }
}
