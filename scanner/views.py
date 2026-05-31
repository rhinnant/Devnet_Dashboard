from django.shortcuts import render, redirect, get_object_or_404
from django.http import HttpResponseRedirect

from .models import Asset, Scan, Vulnerability
from .scanner import run_scan


# -------------------------
# Dashboard
# -------------------------
def dashboard(request):
    assets = Asset.objects.all().order_by("-id")
    scans = Scan.objects.all().order_by("-id")

    critical_count = Vulnerability.objects.filter(severity="Critical").count()
    high_count = Vulnerability.objects.filter(severity="High").count()
    medium_count = Vulnerability.objects.filter(severity="Medium").count()
    low_count = Vulnerability.objects.filter(severity="Low").count()

    return render(
        request,
        "scanner/dashboard.html",
        {
            "assets": assets,
            "scans": scans,
            "critical_count": critical_count,
            "high_count": high_count,
            "medium_count": medium_count,
            "low_count": low_count,
        },
    )


# -------------------------
# Run scan on asset
# -------------------------
def scan_asset(request, asset_id):
    asset = get_object_or_404(Asset, id=asset_id)

    scan = Scan.objects.create(
        asset=asset,
        status="running"
    )

    run_scan(scan)

    return redirect(f"/scanner/scan/{scan.id}/detail/")


# -------------------------
# Scan detail page
# -------------------------
def scan_detail(request, scan_id):
    scan = get_object_or_404(Scan, id=scan_id)
    vulnerabilities = scan.vulnerabilities.all()

    return render(
        request,
        "scanner/scan_detail.html",
        {
            "scan": scan,
            "vulnerabilities": vulnerabilities,
        },
    )


# -------------------------
# Add asset
# -------------------------
def add_asset(request):
    if request.method == "POST":
        name = request.POST.get("name")
        target = request.POST.get("target")

        Asset.objects.create(name=name, target=target)

        return redirect("/scanner/")

    return render(request, "scanner/add_asset.html")


# -------------------------
# Delete single scan
# -------------------------
def delete_scan(request, scan_id):
    scan = get_object_or_404(Scan, id=scan_id)
    scan.delete()
    return redirect("/scanner/")


# -------------------------
# Clear ALL scans (fix for your error)
# -------------------------
def clear_scans(request):
    Scan.objects.all().delete()
    return redirect("/scanner/")

def delete_selected_assets(request):
    if request.method == "POST":
        ids = request.POST.getlist("asset_ids")
        Asset.objects.filter(id__in=ids).delete()

    return redirect("/scanner/")