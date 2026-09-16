# Daegalus Tap

## How do I install these formulae?

`brew install daegalus/tap/<formula>`

Or `brew tap daegalus/tap` and then `brew install <formula>`.

Or, in a `brew bundle` `Brewfile`:

```ruby
tap "daegalus/tap"
brew "<formula>"
```

## Documentation

`brew help`, `man brew` or check [Homebrew's documentation](https://docs.brew.sh).

## Updating casks

The scheduled workflow uses `scripts/bump.py`. It gets Edge Kanban's release
tag from livecheck, compares it with `earthdate compare` and passes newer
tags unchanged to `brew bump-cask-pr`. Other casks use `brew bump`.

Install [Earthdate](https://github.com/daegalus/earthdate) with comparison
support, then check for updates without opening PRs:

```sh
cargo install --git https://github.com/daegalus/earthdate --branch master --locked
python3 scripts/bump.py
```

Add `--open-pr --no-fork` to open update PRs. Existing bump PRs are skipped.
The workflow needs the Earthdate comparison changes on `master` first.
Plain `brew livecheck` still uses Homebrew's version ordering, so use the
updater's result for Earthdate tags.

Run the updater regression tests with:

```sh
python3 -m unittest discover -s tests -v
brew ruby tests/cask_bump.rb
```
