from django.urls import path
from .views import RegisterView
from .views import SignatureView
from .views import EmailTokenView


urlpatterns = [

    path(
        "register/",
        RegisterView.as_view(),
        name="register"
    ),

   path(
    "signature/",
    SignatureView.as_view()
   ),

    



    path(
        "token/",
        EmailTokenView.as_view(),
        name="token"
    ),


]




