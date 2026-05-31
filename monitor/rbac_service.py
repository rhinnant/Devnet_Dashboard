from django.http import JsonResponse
from .rbac_service import check_permission


def rbac_check(request):
    verb = request.GET.get("verb", "get")
    resource = request.GET.get("resource", "pods")
    namespace = request.GET.get("namespace", "dev")

    result = check_permission("user", verb, resource, namespace)

    return JsonResponse(result)
