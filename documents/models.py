from django.db import models
from django.contrib.auth.models import User


class Document(models.Model):

    STATUS = [
        ("pending", "Pending"),
        ("processing", "Processing"),
        ("completed", "Completed"),
        ("signed", "Signed"),
    ]

    owner = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="documents"
    )

    title = models.CharField(max_length=255)

    file = models.FileField(upload_to="documents/")

    extracted_text = models.TextField(
    blank=True,
    null=True
    )

    summary = models.TextField(
        blank=True,
        null=True
)

    recipient_email = models.EmailField(
        blank=True,
        null=True
    )

    signed_file = models.FileField(
        upload_to="signed_documents/",
        blank=True,
        null=True
    )

    status = models.CharField(
        max_length=20,
        choices=STATUS,
        default="pending"
    )

    
    uploaded_at = models.DateTimeField(auto_now_add=True)

    


   


class EmailHistory(models.Model):

    STATUS_CHOICES = [
        ("pending", "Pending"),
        ("sent", "Sent"),
        ("failed", "Failed"),
    ]


    document = models.ForeignKey(
        Document,
        on_delete=models.CASCADE,
        related_name="email_history"
    )


    recipient_email = models.EmailField()


    subject = models.CharField(
        max_length=255
    )


    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default="pending"
    )


    error_message = models.TextField(
        blank=True,
        null=True
    )


    sent_at = models.DateTimeField(
        blank=True,
        null=True
    )


    created_at = models.DateTimeField(
        auto_now_add=True
    )


    def __str__(self):
        return f"{self.document.title} - {self.status}"