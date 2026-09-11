cask "defguard-client-linux" do
  os linux: "linux"

  version "2.1.0-beta1,2.1.0"

  on_linux do
    arch arm: "aarch64", intel: "x86_64"

    sha256 arm64_linux:  "2766d370866380dd6e70342e0855c63705e2286f71e7848379dd3377f47dc766",
           x86_64_linux: "e6632197f7b6a33d4969f8ca45d24da2775a04102bffcd43c8e07648ec5ee54e"

    url "https://github.com/DefGuard/client/releases/download/v#{version.csv.first}/defguard-client-#{version.csv.second}-1.#{arch}.rpm"
    name "Defguard Client"
    desc "Desktop client for managing WireGuard VPN connections"
    homepage "https://defguard.net/wireguard-client/"

    livecheck do
      url "https://github.com/DefGuard/client/releases"
      regex(/^v?((\d+(?:\.\d+)+)(?:-(?:alpha|beta|rc)\d*)?)$/i)
      strategy :github_releases do |json, regex|
        json.filter_map do |release|
          next if release["draft"]

          match = release["tag_name"]&.match(regex)
          next if match.blank?

          "#{match[1]},#{match[2]}"
        end
      end
    end

    depends_on formula: "libayatana-appindicator"
    depends_on formula: "rpm2cpio"

    generated_script "defguard-service-control", content: <<~SH
      #!/bin/sh
      set -eu
      PATH=/usr/sbin:/usr/bin:/sbin:/bin
      export PATH

      root_prefix=/opt/defguard-client
      root_bin_dir="$root_prefix/bin"
      service_file=/etc/systemd/system/defguard-service.service
      bin_pattern="$root_bin_dir(/.*)?"
      selinux_mode=Disabled
      if command -v getenforce >/dev/null 2>&1; then
        selinux_mode=$(getenforce)
      fi

      case "$1" in
        install)
          staged_path=$2
          installing_user=$3
          install -d "$root_bin_dir" /etc/systemd/system
          install -Dm0755 "$staged_path/usr/sbin/defguard-service" "$root_bin_dir/defguard-service"
          install -Dm0644 "$staged_path/defguard-service.service" "$service_file"

          if ! getent group defguard >/dev/null; then
            groupadd --system defguard
          fi
          if [ -n "$installing_user" ] && getent passwd "$installing_user" >/dev/null; then
            case " $(id -nG "$installing_user") " in
              *" defguard "*) ;;
              *)
                usermod -a -G defguard "$installing_user"
                printf 'Added %s to the defguard group; log out and back in before using Defguard\n' "$installing_user"
                ;;
            esac
          fi

          if [ "$selinux_mode" != Disabled ]; then
            if command -v semanage >/dev/null 2>&1; then
              semanage fcontext -a -t bin_t "$bin_pattern" || semanage fcontext -m -t bin_t "$bin_pattern"
            elif command -v chcon >/dev/null 2>&1; then
              chcon -R -t bin_t "$root_bin_dir"
            fi
            if command -v restorecon >/dev/null 2>&1; then
              restorecon -RFv "$root_prefix"
              restorecon -Fv "$service_file"
            fi
          fi

          if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
            systemctl daemon-reload
            systemctl enable defguard-service.service
            systemctl restart defguard-service.service
          fi
          ;;
        uninstall)
          if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ] && [ -f "$service_file" ]; then
            systemctl disable --now defguard-service.service
          fi
          if [ "$selinux_mode" != Disabled ] && command -v semanage >/dev/null 2>&1; then
            if semanage fcontext -l -C 2>/dev/null | awk -v pattern="$bin_pattern" '$1 == pattern { found = 1 } END { exit !found }'; then
              semanage fcontext -d "$bin_pattern"
            fi
          fi
          rm -f "$service_file"
          rm -rf "$root_prefix"
          if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
            systemctl daemon-reload
          fi
          ;;
        *) exit 2 ;;
      esac
    SH
    binary "defguard-client-wrapper", target: "defguard-client"
    binary "usr/bin/dg"
    # Directory artifacts call Homebrew's macOS-only xattr copier during Linux reinstalls.
    %w[
      tray/blue-connected.png
      tray/blue.png
      tray/dark-connected.png
      tray/dark.png
      tray/white-connected.png
      tray/white.png
    ].each do |icon|
      artifact "usr/lib/defguard-client/resources/icons/#{icon}",
               target: "#{HOMEBREW_PREFIX}/lib/defguard-client/resources/icons/#{icon}"
    end
    artifact "usr/share/applications/defguard-client.desktop",
             target: "#{Dir.home}/.local/share/applications/defguard-client.desktop"
    artifact "usr/share/icons/hicolor/32x32/apps/defguard-client.png",
             target: "#{Dir.home}/.local/share/icons/hicolor/32x32/apps/defguard-client.png"
    artifact "usr/share/icons/hicolor/128x128/apps/defguard-client.png",
             target: "#{Dir.home}/.local/share/icons/hicolor/128x128/apps/defguard-client.png"
    artifact "usr/share/icons/hicolor/256x256@2/apps/defguard-client.png",
             target: "#{Dir.home}/.local/share/icons/hicolor/256x256@2/apps/defguard-client.png"

    preflight_steps do
      # Expand the RPM filename at install time, including Defguard's split tag/package version.
      run "/bin/sh",
          args:        ["-c", 'exec "$1" ./*.rpm', "--", "{{HOMEBREW_PREFIX}}/opt/rpm2cpio/bin/rpm2cpio"],
          chdir:       ".",
          stdout_path: "payload.cpio"
      run "/usr/bin/cpio", args: ["-idm", "--quiet"], stdin_path: "payload.cpio", chdir: "."
      remove "payload.cpio"

      mkdir_p ".local/share/applications", base: :home
      mkdir_p ".local/share/icons/hicolor/32x32/apps", base: :home
      mkdir_p ".local/share/icons/hicolor/128x128/apps", base: :home
      mkdir_p ".local/share/icons/hicolor/256x256@2/apps", base: :home
      mkdir_p "{{HOMEBREW_PREFIX}}/lib"

      inreplace "usr/share/applications/defguard-client.desktop", /^Exec=.*/,
                "Exec={{HOMEBREW_PREFIX}}/bin/defguard-client %U"
      inreplace "usr/share/applications/defguard-client.desktop", /^Name=.*/, "Name=Defguard"

      mkdir_p "appindicator-lib"
      symlink "{{HOMEBREW_PREFIX}}/opt/libayatana-appindicator/lib/libayatana-appindicator3.so.1",
              "appindicator-lib/libayatana-appindicator3.so.1", overwrite: true
      symlink "{{HOMEBREW_PREFIX}}/opt/libayatana-appindicator/lib/libayatana-appindicator3.so.1",
              "appindicator-lib/libayatana-appindicator3.so", overwrite: true

      write_file "defguard-client-wrapper", <<~EOS
        #!/bin/sh
        export LD_LIBRARY_PATH="{{staged_path}}/appindicator-lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
        exec "{{staged_path}}/usr/bin/defguard-client" "$@"
      EOS
      set_permissions "defguard-client-wrapper", "755"

      copy "lib/systemd/system/defguard-service.service", "defguard-service.service"
      inreplace "defguard-service.service",
                "ExecStart=/usr/sbin/defguard-service",
                "ExecStart=/opt/defguard-client/bin/defguard-service"
    end

    postflight_steps do
      run "defguard-service-control",
          args:         ["install", "{{staged_path}}", "{{user}}"],
          base:         :staged_path,
          sudo:         true,
          print_stdout: true
    end

    uninstall_preflight_steps do
      run "defguard-service-control", args: ["uninstall"], base: :staged_path, sudo: true
    end

    zap trash: [
      "~/.cache/net.defguard",
      "~/.config/net.defguard",
      "~/.local/share/net.defguard",
    ]

    caveats <<~EOS
      Defguard's daemon is installed to:
        /opt/defguard-client/bin/defguard-service
        /etc/systemd/system/defguard-service.service

      The cask creates the defguard group and adds the installing user to it.
      Log out and back in, or reboot, before first use so group membership is active.

      Defguard also expects the system WebKitGTK/AppIndicator stack and resolvconf
      support from your Linux distribution.
    EOS
  end

  depends_on :linux
end
