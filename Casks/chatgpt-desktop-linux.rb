cask "chatgpt-desktop-linux" do
  os linux: "linux"

  version "26.825.51511"

  on_linux do
    arch arm: "aarch64", intel: "x86_64"

    sha256 arm64_linux:  "45f225f9cd6b3b6bbfda8c3555fcdc03d9cae0421c2323a9b7f2db61bbb7c4f9",
           x86_64_linux: "44e19ee796d788bffd741acb86a87be2f295d74fc4847132e7482bf04972c58d"

    url "https://persistent.oaistatic.com/codex-app-prod/linux/rpm/#{arch}/chatgpt-#{version}-1.#{arch}.rpm"
    name "ChatGPT Desktop for Linux"
    desc "Desktop app for ChatGPT, local files, projects, and Codex"
    homepage "https://learn.chatgpt.com/docs/linux/linux-app"

    livecheck do
      skip "The RPM repository only exposes versions in rotating compressed metadata"
    end

    depends_on cask: "codex"
    depends_on formula: "rpm2cpio"

    binary "usr/lib/chatgpt/codex-launcher", target: "chatgpt"
    artifact "usr/share/applications/chatgpt.desktop",
             target: "#{Dir.home}/.local/share/applications/chatgpt.desktop"
    artifact "usr/share/pixmaps/chatgpt.png",
             target: "#{Dir.home}/.local/share/icons/chatgpt.png"

    preflight_steps do
      # Expand the RPM filename at install time, without hard-coding the architecture or version.
      run "/bin/sh",
          args:        ["-c", 'exec "$1" ./*.rpm', "--", "{{HOMEBREW_PREFIX}}/opt/rpm2cpio/bin/rpm2cpio"],
          chdir:       ".",
          stdout_path: "payload.cpio"
      run "/usr/bin/cpio", args: ["-idm", "--quiet"], stdin_path: "payload.cpio", chdir: "."
      remove "payload.cpio"

      # The app supports CODEX_CLI_PATH, so use the Homebrew cask dependency instead
      # of retaining the large Codex executable bundled in the upstream RPM.
      remove "usr/lib/chatgpt/resources/codex"

      mkdir_p ".local/share/applications", base: :home
      mkdir_p ".local/share/icons", base: :home

      write_file "usr/lib/chatgpt/codex-launcher", <<~SH
        #!/bin/sh
        export PATH="{{HOMEBREW_PREFIX}}/bin:{{HOMEBREW_PREFIX}}/sbin:$PATH"
        export CODEX_CLI_PATH="{{HOMEBREW_PREFIX}}/bin/codex"

        ozone_platform_set=false
        for argument in "$@"; do
          case "$argument" in
            --ozone-platform|--ozone-platform=*)
              ozone_platform_set=true
              break
              ;;
          esac
        done

        if [ "$ozone_platform_set" = false ]; then
          set -- --ozone-platform=wayland "$@"
        fi

        exec "$(dirname "$(readlink -f "$0")")/ChatGPT" "$@"
      SH
      set_permissions "usr/lib/chatgpt/codex-launcher", "755"

      inreplace "usr/share/applications/chatgpt.desktop", /^Exec=.*/, "Exec={{HOMEBREW_PREFIX}}/bin/chatgpt %U"
      # Resolve the installed icon directory at runtime; GNOME needs an absolute icon path.
      run "/bin/sh",
          args:        [
            "-c",
            'exec awk -v icon="$PWD/chatgpt.png" \'/^Icon=/ {$0 = "Icon=" icon} {print}\' "$1"',
            "--",
            "{{staged_path}}/usr/share/applications/chatgpt.desktop",
          ],
          chdir:       "~/.local/share/icons",
          stdout_path: "usr/share/applications/chatgpt.desktop"
    end

    postflight_steps do
      run "/bin/sh",
          args:           [
            "-c",
            "if command -v update-desktop-database >/dev/null 2>&1; then update-desktop-database .; fi",
          ],
          chdir:          "~/.local/share/applications",
          writable_paths: [".local/share/applications"],
          writable_base:  :home,
          must_succeed:   false
    end

    zap trash: "~/.config/Codex"

    caveats <<~EOS
      This cask removes the Codex executable bundled in OpenAI's RPM and uses:
        #{HOMEBREW_PREFIX}/bin/codex
      Keep it current with `brew upgrade --cask codex`.

      ChatGPT Desktop and Codex CLI share:
        ~/.codex/config.toml

      Native Wayland is enabled by default. It is still experimental upstream.
      To use XWayland for a launch instead, run:
        chatgpt --ozone-platform=x11

      OpenAI's Remote host feature currently supports only macOS and Windows.
      This Linux app cannot be paired as a host for Remote Control.
    EOS
  end

  depends_on :linux
end
