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

An **internal integration secret** is just an API key: made in two minutes at
Settings → Connections → Develop, no OAuth flow, no review, no server. OAuth is
only needed when each user connects their own workspace without pasting
anything — a consumer app's problem, not a library's.

## The gotcha that catches everyone

**A perfectly valid token sees nothing until a human shares each page with the
integration** (⋯ → Connections → your integration). An empty search is the
normal symptom, and Notion returns `404` for "not shared" and "does not exist"
alike — indistinguishable.

So this library throws `.notShared` rather than handing back an empty list, and
says what to do. That one behaviour saves more time than everything else here.

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
try await notion.markdown(url)   // headings, lists, to-dos, quotes, code
try await notion.blocks(url)     // or the blocks themselves
```

One level deep. A nested list's children are **reported** by
`block.hasChildren`, not fetched — following them silently would turn one call
into dozens.

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

The response shapes here are Notion's documented ones and are pinned by 18
offline tests. **They have not yet been checked against a live workspace** —
the transport, headers, auth and error paths were (a real request returns
Notion's own `"API token is invalid."`), but the success shapes await a token.

## Installation

```swift
.package(url: "https://github.com/arraypress/swift-notion.git", from: "0.1.0")
```

## Licence

MIT
