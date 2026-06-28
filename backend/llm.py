import os
import logging
from dotenv import load_dotenv
from google import genai
from google.genai import types

load_dotenv(os.path.join(os.path.dirname(__file__), ".env"))
logger = logging.getLogger(__name__)

def get_client(use_paid: bool = False) -> genai.Client:
    if use_paid:
        api_key = os.getenv("GEMINI_API_KEY_PAID")
        if not api_key:
            raise ValueError("GEMINI_API_KEY_PAID is not set in the environment.")
        return genai.Client(api_key=api_key)
    else:
        # Default fallback to standard GEMINI_API_KEY
        api_key = os.getenv("GEMINI_API_KEY")
        if not api_key:
            raise ValueError("GEMINI_API_KEY is not set in the environment.")
        return genai.Client(api_key=api_key)

def extract_card_info(image_path: str) -> str:
    """
    Takes an image path of a Pokémon card and uses Gemini to extract 
    the exact search string needed for TCGplayer.
    Attempts to use the free tier first, and falls back to a paid tier key if it fails (e.g. rate limit).
    """
    # The optimized zero-fluff prompt
    prompt = """You are a precise, zero-fluff text extraction assistant optimized for generating TCGplayer search queries from images of Pokémon cards.

Analyze the provided image of the Pokémon card and output a single search string following these strict constraints:

### 1. Search Format
Output the result strictly in this format: 
[Pokémon Name] [Mechanic Suffix] [Card Number]

### 2. Name & Mechanic Rules
* Extract the Pokémon's exact name (e.g., Meowth, Lucario, Rayquaza).
* Include the gameplay mechanic suffix ONLY if it is part of the card's official name title line (e.g., EX, ex, GX, V, VMAX, VSTAR, Mega, BREAK). 
* Do NOT include aesthetic variants or rarity descriptors. Never include words like "Full Art", "Alternate Art", "Alt Art", "Secret Rare", "Rainbow Rare", "Shiny", or "Illustration Rare". These terms break TCGplayer's search bar.

### 3. Card Number Rules (Strict Zero-Hallucination)
* Scan the bottom-left and bottom-right corners for the collector number (e.g., 123/185, SWSH012, GG44).
* CRITICAL: Only include the card number if you can physically see and read it with 100% absolute certainty. 
* If the number is blurry, cut off, obscured by glare, too small to read, or if you are even 1% uncertain, OMIT the number entirely. It is far better to leave the number out than to guess or misread a single digit.

### 4. Output Constraints
* Output ONLY the clean search string. 
* Do not include any introductory text, pleasantries, markdown formatting, explanations, or punctuation.

### Examples of Correct Output:
* Image shows a clear Meowth EX with a visible number: Meowth EX 12/108
* Image shows a Lucario VMAX, but the corner is blurry: Lucario VMAX
* Image shows a full-art Umbreon VMAX, number is perfectly clear: Umbreon VMAX 215/203
"""

    mime_type = "image/jpeg"
    ext = image_path.lower().split('.')[-1]
    if ext == "png":
        mime_type = "image/png"
    elif ext == "webp":
        mime_type = "image/webp"
    elif ext == "heic":
        mime_type = "image/heic"

    with open(image_path, "rb") as f:
        image_bytes = f.read()
    image_part = types.Part.from_bytes(data=image_bytes, mime_type=mime_type)

    def attempt_extraction(use_paid: bool) -> str:
        client = get_client(use_paid=use_paid)
        response = client.models.generate_content(
            model="gemini-3.1-flash-lite",
            contents=[image_part, prompt]
        )
        return response.text.strip()

    try:
        # First attempt with free key
        logger.info("Attempting extraction with primary Gemini API key (Free Tier)...")
        return attempt_extraction(use_paid=False)
    except Exception as e:
        logger.warning(f"Primary Gemini API key failed ({e}). Falling back to paid key...")
        try:
            # Fallback to paid key
            return attempt_extraction(use_paid=True)
        except Exception as e_paid:
            logger.error(f"Paid Gemini API key also failed: {e_paid}")
            return ""

if __name__ == "__main__":
    sample_image = "PXL_20260624_015031568.jpg"
    if os.path.exists(sample_image):
        print(extract_card_info(sample_image))
