# Code Organization

## Design Goal

A primary design goal of Xgit is to allow git repositories to be stored in
arbitrary locations other than file systems. (In a server environment, it likely
makes sense to store content in a database or cloud-based file system such as S3.)

For that reason, the concept of **"repository"** in Xgit is kept intentionally
minimal. `Xgit.Repository.Storage` defines a behaviour module that describes the interface
that a storage implementor would need to implement and very little else. (A repository
is implemented using `GenServer` so that it can maintain its state independently.
`Xgit.Repository.Storage` provides a wrapper interface for the calls that other modules
within Xgit need to make to manipulate the repository.)

A **typical end-user developer** will typically construct an instance of `Xgit.Repository.OnDisk`
(or some other module that implements a different storage architecture as described
next) and then use the functions in `Xgit.Repository` to inspect and modify the repository.
(These modules are agnostic with regard to storage architecture to the maximum
extent possible.)

A **storage architect** will construct a module that encapsulates the desired storage mechanism
in a `GenServer` process and makes that available to the rest of Xgit by implementing
the `Xgit.Repository.Storage` behaviour interface.

**Guideline:** With the exception of the reference implementation `Xgit.Repository.OnDisk`,
all code in Xgit should be implemented without knowledge of how and where content is stored.
