from django.shortcuts import render, redirect, get_object_or_404

from .models import Asset, Scan, Vulnerability
from .scanner import run_nmap, extract_services
from .cve_intel import get_cves_for_keyword


def dashboard(request):

    assets = Asset.objects.all()
    scans = Scan.objects.order_by("-created_at")

    critical_count = Vulnerability.objects.filter(severity="critical").count()
    high_count = Vulnerability.objects.filter(severity="high").count()
    medium_count = Vulnerability.objects.filter(severity="medium").count()
    low_count = Vulnerability.objects.filter(severity="low").count()

    return render(request, "scanner/dashboard.html", {
        "assets": assets,
        "scans": scans,
        "critical_count": critical_count,
        "high_count": high_count,
        "medium_count": medium_count,
        "low_count": low_count
    })


def add_asset(request):

    if request.method == "POST":
        Asset.objects.create(
            name=request.POST["name"],
            target=request.POST["target"]
        )
        return redirect("dashboard")

    return render(request, "scanner/add_asset.html")


def run_scan(request, asset_id):

    asset = get_object_or_404(Asset, id=asset_id)

    scan = Scan.objects.create(
        asset=asset,
        status="running"
    )

    # =========================
    # STEP 1: RUN NMAP
    # =========================
    output = run_nmap(asset.target)

    print("\n=== NMAP OUTPUT ===")
    print(output)

    # =========================
    # STEP 2: EXTRACT SERVICES
    # =========================
    services = extract_services(output)

    print("\n=== SERVICES FOUND ===")
    print(services)

    # If nothing found, still complete scan safely
    if not services:
        scan.status = "completed"
        scan.save()
        return redirect("scan_detail", scan.id)

    # =========================
    # STEP 3: CVE LOOKUP
    # =========================
    for service in services:

        product = service.get("product", "")

        if not product:
            continue

        # 🔥 FIX: simplified query (THIS IS KEY)
        query = product

        print("\nSearching CVEs for:", query)

        cves = get_cves_for_keyword(query)

        print("CVEs found:", len(cves))

        # =========================
        # STEP 4: SAVE RESULTS
        # =========================
        for cve in cves:

            severity = (
                "critical" if cve.get("cvss", 0) >= 9 else
                "high" if cve.get("cvss", 0) >= 7 else
                "medium" if cve.get("cvss", 0) >= 4 else
                "low"
            )

            Vulnerability.objects.create(
                scan=scan,
                cve=cve.get("cve_id", "UNKNOWN"),
                title=cve.get("description", "")[:250],
                severity=severity,
                raw_output=query
            )

    scan.status = "completed"
    scan.save()

    return redirect("scan_detail", scan.id)


def scan_detail(request, scan_id):

    scan = get_object_or_404(Scan, id=scan_id)

    vulns = Vulnerability.objects.filter(scan=scan)

    return render(request, "scanner/scan_detail.html", {
        "scan": scan,
        "vulns": vulns
    })


def delete_scan(request, scan_id):

    scan = get_object_or_404(Scan, id=scan_id)
    scan.delete()

    return redirect("dashboard")


def clear_scans(request):

    Scan.objects.all().delete()
    return redirect("dashboard")


def delete_selected_assets(request):

    if request.method == "POST":
        ids = request.POST.getlist("asset_ids")
        Asset.objects.filter(id__in=ids).delete()

    return redirect("dashboard")
