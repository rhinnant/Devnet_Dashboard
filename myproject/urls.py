from django.contrib import admin
from django.urls import path, include

urlpatterns = [
    path('admin/', admin.site.urls),

    path('', include('homepage.urls')),
    path('tickets/', include('tickets.urls')),
    path('accounts/', include('accounts.urls')),
    path('network/', include('network.urls')),
    path('assets/', include('assets.urls')),
    path('knowledge/', include('knowledge.urls')),
    path('notifications/', include('notifications.urls')),
    path('api/', include('network_api.urls')),
    path('monitor/', include('monitor.urls')),
    path('scanner/', include('scanner.urls')),
]
