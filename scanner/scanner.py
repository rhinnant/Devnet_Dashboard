import subprocess
import re


def run_nmap(target):

    result = subprocess.run(
        ["/usr/bin/nmap", "-sV", target],
        capture_output=True,
        text=True
    )

    return result.stdout


def extract_services(output):

    services = []

    lines = output.splitlines()

    for line in lines:

        match = re.search(
            r"(\d+)/tcp\s+open\s+(\S+)\s+(.*)",
            line
        )

        if match:

            port = match.group(1)

            service = match.group(2)

            version = match.group(3)

            services.append({
                "port": port,
                "product": service,
                "version": version
            })

    return services
