from rest_framework import generics, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.http import HttpResponse

from .models import Document, EmailHistory, UserSignature
from .serializers import (
    DocumentSerializer, EmailHistorySerializer,
    UserDetailSerializer, UserSignatureSerializer
)
from .utils import extract_text_pdf
from .tasks import process_document_task

import io
import fitz  # PyMuPDF
from PIL import Image
from django.core.files.base import ContentFile

from google.oauth2 import id_token
from google.auth.transport import requests as google_requests
from django.conf import settings
from django.contrib.auth.models import User
from rest_framework.views import APIView
from rest_framework import status
from rest_framework_simplejwt.tokens import RefreshToken

from .gmail_service import send_email_with_attachment
from django.core.mail import EmailMessage
from django.utils import timezone


from rest_framework.permissions import IsAdminUser
from django.db.models import Count
from .serializers import AdminUserSerializer, AdminDocumentSerializer

class MeView(generics.RetrieveUpdateAPIView):
    serializer_class = UserDetailSerializer
    permission_classes = [IsAuthenticated]

    def get_object(self):
        return self.request.user


class UserSignatureView(generics.RetrieveUpdateAPIView):
    serializer_class = UserSignatureSerializer
    permission_classes = [IsAuthenticated]

    def get_object(self):
        obj, created = UserSignature.objects.get_or_create(user=self.request.user)
        return obj


class EmailHistoryListView(generics.ListAPIView):
    serializer_class = EmailHistorySerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return EmailHistory.objects.filter(
            document__owner=self.request.user
        ).order_by("-created_at")


class DocumentViewSet(viewsets.ModelViewSet):
    serializer_class = DocumentSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Document.objects.filter(
            owner=self.request.user
        ).order_by("-uploaded_at")

    def perform_create(self, serializer):
        serializer.save(owner=self.request.user)

    

    @action(detail=True, methods=['get'])
    def preview_info(self, request, pk=None):
        """Renvoie la page suggérée + dimensions. ?source=signed pour le fichier signé."""
        document = self.get_object()
        source = request.query_params.get("source", "original")

        if source == "signed":
            if not document.signed_file:
                return Response({"detail": "Aucun fichier signé disponible."}, status=400)
            file_path = document.signed_file.path
        else:
            file_path = document.file.path

        try:
            pdf = fitz.open(file_path)
            page_count = len(pdf)
            suggested_page = page_count - 1 if page_count > 0 else 0
            page = pdf[suggested_page]
            page_width = page.rect.width
            page_height = page.rect.height
            pdf.close()
        except Exception as e:
            return Response(
                {"detail": f"Impossible de lire le PDF : {str(e)}"},
                status=400
            )

        return Response({
            "page_count": page_count,
            "suggested_page": suggested_page,
            "page_width": page_width,
            "page_height": page_height,
        })

    @action(detail=True, methods=['get'])
    def preview(self, request, pk=None):
        """Renvoie l'image PNG d'une page. ?source=signed pour le fichier signé."""
        document = self.get_object()
        page_number = int(request.query_params.get("page", 0))
        source = request.query_params.get("source", "original")

        if source == "signed":
            if not document.signed_file:
                return Response({"detail": "Aucun fichier signé disponible."}, status=400)
            file_path = document.signed_file.path
        else:
            file_path = document.file.path

        try:
            pdf = fitz.open(file_path)
            if page_number < 0 or page_number >= len(pdf):
                page_number = 0
            page = pdf[page_number]
            pix = page.get_pixmap(matrix=fitz.Matrix(2, 2))
            img_bytes = pix.tobytes("png")
            pdf.close()
        except Exception as e:
            return Response(
                {"detail": f"Impossible de générer l'aperçu : {str(e)}"},
                status=400
            )

        response = HttpResponse(img_bytes, content_type="image/png")
        response["Cache-Control"] = "no-store, no-cache, must-revalidate, max-age=0"
        response["Pragma"] = "no-cache"
        return response

    @action(detail=True, methods=['post'])
    def sign(self, request, pk=None):
        document = self.get_object()

        page_number = int(request.data.get("page", -1))
        x_ratio = float(request.data.get("x", 0.5))
        y_ratio = float(request.data.get("y", 0.5))
        width_ratio = float(request.data.get("width", 0.28))

        uploaded_signature = request.FILES.get("signature_image")

        if uploaded_signature:
            signature_image = Image.open(uploaded_signature)
        else:
            try:
                user_signature = UserSignature.objects.get(user=request.user)
                if not user_signature.signature:
                    raise UserSignature.DoesNotExist
            except UserSignature.DoesNotExist:
                return Response({"detail": "Aucune signature disponible."}, status=400)
            signature_image = Image.open(user_signature.signature.path)

        pdf = fitz.open(document.file.path)
        if page_number == -1:
            page_number = len(pdf) - 1
        page = pdf[page_number]

        page_width, page_height = page.rect.width, page.rect.height

        aspect = signature_image.height / signature_image.width
        sig_width_pt = page_width * width_ratio
        sig_height_pt = sig_width_pt * aspect

        x0 = (page_width * x_ratio) - (sig_width_pt / 2)
        y0 = (page_height * y_ratio) - (sig_height_pt / 2)
        rect = fitz.Rect(x0, y0, x0 + sig_width_pt, y0 + sig_height_pt)

        img_io = io.BytesIO()
        signature_image.convert("RGBA").save(img_io, format="PNG")
        page.insert_image(rect, stream=img_io.getvalue())

        output = pdf.tobytes()
        pdf.close()

        filename = f"signed_{document.id}_{document.title}.pdf"
        document.signed_file.save(filename, ContentFile(output), save=False)
        document.status = "signed"
        document.save()

        return Response({
            "message": "Document signé avec succès",
            "signed_file": request.build_absolute_uri(document.signed_file.url),
            "status": document.status,
        })

    @action(detail=True, methods=['post'])
    def summarize(self, request, pk=None):
        document = self.get_object()

        if document.status == "completed":
            return Response({
                "status": "completed",
                "summary": document.summary
            })

        document.status = "processing"
        document.save()

        process_document_task.delay(document.id)

        return Response({
            "message": "Résumé lancé",
            "status": "processing"
        })
    @action(detail=True, methods=['post'])
    def send_email(self, request, pk=None):
        document = self.get_object()
        recipient_email = request.data.get("recipient_email") or document.recipient_email

        if not recipient_email:
            return Response({"detail": "Adresse email destinataire requise."}, status=400)

        if not document.signed_file:
            return Response({"detail": "Aucun document signé à envoyer."}, status=400)

        subject = request.data.get("subject") or f"Document signé : {document.title}"
        message = request.data.get("message") or (
            f"Bonjour,\n\n"
            f"Le document \"{document.title}\" a été signé avec succès.\n"
            f"Vous trouverez le fichier signé en pièce jointe.\n\n"
            f"Cordialement."
        )

        try:
            email_history = EmailHistory.objects.create(
                document=document,
                recipient_email=recipient_email,
                subject=subject,
                status="pending",
            )
        except Exception as e:
            return Response({"detail": f"Erreur historique : {str(e)}"}, status=500)

        try:
            send_email_with_attachment(
                to_email=recipient_email,
                subject=subject,
                body_text=message,
                attachment_path=document.signed_file.path,
                attachment_name=f"{document.title}_signe.pdf",
            )

            email_history.status = "sent"
            email_history.sent_at = timezone.now()
            email_history.save()

            document.recipient_email = recipient_email
            document.save(update_fields=["recipient_email"])

            return Response({
                "message": "Email envoyé avec succès",
                "status": "sent",
            })
        except Exception as e:
            email_history.status = "failed"
            email_history.error_message = str(e)
            email_history.save()
            return Response({"detail": f"Erreur lors de l'envoi : {str(e)}"}, status=500)

