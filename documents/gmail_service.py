import pickle
import base64
import os
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.application import MIMEApplication
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
from google.auth.transport.requests import Request

TOKEN_PATH = os.path.join(os.path.dirname(os.path.dirname(__file__)), "token.pickle")


def get_gmail_service():
    with open(TOKEN_PATH, "rb") as token:
        creds = pickle.load(token)

    if creds.expired and creds.refresh_token:
        creds.refresh(Request())
        with open(TOKEN_PATH, "wb") as token:
            pickle.dump(creds, token)

    return build("gmail", "v1", credentials=creds)


def send_email_with_attachment(to_email, subject, body_text, attachment_path=None, attachment_name=None):
    service = get_gmail_service()

    message = MIMEMultipart()
    message["to"] = to_email
    message["subject"] = subject
    message.attach(MIMEText(body_text, "plain"))

    if attachment_path:
        with open(attachment_path, "rb") as f:
            part = MIMEApplication(f.read(), Name=attachment_name or "document.pdf")
        part["Content-Disposition"] = f'attachment; filename="{attachment_name or "document.pdf"}"'
        message.attach(part)

    raw_message = base64.urlsafe_b64encode(message.as_bytes()).decode()

    try:
        sent = service.users().messages().send(
            userId="me",
            body={"raw": raw_message}
        ).execute()
        return sent
    except HttpError as e:
        raise Exception(f"Erreur API Gmail : {str(e)}")