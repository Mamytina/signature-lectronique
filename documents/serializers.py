from rest_framework import serializers
from .models import Document, EmailHistory,User,UserSignature

class UserDetailSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ["id", "first_name", "last_name", "username", "email", "is_staff"]
        read_only_fields = ["id", "username", "is_staff"]


class EmailHistorySerializer(serializers.ModelSerializer):
    document_title = serializers.CharField(source="document.title", read_only=True)

    class Meta:
        model = EmailHistory
        fields = "__all__"
        
class DocumentSerializer(serializers.ModelSerializer):

    class Meta:
        model = Document
        fields = "__all__"

        read_only_fields = [
            "owner",
            "summary",
            "status",
            "extracted_text",
            "signed_file",
            "uploaded_at",
        ]

class UserSignatureSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserSignature
        fields = ["id", "signature", "updated_at"]


class AdminUserSerializer(serializers.ModelSerializer):
    document_count = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = [
            "id", "username", "email", "first_name", "last_name",
            "is_active", "is_staff", "date_joined", "document_count"
        ]

    def get_document_count(self, obj):
        return obj.documents.count()


class AdminDocumentSerializer(serializers.ModelSerializer):
    owner_username = serializers.CharField(source="owner.username", read_only=True)
    owner_email = serializers.CharField(source="owner.email", read_only=True)

    class Meta:
        model = Document
        fields = [
            "id", "title", "status", "owner_username", "owner_email",
            "uploaded_at", "recipient_email"
        ]