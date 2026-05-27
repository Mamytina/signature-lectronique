import os
from openai import RateLimitError
from dotenv import load_dotenv
from openai import OpenAI

load_dotenv()

api_key = os.getenv("OPENAI_API_KEY")


client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))


def summarize_text(text):
    try:
        response = client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[
                {
                    "role": "system",
                    "content": "Tu résumes les documents de manière claire et professionnelle."
                },
                {
                    "role": "user",
                    "content": f"Résume ce document : {text}"
                }
            ],
            temperature=0.3
        )

        return response.choices[0].message.content

    except RateLimitError:
        return "Le service IA est temporairement indisponible (quota dépassé)."

    except Exception as e:
        return f"Erreur IA : {str(e)}"