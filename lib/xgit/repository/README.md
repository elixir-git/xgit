# `repository` folder

The modules in this folder implement built-in repository types.

The intention here is to keep the `Repository` API surface as small as possible
so as to make it easy for users of this library to implement different storage
mechanisms.

Operations on repositories can be found in the `plumbing` or (not yet created)
`api` folders.
