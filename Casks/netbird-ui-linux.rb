cask "netbird-ui-linux" do
  version "0.58.0"
  sha256 "aee409a1f8cae6db5051e6867644e42368f1d14970a363f2af7c5e901a0bea00"

  url "https://github.com/netbirdio/netbird/releases/download/v#{version}/netbird-ui-linux_#{version}_linux_amd64.tar.gz"
  name "Netbird UI for Linux"
  desc "User interface for managing Netbird on Linux"
  homepage "https://github.com/netbirdio/netbird"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates true

  binary "netbird-ui"
  artifact "netbird-ui.desktop", target: "#{Dir.home}/.local/share/applications/netbird-ui.desktop"
  artifact "netbird.png", target: "#{HOMEBREW_PREFIX}/share/icons/hicolor/256x256/apps/netbird.png"
  artifact "netbird.png", target: "#{Dir.home}/.local/share/icons/netbird.png"

  preflight do
    system "curl", "-L", "https://raw.githubusercontent.com/netbirdio/netbird/main/client/ui/assets/netbird.png", "-o", "#{staged_path}/netbird.png"
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

  caveats "Run `sudo semanage fcontext -a -t bin_t '#{HOMEBREW_PREFIX}/Cellar/#{token}/#{version}/bin/netbird*'` and `sudo restorecon -RvvF #{HOMEBREW_PREFIX}/Cellar/#{token}/#{version}/bin/netbird*`"
end
