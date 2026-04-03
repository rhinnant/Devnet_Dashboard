from django.shortcuts import render

# Create your views here.
from django.shortcuts import render, get_object_or_404, redirect
from django.contrib.auth.decorators import login_required
from .models import Ticket

@login_required
def ticket_list(request):
    tickets = Ticket.objects.all().order_by('-created_at')
    return render(request, 'tickets/ticket_list.html', {'tickets': tickets})

@login_required
def ticket_detail(request, ticket_id):
    ticket = get_object_or_404(Ticket, id=ticket_id)
    return render(request, 'tickets/ticket_detail.html', {'ticket': ticket})

@login_required
def ticket_create(request):
    if request.method == 'POST':
        Ticket.objects.create(
            title=request.POST['title'],
            description=request.POST['description'],
            created_by=request.user,
            priority=request.POST['priority'],
        )
        return redirect('ticket_list')

    return render(request, 'tickets/ticket_create.html')

@login_required
def ticket_update(request, ticket_id):
    ticket = get_object_or_404(Ticket, id=ticket_id)

    if request.method == 'POST':
        ticket.status = request.POST['status']
        ticket.priority = request.POST['priority']
        ticket.save()
        return redirect('ticket_detail', ticket_id=ticket_id)

    return render(request, 'tickets/ticket_update.html', {'ticket': ticket})
