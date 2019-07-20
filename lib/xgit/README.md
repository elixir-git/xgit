# Code Organization

## Design Goal

A primary design goal of Xgit is to allow git repositories to be stored in
arbitrary locations other than file systems. (In a server environment, it likely
makes sense to store content in a database or cloud-based file system such as S3.)

For that reason, the concept of **"repository"** in Xgit is kept intentionally
minimal. `Xgit.Repository` is a behaviour module that describes the interface
that a storage implementor would need to implement and very little else.

A **typical end-user developer** will typically construct an instance of `Xgit.Repository.OnDisk`
(or some other module that implements a different storage architecture as described
next) and then use the modules in the `api` folder to inspect and modify the repository.
(These modules are agnostic with regard to storage architecture to the maximum
extent possible.)

A **storage architect** will construct a module that implements the `Xgit.Repository`
behaviour and then implement the necessary callbacks to direct git content into
the desired storage mechanism.

**Guideline:** With the exception of the reference implementation `Xgit.Repository.OnDisk`,
all code in Xgit should be implemented without knowledge of how and where content is stored.


## Categories of Code

Code in Xgit is organized into the following categories, reflected in module naming
and corresponding folder organization, listed here roughly in order from top to bottom
of the dependency sequence:

* **`api`** _(none implemented yet)_: These are the typical commands or operations
  that you perform on a git repository. In the git vernacular, these are often
  referred to as **porcelain** (i.e. the refined, user-visible operations).

* **`plumbing`**: These are the raw building-block operations that are often
  composed together to make the user-targeted commands. These are often sophisticated
  operations in and of themselves, but are typically not of interest to end-user
  developers.

* **`repository`**: This describes how a single git repository is persisted. A
  reference "on-disk" implementation is provided and is designed to interoperate
  with the existing git command-line tool.

* **`core`**: The modules in this folder describe the fundamental building blocks
  of git's data model (objects, object IDs, tags, commits, etc.). These are used
  within Xgit to communicate about the content in a repository.

* **`util`**: The modules in this folder aren't really part of the data model
  _per se_, but provide building blocks to make higher layers of Xgit possible.
