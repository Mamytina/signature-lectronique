from celery import shared_task
from .models import Document
from .services import process_document
import time


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