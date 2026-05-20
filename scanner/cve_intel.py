import requests


def get_cves_for_keyword(keyword):

    try:

        url = (
            f"https://services.nvd.nist.gov/rest/json/cves/2.0"
            f"?keywordSearch={keyword}"
        )

        response = requests.get(url, timeout=10)

        data = response.json()

        results = []

        for item in data.get("vulnerabilities", [])[:5]:

            cve = item["cve"]

            metrics = cve.get("metrics", {})

            cvss = 0

            if "cvssMetricV31" in metrics:

                cvss = metrics["cvssMetricV31"][0]["cvssData"]["baseScore"]

            description = cve["descriptions"][0]["value"]

            results.append({
                "cve_id": cve["id"],
                "description": description,
                "cvss": cvss
            })

        return results

    except Exception:

        return []
