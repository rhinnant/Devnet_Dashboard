#!/bin/bash
set -e

PROJECT_DIR=~/Backup/Devnetproject-main
MONITOR_DIR=$PROJECT_DIR/monitor
TEMPLATES_DIR=$MONITOR_DIR/templates/monitor

echo "======================================"
echo "  DevOps Monitor - Setup Script"
echo "======================================"

# ── Create directory structure ──────────────────────────────────────
echo "[1/5] Creating directory structure..."
mkdir -p $TEMPLATES_DIR

# ── views.py ───────────────────────────────────────────────────────
echo "[2/5] Writing views.py..."
cat > $MONITOR_DIR/views.py << 'PYEOF'
import requests
from django.shortcuts import render
from django.http import JsonResponse
import subprocess
import json

PROMETHEUS_URL = "http://localhost:9090"
LOKI_URL = "http://localhost:3100"
ALERTMANAGER_URL = "http://localhost:9093"


def get_prometheus(query):
    try:
        r = requests.get(f"{PROMETHEUS_URL}/api/v1/query", params={"query": query}, timeout=3)
        data = r.json()
        result = data.get("data", {}).get("result", [])
        if result:
            return float(result[0]["value"][1])
        return 0
    except:
        return None


def dashboard(request):
    return render(request, "monitor/dashboard.html")


def api_metrics(request):
    cpu = get_prometheus('100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[2m])) * 100)')
    memory_used = get_prometheus('(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100')
    pods_running = get_prometheus('count(kube_pod_status_phase{phase="Running"})')
    pods_pending = get_prometheus('count(kube_pod_status_phase{phase="Pending"})')

    return JsonResponse({
        "cpu": round(cpu, 2) if cpu is not None else "N/A",
        "memory": round(memory_used, 2) if memory_used is not None else "N/A",
        "pods_running": int(pods_running) if pods_running is not None else "N/A",
        "pods_pending": int(pods_pending) if pods_pending is not None else 0,
    })


def api_logs(request):
    namespace = request.GET.get("namespace", "monitoring")
    try:
        r = requests.get(
            f"{LOKI_URL}/loki/api/v1/query_range",
            params={
                "query": f'{{namespace="{namespace}"}}',
                "limit": 100,
                "direction": "backward"
            },
            timeout=3
        )
        data = r.json()
        logs = []
        for stream in data.get("data", {}).get("result", []):
            for ts, line in stream.get("values", []):
                logs.append({
                    "timestamp": ts,
                    "stream": stream.get("stream", {}),
                    "line": line
                })
        logs.sort(key=lambda x: x["timestamp"], reverse=True)
        return JsonResponse({"logs": logs[:100]})
    except Exception as e:
        return JsonResponse({"logs": [], "error": str(e)})


def api_pods(request):
    try:
        result = subprocess.run(
            ["kubectl", "get", "pods", "--all-namespaces", "-o", "json"],
            capture_output=True, text=True, timeout=10
        )
        data = json.loads(result.stdout)
        pods = []
        for item in data.get("items", []):
            container_statuses = item["status"].get("containerStatuses", [])
            pods.append({
                "name": item["metadata"]["name"],
                "namespace": item["metadata"]["namespace"],
                "status": item["status"].get("phase", "Unknown"),
                "ready": sum(1 for c in container_statuses if c.get("ready")),
                "total": len(container_statuses),
                "restarts": sum(c.get("restartCount", 0) for c in container_statuses),
                "age": item["metadata"].get("creationTimestamp", ""),
            })
        return JsonResponse({"pods": pods})
    except Exception as e:
        return JsonResponse({"pods": [], "error": str(e)})


def api_pod_logs(request):
    name = request.GET.get("name", "")
    namespace = request.GET.get("namespace", "default")
    if not name:
        return JsonResponse({"logs": "", "error": "Pod name required"})
    try:
        result = subprocess.run(
            ["kubectl", "logs", name, "-n", namespace, "--tail=100"],
            capture_output=True, text=True, timeout=10
        )
        logs = result.stdout or result.stderr or "No logs available"
        return JsonResponse({"logs": logs})
    except Exception as e:
        return JsonResponse({"logs": "", "error": str(e)})


def api_pod_describe(request):
    name = request.GET.get("name", "")
    namespace = request.GET.get("namespace", "default")
    if not name:
        return JsonResponse({"output": "", "error": "Pod name required"})
    try:
        result = subprocess.run(
            ["kubectl", "describe", "pod", name, "-n", namespace],
            capture_output=True, text=True, timeout=10
        )
        output = result.stdout or result.stderr or "No output"
        return JsonResponse({"output": output})
    except Exception as e:
        return JsonResponse({"output": "", "error": str(e)})


