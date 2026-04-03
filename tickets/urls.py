from django.urls import path
from . import views

urlpatterns = [
    path('', views.ticket_list, name='ticket_list'),
    path('create/', views.ticket_create, name='ticket_create'),
    path('<int:ticket_id>/', views.ticket_detail, name='ticket_detail'),
    path('<int:ticket_id>/update/', views.ticket_update, name='ticket_update'),

    path('task/', views.task_page, name='task_page'),
    path('request/', views.request_page, name='request_page'),
]

