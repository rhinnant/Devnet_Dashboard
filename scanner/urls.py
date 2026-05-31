from django.urls import path

from . import views


urlpatterns = [

    path(
        '',
        views.dashboard,
        name='dashboard'
    ),

    path(
        'add/',
        views.add_asset,
        name='add_asset'
    ),

    path(
        'scan/<int:asset_id>/',
        views.scan_asset,
        name='run_scan'
    ),

    path(
        'scan/<int:scan_id>/detail/',
        views.scan_detail,
        name='scan_detail'
    ),

    path(
        'scan/delete/<int:scan_id>/',
        views.delete_scan,
        name='delete_scan'
    ),

    path(
        'clear-scans/',
        views.clear_scans,
        name='clear_scans'
    ),

    path(
        'delete-assets/',
        views.delete_selected_assets,
        name='delete_selected_assets'
    ),
]