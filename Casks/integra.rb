cask "integra" do
  version "0.14.4"
  sha256 "ca9a6acc1ae6e72b116f2a37d15bf770b910b2fd8b84af8610c331abb7cd2c0b"

  url "https://github.com/Octadira/integra/releases/download/v#{version}/Integra-v#{version}.dmg"
  name "Integra"
  desc "Native macOS SSHFS & AI Agent Workspace Manager"
  homepage "https://github.com/Octadira/integra"

  depends_on macos: :sonoma

  app "Integra.app"

  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-cr", "#{appdir}/Integra.app"]
  end

  zap trash: [
    "~/Library/Application Support/Integra",
    "~/Library/Logs/Integra",
    "~/Library/Preferences/com.integra.app.plist",
    "~/.ssh/integra",
  ]
end
