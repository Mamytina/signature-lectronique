from django.db import models
from django.contrib.auth.models import User
# Create your models here.
class UserSignature(models.Model):

    user = models.OneToOneField(
        User,
        on_delete=models.CASCADE,
        related_name="signature"
    )

    signature = models.ImageField(
        upload_to="signatures/",
        blank=True,
        null=True
    )

    created_at = models.DateTimeField(auto_now_add=True)

    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.user.username