# Pokemon Cost Scraper

A full-stack application that allows you to point a camera at a Pokémon card, identify it using AI (Gemini), and retrieve real-time market data from TCGplayer.

## Architecture

*   **Frontend (Flutter):** A custom, Halo-HUD-themed Android/iOS app that captures images, handles the UI flows, and presents the scraped TCGplayer data.
*   **Backend (Python/FastAPI):** A secure REST API that uses Google's Gemini models to extract search intents from the raw images, and headless Playwright to scrape real-time market data from TCGplayer.

## Prerequisites

*   Flutter SDK (v3.12+)
*   Python 3.10+
*   Playwright

## Backend Setup

1.  Navigate to the `backend` directory.
2.  Install dependencies:
    ```bash
    pip install -r requirements.txt
    playwright install
    ```
3.  Create a `.env` file in the `backend` directory with the following keys:
    ```env
    GEMINI_API_KEY=your_gemini_api_key
    GEMINI_API_KEY_PAID=your_paid_gemini_api_key_if_applicable
    API_KEY=your_secure_backend_authentication_token
    ```
4.  Run the API server:
    ```bash
    uvicorn backend.api:app --host 0.0.0.0 --port 8000 --reload
    ```

## Frontend Setup

1.  Navigate to the `flutter_app` directory.
2.  Install Flutter dependencies:
    ```bash
    flutter pub get
    ```
3.  Create a `.env` file in the `flutter_app` directory with the matching API base URL and token:
    ```env
    API_BASE_URL=http://<your_local_ip>:8000
    API_KEY=your_secure_backend_authentication_token
    ```
4.  Run the app on a connected device or emulator:
    ```bash
    flutter run
    ```

## Features

*   **Halo UI:** Frosted glassmorphism, animated scanlines, tactical reticles.
*   **AI Vision:** Uses Gemini 3.1 Flash Lite to extract card name, sets, and mechanical details without hallucinating.
*   **Web Scraping:** Uses asynchronous Playwright to fetch accurate, real-time sales data from TCGplayer.
*   **Secured APIs:** Communicates using a Bearer token across the frontend and backend.
