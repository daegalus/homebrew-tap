cask "delta-linux" do
  version "0.18.1"

  on_linux do
    arch arm: "aarch64", intel: "x86_64"

    sha256 arm64_linux:  "7d0c5d9781a5adb0abed6f950b538894880886c36228e0a1a8364e94bde02cd0",
           x86_64_linux: "4e4df21e989e8137cfb42402acbb26c574de21a0f7616d3116ebfa48d75ca718"
  end

  url "https://github.com/zed-industries/delta-nix/releases/download/v#{version}/delta-linux-#{arch}.tar.gz"
  name "Delta"
  desc "Collaborative workspace for coding with agents"
  homepage "https://delta.dev/"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on :linux

  binary "delta-launcher", target: "delta"
  artifact "Delta/share/applications/dev.zed.Delta.desktop",
           target: "#{Dir.home}/.local/share/applications/dev.zed.Delta.desktop"
  artifact "Delta/share/icons/hicolor/512x512/apps/dev.zed.Delta.png",
           target: "#{Dir.home}/.local/share/icons/dev.zed.Delta.png"

  preflight_steps do
    mkdir_p ".local/share/applications", base: :home
    mkdir_p ".local/share/icons", base: :home
    symlink ".local/share/applications", "applications", source_base: :home

    write_file "delta-launcher", <<~SH
      #!/bin/sh
      export DELTA_UPDATE_EXPLANATION="Delta is managed by Homebrew; run brew upgrade --cask daegalus/tap/delta-linux to update."
      exec "{{staged_path}}/Delta/bin/delta" "$@"
    SH
    set_permissions "delta-launcher", "755"

    inreplace "Delta/share/applications/dev.zed.Delta.desktop", "Exec=delta ",
              "Exec={{HOMEBREW_PREFIX}}/bin/delta "
  end

  postflight_steps do
    if_path_exists "/usr/bin/update-desktop-database" do
      run "/usr/bin/update-desktop-database",
          args:           ["{{staged_path}}/applications"],
          writable_paths: [".local/share/applications"],
          writable_base:  :home
    end
  end

  uninstall_postflight_steps do
    if_path_exists "/usr/bin/update-desktop-database" do
      run "/usr/bin/update-desktop-database",
          args:           ["{{staged_path}}/applications"],
          writable_paths: [".local/share/applications"],
          writable_base:  :home
    end
  end

  zap trash: [
    "~/.cache/delta",
    "~/.config/delta",
    "~/.local/share/delta",
  ]
end
