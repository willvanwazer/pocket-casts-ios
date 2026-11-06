#!/usr/bin/env python3
"""Fetch an explicitly selected fork branch and compile it on this Mac."""

import argparse
import datetime
import fcntl
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import sys


REPOSITORY = "https://github.com/willvanwazer/pocket-casts-ios.git"
CHECKOUT = Path.home() / "Developer/pocket-casts-ios-builder"
STATE = Path.home() / "Library/Developer/PocketCastsBuilder"
MIN_MACOS = (26, 6)
MIN_XCODE = (27, 1)


def run(*args, cwd=None, capture=False):
    result = subprocess.run(
        args, cwd=cwd, text=True, check=True,
        stdout=subprocess.PIPE if capture else None,
    )
    return result.stdout.strip() if capture else None


def version(value):
    return tuple(int(part) for part in value.split(".")[:2])


def preflight():
    problems = []
    macos = run("/usr/bin/sw_vers", "-productVersion", capture=True)
    print(f"macOS: {macos}", flush=True)
    if version(macos) < MIN_MACOS:
        problems.append("Install macOS 26.6 or newer and restart before updating Xcode.")

    selected = os.environ.get("DEVELOPER_DIR") or run("/usr/bin/xcode-select", "-p", capture=True)
    developer = Path(selected)
    if developer.suffix == ".app":
        developer = developer / "Contents/Developer"
    info = developer.parent / "Info.plist"
    if not info.exists():
        problems.append("Select a full Xcode installation using DEVELOPER_DIR.")
    else:
        with info.open("rb") as handle:
            xcode = plistlib.load(handle)["CFBundleShortVersionString"]
        print(f"Xcode: {xcode} ({developer})", flush=True)
        if version(xcode) < MIN_XCODE:
            problems.append("Install Xcode 27.1 or newer; Xcode 27.2 is the current setup target.")
        for platform in ("iPhoneOS", "WatchOS"):
            sdk = developer / f"Platforms/{platform}.platform/Developer/SDKs/{platform}.sdk"
            if not sdk.exists():
                problems.append(f"Install {platform} platform support in Xcode Settings > Components.")
    if not shutil.which("xcodebuildmcp"):
        problems.append("Install XcodeBuildMCP and make xcodebuildmcp available on PATH.")
    if problems:
        for problem in problems:
            print(f"Required: {problem}", file=sys.stderr)
        return None
    return developer


def prepare(branch):
    marker = CHECKOUT / ".git/pocketcasts-builder-owner"
    if not CHECKOUT.exists():
        CHECKOUT.parent.mkdir(parents=True, exist_ok=True)
        run("git", "clone", "--single-branch", "--branch", "trunk",
            "--filter=blob:none", REPOSITORY, str(CHECKOUT))
        marker.write_text(REPOSITORY + "\n")
    if not marker.exists() or marker.read_text().strip() != REPOSITORY:
        raise RuntimeError(f"Refusing to modify an unmanaged checkout: {CHECKOUT}")
    if run("git", "remote", "get-url", "origin", cwd=CHECKOUT, capture=True) != REPOSITORY:
        raise RuntimeError("Builder checkout's origin does not match the configured fork.")
    if run("git", "status", "--porcelain", "--untracked-files=normal", cwd=CHECKOUT, capture=True):
        raise RuntimeError(f"Builder checkout has local changes; preserve or remove them manually: {CHECKOUT}")

    run("git", "fetch", "--no-tags", "origin", f"refs/heads/{branch}", cwd=CHECKOUT)
    commit = run("git", "rev-parse", "FETCH_HEAD^{commit}", cwd=CHECKOUT, capture=True)
    run("git", "checkout", "--detach", commit, cwd=CHECKOUT)
    template = CHECKOUT / "podcasts/Credentials/ApiCredentials.tpl"
    credentials = CHECKOUT / "podcasts/Credentials/LocalApiCredentials.swift"
    expected = re.sub(r"%\{.*\}", "", template.read_text())
    if not credentials.exists():
        run("make", "external_contributor", cwd=CHECKOUT)
    if credentials.read_text() != expected:
        raise RuntimeError("The builder only accepts empty external-contributor credentials.")
    print(f"Prepared {branch} at {commit}\nCheckout: {CHECKOUT}", flush=True)
    return commit


def build(branch, commit, developer):
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%S.%fZ")
    output = STATE / "runs" / f"{stamp}-{commit[:12]}"
    output.mkdir(parents=True)
    log = output / "build.json"
    arguments = {
        "projectPath": str(CHECKOUT / "podcasts.xcodeproj"),
        "scheme": "pocketcasts",
        "configuration": "Debug",
        "derivedDataPath": str(STATE / "DerivedData"),
        "platform": "iOS",
        "extraArgs": ["CODE_SIGNING_ALLOWED=NO"],
        "preferXcodebuild": True,
    }
    command = ["xcodebuildmcp", "device", "build", "--json", json.dumps(arguments), "--output", "json"]
    if Path("/usr/bin/caffeinate").exists():
        command = ["/usr/bin/caffeinate", "-i", *command]
    environment = dict(os.environ, DEVELOPER_DIR=str(developer))
    print(f"Building an unsigned iPhone app. Output: {log}", flush=True)
    with log.open("w") as handle:
        result = subprocess.run(command, cwd=CHECKOUT, env=environment, stdout=handle, stderr=subprocess.STDOUT)
    raw = log.read_text()
    print(raw)
    succeeded = result.returncode == 0
    try:
        report = json.loads(raw)
        # A process exit code alone must not turn a tool-level failure into success.
        succeeded = succeeded and report.get("didError") is False
    except (ValueError, AttributeError):
        succeeded = False
    (output / "summary.json").write_text(json.dumps({
        "repository": REPOSITORY, "branch": branch, "commit": commit,
        "developerDirectory": str(developer), "succeeded": succeeded,
        "processExitCode": result.returncode, "buildOutput": str(log),
        "signed": False,
    }, indent=2) + "\n")
    if not succeeded:
        raise RuntimeError(f"Build failed or returned an unrecognized result; inspect {log}")
    print(f"Build succeeded at {commit}. This unsigned app is not installable on a phone.\nRun details: {output}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("branch", nargs="?", help="Exact branch name in willvanwazer/pocket-casts-ios")
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument("--check", action="store_true", help="Check this Mac's toolchain without fetching or building")
    modes.add_argument("--prepare", action="store_true", help="Fetch and prepare the branch without requiring the new Xcode yet")
    args = parser.parse_args()
    if args.check:
        if args.branch:
            parser.error("--check does not take a branch")
        return 0 if preflight() else 1
    if not args.branch:
        parser.error("Specify the branch to build, or use --check")
    run("git", "check-ref-format", "--branch", args.branch, capture=True)
    developer = None if args.prepare else preflight()
    if not args.prepare and developer is None:
        return 1

    STATE.mkdir(parents=True, exist_ok=True, mode=0o700)
    with (STATE / "build.lock").open("w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as error:
            raise RuntimeError("Another pocketcasts-build command is already running.") from error
        commit = prepare(args.branch)
        if not args.prepare:
            build(args.branch, commit, developer)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (RuntimeError, OSError, subprocess.CalledProcessError) as error:
        print(f"pocketcasts-build: {error}", file=sys.stderr)
        sys.exit(1)
