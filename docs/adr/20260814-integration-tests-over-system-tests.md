# 20260814 — Rack integration tests, no browser harness

## Context

Rails ships a Capybara/Selenium system-test harness by default. Bloom's UI is server-rendered
ERB with Turbo defaults and no bespoke JavaScript, so there is no interaction on any page that
a Rack-level request cannot exercise. Carrying a browser harness for it would mean maintaining
driver versions and tolerating flakiness in exchange for nothing.

## Decision

`ActionDispatch::IntegrationTest` with `assert_select`, and no Capybara or Selenium in the
Gemfile. Both were removed from the generated `:test` group before the first commit, along with
`test/system` and `application_system_test_case.rb`.

## Consequences

- The suite runs in about two seconds and needs no browser or driver, so CI stays trivial.
- Genuinely browser-dependent behaviour is not covered. Today there is none; if a page grows a
  Stimulus controller with real logic, that is the moment to reconsider — not a reason to carry
  the harness pre-emptively.
- The scaffolding was deleted rather than left empty, so nothing invites its use back.
- Integration tests run against the test environment's defaults, which differ from production
  in ways that can hide real failures — forgery protection being the one that already bit.
  Where a test asserts that a protection does not apply, it must switch that protection on
  itself rather than trusting the environment.
