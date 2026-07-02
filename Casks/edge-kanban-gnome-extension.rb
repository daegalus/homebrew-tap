cask "edge-kanban-gnome-extension" do
  version "26U30.427"
  sha256 "ca3df7caa5943993941a5f3cbfff2b49ce7f785a4c311330b209a1ed130d52a7"

  url "https://github.com/daegalus/edge-kanban/releases/download/#{version}/edge-kanban%40yulian.local.shell-extension.zip",
      verified: "github.com/daegalus/edge-kanban/"
  name "Edge Kanban GNOME Extension"
  desc "Edge-anchored Kanban board for GNOME Shell"
  homepage "https://github.com/daegalus/edge-kanban"

  livecheck do
    url "https://github.com/daegalus/edge-kanban.git"
    strategy :github_latest do |json, _regex|
      json["tag_name"]
    end
  end

  extension_uuid = "edge-kanban@yulian.local"
  extension_dir = "#{Dir.home}/.local/share/gnome-shell/extensions/#{extension_uuid}"

  artifact "extension.js", target: "#{extension_dir}/extension.js"
  artifact "kanban.js", target: "#{extension_dir}/kanban.js"
  artifact "metadata.json", target: "#{extension_dir}/metadata.json"
  artifact "prefs.js", target: "#{extension_dir}/prefs.js"
  artifact "stylesheet.css", target: "#{extension_dir}/stylesheet.css"
  artifact "schemas", target: "#{extension_dir}/schemas"

  preflight do
    FileUtils.rm_r extension_dir if File.exist?(extension_dir)
    FileUtils.mkdir_p extension_dir
  end

  postflight do
    gnome_extensions = %w[
      /usr/bin/gnome-extensions
      /bin/gnome-extensions
    ].find { |path| File.executable?(path) }

    glib_compile_schemas = %w[
      /usr/bin/glib-compile-schemas
      /bin/glib-compile-schemas
    ].find { |path| File.executable?(path) }

    if glib_compile_schemas
      system glib_compile_schemas, "#{extension_dir}/schemas"
    else
      opoo "glib-compile-schemas was not found; schema compilation was skipped"
    end

    if gnome_extensions
      system "sh", "-c", "#{gnome_extensions} disable #{extension_uuid} >/dev/null 2>&1 || true"
      system gnome_extensions, "enable", extension_uuid
    else
      opoo "gnome-extensions was not found; enable or reload the extension manually"
    end
  end

  uninstall_preflight do
    gnome_extensions = %w[
      /usr/bin/gnome-extensions
      /bin/gnome-extensions
    ].find { |path| File.executable?(path) }

    system "sh", "-c", "#{gnome_extensions} disable #{extension_uuid} >/dev/null 2>&1 || true" if gnome_extensions
  end

  zap trash: [
    "~/.config/edge-kanban",
    "~/.local/share/gnome-shell/extensions/#{extension_uuid}",
  ]

  caveats <<~EOS
    Edge Kanban is installed to:
      #{extension_dir}

    If GNOME Shell was not running during install, enable it with:
      gnome-extensions enable #{extension_uuid}
  EOS
end
