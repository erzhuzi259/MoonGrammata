# Security policy

## Supported version

Security fixes are applied to the latest published minor version. Before the
first release, report issues against the default branch.

## Reporting

Do not publish a working exploit or sensitive third-party corpus in a public
issue. Contact the repository owner through the private security-reporting
channel on GitHub. Include the affected API, smallest reproducible input,
resource configuration, backend, MoonBit version, and whether replay is stable.

## Security boundary

MoonGrammata bounds its own generated trees, corpus, reduction work, event log,
and replay decoding. It does not isolate the `Target` callback. A target can
loop, allocate without bound, access ambient capabilities, terminate the
process, or invoke unsafe foreign code. Run untrusted targets in a separately
managed process/container with appropriate operating-system limits.

Replay records and corpus inputs are untrusted data. Decode them with explicit
input limits and do not interpolate them into shell commands. Failure details
may contain target-provided text; downstream HTML/terminal renderers remain
responsible for contextual escaping.

The pseudo-random generator is deterministic and is not suitable for secrets,
cryptographic nonces, or adversarial unpredictability.