class GoogleLoginView(APIView):
    permission_classes = []

    def post(self, request):
        token = request.data.get("id_token")

        if not token:
            return Response({"detail": "id_token manquant"}, status=status.HTTP_400_BAD_REQUEST)

        try:
            idinfo = id_token.verify_oauth2_token(
                token, google_requests.Request(), settings.GOOGLE_CLIENT_ID
            )
        except ValueError:
            return Response({"detail": "Token Google invalide"}, status=status.HTTP_401_UNAUTHORIZED)

        email = idinfo.get("email")
        first_name = idinfo.get("given_name", "")
        last_name = idinfo.get("family_name", "")

        if not email:
            return Response({"detail": "Email introuvable dans le token Google"}, status=status.HTTP_400_BAD_REQUEST)

        user, created = User.objects.get_or_create(
            email=email,
            defaults={
                "username": email.split("@")[0],
                "first_name": first_name,
                "last_name": last_name,
            }
        )

        refresh = RefreshToken.for_user(user)

        return Response({
            "refresh": str(refresh),
            "access": str(refresh.access_token),
            "email": user.email,
            "username": user.username,
            "created": created,
        })

class AdminStatsView(APIView):
    permission_classes = [IsAuthenticated, IsAdminUser]

    def get(self, request):
        total_users = User.objects.count()
        active_users = User.objects.filter(is_active=True).count()
        total_documents = Document.objects.count()

        docs_by_status = dict(
            Document.objects.values_list("status").annotate(count=Count("id"))
        )

        total_emails_sent = EmailHistory.objects.filter(status="sent").count()
        total_emails_failed = EmailHistory.objects.filter(status="failed").count()

        return Response({
            "total_users": total_users,
            "active_users": active_users,
            "inactive_users": total_users - active_users,
            "total_documents": total_documents,
            "documents_by_status": {
                "pending": docs_by_status.get("pending", 0),
                "processing": docs_by_status.get("processing", 0),
                "completed": docs_by_status.get("completed", 0),
                "signed": docs_by_status.get("signed", 0),
            },
            "total_emails_sent": total_emails_sent,
            "total_emails_failed": total_emails_failed,
        })


class AdminUserListView(generics.ListAPIView):
    serializer_class = AdminUserSerializer
    permission_classes = [IsAuthenticated, IsAdminUser]
    queryset = User.objects.all().order_by("-date_joined")


class AdminUserToggleActiveView(APIView):
    permission_classes = [IsAuthenticated, IsAdminUser]

    def post(self, request, user_id):
        try:
            user = User.objects.get(id=user_id)
        except User.DoesNotExist:
            return Response({"detail": "Utilisateur introuvable."}, status=404)

        if user.id == request.user.id:
            return Response({"detail": "Vous ne pouvez pas désactiver votre propre compte."}, status=400)

        user.is_active = not user.is_active
        user.save(update_fields=["is_active"])

        return Response({
            "id": user.id,
            "is_active": user.is_active,
            "message": f"Utilisateur {'activé' if user.is_active else 'désactivé'} avec succès",
        })


class AdminDocumentListView(generics.ListAPIView):
    serializer_class = AdminDocumentSerializer
    permission_classes = [IsAuthenticated, IsAdminUser]
    queryset = Document.objects.all().order_by("-uploaded_at")