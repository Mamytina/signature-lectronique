from celery import shared_task
from .models import Document
from .services import process_document
import time
from celery import shared_task
from django.core.mail import EmailMessage

from django.utils import timezone
from .models import Document, EmailHistory

@shared_task
def process_document_task(document_id):
    document = Document.objects.get(id=document_id)

    try:
        document.status = "processing"
        document.save()

        # petite pause anti spam API
        time.sleep(1)

        result = process_document(document)

        document.extracted_text = result["text"]
        document.summary = result["summary"]
        document.status = "done"
        document.save()

    except Exception as e:
        document.status = "failed"
        document.summary = "Error generating summary"
        document.save()
        print("Celery error:", e)





@shared_task
def send_signed_document_email(document_id):

    document = Document.objects.get(
        id=document_id
    )


    email_history = EmailHistory.objects.create(

        document=document,

        recipient_email=
            document.recipient_email 
            or "email_non_configure@test.com",

        subject="Document signé",

        status="pending"
    )


    try:

        # ==================================
        # SIMULATION POUR LE MOMENT
        # ==================================

        print(
            f"""
            ==========================
            EMAIL SIMULE

            Document :
            {document.title}

            Destinataire :
            {email_history.recipient_email}

            Message :
            Votre document a été signé.

            ==========================
            """
        )


        # Plus tard ici :
        #
        # email.send()


        email_history.status = "sent"

        email_history.sent_at = timezone.now()

        email_history.save()


    except Exception as e:


        email_history.status = "failed"

        email_history.error_message = str(e)

        email_history.save()


    return "Email traité"