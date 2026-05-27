from rest_framework import viewsets
from rest_framework.decorators import action
from .models import Document
from .serializers import DocumentSerializer
from .utils import extract_text_pdf
from rest_framework.response import Response
from .tasks import process_document_task
from rest_framework.permissions import IsAuthenticated
   

class DocumentViewSet(viewsets.ModelViewSet):
    permission_classes = [IsAuthenticated]
    queryset = Document.objects.all()
    serializer_class = DocumentSerializer

    def get_queryset(self):
        return Document.objects.filter(owner=self.request.user)

    def perform_create(self, serializer):
        serializer.save(owner=self.request.user)

    @action(detail=True, methods=['get'])
    def extract_text(self, request, pk=None):
        document = self.get_object()
        file_path = document.file.path

        text = extract_text_pdf(file_path)

        return Response({
        "id": document.id,
        "title": document.title,
        "text": text
    })

   

    @action(detail=True, methods=['get'])
    def summarize(self, request, pk=None):
        document = self.get_object()

        # si déjà fait → pas refaire appel IA
        if document.status == "done":
            return Response({
                "status": document.status,
                "summary": document.summary,
                "cached": True
            })

        document.status = "processing"
        document.save()

        process_document_task.delay(document.id)

        return Response({
            "status": "processing",
            "message": "Task started"
    })