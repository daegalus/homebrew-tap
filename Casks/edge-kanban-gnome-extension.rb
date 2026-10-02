cask "edge-kanban-gnome-extension" do
  version "26S11.500"

  on_linux do
    sha256 "bfb9a29f32daf7ade705188bbce0d50fafe901608a2efaaf48f2523de614031c"
  end

  url "https://github.com/daegalus/edge-kanban/releases/download/#{version}/edge-kanban%40yulian.local.shell-extension.zip"
  name "Edge Kanban GNOME Extension"
  desc "Edge-anchored Kanban board for GNOME Shell"
  homepage "https://github.com/daegalus/edge-kanban"

  livecheck do
    url "https://github.com/daegalus/edge-kanban.git"
    # scripts/bump.py compares these tags with `earthdate compare`.
    strategy :github_latest do |json, _regex|
      json["tag_name"]
    end
  end

  depends_on :linux

  extension_uuid = "edge-kanban@yulian.local"
  extension_dir = "#{Dir.home}/.local/share/gnome-shell/extensions/#{extension_uuid}"

  artifact "extension.js", target: "#{extension_dir}/extension.js"
  artifact "kanban.js", target: "#{extension_dir}/kanban.js"
  artifact "metadata.json", target: "#{extension_dir}/metadata.json"
  artifact "prefs.js", target: "#{extension_dir}/prefs.js"
  artifact "stylesheet.css", target: "#{extension_dir}/stylesheet.css"
  artifact "schemas", target: "#{extension_dir}/schemas"

  preflight_steps do
    run "glib-compile-schemas",
        args:           ["--strict", "schemas"],
        chdir:          "{{staged_path}}",
        writable_paths: ["schemas"]
  end

  zap trash: [
    "~/.config/edge-kanban",
    "~/.local/share/gnome-shell/extensions/#{extension_uuid}",
  ]

  caveats <<~EOS
    Edge Kanban is installed to:
      #{extension_dir}

    Enable it from a terminal in your GNOME desktop session:
      gnome-extensions enable #{extension_uuid}

    If GNOME Shell does not recognize the extension, log out and back in first.
    After upgrading, log out and back in to load the updated extension.
    Before uninstalling, disable it with:
      gnome-extensions disable #{extension_uuid}
  EOS
end
