from rest_framework import generics, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated

from .models import Document,EmailHistory
from .serializers import DocumentSerializer, EmailHistorySerializer
from .utils import extract_text_pdf
from .tasks import process_document_task
from .serializers import UserDetailSerializer


class MeView(generics.RetrieveUpdateAPIView):
    serializer_class = UserDetailSerializer
    permission_classes = [IsAuthenticated]

    def get_object(self):
        return self.request.user

class EmailHistoryListView(generics.ListAPIView):
    serializer_class = EmailHistorySerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return EmailHistory.objects.filter(
            document__owner=self.request.user
        ).order_by("-created_at")


class DocumentViewSet(viewsets.ModelViewSet):

    permission_classes = [IsAuthenticated]

    serializer_class = DocumentSerializer


    def get_queryset(self):
        return Document.objects.filter(
            owner=self.request.user
        )


    def perform_create(self, serializer):
        serializer.save(
            owner=self.request.user
        )


    @action(
        detail=True,
        methods=['get']
    )
    def extract_text(self, request, pk=None):

        document = self.get_object()

        text = extract_text_pdf(
            document.file.path
        )

        document.extracted_text = text
        document.save()

        return Response({
            "text": text
        })


    @action(
        detail=True,
        methods=['post']
    )
    def summarize(self, request, pk=None):

        document = self.get_object()


        if document.status == "completed":

            return Response({
                "status": "completed",
                "summary": document.summary
            })


        document.status = "processing"
        document.save()


        process_document_task.delay(
            document.id
        )


        return Response({
            "message": "Résumé lancé",
            "status": "processing"
        })
    

    