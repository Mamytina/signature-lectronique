from rest_framework import generics
from django.contrib.auth.models import User
from .serializers import RegisterSerializer,UserSignatureSerializer
from rest_framework.permissions import IsAuthenticated
from .models import UserSignature



from rest_framework_simplejwt.views import TokenObtainPairView
from .jwt import EmailTokenObtainPairSerializer



class EmailTokenView(TokenObtainPairView):

    serializer_class = EmailTokenObtainPairSerializer

class RegisterView(generics.CreateAPIView):
    queryset = User.objects.all()
    serializer_class = RegisterSerializer
    permission_classes = []

class SignatureView(generics.RetrieveUpdateAPIView):

    serializer_class = UserSignatureSerializer
    permission_classes = [IsAuthenticated]


    def get_object(self):

        signature, created = UserSignature.objects.get_or_create(
            user=self.request.user
        )

        return signature