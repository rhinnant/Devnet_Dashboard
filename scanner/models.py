from django.db import models


class Asset(models.Model):

    name = models.CharField(max_length=100)

    target = models.CharField(max_length=255)

    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.name


class Scan(models.Model):

    asset = models.ForeignKey(
        Asset,
        on_delete=models.CASCADE
    )

    status = models.CharField(max_length=50)

    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.asset.name} - {self.status}"


class Vulnerability(models.Model):

    scan = models.ForeignKey(
        Scan,
        on_delete=models.CASCADE
    )

    cve = models.CharField(max_length=100)

    title = models.TextField()

    severity = models.CharField(max_length=20)

    raw_output = models.TextField(blank=True)

    def __str__(self):
        return self.cve
