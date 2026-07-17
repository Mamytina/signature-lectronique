
from openai import OpenAI
import os
import logging

logger = logging.getLogger(__name__)

client = OpenAI(
    api_key=os.getenv("OPENROUTER_API_KEY"),
    base_url="https://openrouter.ai/api/v1",
)


def summarize_text(text: str, max_chars: int = 8000) -> str:
    """
    Résume un texte via un modèle LLM (OpenRouter).
    Retourne le résumé, ou un message d'erreur préfixé par 'Erreur'
    en cas d'échec (utilisé par le task Celery pour détecter l'échec).
    """
    if not text or not text.strip():
        return "Aucun texte à résumer"

    if not os.getenv("OPENROUTER_API_KEY"):
        logger.error("OPENROUTER_API_KEY manquante")
        return "Erreur : clé API non configurée"

    try:
        response = client.chat.completions.create(
            model="openai/gpt-4o-mini",
            max_tokens=500,
            temperature=0.3,
            messages=[
                {
                    "role": "system",
                    "content": (
                        "Tu es un assistant qui résume des documents "
                        "clairement et de façon concise, en 3 à 5 phrases."
                    ),
                },
                {
                    "role": "user",
                    "content": text[:max_chars],
                },
            ],
            extra_headers={
                "HTTP-Referer": "http://127.0.0.1:8000",
                "X-Title": "Signature App",
            },
            timeout=30,
        )
        return response.choices[0].message.content

    except Exception as e:
        logger.exception("Erreur lors de l'appel au service de résumé")
        return f"Erreur lors de la génération du résumé : {str(e)}"