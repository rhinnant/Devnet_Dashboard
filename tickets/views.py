from django.shortcuts import render, get_object_or_404, redirect
from django.http import HttpResponse
from .models import Ticket


# -----------------------------
# HOME PAGE
# -----------------------------
def home(request):
    return render(request, 'tickets/home.html')


# -----------------------------
# TICKET VIEWS
# -----------------------------
def ticket_list(request):
    tickets = Ticket.objects.all().order_by('-created_at')
    return render(request, 'tickets/ticket_list.html', {'tickets': tickets})


def ticket_detail(request, ticket_id):
    ticket = get_object_or_404(Ticket, id=ticket_id)
    return render(request, 'tickets/ticket_detail.html', {'ticket': ticket})


def ticket_create(request):
    if request.method == 'POST':
        title = request.POST.get('title')
        description = request.POST.get('description')

        ticket = Ticket.objects.create(title=title, description=description)
        return redirect('ticket_detail', ticket_id=ticket.id)

    return render(request, 'tickets/ticket_create.html')


def ticket_update(request, ticket_id):
    ticket = get_object_or_404(Ticket, id=ticket_id)

    if request.method == 'POST':
        ticket.title = request.POST.get('title')
        ticket.description = request.POST.get('description')
        ticket.status = request.POST.get('status')
        ticket.save()

        return redirect('ticket_detail', ticket_id=ticket.id)

    return render(request, 'tickets/ticket_update.html', {'ticket': ticket})


# -----------------------------
# TASK & REQUEST PAGES
# -----------------------------
def task_page(request):
    return HttpResponse("This is the Task Page")


def request_page(request):
    return HttpResponse("This is the Request Page")

