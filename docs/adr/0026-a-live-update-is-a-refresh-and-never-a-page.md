# ADR 0026: A live update is a refresh and never a page

- **Status:** Accepted
- **Date:** 2026-10-05
- **Related:** [`../conventions.md`](../conventions.md),
  [`../architecture.md`](../architecture.md),
  [`../visual_design.md`](../visual_design.md),
  [`../features/i18n.md`](../features/i18n.md),
  [`../features/navigation.md`](../features/navigation.md),
  [0016](0016-internationalization-and-browser-locale.md),
  [0023](0023-pending-changes-are-read-from-the-draft-and-drawn-as-badges.md),
  [0025](0025-a-notification-is-a-stored-sentence.md)

The rules this ADR decides are **what** in
[`../conventions.md`](../conventions.md#real-time-updates); this is the reasoning behind them.

## Context

Everything the collaboration system delivered before this ends the same way: a reader's page is
correct for the moment they loaded it and then stops being correct, with no signal that anything
happened. An applied draft writes records that no open list contains, a reply lands in a thread
somebody is not looking at, and a notification arrives for a reader who is somewhere else entirely.
That is ordinary for a single-author application and it is the defect a multi-reader one cannot
afford: two people editing the same universe is the premise of every mode but `direct`.

The obvious implementation is also the one this application cannot make. Turbo Streams can broadcast
**rendered content** — a list of rows, an appended message, a new count — and that is what most of
its documentation shows. Rendering here happens inside `ApplicationController.render`, outside any
request. The consequences are not subtle and none of them raise:

- **There is no receiver's locale.** The browser that receives the broadcast did not choose the
  language the HTML was rendered in. A Spanish reader would be sent an English sentence, which is the
  boundary ADR 0016 draws for client-side strings, broken at the other end.
- **There is no receiver's authorization answer.** A broadcast reaches a subscriber by stream name,
  and no CanCan rule runs on the way. Broadcasting a list of records would disclose them to somebody
  whose membership was withdrawn after the page was rendered — a case this application already has to
  handle deliberately for notifications.
- **There is no session and no `Current`.** Anything the render would reach for is missing.

And the second half of the problem is not visible from the server at all. A refresh is a
whole-document re-request, and this application has unsent work in four different places: a
discussion composer, a reviewer's notes, a submission message, and an open modal editor holding a
photo crop or a JSON payload. Turbo's own handling of a refresh is to apply it, unconditionally.

## Decision

### Every broadcast is a `refresh` and nothing else

`LiveUpdates` publishes `Turbo::StreamsChannel.broadcast_refresh_to(stream, "data-live-update" =>
event)`. No broadcast carries content. The receiving browser re-requests the page through its own
session, in its own language, and the page answers for that reader — which is the only way to render
content that is correct for them.

The `data-live-update` attribute names the event for the client controller and for anyone reading a
broadcast in the log. It is not a payload.

### Three streams, because there are three audiences

A stream name is `[LiveUpdates::NAMESPACE, kind, id]` under the `collaboration` namespace, so a
collaboration stream can never collide with another kind:

- **`universe`** — "the records here changed", to everyone with that universe open. This is what an
  applied draft means: a Character that did not exist a second ago is now stored, and every list in
  the universe is stale until it is re-read.
- **`discussion`** — "this thread has another message", to the readers already looking at it. A
  thread is a conversation between the people who posted in it, not a universe-wide event.
- **`reader`** — "your bell has something new", to one person. This is the delivery for every
  notification the application writes.

The review workflow's three events are announced **through** the notification each of them already
writes, not by streams of their own: ADR 0025 already decided who is told, and a second copy of
those recipient rules here would be free to disagree with the rows.

### The stream name is the authorization

`turbo_stream_from` signs what it renders and `Turbo::StreamsChannel` refuses a subscription whose
signature does not verify, so a reader cannot name a stream their own pages never offered them. The
subscriptions are rendered only where the request has already authorized that reader — the universe
stream only inside `Current.universe`, and the reader stream only for a signed-in reader, because
`ApplicationCable::Connection` applies ADR 0018's session rules itself and refuses a websocket with
no session. **A guest therefore has no subscription at all**, which is correct rather than a missing
feature: there is nothing a guest could receive, and the element would open a connection rejected on
arrival.

### Every broadcast is published after the outermost commit

`Draft`, `DiscussionMessage`, and `Notification` each announce from an `after_*_commit` callback
rather than from inside the write path. A refresh published inside a transaction invites readers to
re-read a universe that has not been written yet; a rolled-back apply or a refused reply announces
something that does not exist. Waiting for the outermost commit is also what makes a reviewer's
approval correct — that write is wrapped in the decision's own transaction above the applier's, so an
announcement from the inner one would fire while the decision was still uncommitted.

### The reader's own browser is not told

`turbo_stream_refresh_tag` carries `request-id`, and Turbo drops a refresh whose request id the page
has just made itself. The person who pressed **Apply changes** or **Post message** is not reloaded
underneath the navigation they are already doing. That check is left to Turbo rather than
reimplemented: it is a question about the browser's own history of requests, and the client
controller has nothing to add to it.

### The client decides whether a refresh is applied at all

`live_update_controller.js` cancels Turbo's handling at `turbo:before-stream-render` and answers one
question: **does this page hold anything the reader typed that the server did not send?** A field is
unsent when its value differs from `defaultValue`; an open Bootstrap modal counts for the same
reason a dirty field does. When the answer is no, the refresh is applied. When it is yes, it is
**held** and the notice in `layouts/_live_updates` appears, so the reader decides when their work is
worth losing.

### The adapters are chosen for what each environment has to prove

`async` in development, `async` in test, `solid_cable` in production. The test adapter records
broadcasts and delivers them to nobody, which is right for asserting a broadcast and wrong for a
browser; the system suite runs the server in the test process, so `async` is what lets
`test/system/live_updates_test.rb` observe a real delivery. The cost is that
`ActionCable::TestHelper`'s `assert_broadcasts` is unavailable, so
`test/services/live_updates_test.rb` subscribes to the streams directly — which tests the thing this
application actually decided, the stream name.

## Consequences

### Benefits

- No broadcast can be wrong for the reader who receives it. Locale, access, and session are all
  answered by the reader's own request, because the server sends no content at all.
- Adding a collaboration surface that can go stale does not require adding a broadcast: a page in a
  draft-based universe is already subscribed to its universe's stream.
- The refresh is applied only when nothing would be lost, so a real-time feature cannot be the thing
  that discards a reviewer's notes.
- A reader's own write is not announced back to them by anything this application has to maintain —
  Turbo's own echo check does it.

### Costs and constraints

- **A refresh is coarse.** The whole document is re-requested, so scroll position inside a long list
  and an open tab's state are given up for a change that may have been one row. This is the price of
  the decision above and it is not going to be negotiated away by a partial-rendering story, which
  would reintroduce every problem the refresh was chosen to avoid.
- **A held update is dropped, not queued.** The notice tells the reader to reload; it does not
  remember the update and replay it. A reader who dismisses the notice has genuinely missed the
  update until they navigate.
- **`async` delivers within one process.** A broadcast made from `bin/rails console` reaches nothing,
  because a console is a second process. That is right for development and for the test environment,
  and it means neither can prove the production adapter's cross-process delivery.
- **The unsent-work question has known blind spots, and they are deliberate.** `range` and `color`
  inputs are excluded because the photo editor writes their value after the page renders, and
  `checkbox` and `radio` are excluded because their `value` is `"on"` whether or not they are
  ticked — asking them would report every page as holding unsent work and hold every update in the
  application. A checkbox the reader has changed and submitted is therefore not detected, which is
  correct: the server sent the new value.
- **One controller per page.** It is attached to a permanently present hidden element rather than to
  a stream source, because there is one per page while the streams differ per page, and because the
  notice has to be somewhere on the page to be revealed into.
- **There is no guest story.** A public universe is readable by people with no account, and this
  feature does nothing for them. That is a consequence of the connection's session rules, not a
  separate decision, and it is worth stating rather than discovering.

### Rejected: broadcasting rendered content

The obvious implementation, and the one that cannot be made correct here. It renders without a
session, without `Current`, and without the receiving reader's locale, and it dispenses records to a
subscriber whose access was withdrawn after the page was rendered. Every one of those is silent.

### Rejected: broadcasting to a per-reader-per-universe stream instead of a universe stream

It would be narrower — a refresh only for readers who could see what changed — and it would multiply
streams by the size of the membership, with one broadcast per subscriber instead of one per universe.
The authorization it would buy is the authorization the re-request already performs.

### Rejected: three more streams for the review workflow

A submission stream and a decision stream would be a second answer to who is told, written in a
different file from the rows that already record it. ADR 0025's recipient rules would then have two
homes, and the notification write would have to stay in step with both.

### Rejected: publishing inside the write path

Cheaper to write and wrong in two directions: a reader is invited to re-read a universe that has not
been written yet, and a rolled-back apply or a refused reply announces something that does not
exist. It also breaks a reviewer's approval specifically, whose decision transaction wraps the
applier's.

### Rejected: two people typing into the same record at once

The collaboration plan defers this deliberately, and the refresh decision is what defers it. Shared
editing needs every keystroke to be merged into somebody else's open document — an operational
transform or a CRDT, a conflict resolution the *browser* performs rather than an author, and an
unmergeable state that only a lock can prevent. This application already answered the problem it was
going to solve: a second reader's write is not lost, it is **announced** and applied through the live
mutation path with a per-record conflict check the author answers. The promise is asynchronous with an
explicit apply, and a reader is never holding half of somebody else's sentence.

### Rejected: letting Turbo apply the refresh unconditionally

The default, and it discards unsent work without asking — a half-typed reply, a reviewer's notes, a
submission message, a modal editor's payload. A real-time feature that loses what the reader was
typing is worse than a stale page.

### Rejected: a dirty-field registry per form

The alternative to one question is a list of every form and every field that can hold unsent work,
which is a second place for every new editor to be declared, and which is wrong the first time a form
is added without being declared. `defaultValue` is the browser's own record of what the server sent,
so one comparison answers the search bar, the modal editors, the composers, and every filter input
that came back populated.

### Rejected: the `test` cable adapter

It is the documented adapter for asserting broadcasts, and it would have made
`assert_broadcasts` available in exchange for making the system test impossible: nothing is delivered,
so a browser can never observe a page changing without a reload. Asserting the broadcast is what the
Ruby test is for; observing the delivery is what the browser test is for.

## Related documentation

- [`../conventions.md`](../conventions.md)
- [`../architecture.md`](../architecture.md)
- [`../visual_design.md`](../visual_design.md)
- [0016](0016-internationalization-and-browser-locale.md)
- [0025](0025-a-notification-is-a-stored-sentence.md)