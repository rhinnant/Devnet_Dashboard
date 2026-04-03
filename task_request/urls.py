from django.urls import path
from . import views

urlpatterns = [
    path('', views.home, name='task_request_home'),
    path('tasks/', views.task_page, name='task_page'),
    path('requests/', views.request_page, name='request_page'),
    path('tasks/', views.task_page, name='task_page'),
    path('tasks/complete/<int:task_id>/', views.complete_task, name='complete_task'),
    path('tasks/delete/<int:task_id>/', views.delete_task, name='delete_task'),
]

