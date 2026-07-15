cask "netbird-ui-linux" do
  version "0.74.6"
  sha256 "bb667d0f80f3ee2fb92617f2c743827cc1b515243b8dcaaf66f4f68fdd9aa8d0"

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
    # if Dir.home[/^\/var.*$/]
    # system "noglob", "sudo", "semanage", "fcontext", "-a", "-t", "bin_t", "#{staged_path}/netbird*"
    system "noglob", "sudo", "semanage", "fcontext", "-a", "-t", "bin_t", "#{staged_path}/netbird*"
    system "sudo", "restorecon", "-RvvF", "#{staged_path}/netbird*"
  end

  # caveats "Run `sudo semanage fcontext -a -t bin_t '#{HOMEBREW_PREFIX}/Cellar/#{token}/#{version}/bin/netbird*'` and `sudo restorecon -RvvF #{HOMEBREW_PREFIX}/Cellar/#{token}/#{version}/bin/netbird*`"
end
