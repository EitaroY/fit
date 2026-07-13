# Security Policy

Fit runs entirely locally: no network code, no auto-update, no telemetry, and the only permission it requests is macOS Accessibility. The most likely security-relevant issues are misuse of the Accessibility API, a flaw that lets another process abuse Fit's permission, or a problem in the documented build/signing instructions.

## Reporting a vulnerability

Please use GitHub's private vulnerability reporting (**Security** tab → *Report a vulnerability*) instead of opening a public issue. If private reporting is unavailable, email temma.ai.brain@gmail.com.

You should get an initial response within a week. Fixes ship as a new tagged commit on `main`; since users build from source, please re-pull and rebuild.
