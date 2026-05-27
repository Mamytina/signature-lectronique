from rest_framework.exceptions import ValidationError

MAX_FILE_SIZE = 5 * 1024 * 1024  # 5 MB


def validate_pdf(file):

    # Vérification extension
    if not file.name.endswith('.pdf'):
        raise ValidationError("Only PDF files are allowed.")

    # Vérification content type
    if file.content_type != 'application/pdf':
        raise ValidationError("Invalid PDF file.")

    # Vérification taille
    if file.size > MAX_FILE_SIZE:
        raise ValidationError("File too large. Max 5MB.")