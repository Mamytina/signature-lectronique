from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import AdminDocumentListView, GoogleLoginView
from .views import DocumentViewSet
from .views import MeView, EmailHistoryListView,UserSignatureView,AdminStatsView,AdminUserToggleActiveView,AdminUserListView
from rest_framework_simplejwt.views import TokenRefreshView 

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
    ),

    path(
            "token/refresh/",
            TokenRefreshView.as_view(),
            name="token_refresh"
        ),  
    path("auth/google/", GoogleLoginView.as_view(), name="google-login"),
    path("signature/", UserSignatureView.as_view(), name="signature"),



    # Admin
    path("admin/stats/", AdminStatsView.as_view(), name="admin-stats"),
    path("admin/users/", AdminUserListView.as_view(), name="admin-users"),
    path("admin/users/<int:user_id>/toggle-active/", AdminUserToggleActiveView.as_view(), name="admin-toggle-user"),
    path("admin/documents/", AdminDocumentListView.as_view(), name="admin-documents"),

]