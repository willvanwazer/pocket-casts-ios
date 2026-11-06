# Building cloud changes on a Mac

Push code changes to a branch of `willvanwazer/pocket-casts-ios`, then run the
local builder on the Mac with that exact branch name:

```sh
pocketcasts-build codex/pocketcasts-integration
```

This is a manually invoked build command. It does not register a GitHub Actions
runner or start an automatic polling service. Only select branches whose code
and build scripts you trust: Xcode builds execute those scripts on the Mac.

## Setup

Install macOS 26.6 or newer, then Xcode 27.1 or newer. Xcode 27.2 is the current
setup target. Open Xcode to finish its first-launch setup and install the iOS and
watchOS components; the iPhone target embeds a Watch app. XcodeBuildMCP and Python
3 must be available on `PATH`.

Install the versioned script as a local command:

```sh
mkdir -p "$HOME/.local/bin"
install -m 755 scripts/local-builder.py "$HOME/.local/bin/pocketcasts-build"
pocketcasts-build --check
```

Include `$HOME/.local/bin` in your shell's `PATH` if needed. The command uses
`DEVELOPER_DIR` when provided, otherwise the Xcode selected by `xcode-select`.
For example, to select a side-by-side Xcode without changing the system default:

```sh
DEVELOPER_DIR=/Applications/Xcode-27.2.app/Contents/Developer \
  pocketcasts-build codex/my-change
```

## What a build does

1. Checks macOS, Xcode, iOS/watchOS SDKs, and XcodeBuildMCP.
2. Creates or reuses a dedicated checkout at `~/Developer/pocket-casts-ios-builder`.
3. Fetches the exact branch from the fork, resolves its commit, and checks out
   that commit with a detached HEAD. The normal development checkout is untouched.
4. Generates empty external-contributor credentials using the upstream Makefile.
5. Compiles scheme `pocketcasts`, configuration `Debug`, for an iOS device through
   XcodeBuildMCP with `CODE_SIGNING_ALLOWED=NO`.
6. Records the branch, commit, selected Xcode, result, and tool output locally in
   `~/Library/Developer/PocketCastsBuilder/runs/`. DerivedData is reused between builds.

Only one build can run at a time. The Mac stays awake while the build command
runs. A dirty or unmanaged builder checkout is refused rather than reset or
cleaned. Credentials, certificates, device IDs, and artifacts are not uploaded.

To fetch and prepare a branch before the Xcode upgrade is complete:

```sh
pocketcasts-build --prepare codex/my-change
```

`--prepare` is not a successful build. `--check` exits unsuccessfully until the
required toolchain is installed. The installer should be rerun after changes to
`scripts/local-builder.py`; the command does not update itself from a build branch.

## Phone installation

The resulting build is **unsigned** and cannot be installed on an iPhone. A signed
development variant still needs a unique bundle identifier, matching app groups
and extension identifiers, and provisioning under the developer's own Apple team.
That is a separate local build/install step after compilation succeeds.

## Build verification, November 6, 2026

The local command is installed and its isolated checkout was prepared from the
fork. Checks verified rejection of an old toolchain, invalid branch names, a
dirty checkout, and overlapping builds. Simulated tool results verified that a
tool-level error with exit code zero is still recorded as failure, and that a
successful result is recorded with its commit and logs.

After updating to macOS 26.7.2 and Xcode 27.2 and completing Xcode's first-launch
setup, the real command built `codex/pocketcasts-integration` at commit
`e5cf85793505297c8ef890f2273f936e60c7bcda` successfully in about five minutes.
The resulting iOS 27.2 SDK device app reports version 8.24 (8.24.0.1), contains
six extensions and the Watch app, and remains unsigned. The dedicated checkout
was still clean after the build. Xcode's only reported diagnostic was the
expected external-contributor credentials warning.

The build result and commit record are in
`~/Library/Developer/PocketCastsBuilder/runs/20261106T145801.898195Z-e5cf85793505/`.
This verifies branch fetching and actual compilation. Signing, phone
installation, and runtime behavior require their own checks.

A separate development variant was subsequently signed, installed, and launched
on a physical iPhone. Its local configuration uses a distinct app identity and
app group. CarPlay entitlements were excluded from that development variant
because they require separate approval from Apple. The branch builder above
continues to produce unsigned compilation artifacts; personal signing settings
remain local to the Mac.

Reference: [Apple's Xcode requirements](https://developer.apple.com/xcode/system-requirements/).
