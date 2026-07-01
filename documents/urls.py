from django.urls import path, include
from rest_framework.routers import DefaultRouter

from .views import DocumentViewSet
from .views import MeView, EmailHistoryListView


router = DefaultRouter()

router.register(
    "documents",
    DocumentViewSet,
    basename="documents"
)


urlpatterns = [
    path("me/", MeView.as_view(), name="me"),
    path("email-history/", EmailHistoryListView.as_view(), name="email-history"),
    path(
        "",
        include(router.urls)
    )
]