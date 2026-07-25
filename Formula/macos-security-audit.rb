class MacosSecurityAudit < Formula
  desc "Read-only macOS security audit with Markdown or JSON report generation"
  homepage "https://github.com/fexxdev/macos_security_audit"
  url "https://github.com/fexxdev/macos_security_audit/archive/refs/tags/v3.1.0.tar.gz"
  sha256 "f96e2a7228b940d786004cd034dce084f5e563192e8fdc09f6cd88afe707db8f"
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
