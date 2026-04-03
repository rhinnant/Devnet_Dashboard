from django.shortcuts import render

# Create your views here.
from django.shortcuts import render
from tickets.models import Ticket

def dashboard_home(request):
    data = {
        'total': Ticket.objects.count(),
        'open': Ticket.objects.filter(status='open').count(),
        'progress': Ticket.objects.filter(status='in_progress').count(),
        'resolved': Ticket.objects.filter(status='resolved').count(),
    }
    return render(request, 'dashboard/home.html', data)
