# typed: strict
# frozen_string_literal: true

require "cask"
require "dev-cmd/bump-cask-pr"

# This standalone tap test needs the same AST gems as bump-cask-pr.
Utils::GemSetup.install_bundler_gems!(groups: ["ast"]) # rubocop:disable Homebrew/InstallBundlerGems
require "utils/ast"

%w[netbird-ui-linux edge-kanban-gnome-extension].each do |token|
  cask = Cask::CaskLoader.load("#{ENV.fetch("GITHUB_REPOSITORY", "daegalus/tap")}/#{token}")
  next_version = "#{cask.version}.test"
  command = Homebrew::DevCmd::BumpCaskPr.new([
    "--write-only", "--no-audit", "--no-style", "--version=#{next_version}", cask.full_name
  ])
  source_path = cask.sourcefile_path
  raise "Missing source path for #{token}" unless source_path

  # Reuse the checksum to test the real rewrite without fetching a release.
  rewritten = command.replace_version_and_checksum(
    cask, cask.sha256.to_s,
    Homebrew::BumpVersionParser.new(general: next_version), source_path.read
  )
  result = Cask::CaskLoader::FromContentLoader.new(rewritten).load(config: nil)
  raise "#{token}: version rewrite was skipped" if result.version.to_s != next_version
  raise "#{token}: checksum changed unexpectedly" if result.sha256 != cask.sha256
  raise "#{token}: download URL did not follow the version" unless result.url.to_s.include?(next_version)

  puts "#{token}: Linux cask version rewrite passed"
end
