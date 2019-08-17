# Changelog for v0.1.x Series

## v0.1.4

_17 August 2019_

* Fix logo in exdoc. (#95)

## v0.1.3

_17 August 2019_

* Fix a couple minor issues in documentation. (#92, #93, #94)

## v0.1.2

_17 August 2019_

* **Implement `Xgit.Plumbing.LsFiles.Stage`. (#90)** This is an API equivalent of `git ls-files --stage`.
* Implement `Xgit.Repository.WorkingTree`. (#72, #80, #89)
* Implement `Xgit.Core.DirCache`. (#65, #70, #71, #73, #85)
* Automatically attach a working tree to on-disk repository. (#84)
* Implement `Xgit.Util.FileSnapshot` (borrowed from old jgit port). (#83)
* Add Elixir 1.9.1 and OTP 22.0 to test matrix. (#82)
* Add `valid?/1` test functions to most `Xgit.Core.*` modules. (#74, #76, #77, #78)
* Add a second implementation (in-memory) of `Xgit.Repository`. (#68)

## v0.1.1

_10 August 2019_

* **Implement `Xgit.Plumbing.CatFile`. (#59)**
* Implement `Xgit.Util.UnzipStream`. (#51)
* Fix documentation for `Repository.handle_put_loose_object/2`. (#53)
* Implement `Xgit.Repository.get_object/2`. (#54)
* Add Xgit logo and hex.pm badges. (#55)
* Change all `{:error, (string)}` tuples to be `{:error, (atom)}`. (#58)
* Update `@spec` documentation to call out all possible reason codes. (#60)
* Add Dialyxir as dev-only dependency and fix warnings it reported. (#61)

## v0.1.0

_03 August 2019_

* **Initial public release of this version.**
* Implement `Xgit.Plumbing.HashObject`.
* Implement `Xgit.Repository.OnDisk.create/1`.
