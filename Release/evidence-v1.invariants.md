# Release evidence v1 invariants

`Release/evidence-v1.schema.json` is the portable structural schema. The
normative executable validator is `Tools/release_evidence.py`; consumers that
make a release decision must run its `validate` command rather than treating a
JSON Schema pass as sufficient.

The executable validator additionally enforces invariants JSON Schema cannot
express by itself:

1. `workflow.url` is exactly derived from `repository`, `workflow.runId`, and
   `workflow.attempt`.
2. `createdAt` is a real, canonical UTC calendar timestamp, not only a string
   matching the timestamp pattern.
3. The document has exactly the published top-level and nested fields; duplicate
   JSON names are rejected.
4. `releaseStatus` is always `candidate`. The v1 format never records or infers
   App Store processing, a TestFlight build identifier, or Beta App Review.
5. Candidate creation reopens the exact IPA after upload and requires both its
   SHA-256 and byte size to match the identity locked before upload. File
   identity, size, modification time, and change time must stay stable during
   each read.
6. Validation and upload success describe successful `altool` command exits.
   They do not prove App Store processing or Beta App Review.

`Release/evidence-v1.corpus.json` is the public conformance corpus. CI runs
`validate-corpus` and requires both accepted and rejected cases to produce their
declared outcome. A protected workflow artifact plus Apple-side evidence remains
the release authority; a detached JSON file is never sufficient.
