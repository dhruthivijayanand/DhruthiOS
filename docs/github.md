# GitHub setup and ongoing workflow

As of 2026-09-17, the user requested a GitHub repository and ongoing milestone
uploads alongside development. The connected account is dhruthivijayanand.

The user supplied https://github.com/dhruthivijayanand/DhruthiOS.git after creating
the repository. It is now configured locally as origin. Initial upload is still
pending. The connector's lookup returns 404, which does not distinguish absence
from inaccessible private content; visibility and remote contents are unverified.

Setup limitation: available GitHub connector tools can manage existing content
but do not expose repository creation. GitHub CLI was not found in PATH or the
checked standard install locations. Local Git Credential Manager account lookup
failed with a wincredman credential-store error. Authentication for shell pushes
has not been established.

Network permission was granted for a shell connection attempt. The default TLS
backend failed with SEC_E_NO_CREDENTIALS. A command-scoped OpenSSL backend passed
that layer, but Git Credential Manager still could not access its Windows
credential store. No certificate verification was disabled and no persistent
TLS or credential settings were changed.

Next action: in the user's own PowerShell window, from this repository, run
`git push -u origin main` and complete GitHub sign-in if prompted. This ordinary
push does not force-overwrite remote history. Stop and inspect any rejection.
After success, verify the remote commit against local HEAD. The connector may
also require access to this newly created private repository for later uploads.

For each subsequent milestone during active sessions:
1. Make and explain a bounded implementation change.
2. Run the appropriate build and QEMU checks.
3. Update actual feature status, test evidence, and limitations.
4. Commit with a meaningful message.
5. Upload to the verified remote and check its resulting commit.

The verified boot commit e9b567c remains part of the local history. Build outputs
are reproducible and ignored; the licensed third-party UEFI loader is tracked.

Reference: https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-new-repository
