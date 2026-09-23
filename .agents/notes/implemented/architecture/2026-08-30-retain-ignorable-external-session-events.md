# Agent Note: Retain ignorable session events for external plugins

Status: implemented

English | [中文](2026-08-30-retain-ignorable-external-session-events.zh.md)

## Problem

The session event envelope carries `ignorable?: true` so a reader can accept an unrecognized informational event without treating every vocabulary addition as a new session format. PR #3087 removed the field after finding no first-party producer and made every unknown event required-on-read.

That producer inventory did not cover a third-party plugin that currently depends on the field. Without `ignorable`, a first-party reader rejects a stored session containing the plugin's informational event because the event is outside the repository-generated `KNOWN_SESSION_EVENT_TYPES`. The plugin has no replacement registration or versioning mechanism, so deleting the field before a replacement exists breaks a current external consumer.

## Decision

The canonical `SessionEvent` envelope retains `ignorable?: true`, and every representation preserves it: seed validation, JSONL, API transport, generated catalogs, and test fixtures. The persistence seam's stored-event validation (`validateStoredEvents`) continues to refuse an unknown event unless its stored envelope explicitly carries `ignorable: true`; absent remains required-on-read.

`Session.append` is the writer side of the same mechanism. A non-surface event accepts [`NonSurfaceAppendOptions`](../../../../packages/core/session/src/index.ts), whose `ignorable: true` marks a record this build's vocabulary does not declare; surface events keep their `SurfaceIntent` parameter and cannot carry the marker. The append refuses the marker on a type `KNOWN_SESSION_EVENT_TYPES` already names, because a known type's omission safety is a vocabulary decision the read path enforces rather than something a caller may assert; without that guard the mistake would surface only at the next reload, as a session the reader refuses.

The field is removable only after a replacement supports the current third-party plugin across event production, persistence, reload, and transport, with an explicit cutover for sessions already containing the marker. Event production now has that replacement. The [session log versioning decision](2026-08-10-session-log-version-mechanism.md) continues to own the default-required safety rule and format-version policy.

Historical format migration is deliberately stricter in the alpha implementation. The v0-to-v1 edge refuses every unknown v0 type, including an ignorable one, because an opaque payload may contain references that a format edge cannot validate. The [alpha historical-event decision](2026-08-31-alpha-historical-unknown-event-refusal.md) owns that bounded exception; equal-version append and reload continue to follow this note.

## Alternatives considered

**Require every unknown event on read.** Rejected because the current third-party plugin emits an informational event outside the repository-generated vocabulary. A first-party reload would reject that session even though omitting the event is safe.

**Delete the field and design a replacement later.** Rejected because that ordering creates an immediate compatibility gap with no migration or cutover path for the plugin or its stored sessions.

**Treat every repository-external event as ignorable.** Rejected because a reader cannot infer that an unknown durable event is informational. An external event may change later reconstruction or plugin-owned state.

**Register mounted plugin event names as known.** Not adopted as the removal mechanism because event-name registration alone does not classify whether absence is safe, and acceptance would depend on the reader's current composition rather than the stored record.

**Let a writer mark any event ignorable, including a known one.** Rejected because the read path refuses a known type that carries the marker, so the append would produce a session that loads in the writing process and fails on reload. The guard reports that at the append site instead.

## Consequences

Third-party informational events can remain reloadable when their stored records carry the explicit marker, while unknown required events still fail loudly. The field remains part of the public event envelope, JSONL representation, transport types, generated references, and their tests until a replacement satisfies the cutover condition. Event production is no longer the missing half: an out-of-repo plugin marks its own non-surface record through `Session.append` and never writes an envelope itself.