def api_alerts(request):
    try:
        r = requests.get(f"{ALERTMANAGER_URL}/api/v2/alerts", timeout=3)
        data = r.json()
        alerts = []
        for a in data:
            labels = a.get("labels", {})
            annotations = a.get("annotations", {})
            alerts.append({
                "name": labels.get("alertname", "Unknown"),
                "severity": labels.get("severity", "info"),
                "state": a.get("status", {}).get("state", "unknown"),
                "summary": annotations.get("summary", ""),
                "description": annotations.get("description", ""),
                "labels": labels,
            })
        return JsonResponse({"alerts": alerts})
    except Exception as e:
        return JsonResponse({"alerts": [], "error": str(e)})
PYEOF

# ── urls.py ────────────────────────────────────────────────────────
echo "[3/5] Writing urls.py..."
cat > $MONITOR_DIR/urls.py << 'PYEOF'
from django.urls import path
from . import views

urlpatterns = [
    path('monitor/', views.dashboard, name='monitor_dashboard'),
    path('monitor/api/metrics/', views.api_metrics, name='api_metrics'),
    path('monitor/api/logs/', views.api_logs, name='api_logs'),
    path('monitor/api/pods/', views.api_pods, name='api_pods'),
    path('monitor/api/pod-logs/', views.api_pod_logs, name='api_pod_logs'),
    path('monitor/api/pod-describe/', views.api_pod_describe, name='api_pod_describe'),
    path('monitor/api/alerts/', views.api_alerts, name='api_alerts'),
]
PYEOF

# ── apps.py ────────────────────────────────────────────────────────
echo "[4/5] Writing apps.py..."
cat > $MONITOR_DIR/apps.py << 'PYEOF'
from django.apps import AppConfig

class MonitorConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'monitor'
PYEOF

# ── Register in settings.py ────────────────────────────────────────
if ! grep -q "'monitor'" $PROJECT_DIR/myproject/settings.py; then
    sed -i "s/'core',/'core',\n    'monitor',/" $PROJECT_DIR/myproject/settings.py
    echo "      Added 'monitor' to INSTALLED_APPS"
else
    echo "      'monitor' already in INSTALLED_APPS, skipping"
fi

# ── Register in main urls.py ───────────────────────────────────────
if ! grep -q "monitor.urls" $PROJECT_DIR/myproject/urls.py; then
    sed -i "s|path('', include('core.urls')),|path('', include('core.urls')),\n    path('', include('monitor.urls')),|" $PROJECT_DIR/myproject/urls.py
    echo "      Added monitor.urls to urlpatterns"
else
    echo "      monitor.urls already registered, skipping"
fi

# ── Install dependencies ───────────────────────────────────────────
echo "[5/5] Installing dependencies..."
pip install requests --quiet
if ! grep -q "requests" $PROJECT_DIR/requirements.txt; then
    echo "requests==2.32.3" >> $PROJECT_DIR/requirements.txt
fi

