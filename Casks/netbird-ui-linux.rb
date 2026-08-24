cask "netbird-ui-linux" do
  version "0.77.0"
  sha256 "4afc692ba55e28800ea496eb7be9dad988f24597533d08be03a93188f8df9b7c"

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

  preflight do
    system "curl", "-L", "https://raw.githubusercontent.com/netbirdio/netbird/main/client/ui/assets/netbird.png",
           "-o", "#{staged_path}/netbird.png"
    FileUtils.mkdir_p "#{Dir.home}/.local/share/applications"
    File.write("#{staged_path}/netbird-ui.desktop", <<~EOS)
      [Desktop Entry]
      Name=Netbird
      Exec=#{HOMEBREW_PREFIX}/bin/netbird-ui
      Icon=netbird
      Type=Application
      Terminal=false
      Categories=Utility;
      Keywords=netbird;
    EOS
  end

  postflight do
    # Label the UI staged path
    system "noglob", "sudo", "semanage", "fcontext", "-a", "-t", "bin_t", "#{staged_path}/netbird*"
    system "sudo", "restorecon", "-RvvF", "#{staged_path}/netbird*"

    # Label the core daemon if it is installed
    core_path = "#{HOMEBREW_PREFIX}/Cellar/netbird"
    if Dir.exist?(core_path)
      system "noglob", "sudo", "semanage", "fcontext", "-a", "-t", "bin_t", "#{core_path}/.*/bin/netbird"
      system "sudo", "restorecon", "-RvvF", core_path
    end

    # Also label the common bin path for netbird symlink
    system "noglob", "sudo", "semanage", "fcontext", "-a", "-t", "bin_t", "#{HOMEBREW_PREFIX}/bin/netbird"
    system "sudo", "restorecon", "-vvF", "#{HOMEBREW_PREFIX}/bin/netbird"
  end

  # caveats "Run `sudo semanage fcontext -a -t bin_t '#{HOMEBREW_PREFIX}/Cellar/#{token}/#{version}/bin/netbird*'` and `sudo restorecon -RvvF #{HOMEBREW_PREFIX}/Cellar/#{token}/#{version}/bin/netbird*`"
end
