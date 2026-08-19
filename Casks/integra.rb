cask "integra" do
  version "0.14.0"
  sha256 "3d8c6a55570d1fba7671b649243c8d6fa88986bf1c5c1a424c1207efc5aba1a4"

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
