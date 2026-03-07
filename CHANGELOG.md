# Changelog

## [0.2.6](https://github.com/chiply/repeatable-lite/compare/v0.2.5...v0.2.6) (2026-03-07)


### Bug Fixes

* update copyright year to 2025-2026 ([#14](https://github.com/chiply/repeatable-lite/issues/14)) ([9d2ab4b](https://github.com/chiply/repeatable-lite/commit/9d2ab4baba7469e4eb8b5d76879ab604a120ea6b))

## [0.2.5](https://github.com/chiply/repeatable-lite/compare/v0.2.4...v0.2.5) (2026-03-07)


### Features

* add dismiss key to hide help while preserving active prefix ([3872d0e](https://github.com/chiply/repeatable-lite/commit/3872d0ec890e74cf28e573571b6e95a3eed41472))
* add generic backend switching and combined C-h dispatch prompt ([7b3b927](https://github.com/chiply/repeatable-lite/commit/7b3b927b27c4b048ec5da578a62cebb1f39f2f3f))


### Bug Fixes

* update tests to use which-key-reload-key-sequence ([f5b95fb](https://github.com/chiply/repeatable-lite/commit/f5b95fb54fd9f892c15e3b170c1febb899f0695f))

## [0.2.4](https://github.com/chiply/repeatable-lite/compare/v0.2.3...v0.2.4) (2026-03-07)


### Bug Fixes

* return to command loop for prefix help so which-key updates nested prefixes ([3f3306e](https://github.com/chiply/repeatable-lite/commit/3f3306e36990e62e452c4730e057fc36c4a31716))

## [0.2.3](https://github.com/chiply/repeatable-lite/compare/v0.2.2...v0.2.3) (2026-03-07)


### Bug Fixes

* prevent which-key settings corruption, make versatile-C-h extensible ([db3ea4e](https://github.com/chiply/repeatable-lite/commit/db3ea4e1478f2b83d9661bad966636727ed22bbb))
* update tests for guarded kill-which-key restore ([dcd86a3](https://github.com/chiply/repeatable-lite/commit/dcd86a3a325ca33cfb21881096bec86d3ced8c2c))

## [0.2.2](https://github.com/chiply/repeatable-lite/compare/v0.2.1...v0.2.2) (2026-03-04)


### Bug Fixes

* install Nix before magic-nix-cache-action in CI ([b0946c2](https://github.com/chiply/repeatable-lite/commit/b0946c2c5189bbb1ca1e1145b941c3da8156fdc6))

## [0.2.1](https://github.com/chiply/repeatable-lite/compare/v0.2.0...v0.2.1) (2026-03-01)


### Bug Fixes

* bump min Emacs to 30.1, drop which-key dependency, fix checkdoc warnings ([328e5f0](https://github.com/chiply/repeatable-lite/commit/328e5f079beda0f05873d8174be831d26b466977))
* update CI for Emacs 30.1+ minimum, remove continue-on-error on package-lint ([feec14f](https://github.com/chiply/repeatable-lite/commit/feec14fb66b181d4372c74349090ec55241f64db))

## [0.2.0](https://github.com/chiply/repeatable-lite/compare/v0.1.3...v0.2.0) (2026-02-24)


### ⚠ BREAKING CHANGES

* the ** macro is renamed to repeatable-lite-wrap. Update all keybinding configs: (** fn) -> (repeatable-lite-wrap fn)

### Bug Fixes

* revert to block-style release-please version markers ([4eb2a02](https://github.com/chiply/repeatable-lite/commit/4eb2a028f3772830bdbf22d5eb0eaed26c111c71))
* update tests to use renamed repeatable-lite-wrap macro ([8de5632](https://github.com/chiply/repeatable-lite/commit/8de56323ff430679d39f6f6131b078a2e6ba6a7b))


### Miscellaneous Chores

* prepare for MELPA submission ([5969aff](https://github.com/chiply/repeatable-lite/commit/5969affcf371d1090b79e46a4ef3c48fa77587ae))

## [0.1.3](https://github.com/chiply/repeatable-lite/compare/v0.1.2...v0.1.3) (2026-02-23)


### Bug Fixes

* save and restore which-key settings, add (require 'seq) ([98c6d11](https://github.com/chiply/repeatable-lite/commit/98c6d11cc75e9741c8de42da5bd0e0e4bde8f2f9))
* wrap advice in minor mode and fix C-u overflow and nil keymap ([c6db56d](https://github.com/chiply/repeatable-lite/commit/c6db56d5ad0cdec792bb968250493c8072b1a7fa))

## [0.1.2](https://github.com/chiply/repeatable-lite/compare/v0.1.1...v0.1.2) (2026-02-23)


### Bug Fixes

* add cl-lib require in tests and MELPA recipe ([416ac9d](https://github.com/chiply/repeatable-lite/commit/416ac9d5f43bb5a54d18fcf77f9decf0b20664f1))
* rename repeatable-current-prefix and fix test expansion check ([b58039e](https://github.com/chiply/repeatable-lite/commit/b58039e4176f2ad60c4e171928a6db0e59e56c24))

## [0.1.1](https://github.com/chiply/repeatable-lite/compare/v0.1.0...v0.1.1) (2026-02-19)


### Features

* CI improvements from space-tree/brushup ([#3](https://github.com/chiply/repeatable-lite/issues/3)) ([60b3e85](https://github.com/chiply/repeatable-lite/commit/60b3e85efd52f924743020f541ed0530edc4484b))
* initial release of repeatable-lite ([d7b1cf6](https://github.com/chiply/repeatable-lite/commit/d7b1cf6fd4362b1c796d7b9b6fd141ac31455f66))


### Bug Fixes

* add repeatable-lite.el source code ([26dd65d](https://github.com/chiply/repeatable-lite/commit/26dd65d86ef9ddc4992ee36339319d04f59ebdd3))
* populate empty scaffolding files ([a6154c4](https://github.com/chiply/repeatable-lite/commit/a6154c410496373e90bc6fd0b663fdd623dd3454))
* remove unused version.txt ([#4](https://github.com/chiply/repeatable-lite/issues/4)) ([6af459d](https://github.com/chiply/repeatable-lite/commit/6af459db7ff218542cd1d901aa73850174660456))
* use PAT and extra-files for release-please ([#1](https://github.com/chiply/repeatable-lite/issues/1)) ([8507d54](https://github.com/chiply/repeatable-lite/commit/8507d54222057bd1a8f4316c696cbba1e5bf8c1f))
