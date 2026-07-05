import httpx
import base64
import os
import logging

logger = logging.getLogger(__name__)

async def identify_card_tcgdb(image_path: str) -> str | None:
    api_key = os.environ.get('tcgdb_api')
    if not api_key:
        logger.error("tcgdb_api environment variable not found")
        return None

    try:
        with open(image_path, "rb") as image_file:
            encoded_string = base64.b64encode(image_file.read()).decode('utf-8')
            # Use jpeg as a default, the API will parse the data URI
            image_data = f"data:image/jpeg;base64,{encoded_string}"
            
        url = 'https://tcgdb.org/api/external/identify'
        headers = {
            'Content-Type': 'application/json',
            'X-API-Key': api_key
        }
        payload = {
            'imageData': image_data
        }
        
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(url, headers=headers, json=payload)
            
        if response.status_code == 429:
            logger.warning("TCGdb API rate limit reached.")
            return None
            
        if response.status_code != 200:
            logger.warning(f"TCGdb API failed with status code {response.status_code}: {response.text}")
            return None
            
        data = response.json()
        if data.get('success') and 'data' in data:
            card_data = data['data']
            name = card_data.get('name')
            card_number = card_data.get('cardNumber')
            
            # Construct search query from name and cardNumber
            if name and card_number:
                return f"{name} {card_number}"
            elif name:
                return name
                
        return None
    except Exception as e:
        logger.error(f"Error calling TCGdb API: {e}")
        return None
