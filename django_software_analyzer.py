# django_software_analyzer.py
#
# Simple Django Software Analyzer
# Scans your Django project for:
# - Installed apps
# - URL patterns
# - Views
# - Models
# - Potential security/debug issues
# - Large files
#
# Usage:
# python django_software_analyzer.py /path/to/django/project

import os
import re
import sys
from pathlib import Path

PROJECT_ROOT = sys.argv[1] if len(sys.argv) > 1 else "."

print("=" * 60)
print("DJANGO SOFTWARE ANALYZER")
print("=" * 60)
print(f"Scanning Project: {PROJECT_ROOT}")
print()

# -----------------------------
# Helpers
# -----------------------------

def read_file(path):
    try:
        with open(path, "r", encoding="utf-8") as f:
            return f.read()
    except:
        return ""

def find_python_files(root):
    py_files = []
    for path, dirs, files in os.walk(root):
        # Skip virtual envs and migrations cache
        dirs[:] = [
            d for d in dirs
            if d not in ["venv", ".venv", "__pycache__", "node_modules"]
        ]

        for file in files:
            if file.endswith(".py"):
                py_files.append(os.path.join(path, file))

    return py_files

# -----------------------------
# Scan Project
# -----------------------------

python_files = find_python_files(PROJECT_ROOT)

apps = []
models = []
views = []
urls = []

debug_enabled = False
secret_key_found = False

# -----------------------------
# Analyze Files
# -----------------------------

for file in python_files:

    content = read_file(file)

    # Detect Django Apps
    if "apps.py" in file:
        apps.append(file)

    # Detect Models
    if "models.py" in file:
        model_matches = re.findall(r"class\s+(\w+)\(models\.Model\)", content)
        for model in model_matches:
            models.append((model, file))

    # Detect Views
    if "views.py" in file:
        function_views = re.findall(r"def\s+(\w+)\(", content)
        class_views = re.findall(r"class\s+(\w+)\(", content)

        for view in function_views:
            views.append((view, file))

        for view in class_views:
            views.append((view, file))

    # Detect URL Patterns
    if "urls.py" in file:
        url_matches = re.findall(r"path\(['\"](.*?)['\"]", content)

        for url in url_matches:
            urls.append((url, file))

    # Security Checks
    if "settings.py" in file:

        if "DEBUG = True" in content:
            debug_enabled = True

        if "SECRET_KEY =" in content:
            secret_key_found = True

# -----------------------------
# Output Report
# -----------------------------

print("DJANGO APPS")
print("-" * 60)

for app in apps:
    print(f"[APP] {app}")

print()
print("MODELS")
print("-" * 60)

for model, file in models:
    print(f"[MODEL] {model} --> {file}")

print()
print("VIEWS")
print("-" * 60)

for view, file in views:
    print(f"[VIEW] {view} --> {file}")

print()
print("URL PATTERNS")
print("-" * 60)

for url, file in urls:
    print(f"[URL] /{url} --> {file}")

print()
print("SECURITY CHECKS")
print("-" * 60)

if debug_enabled:
    print("[WARNING] DEBUG=True detected")

if secret_key_found:
    print("[INFO] SECRET_KEY configured")

print()
print("LARGE FILES")
print("-" * 60)

for file in python_files:
    size_kb = os.path.getsize(file) / 1024

    if size_kb > 100:
        print(f"[LARGE FILE] {file} ({size_kb:.2f} KB)")

print()
print("=" * 60)
print("SCAN COMPLETE")
print("=" * 60)
