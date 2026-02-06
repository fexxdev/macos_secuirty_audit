class MacosSecurityAudit < Formula
  desc "Comprehensive macOS security audit with Markdown report generation"
  homepage "https://github.com/fexxdev/macos-security-audit"
  url "https://github.com/fexxdev/macos-security-audit/archive/refs/tags/v1.0.0.tar.gz"
  # sha256 "UPDATE_WITH_ACTUAL_SHA256_AFTER_RELEASE"
  license "MIT"
  version "1.0.0"

  def install
    bin.install "bin/macos-security-audit"
  end

  test do
    assert_match "macos-security-audit", shell_output("#{bin}/macos-security-audit --help")
  end
end
