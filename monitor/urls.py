from django.urls import path
from . import views
from .views import rbac_check

urlpatterns = [
    path('', views.dashboard, name='monitor_dashboard'),

    path('api/metrics/', views.api_metrics, name='api_metrics'),
    path('api/logs/', views.api_logs, name='api_logs'),
    path('api/pods/', views.api_pods, name='api_pods'),
    path('api/pod-logs/', views.api_pod_logs, name='api_pod_logs'),
    path('api/pod-describe/', views.api_pod_describe, name='api_pod_describe'),
    path('api/alerts/', views.api_alerts, name='api_alerts'),
    path("api/rbac-check/", rbac_check),
    path("api/cve/", views.api_cve_scan, name="api_cve_scan"),

]
