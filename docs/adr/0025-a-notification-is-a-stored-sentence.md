# ADR 0025: A notification is a stored sentence, and each kind answers its own recipient question

- **Status:** Accepted
- **Date:** 2026-10-05
- **Related:** [`../conventions.md`](../conventions.md),
  [`../data_model.md`](../data_model.md),
  [`../architecture.md`](../architecture.md),
  [`../features/navigation.md`](../features/navigation.md),
  [`../known_quirks.md`](../known_quirks.md),
  [0019](0019-collaboration-foundations.md),
  [0021](0021-applying-a-draft-through-the-live-mutation-path.md)

The rules this ADR decides are **what** in [`../conventions.md`](../conventions.md#notifications);
this is the reasoning behind them, written once so that a future contributor changing the bell does
not have to re-derive why it is shaped this way.

## Context

The review workflow and the discussion threads both leave a person waiting on something that
happens while they are somewhere else. An author hands a draft over and closes the tab; a reviewer
approves or rejects it an hour later; two people argue about a character in a thread and only one of
them is looking at it. Nothing was broken about any of that — the writes are committed, the rows are
stored, and the pages the reader eventually visits answer correctly. What was missing is the moment:
the person who has to know has no way to learn that they are the one waiting.

Three questions had to be answered before any of it could be written, and each of them has a way of
being answered wrong that does not raise.

**1. What is a notification — a pointer to the thing that happened, or a record of it?** A pointer
is the obvious modelling answer and the ordinary one in a Rails application: a `review_request_id`,
resolved on read. It is also wrong here, and the reason is a lifetime. A `ReviewRequest` is destroyed
with its draft, and a draft is destroyed with its universe. The bell is in the navbar, on **every**
page, for a signed-in reader — so a pointer row does not fail in the page where its subject was
deleted, it fails in the navbar of an unrelated universe, and it takes the page down with it. The
same argument applies one level down: a thread is destroyed with its record, and a universe renamed
since the notice was written changes the slug its row would resolve to.

**2. Who is told?** One rule — "tell the people who can see this universe" — is available and is
wrong for all three kinds, in three different ways. Telling the universe about a submission tells
everybody who is not allowed to open the queue, and tells the author news they caused. Telling the
universe about a decision tells every bystander about somebody else's work. Telling the universe
about a reply tells every member of a conversation two people chose to have with each other about
one record, and discloses to a reader whose membership was withdrawn after they posted that they
said something, to somebody who may not know they ever did. Each of those is a disclosure rather
than a failure, which is why the recipient rule cannot be one rule with parameters.

**3. Where does the page live?** A notification belongs to a universe — the submission, the thread,
the review — so a universe-scoped bell is the natural shape and it is wrong too. The person who was
handed a draft and the person who handed it over are rarely on the same page; the author is in their
own workspace, the reviewer is in somebody else's. A bell scoped to `Current.universe` can only
answer for one of a reader's universes, and the question it answers is not about a universe at all.

## Decision

### The payload is the sentence, and there is no foreign key to anything it names

A notification's `payload` carries the universe's slug and name, the ids the row links at, the other
person's name, and a reviewer's note where there is one. Every value is copied at the moment the
notice is written. `docs/data_model.md` owns the columns; the decision is that **reading what a
notice says must never require the thing it is about to still exist.**

The cost is names stored twice and validated by nothing, and it is paid deliberately: a stale name
in a bell is a sentence about the past, while a resolved name that no longer exists is a 500 on
every page. The row's own `user_id` is the one pointer kept, because a notification has exactly one
reader and marking it read is that person's act.

The column is `kind` and not the `type` the collaboration plan named, for the reason ADR 0019 gave
for `draft_changes.payload`: `type` is Active Record's single-table-inheritance discriminator, so a
row whose type was `"review_submitted"` would be looked up as a class name and raise
`SubclassNotFound` on a value this application invented.

### Each kind answers its own question about who is waiting

`Notification::KINDS` holds three kinds, and each recipient rule is the answer to a *different*
question rather than a variation on one.

- A **submission** goes to `Universe#administrators`, minus the author. `admin` access is the whole
  of who may read the reviewer's queue, so the administrators are exactly the people for whom the
  fact is news. The author is excluded because they pressed the control that caused it and the page
  they land on already says it.
- A **decision** goes to the author alone, because the decision is addressed to them and the
  reviewer's note is written for them. Nobody else has standing to read it.
- A **reply** goes to everybody else who has posted in that thread and can still read the universe.
  The recipients are read from the thread's stored messages rather than from a participants column,
  because a thread has a history rather than a membership: three posts is one recipient, one row
  each, and a member who has never posted is not in the conversation at all.

The read-access filter on the third rule is not decoration. It is the only thing standing between a
conversation and a reader who has lost the right to open the universe it happened in.

### It is not a content class, and the page is not universe-scoped

`Notification` is deliberately absent from `Ability::CONTENT_CLASS_NAMES`, for the reason `Draft` and
`ReviewRequest` are: the content rules would answer `read` for a guest in a public universe, and
somebody's unfinished work under somebody else's decision is not something a universe publishes.
`NotificationsController` requires an account and scopes to `Current.user.notifications` — another
person's row and a row that does not exist are one answer — and its routes carry no universe, because
the row carries its own universe's slug in the payload.

### Every notice is written inside the transaction that made the event

`Draft#submit!`, `ReviewRequest#reject!`, the approval's own transaction in
`ReviewRequestsController`, and `DiscussionMessage#post!` each write their notice inside the same
transaction as the write that caused it. A decision that committed without its notice leaves an
author waiting for a verdict that has already been given; a message that landed while its notice
failed to write leaves a thread looking like it did not answer.

An approval stopped by a conflict announces nothing, because the decision was never taken.
`DiscussionMessage#post!` is the one of these that answers `true`/`false` rather than raising, since
an empty composer is an ordinary form error with a place to report it; its transaction still rolls
back, so a refused reply writes neither the message nor the notice.

### Marking read is an explicit act, and the figure is never cached

Two POSTs, both on the page rather than in the dropdown: `read` for one row and `read_all` for
everything unread. A dropdown that marked a row read as it was rendered would answer for the reader
— a reader who has read three of five entries has not read the other two — and a `GET` that marked a
row read would let a link, a prefetch, or a crawler silence a bell on their behalf.

The bell's figure is one uncached `COUNT` over `[user_id, read]`. It is uncached because it moves
when somebody else does something in another browser, which nothing in the cache can expire on, and a
bell that is up to an hour late is a bell that fails at its one job. The bell stays rendered when
everything is read, because a reader who has read everything still has a list.

## Consequences

### Benefits

- The navbar cannot be taken down by a universe that was deleted, a submission that was discarded,
  or a slug that changed. A row that cannot resolve anything still prints a sentence.
- The three recipient rules are one fact each, stated once, and each answers the question its kind
  actually poses. There is no fourth place to keep them in step.
- A reviewer with no admin access can still be shown what a notice says, because a notice is a
  sentence rather than a permission; what each row links at is chosen for the reader who receives it
  instead.
- Notices survive the delivery channel. When a live update later moves a bell under a reader who is
  on another page, the rule that made the bell unreadable — "look again" — reads the same rows.

### Costs and constraints

- **Names are copied and never reconciled.** A universe renamed after a notice was written leaves the
  old name in the sentence and a link that answers `404`. That is the accepted price and it is the
  only place this application accepts a stale name in a rendered sentence.
- **Nothing is deduplicated.** A draft that is rejected, edited, and submitted again is two real
  submissions and two real notices. Leaving that alone is a decision, not an oversight: the second
  arrival of the same news is not an error to raise about.
- **A withdrawal notifies nobody**, because it is the author taking back their own work. A reviewer
  watching the queue sees the row leave the waiting figure and has to open it to learn why.
- **The unread figure is asked on every page** a signed-in reader opens. It is one indexed `COUNT`
  and it is the price of a bell that is right; `MenuCountCache` is used everywhere else in the shell
  for exactly the opposite reason.
- **A reply notice names the record but not its class.** "Somebody replied about Gandalf" is the
  sentence; the record type would add nothing printable and would have to be resolved from a stored
  polymorphic pair to be trusted at all.
- **The participant filter is per reader, not one query.** A thread holds a handful of authors, and
  each one needs their own `readable_by?` answer, so the recipient list is a `SELECT` plus a Ruby
  filter rather than one scoped query.

### Rejected: a foreign key to the thing being announced

It is the ordinary answer and it is the one that fails in the navbar. A `review_request_id` with a
cascade delete removes the notice when its subject goes, which sounds tidier than it is: the author's
own decision history disappears with the draft, and a reader who was told something loses the record
that they were. It also makes the sentence a join — the other person's name, the universe's name,
and the reviewer's note would each have to be resolved on read, which is the failure the copy was
made to avoid.

### Rejected: store ids and resolve the sentence on read

Cheaper to write and better normalized, and it puts every render on the critical path of two
lifetimes this application does not control. It also cannot answer "what did this say" once the
subject is gone, which is the one question a bell exists to answer.

### Rejected: one recipient rule for all three kinds

The "tell everybody who can read the universe" rule fails three different ways at once, and two of
them are disclosures rather than noise. A submission would tell readers who may not open the queue,
a decision would tell bystanders about somebody else's work, and a reply would disclose to a
withdrawn member that they had spoken. The rules differ in **who may know**, not in how many
recipients there are, which is why one parameterized rule could not have produced them.

### Rejected: a participants column on the thread

It would be a second record of who posted, written by a different caller than the one that posts.
A thread's participants are derivable from its messages and nobody else needs them, so the column
would have to be kept in step with a `has_many` it duplicates — and the reply rule is the only
caller, so the derivation would be paid for constantly to be read once.

### Rejected: telling the author about their own submission

It is the same news arriving twice: the author pressed the control, the page they land on says it,
and the draft's own row carries it for as long as it is open. It also makes the rule awkward in the
one case it is most likely to matter — an author who is also their universe's only administrator
would receive a notice about work they are the only person who can review, which is the situation in
which a bell is least useful.

### Rejected: marking rows read when the bell renders

It is one write per row on every page, it is a `GET`, and it answers a question the reader never
asked. Opening the bell is not a decision about every entry in it.

### Rejected: email delivery

Deferred deliberately, and it is a separate decision rather than a delivery detail: it introduces an
address this application does not store, an unsubscribe the reader cannot exercise without one, and a
retention question that the in-app row does not have — the row is in the reader's own universe and
is deleted with their account's data, while an email is not. The in-app bell is the whole of the
delivery this application has decided to offer.

## Related documentation

- [`../conventions.md`](../conventions.md)
- [`../data_model.md`](../data_model.md)
- [`../architecture.md`](../architecture.md)
- [`../features/navigation.md`](../features/navigation.md)
- [0019](0019-collaboration-foundations.md)
- [0021](0021-applying-a-draft-through-the-live-mutation-path.md)
- [0026](0026-a-live-update-is-a-refresh-and-never-a-page.md)