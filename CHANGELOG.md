# Changelog for v0.x Series

## v0.2.0

_28 August 2019_

* **This is a refactoring release. It breaks API compatibility, thus the secondary version bump.**
* Introduce a common data type for less-than / equal / greater-than comparisons. (#128)
* [API BREAKING] Refactor file path code into new module `Xgit.Core.FilePath`. (#129)
* Introduce `Xgit.Core.DirCache.Entry.stage` type for index file stage references. (#130)
* [API BREAKING] Merge `Xgit.Core.ValidateObject` into `Xgit.Core.Object`. (#132)
* Share code for finding working tree in plumbing command modules. (#134)
* Update several dependencies. (#135, #136, #137)

## v0.1.6

_27 August 2019_

* **Implement `Xgit.Plumbing.UpdateIndex.CacheInfo`. (#125)** This is an API equivalent of `git update-index --cacheinfo`.
* Implement `DirCache.add_entries/2`. (#97)
* `Xgit.Util.TrailingHashDevice`: Add support for writing files. (#108)
* `Xgit.Util.NB`: Add encode_uint32 function. (#109)
* Fix `@type` declaration for `ParseIndexFile.from_iodevice_reason`. (#110)
* `FolderDiff`: Expose `assert_files_are_equal/2`. (#111)
* Implement `Xgit.Util.NB.encode_uint16/1`. (#112)
* Implement `Xgit.Repository.WorkingTree.WriteIndexFile`. (#115)
* Implement `Xgit.Core.DirCache.remove_entries/2`. (#119)
* Implement `Xgit.Repository.WorkingTree.update_dir_cache/3`. (#123)

## v0.1.5

_19 August 2019_

* **This is a bug fix and optimization release.**
* When reading `.git/index` file, verify the trailling SHA-1 hash. (#98, #99, #100, #101, #102, #103)
* Generate code coverage for `Xgit.Util.UnzipStream` `:continue` case. (#104)
* Remove unnecessary data transformations in `Xgit.Repository.OnDisk.PutLooseObject`. (#105)

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
