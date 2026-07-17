from pypdf import PdfReader
from docx import Document as DocxDocument
import os

def extract_text_pdf(file_path):

    ext = os.path.splitext(file_path)[1].lower()

    # 📄 PDF
    if ext == ".pdf":
        text = ""
        try:
            reader = PdfReader(file_path)
            for page in reader.pages:
                text += page.extract_text() or ""
            return text
        except Exception as e:
            return f"Erreur PDF: {str(e)}"

    # 📝 Word
    elif ext == ".docx":
        doc = DocxDocument(file_path)
        text = "\n".join([para.text for para in doc.paragraphs])
        return text

    else:
        return "Format non supporté"
    


