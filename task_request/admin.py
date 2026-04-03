from django.contrib import admin

# Register your models here.
# main/admin.py
from django.contrib import admin
from .models import Task, Request

admin.site.register(Task)
admin.site.register(Request)
