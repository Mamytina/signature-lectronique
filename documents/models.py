from django.db import models
from django.contrib.auth.models import User

class Document(models.Model):
    owner = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='documents'
    )

    title = models.CharField(max_length=255)

    file = models.FileField(upload_to='documents/')

    extracted_text = models.TextField(blank=True, null=True)

    summary = models.TextField(blank=True, null=True)

    status = models.CharField(
        max_length=20,
        default='pending'
    )

    uploaded_at = models.DateTimeField(auto_now_add=True)