from .utils import extract_text_pdf
from ai.services import summarize_text


def process_document(document):
    text = extract_text_pdf(document.file.path)

    summary = summarize_text(text)

    return {
        "text": text,
        "summary": summary
    }