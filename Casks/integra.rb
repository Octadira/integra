cask "integra" do
  version "0.16.5"
  sha256 "16076013aee812ed1ea3fb790647231ef7cfd6b33fb996a3fae1d88c1a5eac3d"

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
