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
    path('', views.dashboard, name='monitor_dashboard'),
]
