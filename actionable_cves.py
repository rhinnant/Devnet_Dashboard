import json

APP_KEYWORDS = [
    "django", "pillow", "flask", "fastapi", "requests",
    "sqlalchemy", "gunicorn", "uvicorn", "cryptography",
    "pyjwt", "sqlite"
]

NOISE_PACKAGES = [
    "libc", "glibc", "systemd", "kernel", "linux",
    "ncurses", "libtinfo", "libcap", "libudev",
    "nghttp2", "zlib", "ldap"
]

def is_noise(pkg):
    pkg = pkg.lower()
    return any(x in pkg for x in NOISE_PACKAGES)

def is_app(pkg):
    pkg = pkg.lower()
    return any(x in pkg for x in APP_KEYWORDS)

def load_trivy(path):
    with open(path, "r") as f:
        return json.load(f)

def extract_findings(data):
    results = []

    # Trivy structure
    for result in data.get("Results", []):
        for vuln in result.get("Vulnerabilities", []):
            pkg = vuln.get("PkgName", "")
            sev = vuln.get("Severity", "")
            cve = vuln.get("VulnerabilityID", "")
            fixed = vuln.get("FixedVersion", "")

            if is_noise(pkg):
                continue

            # KEEP ONLY app-level or critical/high unknowns
            if not (is_app(pkg) or sev in ["CRITICAL", "HIGH"]):
                continue

            results.append({
                "pkg": pkg,
                "cve": cve,
                "severity": sev,
                "fixed": fixed
            })

    # sort by severity
    order = {"CRITICAL": 3, "HIGH": 2, "MEDIUM": 1, "LOW": 0}
    results.sort(key=lambda x: order.get(x["severity"], 0), reverse=True)

    return results[:5]  # 🔥 LIMIT TO TOP 5 ACTIONABLE

def main():
    data = load_trivy("scan.json")
    findings = extract_findings(data)

    print("\n🔥 TOP 5 ACTIONABLE DEVSECOPS CVEs\n")

    for f in findings:
        print(f"[{f['severity']}] {f['pkg']}")
        print(f"  CVE: {f['cve']}")
        print(f"  Fix: {f['fixed'] or 'upgrade required'}\n")

if __name__ == "__main__":
    main()
