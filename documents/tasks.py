from celery import shared_task
from django.core.mail import EmailMessage
from django.utils import timezone
from .models import Document, EmailHistory
from .services import summarize_text
from .utils import extract_text_pdf
import time


@shared_task
def extract_text_task(document_id):
    """
    Extrait le texte du document dès l'upload.
    Ne touche pas au résumé ni au statut 'completed'.
    """
    try:
        document = Document.objects.get(id=document_id)
    except Document.DoesNotExist:
        print(f"Document {document_id} introuvable")
        return

    try:
        text = extract_text_pdf(document.file.path)
        document.extracted_text = text
        document.save()
        print(f"✅ Texte extrait pour le document {document_id}")

    except Exception as e:
        document.status = "failed"
        document.summary = f"Erreur lors de l'extraction du texte : {str(e)}"
        document.save()
        print("Celery error (extract):", e)


@shared_task
def process_document_task(document_id):
    """
    Génère le résumé à partir du texte déjà extrait.
    Si le texte n'a pas encore été extrait (edge case), l'extrait d'abord.
    """
    try:
        document = Document.objects.get(id=document_id)
    except Document.DoesNotExist:
        print(f"Document {document_id} introuvable")
        return

    try:
        document.status = "processing"
        document.save()

        # Sécurité : si extracted_text est vide (extraction pas encore faite
        # ou échouée), on l'extrait maintenant avant de résumer
        if not document.extracted_text:
            text = extract_text_pdf(document.file.path)
            document.extracted_text = text
            document.save()
        else:
            text = document.extracted_text

        time.sleep(1)  # petite pause anti-spam API

        summary = summarize_text(text)
        document.summary = summary
        document.status = "failed" if summary.startswith("Erreur") else "completed"
        document.save()

    except Exception as e:
        document.status = "failed"
        document.summary = f"Erreur lors de la génération du résumé : {str(e)}"
        document.save()
        print("Celery error (summarize):", e)


@shared_task
def send_signed_document_email(document_id):
    document = Document.objects.get(id=document_id)

    recipient = document.recipient_email or "email_non_configure@test.com"

    email_history = EmailHistory.objects.create(
        document=document,
        recipient_email=recipient,
        subject="Document signé",
        status="pending",
    )

    try:
        email = EmailMessage(
            subject="Document signé",
            body="""
Bonjour,

Votre document a été signé avec succès.

Cordialement.
""",
            to=[recipient],
        )

        if document.signed_file:
            email.attach_file(document.signed_file.path)

        email.send()

        email_history.status = "sent"
        email_history.sent_at = timezone.now()
        email_history.save()

        return "Email envoyé"

    except Exception as e:
        email_history.status = "failed"
        email_history.error_message = str(e)
        email_history.save()
        return "Erreur envoi email"