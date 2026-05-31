import requests


def search_cves(query):

    vulnerabilities = []

    try:

        url = f"https://cve.circl.lu/api/search/{query}"

        response = requests.get(
            url,
            timeout=15
        )

        data = response.json()

        results = data.get("results", [])

        for item in results[:10]:

            summary = item.get(
                "summary",
                "No description"
            )

            cvss = item.get(
                "cvss",
                0
            )

            # Severity Logic
            severity = "Low"

            if cvss >= 9:
                severity = "Critical"

            elif cvss >= 7:
                severity = "High"

            elif cvss >= 4:
                severity = "Medium"

            vulnerabilities.append({

                "id": item.get(
                    "id",
                    "UNKNOWN"
                ),

                "summary": summary,

                "severity": severity,

                "cvss": cvss
            })

    except Exception as e:

        print("")
        print("CVE API ERROR")
        print(e)
        print("")

    return vulnerabilities
