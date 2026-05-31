import requests
import importlib.metadata as metadata

OSV_API = "https://api.osv.dev/v1/query"


def scan_package(package_name, package_version):
    """
    Query real CVEs from OSV database
    """

    payload = {
        "package": {
            "name": package_name,
            "ecosystem": "PyPI"
        },
        "version": package_version
    }

    response = requests.post(OSV_API, json=payload)

    if response.status_code != 200:
        return []

    data = response.json()

    vulns = []

    for v in data.get("vulns", []):
        vulns.append({
            "id": v.get("id"),
            "summary": v.get("summary"),
            "severity": v.get("database_specific", {}).get("severity"),
        })

    return vulns


def scan_requirements():
    """
    Scan all installed Python packages in container
    """

    results = []

    for dist in pkg_resources.working_set:
        pkg = dist.project_name
        ver = dist.version

        vulns = scan_package(pkg, ver)

        if vulns:
            results.append({
                "package": pkg,
                "version": ver,
                "vulnerabilities": vulns
            })

    return results
