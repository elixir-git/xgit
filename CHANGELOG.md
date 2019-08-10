# Changelog for v0.1.x Series

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
