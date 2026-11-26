cask "juggler-linux" do
  version "0.8.3"

  on_linux do
    arch arm: "arm64", intel: "amd64"

    sha256 arm64_linux:  "400ddcc7b8fd4cdb1441be500d5b1f91b287a8cef098899a72e1be44444f9333",
           x86_64_linux: "49546ff1669b9b98c17d5caf1e2a89ac0a5e47b2482057d9b781558d6c3e386e"
  end

  url "https://github.com/juggler-ai/juggler/releases/download/v#{version}/juggler-linux-#{arch}.tar.gz"
  name "Juggler"
  desc "Visual workbench for AI coding agents"
  homepage "https://juggler.studio/"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on :linux

  binary "juggler"
  binary "juggler-app"
  artifact "juggler.desktop", target: "#{Dir.home}/.local/share/applications/juggler.desktop"
  artifact "juggler.png", target: "#{Dir.home}/.local/share/icons/juggler.png"

  preflight_steps do
    run "/usr/bin/curl",
        args:           ["--fail", "--location", "https://raw.githubusercontent.com/juggler-ai/juggler/v{{version}}/assets/icons/juggler-icon.png"],
        stdout_path:    "juggler.png",
        network_access: true
    mkdir_p ".local/share/applications", base: :home
    mkdir_p ".local/share/icons", base: :home
    write_file "juggler.desktop", <<~EOS
      [Desktop Entry]
      Name=Juggler
      Comment=Visual workbench for AI coding agents
      Exec={{HOMEBREW_PREFIX}}/bin/juggler-app
      Icon=juggler
      Type=Application
      Terminal=false
      Categories=Development;
    EOS
  end

  zap trash: [
    "~/.cache/juggler",
    "~/.config/juggler",
    "~/.juggler",
    "~/.local/state/juggler",
  ]

  caveats <<~EOS
    Juggler requires your distribution's GTK4 and WebKitGTK 6.0 libraries.
    Launch the desktop app with `juggler-app`; `juggler` runs the server.
    The server also needs a display, so headless hosts need Xvfb.
  EOS
end
