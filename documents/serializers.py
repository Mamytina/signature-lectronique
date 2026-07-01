from rest_framework import serializers
from .models import Document, EmailHistory,User

class UserDetailSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ["id", "first_name", "last_name", "username", "email"]
        read_only_fields = ["id", "username"]


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