cask "integra" do
  version "0.8.5"
  sha256 "c04b792141744e3df6744f033b300fdb0a01d5d4a86374af0c16f092aed8d7b8"

  url "https://github.com/Octadira/integra/releases/download/v#{version}/Integra-v#{version}.dmg"
  name "Integra"
  desc "Native macOS SSHFS & AI Agent Workspace Manager"
  homepage "https://github.com/Octadira/integra"

  depends_on macos: :sonoma

  app "Integra.app"

  zap trash: [
    "~/Library/Application Support/Integra",
    "~/Library/Logs/Integra",
    "~/Library/Preferences/com.integra.app.plist",
    "~/.ssh/integra",
  ]
end