# ── dashboard.html is written last (long heredoc) ──────────────────
cat > $TEMPLATES_DIR/dashboard.html << 'HTMLEOF'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>DevOps Monitor</title>
<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
<style>
* { margin: 0; padding: 0; box-sizing: border-box; }
body { background: #0f1117; color: #e0e0e0; font-family: 'Segoe UI', sans-serif; display: flex; height: 100vh; overflow: hidden; }
.sidebar { width: 220px; background: #161b27; border-right: 1px solid #2a2f3e; padding: 20px 0; display: flex; flex-direction: column; flex-shrink: 0; }
.sidebar-logo { padding: 0 20px 24px; font-size: 18px; font-weight: 700; color: #5b9bd5; border-bottom: 1px solid #2a2f3e; margin-bottom: 8px; }
.sidebar-logo span { color: #e0e0e0; }
.nav-item { padding: 12px 20px; cursor: pointer; display: flex; align-items: center; gap: 10px; font-size: 14px; color: #9ca3af; transition: all 0.2s; border-left: 3px solid transparent; user-select: none; }
.nav-item:hover { background: #1e2535; color: #c0cfe0; }
.nav-item.active { background: #1e2535; color: #5b9bd5; border-left-color: #5b9bd5; }
.nav-item .icon { font-size: 16px; }
.sidebar-footer { margin-top: auto; padding: 16px 20px; border-top: 1px solid #2a2f3e; font-size: 11px; color: #4b5563; }
.main { flex: 1; display: flex; flex-direction: column; overflow: hidden; min-width: 0; }
.topbar { background: #161b27; border-bottom: 1px solid #2a2f3e; padding: 14px 24px; display: flex; justify-content: space-between; align-items: center; flex-shrink: 0; }
.topbar h1 { font-size: 16px; font-weight: 600; color: #e0e0e0; }
.topbar-right { display: flex; align-items: center; gap: 14px; }
.status-dot { width: 8px; height: 8px; background: #22c55e; border-radius: 50%; display: inline-block; margin-right: 6px; animation: pulse 2s infinite; }
.status-dot.red { background: #ef4444; }
@keyframes pulse { 0%,100%{opacity:1} 50%{opacity:0.4} }
.refresh-info { font-size: 12px; color: #6b7280; }
.btn { padding: 6px 14px; border-radius: 5px; border: 1px solid #2a2f3e; background: #1e2535; color: #9ca3af; font-size: 12px; cursor: pointer; transition: all 0.2s; }
.btn:hover { background: #2a3447; color: #e0e0e0; border-color: #5b9bd5; }
.btn.primary { background: #1d3a5e; color: #5b9bd5; border-color: #5b9bd5; }
.btn.primary:hover { background: #5b9bd5; color: #fff; }
.btn.danger { background: #3b0a0a; color: #ef4444; border-color: #ef4444; }
.content { flex: 1; overflow-y: auto; padding: 20px 24px; }
.section { display: none; }
.section.active { display: block; }
.cards { display: grid; grid-template-columns: repeat(4, 1fr); gap: 16px; margin-bottom: 20px; }
.card { background: #161b27; border: 1px solid #2a2f3e; border-radius: 8px; padding: 20px; transition: border-color 0.2s; }
.card:hover { border-color: #3a4a6a; }
.card-label { font-size: 12px; color: #6b7280; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 8px; }
.card-value { font-size: 32px; font-weight: 700; color: #5b9bd5; }
.card-value.green { color: #22c55e; }
.card-value.yellow { color: #f59e0b; }
.card-value.red { color: #ef4444; }
.card-sub { font-size: 12px; color: #6b7280; margin-top: 4px; }
.charts-row { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; margin-bottom: 20px; }
.panel { background: #161b27; border: 1px solid #2a2f3e; border-radius: 8px; padding: 16px; }
.panel-title { font-size: 13px; font-weight: 600; color: #9ca3af; margin-bottom: 12px; text-transform: uppercase; letter-spacing: 0.5px; display: flex; justify-content: space-between; align-items: center; }
.toolbar { display: flex; gap: 10px; margin-bottom: 14px; align-items: center; flex-wrap: wrap; }
.toolbar input, .toolbar select { background: #0f1117; border: 1px solid #2a2f3e; color: #e0e0e0; padding: 7px 12px; border-radius: 5px; font-size: 13px; outline: none; transition: border-color 0.2s; }
.toolbar input:focus, .toolbar select:focus { border-color: #5b9bd5; }
.toolbar input { width: 220px; }
.toolbar-right { margin-left: auto; display: flex; gap: 8px; align-items: center; }
.pods-panel { background: #161b27; border: 1px solid #2a2f3e; border-radius: 8px; padding: 16px; margin-bottom: 20px; }
table { width: 100%; border-collapse: collapse; font-size: 13px; }
th { text-align: left; padding: 8px 12px; color: #6b7280; font-weight: 500; border-bottom: 1px solid #2a2f3e; font-size: 11px; text-transform: uppercase; cursor: pointer; user-select: none; }
th:hover { color: #9ca3af; }
th.sorted-asc::after { content: " ↑"; color: #5b9bd5; }
th.sorted-desc::after { content: " ↓"; color: #5b9bd5; }
td { padding: 10px 12px; border-bottom: 1px solid #1e2535; color: #d1d5db; }
tr:hover td { background: #1a2033; }
.badge { padding: 2px 8px; border-radius: 4px; font-size: 11px; font-weight: 600; }
.badge.running { background: #14532d; color: #22c55e; }
.badge.pending { background: #451a03; color: #f59e0b; }
.badge.failed { background: #450a0a; color: #ef4444; }
.badge.unknown { background: #1f2937; color: #9ca3af; }
.pod-actions { display: flex; gap: 6px; }
.pod-btn { padding: 3px 8px; border-radius: 3px; border: 1px solid #2a2f3e; background: #0f1117; color: #9ca3af; font-size: 11px; cursor: pointer; transition: all 0.15s; }
.pod-btn:hover { border-color: #5b9bd5; color: #5b9bd5; }
.stat-badge { display: inline-block; padding: 2px 8px; border-radius: 12px; font-size: 11px; background: #1e2535; color: #9ca3af; }
.logs-panel { background: #161b27; border: 1px solid #2a2f3e; border-radius: 8px; padding: 16px; }
.log-container { background: #0a0d14; border-radius: 4px; padding: 12px; height: 340px; overflow-y: auto; font-family: 'Courier New', monospace; font-size: 12px; }
.log-line { padding: 3px 0; border-bottom: 1px solid #0f1117; word-break: break-all; display: flex; gap: 6px; }
.log-line:hover { background: #0f1520; }
.log-time { color: #4b5563; flex-shrink: 0; }
.log-ns { color: #5b9bd5; flex-shrink: 0; }
.log-msg { color: #d1d5db; }
.log-line.error .log-msg { color: #ef4444; }
.log-line.warn .log-msg { color: #f59e0b; }
.log-line.info .log-msg { color: #60a5fa; }
.modal-bg { display: none; position: fixed; inset: 0; background: rgba(0,0,0,0.7); z-index: 100; align-items: center; justify-content: center; }
.modal-bg.open { display: flex; }
.modal { background: #161b27; border: 1px solid #2a2f3e; border-radius: 10px; padding: 24px; width: 680px; max-height: 80vh; display: flex; flex-direction: column; }
.modal-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
.modal-header h2 { font-size: 15px; color: #e0e0e0; }
.modal-close { background: none; border: none; color: #6b7280; font-size: 20px; cursor: pointer; }
.modal-close:hover { color: #e0e0e0; }
.modal-body { overflow-y: auto; flex: 1; font-family: 'Courier New', monospace; font-size: 12px; background: #0a0d14; border-radius: 4px; padding: 12px; color: #9ca3af; white-space: pre-wrap; word-break: break-all; }
.alerts-list { display: flex; flex-direction: column; gap: 10px; }
.alert-item { background: #161b27; border: 1px solid #2a2f3e; border-radius: 8px; padding: 16px; border-left: 4px solid #ef4444; }
.alert-item.warning { border-left-color: #f59e0b; }
.alert-item.info { border-left-color: #5b9bd5; }
.alert-name { font-size: 14px; font-weight: 600; color: #e0e0e0; margin-bottom: 4px; }
.alert-desc { font-size: 13px; color: #9ca3af; }
.alert-meta { font-size: 11px; color: #4b5563; margin-top: 6px; }
.toast { position: fixed; bottom: 24px; right: 24px; background: #1e2535; border: 1px solid #2a2f3e; border-radius: 6px; padding: 12px 18px; font-size: 13px; color: #e0e0e0; opacity: 0; transition: opacity 0.3s; pointer-events: none; z-index: 200; }
.toast.show { opacity: 1; }
.toast.success { border-color: #22c55e; color: #22c55e; }
.toast.error { border-color: #ef4444; color: #ef4444; }
.empty { text-align: center; padding: 40px; color: #4b5563; }
.empty-icon { font-size: 32px; margin-bottom: 10px; }
</style>
</head>
<body>

<div class="sidebar">
  <div class="sidebar-logo">⬡ DevOps<span>Monitor</span></div>
  <div class="nav-item active" onclick="showSection('dashboard', this, '📊 Cluster Overview')">
    <span class="icon">📊</span> Dashboard
  </div>
  <div class="nav-item" onclick="showSection('pods', this, '🟢 Pod Management')">
    <span class="icon">🟢</span> Pods
  </div>
  <div class="nav-item" onclick="showSection('logs', this, '📋 Live Logs')">
    <span class="icon">📋</span> Logs
  </div>
  <div class="nav-item" onclick="showSection('alerts', this, '🔔 Alerts')">
    <span class="icon">🔔</span> Alerts
  </div>
  <div class="sidebar-footer">
    Minikube · Local Cluster<br>
    <span id="last-updated">Never updated</span>
  </div>
</div>

<div class="main">
  <div class="topbar">
    <h1 id="topbar-title">📊 Cluster Overview</h1>
    <div class="topbar-right">
      <span class="refresh-info"><span class="status-dot" id="status-dot"></span><span id="status-text">Live</span></span>
      <button class="btn primary" onclick="refreshAll()">⟳ Refresh Now</button>
    </div>
  </div>

  <div class="content">

    <!-- DASHBOARD -->
    <div class="section active" id="section-dashboard">
      <div class="cards">
        <div class="card">
          <div class="card-label">CPU Usage</div>
          <div class="card-value" id="cpu-val">—</div>
          <div class="card-sub">Across all nodes</div>
        </div>
        <div class="card">
          <div class="card-label">Memory Usage</div>
          <div class="card-value" id="mem-val">—</div>
          <div class="card-sub">Across all nodes</div>
        </div>
        <div class="card" onclick="showSection('pods', document.querySelectorAll('.nav-item')[1], '🟢 Pod Management')" style="cursor:pointer">
          <div class="card-label">Pods Running</div>
          <div class="card-value green" id="pods-running">—</div>
          <div class="card-sub">Click to view →</div>
        </div>
        <div class="card" onclick="showSection('pods', document.querySelectorAll('.nav-item')[1], '🟢 Pod Management')" style="cursor:pointer">
          <div class="card-label">Pods Pending</div>
          <div class="card-value yellow" id="pods-pending">—</div>
          <div class="card-sub">Click to investigate →</div>
        </div>
      </div>
      <div class="charts-row">
        <div class="panel">
          <div class="panel-title">CPU Usage % <span style="font-size:11px;color:#4b5563;text-transform:none;font-weight:400">last 10 readings</span></div>
          <canvas id="cpuChart" height="110"></canvas>
        </div>
        <div class="panel">
          <div class="panel-title">Memory Usage % <span style="font-size:11px;color:#4b5563;text-transform:none;font-weight:400">last 10 readings</span></div>
          <canvas id="memChart" height="110"></canvas>
        </div>
      </div>
      <div class="pods-panel">
        <div class="panel-title" style="display:flex;justify-content:space-between;align-items:center;margin-bottom:12px">
          <span>Recent Pods</span>
          <button class="btn" onclick="showSection('pods', document.querySelectorAll('.nav-item')[1], '🟢 Pod Management')">View All →</button>
        </div>
        <table>
          <thead><tr><th>Pod Name</th><th>Namespace</th><th>Status</th><th>Ready</th></tr></thead>
          <tbody id="dashboard-pods-table"><tr><td colspan="4" class="empty">Loading...</td></tr></tbody>
        </table>
      </div>
    </div>

    <!-- PODS -->
    <div class="section" id="section-pods">
      <div class="pods-panel">
        <div class="toolbar">
          <input type="text" id="pod-search" placeholder="🔍 Search pods..." oninput="filterPods()">
          <select id="ns-filter" onchange="filterPods()">
            <option value="">All Namespaces</option>
            <option value="monitoring">monitoring</option>
            <option value="argocd">argocd</option>
            <option value="dev">dev</option>
            <option value="kube-system">kube-system</option>
          </select>
          <select id="status-filter" onchange="filterPods()">
            <option value="">All Statuses</option>
            <option value="Running">Running</option>
            <option value="Pending">Pending</option>
            <option value="Failed">Failed</option>
          </select>
          <div class="toolbar-right">
            <span id="pod-count-badge" class="stat-badge">0 pods</span>
            <button class="btn primary" onclick="fetchPods()">⟳ Refresh</button>
          </div>
        </div>
        <table>
          <thead><tr>
            <th onclick="sortPods('name')">Pod Name</th>
            <th onclick="sortPods('namespace')">Namespace</th>
            <th onclick="sortPods('status')">Status</th>
            <th onclick="sortPods('ready')">Ready</th>
            <th>Actions</th>
          </tr></thead>
          <tbody id="pods-table"><tr><td colspan="5" class="empty"><div class="empty-icon">⏳</div>Loading pods...</td></tr></tbody>
        </table>
      </div>
    </div>

    <!-- LOGS -->
    <div class="section" id="section-logs">
      <div class="logs-panel">
        <div class="toolbar">
          <select id="ns-select" onchange="fetchLogs()">
            <option value="monitoring">monitoring</option>
            <option value="argocd">argocd</option>
            <option value="dev">dev</option>
            <option value="kube-system">kube-system</option>
          </select>
          <select id="log-level" onchange="filterLogs()">
            <option value="">All Levels</option>
            <option value="error">Errors only</option>
            <option value="warn">Warnings only</option>
            <option value="info">Info only</option>
          </select>
          <input type="text" id="log-search" placeholder="🔍 Filter logs..." oninput="filterLogs()" style="width:200px">
          <div class="toolbar-right">
            <span id="log-count" class="stat-badge">0 lines</span>
            <button class="btn" onclick="toggleAutoScroll()" id="autoscroll-btn">📌 Auto-scroll ON</button>
            <button class="btn" onclick="clearLogs()">🗑 Clear</button>
            <button class="btn primary" onclick="fetchLogs()">⟳ Refresh</button>
          </div>
        </div>
        <div class="log-container" id="log-container">
          <div class="empty"><div class="empty-icon">📋</div>Loading logs...</div>
        </div>
      </div>
    </div>

    <!-- ALERTS -->
    <div class="section" id="section-alerts">
      <div class="toolbar">
        <div class="toolbar-right">
          <button class="btn primary" onclick="fetchAlerts()">⟳ Refresh Alerts</button>
        </div>
      </div>
      <div class="alerts-list" id="alerts-list">
        <div class="empty"><div class="empty-icon">⏳</div>Loading alerts...</div>
      </div>
    </div>

  </div>
</div>

<!-- Modal -->
<div class="modal-bg" id="log-modal">
  <div class="modal">
    <div class="modal-header">
      <h2 id="modal-title">Pod Logs</h2>
      <button class="modal-close" onclick="closeModal()">✕</button>
    </div>
    <div class="modal-body" id="modal-body">Loading...</div>
  </div>
</div>

<div class="toast" id="toast"></div>

<script>
let allPods = [], allLogs = [], podSortKey = 'namespace', podSortDir = 1, autoScroll = true;

const cpuData = [], memData = [], labels = [];
const chartOpts = () => ({
  responsive: true, animation: false,
  plugins: { legend: { display: false } },
  scales: {
    x: { ticks: { color: '#4b5563', font: { size: 10 } }, grid: { color: '#1e2535' } },
    y: { min: 0, max: 100, ticks: { color: '#4b5563', callback: v => v + '%', font: { size: 10 } }, grid: { color: '#1e2535' } }
  }
});
const cpuChart = new Chart(document.getElementById('cpuChart'), {
  type: 'line',
  data: { labels, datasets: [{ data: cpuData, borderColor: '#5b9bd5', backgroundColor: 'rgba(91,155,213,0.1)', tension: 0.4, fill: true, pointRadius: 3 }] },
  options: chartOpts()
});
const memChart = new Chart(document.getElementById('memChart'), {
  type: 'line',
  data: { labels, datasets: [{ data: memData, borderColor: '#22c55e', backgroundColor: 'rgba(34,197,94,0.1)', tension: 0.4, fill: true, pointRadius: 3 }] },
  options: chartOpts()
});

function showSection(id, el, title) {
  document.querySelectorAll('.section').forEach(s => s.classList.remove('active'));
  document.querySelectorAll('.nav-item').forEach(n => n.classList.remove('active'));
  document.getElementById('section-' + id).classList.add('active');
  if (el) el.classList.add('active');
  document.getElementById('topbar-title').textContent = title || id;
  if (id === 'pods') fetchPods();
  if (id === 'logs') fetchLogs();
  if (id === 'alerts') fetchAlerts();
}

function showToast(msg, type = '') {
  const t = document.getElementById('toast');
  t.textContent = msg;
  t.className = 'toast show ' + type;
  setTimeout(() => t.className = 'toast', 2500);
}

function setColor(val, el) {
  if (val === "N/A" || val === null) { el.className = 'card-value'; return; }
  if (val > 80) el.className = 'card-value red';
  else if (val > 60) el.className = 'card-value yellow';
  else el.className = 'card-value green';
}

async function fetchMetrics() {
  try {
    const r = await fetch('/monitor/api/metrics/');
    const d = await r.json();
    const now = new Date().toLocaleTimeString();
    const cpuEl = document.getElementById('cpu-val');
    const memEl = document.getElementById('mem-val');
    cpuEl.textContent = d.cpu !== "N/A" ? d.cpu + '%' : 'N/A';
    memEl.textContent = d.memory !== "N/A" ? d.memory + '%' : 'N/A';
    document.getElementById('pods-running').textContent = d.pods_running;
    document.getElementById('pods-pending').textContent = d.pods_pending;
    setColor(d.cpu, cpuEl);
    setColor(d.memory, memEl);
    if (labels.length >= 10) { labels.shift(); cpuData.shift(); memData.shift(); }
    labels.push(now);
    cpuData.push(d.cpu === "N/A" ? null : d.cpu);
    memData.push(d.memory === "N/A" ? null : d.memory);
    cpuChart.update(); memChart.update();
    document.getElementById('last-updated').textContent = 'Updated ' + now;
    document.getElementById('status-dot').className = 'status-dot';
    document.getElementById('status-text').textContent = 'Live';
  } catch(e) {
    document.getElementById('status-dot').className = 'status-dot red';
    document.getElementById('status-text').textContent = 'Prometheus offline';
  }
}

async function fetchPods() {
  try {
    const r = await fetch('/monitor/api/pods/');
    const d = await r.json();
    allPods = d.pods || [];
    renderPods();
    renderDashboardPods();
    showToast('Pods refreshed ✓', 'success');
  } catch(e) {
    showToast('Failed to load pods', 'error');
  }
}

function filterPods() { renderPods(); }

function renderPods() {
  const search = (document.getElementById('pod-search').value || '').toLowerCase();
  const ns = document.getElementById('ns-filter').value;
  const status = document.getElementById('status-filter').value;
  let filtered = allPods.filter(p => {
    return (!search || p.name.toLowerCase().includes(search) || p.namespace.toLowerCase().includes(search))
      && (!ns || p.namespace === ns)
      && (!status || p.status === status);
  });
  filtered.sort((a, b) => String(a[podSortKey] || '').localeCompare(String(b[podSortKey] || '')) * podSortDir);
  document.getElementById('pod-count-badge').textContent = filtered.length + ' pods';
  const tbody = document.getElementById('pods-table');
  if (!filtered.length) { tbody.innerHTML = '<tr><td colspan="5" class="empty"><div class="empty-icon">🔍</div>No pods match filters</td></tr>'; return; }
  tbody.innerHTML = filtered.map(p => `
    <tr>
      <td style="font-family:monospace;font-size:12px">${p.name}</td>
      <td><span style="color:#5b9bd5">${p.namespace}</span></td>
      <td><span class="badge ${(p.status||'unknown').toLowerCase()}">${p.status}</span></td>
      <td style="color:${p.ready===p.total&&p.total>0?'#22c55e':'#f59e0b'}">${p.ready}/${p.total}</td>
      <td><div class="pod-actions">
        <button class="pod-btn" onclick="viewPodLogs('${p.name}','${p.namespace}')">📋 Logs</button>
        <button class="pod-btn" onclick="describePod('${p.name}','${p.namespace}')">🔍 Describe</button>
      </div></td>
    </tr>`).join('');
}

function renderDashboardPods() {
  const tbody = document.getElementById('dashboard-pods-table');
  const recent = allPods.slice(0, 8);
  if (!recent.length) { tbody.innerHTML = '<tr><td colspan="4" class="empty">No pods</td></tr>'; return; }
  tbody.innerHTML = recent.map(p => `
    <tr>
      <td style="font-family:monospace;font-size:12px">${p.name}</td>
      <td style="color:#5b9bd5">${p.namespace}</td>
      <td><span class="badge ${(p.status||'unknown').toLowerCase()}">${p.status}</span></td>
      <td>${p.ready}/${p.total}</td>
    </tr>`).join('');
}

function sortPods(key) {
  if (podSortKey === key) podSortDir *= -1; else { podSortKey = key; podSortDir = 1; }
  document.querySelectorAll('th').forEach(th => th.className = '');
  event.target.className = podSortDir === 1 ? 'sorted-asc' : 'sorted-desc';
  renderPods();
}

async function viewPodLogs(name, namespace) {
  openModal('📋 Logs — ' + name, 'Fetching logs...');
  try {
    const r = await fetch(`/monitor/api/pod-logs/?name=${name}&namespace=${namespace}`);
    const d = await r.json();
    document.getElementById('modal-body').textContent = d.logs || 'No logs available';
  } catch(e) { document.getElementById('modal-body').textContent = 'Error: ' + e.message; }
}

async function describePod(name, namespace) {
  openModal('🔍 Describe — ' + name, 'Fetching details...');
  try {
    const r = await fetch(`/monitor/api/pod-describe/?name=${name}&namespace=${namespace}`);
    const d = await r.json();
    document.getElementById('modal-body').textContent = d.output || 'No details available';
  } catch(e) { document.getElementById('modal-body').textContent = 'Error: ' + e.message; }
}

function openModal(title, body) {
  document.getElementById('modal-title').textContent = title;
  document.getElementById('modal-body').textContent = body;
  document.getElementById('log-modal').classList.add('open');
}
function closeModal() { document.getElementById('log-modal').classList.remove('open'); }
document.getElementById('log-modal').addEventListener('click', function(e) { if (e.target === this) closeModal(); });

async function fetchLogs() {
  const ns = document.getElementById('ns-select').value;
  try {
    const r = await fetch(`/monitor/api/logs/?namespace=${ns}`);
    const d = await r.json();
    allLogs = d.logs || [];
    filterLogs();
    if (d.error) showToast('Loki: ' + d.error, 'error');
  } catch(e) {
    showToast('Failed to load logs', 'error');
    document.getElementById('log-container').innerHTML = '<div class="empty">Error. Is Loki port-forwarded on :3100?</div>';
  }
}

function filterLogs() {
  const level = document.getElementById('log-level').value;
  const search = (document.getElementById('log-search').value || '').toLowerCase();
  let filtered = allLogs.filter(log => {
    const line = (log.line || '').toLowerCase();
    if (level === 'error' && !line.includes('error') && !line.includes('err=')) return false;
    if (level === 'warn' && !line.includes('warn')) return false;
    if (level === 'info' && !line.includes('info')) return false;
    if (search && !line.includes(search)) return false;
    return true;
  });
  document.getElementById('log-count').textContent = filtered.length + ' lines';
  const container = document.getElementById('log-container');
  if (!filtered.length) { container.innerHTML = '<div class="empty"><div class="empty-icon">🔍</div>No logs match filter</div>'; return; }
  container.innerHTML = filtered.map(log => {
    const line = log.line || '';
    const ll = line.toLowerCase();
    const cls = (ll.includes('error')||ll.includes('err=')) ? 'error' : ll.includes('warn') ? 'warn' : (ll.includes('level=info')||ll.includes('"level":"info"')) ? 'info' : '';
    const ns_label = log.stream.namespace || log.stream.app || log.stream.pod || '';
    const time = new Date(parseInt(log.timestamp) / 1000000).toLocaleTimeString();
    return `<div class="log-line ${cls}"><span class="log-time">${time}</span><span class="log-ns">[${ns_label}]</span><span class="log-msg">${line.replace(/</g,'&lt;').replace(/>/g,'&gt;').substring(0,300)}</span></div>`;
  }).join('');
  if (autoScroll) container.scrollTop = container.scrollHeight;
}

function clearLogs() {
  allLogs = [];
  document.getElementById('log-container').innerHTML = '<div class="empty">Cleared. Waiting for next refresh...</div>';
  document.getElementById('log-count').textContent = '0 lines';
}

function toggleAutoScroll() {
  autoScroll = !autoScroll;
  document.getElementById('autoscroll-btn').textContent = autoScroll ? '📌 Auto-scroll ON' : '📌 Auto-scroll OFF';
  document.getElementById('autoscroll-btn').className = autoScroll ? 'btn' : 'btn danger';
}

async function fetchAlerts() {
  try {
    const r = await fetch('/monitor/api/alerts/');
    const d = await r.json();
    const list = document.getElementById('alerts-list');
    if (!d.alerts || !d.alerts.length) { list.innerHTML = '<div class="empty"><div class="empty-icon">✅</div>No active alerts</div>'; return; }
    list.innerHTML = d.alerts.map(a => `
      <div class="alert-item ${a.severity}">
        <div class="alert-name">🔔 ${a.name}</div>
        <div class="alert-desc">${a.description || a.summary || 'No description'}</div>
        <div class="alert-meta">Severity: ${a.severity} · State: ${a.state}</div>
      </div>`).join('');
  } catch(e) {
    document.getElementById('alerts-list').innerHTML = '<div class="empty">Could not load alerts. Is Alertmanager port-forwarded on :9093?</div>';
  }
}

function refreshAll() {
  fetchMetrics(); fetchPods();
  const active = document.querySelector('.section.active').id;
  if (active === 'section-logs') fetchLogs();
  if (active === 'section-alerts') fetchAlerts();
  showToast('Refreshed ✓', 'success');
}

fetchMetrics();
fetchPods();
setInterval(fetchMetrics, 15000);
setInterval(fetchPods, 30000);
setInterval(() => { if (document.getElementById('section-logs').classList.contains('active')) fetchLogs(); }, 20000);
setInterval(() => { if (document.getElementById('section-alerts').classList.contains('active')) fetchAlerts(); }, 30000);
</script>
</body>
</html>
HTMLEOF

echo ""
echo "======================================"
echo "  ✅ Setup Complete!"
echo "======================================"
echo ""
echo "Start the monitor with these 3 terminals:"
echo ""
echo "  Terminal 1 (Prometheus):"
echo "  kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090"
echo ""
echo "  Terminal 2 (Loki):"
echo "  kubectl port-forward -n monitoring svc/loki 3100:3100"
echo ""
echo "  Terminal 3 (Alertmanager):"
echo "  kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-alertmanager 9093:9093"
echo ""
echo "  Terminal 4 (Django):"
echo "  cd ~/Backup/Devnetproject-main && source venv/bin/activate && python3 manage.py runserver"
echo ""
echo "  Then open: http://localhost:8000/monitor/"
echo ""
