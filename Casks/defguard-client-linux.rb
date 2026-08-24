cask "defguard-client-linux" do
  os linux: "linux"

  version "2.1.0-beta1,2.1.0"

  on_linux do
    arch arm: "aarch64", intel: "x86_64"

    sha256 arm64_linux:  "2766d370866380dd6e70342e0855c63705e2286f71e7848379dd3377f47dc766",
           x86_64_linux: "e6632197f7b6a33d4969f8ca45d24da2775a04102bffcd43c8e07648ec5ee54e"

    url "https://github.com/DefGuard/client/releases/download/v#{version.csv.first}/defguard-client-#{version.csv.second}-1.#{arch}.rpm",
        verified: "github.com/DefGuard/client/"
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

    preflight do
      rpm_path = "#{staged_path}/defguard-client-#{version.csv.second}-1.#{arch}.rpm"
      system "sh", "-c", "rpm2cpio '#{rpm_path}' | cpio -idm --quiet", chdir: staged_path

      FileUtils.mkdir_p "#{Dir.home}/.local/share/applications"
      FileUtils.mkdir_p "#{Dir.home}/.local/share/icons/hicolor/32x32/apps"
      FileUtils.mkdir_p "#{Dir.home}/.local/share/icons/hicolor/128x128/apps"
      FileUtils.mkdir_p "#{Dir.home}/.local/share/icons/hicolor/256x256@2/apps"
      FileUtils.mkdir_p "#{HOMEBREW_PREFIX}/lib"

      desktop_file = "#{staged_path}/usr/share/applications/defguard-client.desktop"
      desktop_content = File.read(desktop_file)
      desktop_content.gsub!(/^Exec=.*/, "Exec=#{HOMEBREW_PREFIX}/bin/defguard-client %U")
      desktop_content.gsub!(/^Name=.*/, "Name=Defguard")
      File.write(desktop_file, desktop_content)

      appindicator_lib = "#{HOMEBREW_PREFIX}/opt/libayatana-appindicator/lib/libayatana-appindicator3.so.1"
      appindicator_lib_dir = "#{staged_path}/appindicator-lib"
      FileUtils.mkdir_p appindicator_lib_dir
      FileUtils.ln_sf appindicator_lib, "#{appindicator_lib_dir}/libayatana-appindicator3.so.1"
      FileUtils.ln_sf appindicator_lib, "#{appindicator_lib_dir}/libayatana-appindicator3.so"

      File.write("#{staged_path}/defguard-client-wrapper", <<~EOS)
        #!/bin/sh
        export LD_LIBRARY_PATH="#{appindicator_lib_dir}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
        exec "#{staged_path}/usr/bin/defguard-client" "$@"
      EOS
      set_permissions("#{staged_path}/defguard-client-wrapper", "755")
    end

    postflight do
      group_name = "defguard"
      root_prefix = "/opt/defguard-client"
      root_bin_dir = "#{root_prefix}/bin"
      systemd_dir = "/etc/systemd/system"

      getenforce = %w[/usr/sbin/getenforce /usr/bin/getenforce /bin/getenforce].find do |path|
        File.executable?(path)
      end
      restorecon = %w[/usr/sbin/restorecon /usr/bin/restorecon /bin/restorecon].find do |path|
        File.executable?(path)
      end
      semanage = %w[/usr/sbin/semanage /usr/bin/semanage /bin/semanage].find do |path|
        File.executable?(path)
      end
      chcon = %w[/usr/sbin/chcon /usr/bin/chcon /bin/chcon].find do |path|
        File.executable?(path)
      end
      systemctl = %w[/usr/bin/systemctl /bin/systemctl].find do |path|
        File.executable?(path)
      end

      ohai "Installing Defguard service payload under #{root_prefix}"

      system "sudo", "install", "-d", root_bin_dir, systemd_dir
      system "sudo", "install", "-Dm0755",
             "#{staged_path}/usr/sbin/defguard-service",
             "#{root_bin_dir}/defguard-service"

      service_file = File.read("#{staged_path}/lib/systemd/system/defguard-service.service")
      service_file.gsub!("ExecStart=/usr/sbin/defguard-service", "ExecStart=#{root_bin_dir}/defguard-service")
      File.write("#{staged_path}/defguard-service.service", service_file)
      system "sudo", "install", "-Dm0644",
             "#{staged_path}/defguard-service.service",
             "#{systemd_dir}/defguard-service.service"

      group_exists = !IO.popen(["getent", "group", group_name], &:read).strip.empty?
      system "sudo", "groupadd", "--system", group_name unless group_exists

      installing_user = ENV.fetch("SUDO_USER", nil)
      installing_user = ENV.fetch("USER", nil) if installing_user.to_s.empty? || installing_user == "root"
      if installing_user.present? && IO.popen(["getent", "passwd", installing_user], &:read).present?
        user_groups = IO.popen(["id", "-nG", installing_user], &:read).split
        unless user_groups.include?(group_name)
          system "sudo", "usermod", "-a", "-G", group_name, installing_user
          ohai "Added #{installing_user} to the #{group_name} group; log out and back in before using Defguard"
        end
      end

      selinux_mode = if getenforce
        IO.popen([getenforce], &:read).strip
      else
        "Disabled"
      end

      if selinux_mode != "Disabled"
        bin_pattern = "#{root_bin_dir}(/.*)?"

        if semanage
          local_fcontexts = IO.popen([semanage, "fcontext", "-l", "-C"], err: File::NULL, &:read)
          fcontext_defined = local_fcontexts.lines.any? do |line|
            line.split(/\s+/, 2).first == bin_pattern
          end

          if fcontext_defined
            system "sudo", semanage, "fcontext", "-m", "-t", "bin_t", bin_pattern
          else
            added = system "sudo", semanage, "fcontext", "-a", "-t", "bin_t", bin_pattern
            system "sudo", semanage, "fcontext", "-m", "-t", "bin_t", bin_pattern unless added
          end
        elsif chcon
          system "sudo", chcon, "-R", "-t", "bin_t", root_bin_dir
        end

        if restorecon
          system "sudo", restorecon, "-RFv", root_prefix
          system "sudo", restorecon, "-Fv", "#{systemd_dir}/defguard-service.service"
        end
      end

      if systemctl && Dir.exist?("/run/systemd/system")
        system "sudo", systemctl, "daemon-reload"
        system "sudo", systemctl, "enable", "defguard-service.service"
        system "sudo", systemctl, "restart", "defguard-service.service"
      end
    end

    uninstall_preflight do
      root_prefix = "/opt/defguard-client"
      root_bin_dir = "#{root_prefix}/bin"
      systemd_dir = "/etc/systemd/system"
      service_file = "#{systemd_dir}/defguard-service.service"

      getenforce = %w[/usr/sbin/getenforce /usr/bin/getenforce /bin/getenforce].find do |path|
        File.executable?(path)
      end
      semanage = %w[/usr/sbin/semanage /usr/bin/semanage /bin/semanage].find do |path|
        File.executable?(path)
      end
      systemctl = %w[/usr/bin/systemctl /bin/systemctl].find do |path|
        File.executable?(path)
      end

      if systemctl && Dir.exist?("/run/systemd/system") && File.exist?(service_file)
        system "sudo", systemctl, "disable", "--now", "defguard-service.service"
      end

      selinux_mode = if getenforce
        IO.popen([getenforce], &:read).strip
      else
        "Disabled"
      end

      if selinux_mode != "Disabled" && semanage
        bin_pattern = "#{root_bin_dir}(/.*)?"
        local_fcontexts = IO.popen([semanage, "fcontext", "-l", "-C"], err: File::NULL, &:read)
        fcontext_defined = local_fcontexts.lines.any? do |line|
          line.split(/\s+/, 2).first == bin_pattern
        end
        system "sudo", semanage, "fcontext", "-d", bin_pattern if fcontext_defined
      end

      system "sudo", "rm", "-f", service_file
      system "sudo", "rm", "-rf", root_prefix
      system "sudo", systemctl, "daemon-reload" if systemctl && Dir.exist?("/run/systemd/system")
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
end
