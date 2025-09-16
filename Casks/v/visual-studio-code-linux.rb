cask "visual-studio-code-linux" do
  arch arm: "arm64", intel: "x64"
  os linux: "linux"

    version "1.104.0"
    sha256 arm64_linux:  "92d29b2206c5d5e979c4707e012dee3f7a37e47d9d221509e0d1cd0a8421237b",
           x86_64_linux: "0019db2e217c00a0a5b068e11dbff22b88c3dd3b7ccbf35d6f189c4a4a7e1dbb"

    livecheck do
      url "https://update.code.visualstudio.com/api/update/#{os}-#{arch}/stable/latest"
      strategy :json do |json|
        json["productVersion"]
      end
    end

  url "https://update.code.visualstudio.com/#{version}/#{os}-#{arch}/stable"
  name "Microsoft Visual Studio Code"
  name "VS Code"
  desc "Open-source code editor"
  homepage "https://code.visualstudio.com/"

  auto_updates true

  binary "#{staged_path}/VSCode-linux-#{arch}/bin/code"
  binary "#{staged_path}/VSCode-linux-#{arch}/bin/code-tunnel"
  artifact "#{staged_path}/VSCode-linux-#{arch}/code.desktop", target: "#{ENV["HOME"]}/.local/share/applications/code.desktop"
  artifact "#{staged_path}/VSCode-linux-#{arch}/code-url-handler.desktop", target: "#{ENV["HOME"]}/.local/share/applications/code-url-handler.desktop"

  preflight do
    FileUtils.mkdir_p "#{ENV["HOME"]}/.local/share/applications"
    File.write("#{staged_path}/VSCode-linux-#{arch}/code.desktop", <<~EOS)
      [Desktop Entry]
      Name=Visual Studio Code
      Comment=Code Editing. Redefined.
      GenericName=Text Editor
      Exec=#{HOMEBREW_PREFIX}/bin/code %F
      Icon=vscode
      Type=Application
      StartupNotify=false
      StartupWMClass=Code
      Categories=TextEditor;Development;IDE;
      MimeType=application/x-code-workspace;
      Actions=new-empty-window;
      Keywords=vscode;

      [Desktop Action new-empty-window]
      Name=New Empty Window
      Name[cs]=Nové prázdné okno
      Name[de]=Neues leeres Fenster
      Name[es]=Nueva ventana vacía
      Name[fr]=Nouvelle fenêtre vide
      Name[it]=Nuova finestra vuota
      Name[ja]=新しい空のウィンドウ
      Name[ko]=새 빈 창
      Name[ru]=Новое пустое окно
      Name[zh_CN]=新建空窗口
      Name[zh_TW]=開新空視窗
      Exec=#{HOMEBREW_PREFIX}/bin/code --new-window %F
      Icon=vscode
    EOS
    File.write("#{staged_path}/VSCode-linux-#{arch}/code-url-handler.desktop", <<~EOS)
      [Desktop Entry]
      Name=Visual Studio Code - URL Handler
      Comment=Code Editing. Redefined.
      GenericName=Text Editor
      Exec=#{HOMEBREW_PREFIX}/bin/code --open-url %U
      Icon=vscode
      Type=Application
      NoDisplay=true
      StartupNotify=true
      Categories=Utility;TextEditor;Development;IDE;
      MimeType=x-scheme-handler/vscode;
      Keywords=vscode;
    EOS
  end


  # zap trash: [
  #   "#{ENV["HOME"]}/.config/Code",
  #   "#{ENV["HOME"]}/.vscode",
  # ]
end
