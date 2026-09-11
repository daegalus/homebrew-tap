cask "netbird-ui-linux" do
  version "0.77.1"
  sha256 "0e2f773250e6c68d10095ca8eed8f130e53f8f999f2a4deeec29d110df3a3a1f"

  url "https://github.com/netbirdio/netbird/releases/download/v#{version}/netbird-ui-linux_#{version}_linux_amd64.tar.gz"
  name "Netbird UI for Linux"
  desc "User interface for managing Netbird on Linux"
  homepage "https://github.com/netbirdio/netbird"

  livecheck do
    url :url
    strategy :github_latest
  end

  binary "netbird-ui"
  artifact "netbird-ui.desktop", target: "#{Dir.home}/.local/share/applications/netbird-ui.desktop"
  artifact "netbird.png", target: "#{Dir.home}/.local/share/icons/netbird.png"

  preflight_steps do
    run "/usr/bin/curl",
        args:           ["--fail", "--location", "https://raw.githubusercontent.com/netbirdio/netbird/main/client/ui/assets/netbird.png"],
        stdout_path:    "netbird.png",
        network_access: true
    mkdir_p ".local/share/applications", base: :home
    write_file "netbird-ui.desktop", <<~EOS
      [Desktop Entry]
      Name=Netbird
      Exec={{HOMEBREW_PREFIX}}/bin/netbird-ui
      Icon=netbird
      Type=Application
      Terminal=false
      Categories=Utility;
      Keywords=netbird;
    EOS
  end

  postflight_steps do
    # Label the UI staged path.
    run "semanage",
        args:         ["fcontext", "-a", "-t", "bin_t", "{{staged_path}}/netbird.*"],
        sudo:         true,
        must_succeed: false
    run "restorecon", args: ["-RvvF", "{{staged_path}}"], sudo: true, must_succeed: false

    # Label the core daemon if it is installed.
    if_path_exists "{{HOMEBREW_CELLAR}}/netbird" do
      run "semanage",
          args:         ["fcontext", "-a", "-t", "bin_t", "{{HOMEBREW_CELLAR}}/netbird/.*/bin/netbird"],
          sudo:         true,
          must_succeed: false
      run "restorecon", args: ["-RvvF", "{{HOMEBREW_CELLAR}}/netbird"], sudo: true, must_succeed: false
    end

    # Also label the common bin path for the netbird symlink.
    run "semanage",
        args:         ["fcontext", "-a", "-t", "bin_t", "{{HOMEBREW_PREFIX}}/bin/netbird"],
        sudo:         true,
        must_succeed: false
    run "restorecon", args: ["-vvF", "{{HOMEBREW_PREFIX}}/bin/netbird"], sudo: true, must_succeed: false
  end

  # caveats "Run `sudo semanage fcontext -a -t bin_t '#{HOMEBREW_PREFIX}/Cellar/#{token}/#{version}/bin/netbird*'` and `sudo restorecon -RvvF #{HOMEBREW_PREFIX}/Cellar/#{token}/#{version}/bin/netbird*`"
end
