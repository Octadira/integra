cask "integra" do
  version "0.13.0"
  sha256 "be9fa45dccfe70ffb9397e6617396adb1e8f92e55400e4062eb7fa59636b06fb"

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
