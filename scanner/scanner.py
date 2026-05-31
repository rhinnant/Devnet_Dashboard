import socket


COMMON_PORTS = [
    21,
    22,
    23,
    25,
    53,
    80,
    110,
    139,
    143,
    443,
    445,
    3389
]


def run_scan(scan):

    target = scan.asset.target

    print(f"Scanning target: {target}")

    services = []

    for port in COMMON_PORTS:

        sock = socket.socket(
            socket.AF_INET,
            socket.SOCK_STREAM
        )

        sock.settimeout(1)

        result = sock.connect_ex(
            (target, port)
        )

        if result == 0:

            try:
                service = socket.getservbyport(port)

            except:
                service = "unknown"

            services.append({
                "port": port,
                "service": service
            })

        sock.close()

    print("\n=== SERVICES FOUND ===")
    print(services)

    scan.output = str(services)

    scan.status = "completed"

    scan.save()

    print("\nScan completed.")