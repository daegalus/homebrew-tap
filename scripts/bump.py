#!/usr/bin/env python3
"""Bump tap casks, using Earthdate to order Earthdate release tags."""

import argparse
import json
from pathlib import Path
import subprocess
import sys


EARTHDATE_CASKS = {"edge-kanban-gnome-extension"}


def bump_earthdate(cask, earthdate, *, open_pr=False, no_fork=False):
    try:
        records = json.loads(subprocess.check_output(
            ["brew", "livecheck", "--cask", "--json", "--full-name", cask], text=True,
        ))
    except subprocess.CalledProcessError as error:
        raise RuntimeError(f"Livecheck failed for {cask}: {error.output.strip()}") from error
    if len(records) != 1 or "version" not in records[0]:
        raise RuntimeError(f"Livecheck failed for {cask}: {records}")

    current = records[0]["version"]["current"]
    latest = records[0]["version"]["latest"]
    # Homebrew's outdated/newer_than_upstream flags use the wrong month order.
    comparison = subprocess.check_output(
        [earthdate, "compare", current, latest], text=True,
    ).strip()
    if comparison not in {"-1", "0", "1"}:
        raise RuntimeError(f"Unexpected Earthdate comparison: {comparison!r}")

    print(f"{cask}: {current} -> {latest}", flush=True)
    if comparison == "0":
        print("Already up to date.", flush=True)
        return
    if comparison == "1":
        print("The cask is newer than upstream; skipping.", flush=True)
        return
    if not open_pr:
        print("Update available; use --open-pr to create the bump PR.", flush=True)
        return

    owner, tap, token = cask.split("/")
    repository = f"{owner}/{tap if tap.startswith('homebrew-') else 'homebrew-' + tap}"
    pull_requests = json.loads(subprocess.check_output([
        "gh", "pr", "list", "--repo", repository, "--state", "all",
        "--search", f"{token} in:title", "--limit", "100", "--json", "title,url,state",
    ], text=True))
    for pr in pull_requests:
        title = pr["title"]
        if title == f"{token} {latest}" or (
            pr["state"] == "OPEN" and title.startswith((f"{token} ", f"{token}:"))
        ):
            print(f"Existing bump PR: {pr['url']}; skipping.", flush=True)
            return

    command = ["brew", "bump-cask-pr", cask, f"--version={latest}", "--no-browse"]
    if no_fork:
        command.append("--no-fork")
    subprocess.run(command, check=True)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tap", default="daegalus/tap")
    parser.add_argument("--earthdate", default="earthdate", help="Earthdate executable")
    parser.add_argument("--open-pr", action="store_true")
    parser.add_argument("--no-fork", action="store_true")
    args = parser.parse_args(argv)

    casks = sorted(path.stem for path in (Path(__file__).resolve().parents[1] / "Casks").glob("*.rb"))
    for token in casks:
        if token in EARTHDATE_CASKS:
            bump_earthdate(
                f"{args.tap}/{token}", args.earthdate,
                open_pr=args.open_pr, no_fork=args.no_fork,
            )

    standard_casks = [f"{args.tap}/{token}" for token in casks if token not in EARTHDATE_CASKS]
    if standard_casks:
        command = ["brew", "bump", "--cask", *standard_casks]
        if args.open_pr:
            command.append("--open-pr")
        else:
            command.append("--no-pull-requests")
        if args.no_fork:
            command.append("--no-fork")
        subprocess.run(command, check=True)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, RuntimeError, subprocess.CalledProcessError) as error:
        print(f"Bump failed: {error}", file=sys.stderr)
        sys.exit(1)
