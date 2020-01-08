# Changelog for v0.x Series

## v0.7.2

_07 January 2020_

* **Implement `Xgit.Repository.tag/4`**. This is an API equivalent to the creation case of [`git tag`](https://git-scm.com/docs/git-tag).
* Transfer responsibility for enforcing tag target type to `Xgit.Repository.Plumbing`. (#279)
* Implement `Xgit.Tag.valid_name?/1`. (#277)
* Implement `Xgit.Tag.to_object/1`. (#276)
* Remove `Xgit.GitInitTestCase`. (#275)

## v0.7.1

_30 December 2019_

* **Implement `Xgit.Repository.Plumbing.cat_file_tag/2`.** (#272) This is an API equivalent to [`git cat_file -p`](https://git-scm.com/docs/git-cat-file#Documentation/git-cat-file.txt--p) when the target object is of type `tag`.
* Implement `Xgit.Tag.from_object/1`. (#270, #271)
* Implement `Xgit.ObjectType.from_bytelist/1`. (#269)
* Back to 100% code coverage. (#268)
* Define `Xgit.Tag`, which describes a `tag` object in memory. (#267)

## v0.7.0

_21 December 2019_

* **Implement `Xgit.Repository.Plumbing.delete_symbolic_ref/2`.** (#263) This is an API analogue for `git symbolic-ref --delete (ref_name)`.
* Parse, don't validate. Redefine Storage type to be `{:xgit_repo, pid}` and optimize for the case where the PID has been remembered. (#265)
* [API BREAKING] Replace `{:error, :invalid_repository}` response with error. (#264)
* [API BREAKING] Rework `Xgit.Repository.Plumbing.delete_ref/3` to trace (or not) symbolic links. (#262)
* Implement `Xgit.Repository.Plumbing.get_symbolic_ref/2`. (#261)

## v0.6.0

_15 December 2019_

**This is a significant refactoring release aimed at making Xgit's APIs easier to understand.**

* Documentation tweak: Put `Xgit.Repository.WorkingTree` in repository group. (#259)
* [API BREAKING] Move index file format parsing into `Xgit.DirCache` module. (#258)
* [API BREAKING] Rename `Xgit.Core.*` modules to `Xgit.*`. (#257)
* Introduce new `Xgit.Repository` module. (#256)
* Merge all the plumbing commands together into a single module. (#255)
* Rename `Xgit.Repository` to `Xgit.Repository.Storage`. (#254)

## v0.5.0

_05 December 2019_

* **Implement `Xgit.Plumbing.SymbolicRef.Put`.** (#252) This is an API analogue to the 2-argument form of `git symbolic-ref`.
* [API BREAKING] `Xgit.Repository.put_ref/4`: Add `:follow_link?` option. (#250)
* `Xgit.Repository.put_ref/4`: Should not fail if creating a sym ref to a non-existent ref. (#247)
* Share the code for ref-related tests in `Xgit.Repository` implementations. (#246)
* `Xgit.Repository.InMemory`: Remove a line of code that is unreachable. (#245)

## v0.4.0

_28 November 2019_

* **Implement `Xgit.Plumbing.UpdateRef`.** (#242) This is an API equivalent to `git update-ref`.
* [API BREAKING] Add reference operations to `Xgit.Repository` interface. (#222, #230, #231, #233, #236, #238, #239)
* Run `mix credo` and `mix format --check-formatted` separately. (#221)
* Avoid the `mix deps.get` and `mix deps.compile` steps via cache. (#220)
* Start using GitHub actions to build PRs. (#215, #218)
* Switch from Coveralls to CodeCov. (#216)
* `TrailingHashDevice` test frequently times out. Give it more time. (#217)
* Move all the implementation details for `Xgit.Repository.OnDisk` into a single file. (#214)
* Implement `Xgit.Util.FileUtils.recursive_files!/1`. (#213)
* Implement `Xgit.Core.Ref`. (#211, #212, #229, #232, #235, #237, #240)
* Bump excoveralls from 0.11.2 to 0.12.1 (#210, #234)

## v0.3.0

_19 October 2019_

* **Implement `Xgit.Plumbing.CatFile.Commit`.** This is an API equivalent to `git cat-file -p` when the target object is of type `commit`. (#207)
* Implement `Xgit.Core.Commit.from_object/1`. (#204, #205, #206)
* [API BREAKING] Make `Xgit.Util.*` modules private. (#201)
* [API BREAKING] Remove `Xgit.Util.RawParseUtils`. (#195, #198, #199, #200)
* Move `parse_timzeone_offset` into `Xgit.Core.PersonIdent`. (#197)
* Implement `Xgit.Util.ParseCharlist.decode_ambiguous_charlist/1`. (#196)
* Bump credo from 1.1.4 to 1.1.5 (#194)

## v0.2.5

_08 October 2019_

* **Implement `Xgit.Plumbing.CommitTree`.** (#191)
* Introduce `Xgit.Core.Commit` struct. (#182)
* [BUG FIX]: Unable to decode certain `tree` structures. (#183)
* Implement `Xgit.Core.Commit.to_object/1`. (#184)
* Fix broken `coveralls-ignore` comments. (#186)
* Refactor the basics of how tests are set up. (#187)
* Clean up issues flagged by ElixirLS. (#188)
* `OnDiskRepoTestCase`: Make it possible to override the temporary directory for testing purposes. (#189, #190)

## v0.2.4

_28 September 2019_

* **Implement `Xgit.Plumbing.ReadTree`.** This is an API equivalent to `git read-tree`. (#180)
* First benchmark: Looking at `Xgit.Repository.WorkingTree.ParseIndexFile.from_iodevice/1`. (#167)
* Implement `WorkingTree.reset_dir_cache/1`. (#169)
* Implement `Xgit.Repository.WorkingTree.write_tree/2`. (#170)
* Refactor `Xgit.Plumbing.WriteTree` to use `WorkingTree.write_tree/2`. (#171)
* Minimal extension support for index file parsing. (#173)
* Bump `dialyxir` from 1.0.0-rc.6 to 1.0.0-rc.7 (#174)
* Pull out index file as part of WorkingTree state. (#177)
* Implement `Xgit.Repository.WorkingTree.read_tree/3`. (#176)

## v0.2.3

_16 September 2019_

* **Implement `Xgit.Plumbing.CatFile.Tree`.** This is an API equivalent to `git cat-file -p` when the target object is of type `tree`. (#165)
* `Object.valid?/1`: Require that content has an implementation for `ContentSource` protocol. (#161)
* [BUG FIX] `OnDisk`'s implementation of `get_object/2` didn't contain a valid `ContentSource`. (#162)
* Implement `Xgit.Core.ObjectId.from_raw_object_id/1`. (#163)
* Implement `Xgit.Core.Tree.from_object/1`. (#164)

## v0.2.2

_07 September 2019_

* **Implement `Xgit.Plumbing.WriteTree`.** This is an API equivalent to `git write-tree`. (#158)
* Fix `@spec` for `Xgit.Plumbing.HashObject.run/2`. (#142)
* Implement `Xgit.Core.DirCache.fully_merged?/1`. (#143)
* Remove redundant alias in `Xgit.Core.Object`. (#144)
* Implement `Xgit.Core.FilePath.ensure_trailing_separator/1`. (#145)
* Implement `Xgit.Core.FilePath.starts_with?/2`. (#146)
* Implement `Xgit.Core.Tree` struct. (#147)
* Implement `Xgit.Core.FileMode.to_octal/1`. (#149)
* Implement `Xgit.Core.ObjectId.to_binary_iodata/1`. (#150)
* Bump ex_doc from 0.21.1 to 0.21.2 (#151)
* Bump credo from 1.1.3 to 1.1.4 (#152)
* Implement `Xgit.Core.Tree.to_object/1`. (#153)
* `Xgit.Core.FileMode`: Replace `to_octal/1` with `to_short_octal/1`. (#154)
* `DirCache.valid?/1` should not allow a file and directory to exist at the same prefix. (#155)
* Implement `Xgit.Core.DirCache/to_tree_objects/2`. (#156)
* Implement `Xgit.Repository.has_all_object_ids?/2`. (#157)

## v0.2.1

_01 September 2019_

* Force code coverage for cases where a literal value is returned. (#122)

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
