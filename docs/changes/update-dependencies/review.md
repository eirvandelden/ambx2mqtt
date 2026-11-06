# Review: update dependencies

## Round 1 — 2026-11-06T13:52Z — b74936e

No findings.

Notes (not findings):

- No `REVIEW.md` or `REVIEW.local.md` at the repository root; the reviewer's default Bugs, Security, Compliance and Design passes apply.
- Scope: only `Gemfile.lock` changes against `origin/main`, as plan step 3 requires.
- Proof: `bundle exec rake test` (138 runs, 0 failures), `bundle exec rubocop` (45 files, no offenses) and `bundle exec bundler-audit check --update` (no vulnerabilities) are green on `b74936e`.
- libambx `3c8eef6` → `be5eceb` (0.4.1 → 0.5.0): the library diff adds inline RBS comments only; `Ambx.devices`, `Ambx::Device#identity`, `#open`, `#write` and `#close` behave the same. The release requires Ruby ≥ 4.0; `.ruby-version` is 4.0.6, and CI reads it through `setup-rv` with `ruby-version: current`.
- prism stays on 1.9.0 although plan step 1 names it: minitest (`~> 1.5`) and rubocop-ast (`~> 1.7`) do not accept prism 2, as the libambx 0.5.0 changelog also records.
- Every other bump is a patch or minor release of a development or transitive gem (activesupport and rack arrive through rubocop-rails); no runtime code changes.
