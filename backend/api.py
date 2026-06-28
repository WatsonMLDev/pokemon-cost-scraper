from contextlib import asynccontextmanager
from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
import shutil
import os
import json
import logging
import asyncio
from tempfile import NamedTemporaryFile
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi import Depends

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] backend: %(message)s")
logger = logging.getLogger(__name__)

security = HTTPBearer()

def verify_token(credentials: HTTPAuthorizationCredentials = Depends(security)):
    expected_token = os.environ.get("API_KEY")
    if credentials.credentials != expected_token:
        raise HTTPException(status_code=401, detail="Invalid authentication token")
    return credentials.credentials

from backend.llm import extract_card_info
from backend.tcg_scraper import search_cards, scrape_card_data, init_crawler, close_crawler

@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_crawler()
    yield
    await close_crawler()

app = FastAPI(lifespan=lifespan)

class ScrapeRequest(BaseModel):
    url: str
    name: str

class SearchTextRequest(BaseModel):
    query: str

@app.post("/api/v1/search_by_image")
async def search_by_image(file: UploadFile = File(...), token: str = Depends(verify_token)):
    async def event_stream():
        logger.info(f"Received image for search: {file.filename}")
        yield json.dumps({"type": "status", "message": "Receiving image..."}) + "\n"
        
        temp_file = NamedTemporaryFile(delete=False, suffix=f"_{file.filename}")
        try:
            with open(temp_file.name, "wb") as buffer:
                shutil.copyfileobj(file.file, buffer)
                
            # 1. Identify card query from image
            logger.info("Extracting card info using LLM...")
            yield json.dumps({"type": "status", "message": "Parsing details (LLM)..."}) + "\n"
            
            query = await asyncio.to_thread(extract_card_info, temp_file.name)
            if not query:
                logger.error("Failed to extract search query from image")
                yield json.dumps({"type": "error", "message": "Could not extract search query from image"}) + "\n"
                return
                
            # 2. Search TCGPlayer
            logger.info(f"Searching TCGPlayer for query: {query}")
            yield json.dumps({"type": "status", "message": f"Searching for: {query}"}) + "\n"
            
            results = await search_cards(query)
            logger.info(f"Found {len(results)} results for query: {query}")
            
            yield json.dumps({
                "type": "result",
                "data": {
                    "query": query,
                    "search_items": results
                }
            }) + "\n"
            
        except Exception as e:
            logger.error(f"Error in search_by_image stream: {e}")
            yield json.dumps({"type": "error", "message": str(e)}) + "\n"
        finally:
            if os.path.exists(temp_file.name):
                os.remove(temp_file.name)
                
    return StreamingResponse(event_stream(), media_type="application/x-ndjson")

@app.post("/api/v1/search_by_text")
async def search_by_text(req: SearchTextRequest, token: str = Depends(verify_token)):
    async def event_stream():
        logger.info(f"Received text search for query: {req.query}")
        try:
            # 2. Search TCGPlayer
            logger.info(f"Searching TCGPlayer for query: {req.query}")
            yield json.dumps({"type": "status", "message": f"Searching for: {req.query}"}) + "\n"
            
            results = await search_cards(req.query)
            logger.info(f"Found {len(results)} results for query: {req.query}")
            
            yield json.dumps({
                "type": "result",
                "data": {
                    "query": req.query,
                    "search_items": results
                }
            }) + "\n"
            
        except Exception as e:
            logger.error(f"Error in search_by_text stream: {e}")
            yield json.dumps({"type": "error", "message": str(e)}) + "\n"
            
    return StreamingResponse(event_stream(), media_type="application/x-ndjson")

@app.post("/api/v1/scrape_card")
async def scrape_card(req: ScrapeRequest, token: str = Depends(verify_token)):
    async def event_stream():
        logger.info(f"Scraping detailed data for: {req.name}")
        try:
            async for chunk in scrape_card_data(req.url, req.name):
                yield json.dumps(chunk) + "\n"
            logger.info(f"Successfully scraped data for: {req.name}")
        except Exception as e:
            logger.error(f"Error scraping card data for {req.name}: {e}")
            yield json.dumps({"type": "error", "message": str(e)}) + "\n"
            
    return StreamingResponse(event_stream(), media_type="application/x-ndjson")
