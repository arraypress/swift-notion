# swift-notion

Notion on an integration token, not OAuth — with the property model flattened.

```swift
import Notion

let notion = Notion(token: myToken)

try await notion.search("meeting notes")
try await notion.page(url)          // properties, already readable
try await notion.markdown(url)      // the content
try await notion.rows(databaseURL, sortBy: "Due")
```

## Why a token and not OAuth

Both kinds of Notion token are just API keys, made in about two minutes, with
no OAuth flow, no review and no server. OAuth is only needed when each user
connects their own workspace without pasting anything — a consumer app's
problem, not a library's.

## Two kinds of token, and the gotcha only one of them has

| | Where | What it can see |
|---|---|---|
| **Personal access token** (`ntn_…`) | Settings → Connections → your token | The whole workspace, immediately |
| **Internal integration secret** | Settings → Connections → Develop | **Nothing, until a human shares each page with it** |

The second is the one that catches everyone: a perfectly valid secret sees
nothing until someone opens each page → ⋯ → Connections → the integration. An
empty search is the normal symptom, and Notion returns `404` for "not shared"
and "does not exist" alike — indistinguishable.

So an **unfiltered** search that comes back empty throws `.notShared` and says
what to do, rather than looking like an empty workspace. A search with a query
that simply matches nothing returns empty results, because that is an answer
and not a fault — reporting it as "nothing is shared" would send you off to
re-share pages that were never the problem.

## The property model is the difficulty

Every Notion property is a tagged union nested two or three levels deep, and
the nesting differs per type. A page's title is not `properties.Name` — it is
`properties.Name.title[0].plain_text`, where `Name` is whatever the user called
that column. A date is `properties.Due.date.start`. A multi-select is an array
of objects each with a `name`.

Twenty-odd types, a different walk each. This does it once:

```swift
page.title                      // "Ship it" — found by TYPE, not by key
page.properties["Due"]?.text    // "2026-09-05"
page.properties["Tags"]?.values // ["urgent", "backend"]
page.properties["Score"]?.number
page.properties["Done"]?.checkbox
```

Every type is covered, including the ones that wrap another typed value —
a `formula` or `rollup` is unwrapped but keeps its own type, so you can still
tell a computed number from a typed one. A type this library predates still
appears rather than vanishing.

**The title is found by type, not by key**, because the title column can be
called anything — `Name`, `Task`, `Aa`. Same for a database's `titleColumn`.

## Ids, as people actually paste them

```swift
try await notion.page("https://notion.so/My-Page-2f8e1c0d1234...")  // a share link
try await notion.page("2f8e1c0d123456789abcdef012345678")           // undashed
try await notion.page("2f8e1c0d-1234-5678-9abc-def012345678")        // dashed
```

All three work. The URL is what people have to hand.

## Content

```swift
try await notion.markdown(url)      // Notion's own renderer
try await notion.pageMarkdown(url)  // …plus whether anything was lost
try await notion.blocks(url)        // or the blocks themselves
```

`markdown` is `GET /v1/pages/{id}/markdown` — Notion renders the page itself,
so **bold, italics, strikethrough, code, links and colour survive**, toggles
come back as `<details>`, and nested content comes with it. Measured on a real
page: the server's render was 1441 characters against 854 for a local block
walk, and the walk preserved none of the seven formatting markers.

`pageMarkdown` adds the two ways Notion admits the result is incomplete —
`truncated` for a page too large to render, and `unknownBlockIDs` for blocks it
has no Markdown for. `isComplete` is both at once. Ignoring them loses content
silently, which is the failure worth preventing.

`blocks` is still one level deep: a nested list's children are **reported** by
`block.hasChildren`, not fetched. `blockMarkdown` assembles Markdown from them
locally, for callers that already hold blocks or must not spend a second
request — it flattens formatting, and that is the trade.

## Writing

```swift
try await notion.createPage(parent: url, title: "Notes", paragraphs: ["…"])
try await notion.append(to: url, paragraphs: ["…"])
```

Paragraphs and headings only. Notion's block model is far larger, and a partial
Markdown converter that silently drops your tables would be worse than one that
states its scope.

## Scope, honestly

`Notion-Version: 2022-06-28` is pinned, not "latest" — an unannounced shape
change is not something to discover in production.

That pin is now four years old and there is a migration waiting. At
`2026-03-11` a **database becomes a `data_source`, with a different id**:
a search filter of `"database"` is rejected outright (`body.filter.value should
be "page" or "data_source"`), and the same database comes back under a
different identifier. `GET /v1/databases/{id}` still answers at both versions,
so nothing is broken today — but moving the pin means migrating the model, not
editing a string. Verified against a live workspace, both versions, 2026-09-05.

Verified live against a real workspace on 2026-09-05: `me`, `search`, `page`,
`blocks`, `markdown`, `pageMarkdown`, `database` and `rows` all decode from
real data, including a title column named something other than "Title". Pinned
by 23 offline tests, with the fixtures taken from those real responses.

## Installation

```swift
.package(url: "https://github.com/arraypress/swift-notion.git", from: "0.1.0")
```

## Licence

MIT
