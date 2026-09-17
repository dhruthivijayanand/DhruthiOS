# GitHub setup and ongoing workflow

As of 2026-09-17, the user requested a GitHub repository and ongoing milestone
uploads alongside development. The connected account is dhruthivijayanand.

Proposed repository: DhruthiOS, initially private. No remote is configured yet
and no upload has occurred. A repository lookup returned 404, which does not
distinguish absence from inaccessible private content.

Setup limitation: available GitHub connector tools can manage existing content
but do not expose repository creation. GitHub CLI was not found in PATH or the
checked standard install locations. Local Git Credential Manager account lookup
failed with a wincredman credential-store error. Authentication for shell pushes
has not been established.

Next action: create an empty private repository under the connected account with
no generated README, .gitignore, or license. Then verify ownership/access, attach
the remote, establish an authorized upload path, and preserve the local history.
If an existing repository is found, inspect it before modifying anything.

For each subsequent milestone during active sessions:
1. Make and explain a bounded implementation change.
2. Run the appropriate build and QEMU checks.
3. Update actual feature status, test evidence, and limitations.
4. Commit with a meaningful message.
5. Upload to the verified remote and check its resulting commit.

The verified boot commit e9b567c remains part of the local history. Build outputs
are reproducible and ignored; the licensed third-party UEFI loader is tracked.

Reference: https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-new-repository
