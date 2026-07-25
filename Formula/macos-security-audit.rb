class MacosSecurityAudit < Formula
  desc "Comprehensive macOS security audit with Markdown report generation"
  homepage "https://github.com/fexxdev/macos_security_audit"
  url "https://github.com/fexxdev/macos_security_audit/archive/refs/tags/v3.1.0.tar.gz"
  # sha256 "UPDATE_WITH_ACTUAL_SHA256_AFTER_RELEASE"
  license "MIT"
  version "3.1.0"

  def install
    bin.install "bin/macos-security-audit"
  end

  test do
    assert_match "macos-security-audit", shell_output("#{bin}/macos-security-audit --help")
    assert_match version.to_s, shell_output("#{bin}/macos-security-audit --version")
    # Usage errors must be distinguishable from a bad security grade.
    shell_output("#{bin}/macos-security-audit --category nonexistent 2>&1", 64)
  end
end
