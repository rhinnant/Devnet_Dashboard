from django.shortcuts import render, redirect, get_object_or_404
from django.http import HttpResponse
from .models import Task, Request

# Home page
def home(request):
    return render(request, 'task_request/home.html')

# Tasks page
def task_page(request):
    tasks = Task.objects.all()
    return render(request, 'task_request/tasks.html', {'tasks': tasks})

# Requests page
def request_page(request):
    return render(request, 'task_request/request_page.html')



# List all requests
def request_list(request):
    requests = Request.objects.all()
    return render(request, 'task_request/request_list.html', {'requests': requests})

# Mark a task as completed
def complete_task(request, task_id):
    task = get_object_or_404(Task, id=task_id)
    task.completed = True
    task.save()
    return redirect('task_page')  # redirects back to tasks page

def delete_task(request, task_id):
    task = get_object_or_404(Task, id=task_id)
    task.delete()
    return redirect('/')
