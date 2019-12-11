When there's a concern about algorithmic or absolute cost of a specific implementation,
let's build a microbenchmark here. As of this writing (mid-September 2019), I think the
following functions need study.

```
Xgit.Core.DirCache
	add_entries/2
	fully_merged?/1
	remove_entries/2
	to_tree_objects/2

Xgit.Core.FilePath
	check_path_segment/2
	check_path/2
	valid?/2

Xgit.Core.Object
	valid?/1

Xgit.Core.Tree
	from_object/1
	to_object/1

Xgit.Repository.Storage (permute on the implementations)
	get_object/2
	has_all_object_ids?/2
	put_loose_object/2

Xgit.Repository.WorkingTree.WriteIndexFile
	to_iodevice/1
```
