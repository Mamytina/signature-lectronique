from django.contrib.auth.models import User
from rest_framework import serializers
from .models import UserSignature



class UserSignatureSerializer(serializers.ModelSerializer):

    class Meta:
        model = UserSignature
        fields = "__all__"

        read_only_fields = [
            "user",
            "created_at",
            "updated_at",
        ]

class RegisterSerializer(serializers.ModelSerializer):

    password = serializers.CharField(
        write_only=True
    )

    confirm_password = serializers.CharField(
        write_only=True
    )

    class Meta:
        model = User

        fields = [

            "first_name",
            "last_name",

            "username",

            "email",

            "password",

            "confirm_password",

        ]


    def validate(self, attrs):

        if attrs["password"] != attrs["confirm_password"]:

            raise serializers.ValidationError({

                "confirm_password":
                "Les mots de passe sont différents."

            })

        return attrs


    def create(self, validated_data):

        validated_data.pop("confirm_password")

        return User.objects.create_user(

            username=validated_data["username"],

            first_name=validated_data["first_name"],

            last_name=validated_data["last_name"],

            email=validated_data["email"],

            password=validated_data["password"]

        )