# jwt.py
from django.contrib.auth.models import User
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from rest_framework import serializers, exceptions


class EmailTokenObtainPairSerializer(TokenObtainPairSerializer):
    username_field = "email"

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        # Retirer le champ auto-généré (username ou email mal typé)
        self.fields.pop("username", None)
        self.fields["email"] = serializers.EmailField()

    def validate(self, attrs):
        email = attrs.get("email")
        password = attrs.get("password")

        try:
            user = User.objects.get(email=email)
        except User.DoesNotExist:
            raise exceptions.AuthenticationFailed(
                "Aucun compte actif trouvé avec cet email."
            )
        except User.MultipleObjectsReturned:
            raise exceptions.AuthenticationFailed(
                "Plusieurs comptes utilisent cet email. Contactez le support."
            )

        if not user.check_password(password):
            raise exceptions.AuthenticationFailed(
                "Aucun compte actif trouvé avec cet email."
            )

        if not user.is_active:
            raise exceptions.AuthenticationFailed("Ce compte est désactivé.")

        # On ne passe PAS par authenticate() / super().validate()
        # On génère le token nous-mêmes
        self.user = user
        refresh = self.get_token(self.user)

        data = {
            "refresh": str(refresh),
            "access": str(refresh.access_token),
            "email": user.email,
            "username": user.username,
        }
        return data