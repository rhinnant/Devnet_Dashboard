from django.db import models


class Asset(models.Model):
    name = models.CharField(max_length=255)
    target = models.CharField(max_length=255)

    def __str__(self):
        return self.name


class Scan(models.Model):
    asset = models.ForeignKey(
        Asset,
        on_delete=models.CASCADE,
        related_name="scans"
    )

    status = models.CharField(max_length=50, default="running")

    output = models.TextField(blank=True, null=True)

    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Scan {self.id} - {self.asset.name}"


class Vulnerability(models.Model):
    scan = models.ForeignKey(
        Scan,
        on_delete=models.CASCADE,
        related_name="vulnerabilities"
    )

    name = models.CharField(max_length=255)
    severity = models.CharField(max_length=50)

    def __str__(self):
        return self.name