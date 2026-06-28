"""
app.py — PKMN_VAL_V1.0 Halo HUD Client
Runs main.lua in a 2x scaled pygame window with a circular mask.
Communicates with the FastAPI backend to fetch card data.
"""

import os
import threading
import time
import logging
import httpx
import json
from typing import Any

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] frontend: %(message)s")
logger = logging.getLogger(__name__)

os.environ.setdefault("SDL_VIDEO_WINDOW_POS", "200,80")

from halo_emulator import HaloEmulator

APP_DIR = "./frontend"
API_BASE = "http://127.0.0.1:8000"

MSG_CARD_DATA    = 0x01
MSG_SEARCH_ITEMS = 0x02
MSG_STATUS       = 0x05

# Global state to keep track of the current search results
last_search_results = []

def pack_card_data(data: dict) -> bytes:
    lines = [data["name"]]
    for cond in data.get("conditions", []):
        lines.append(f"{cond['short']}|{cond['long']}")
        for sale in cond.get("sales", []):
            lines.append(f"{sale['date']}|{sale['type']}|{sale['qty']}|{sale['price']}")
        lines.append("---")
    payload = "\n".join(lines)
    return bytes([MSG_CARD_DATA]) + payload.encode("ascii", errors="replace")


def pack_search_items(items: list[dict]) -> bytes:
    lines = [f"{item['name']}|{item.get('num', '')}" for item in items]
    payload = "\n".join(lines)
    return bytes([MSG_SEARCH_ITEMS]) + payload.encode("ascii", errors="replace")


# ---------------------------------------------------------------------------
# API / Data Fetching
# ---------------------------------------------------------------------------

def send_status(emulator, status_text: str):
    logger.info(f"Sending status to Lua: {status_text}")
    payload = bytes([MSG_STATUS]) + status_text.encode("ascii", errors="replace")
    emulator.inject_bluetooth_data(payload)

def fetch_search_results(emulator):
    """
    Called when user double-taps to scan. In a real app, this would capture
    the camera image. Here we just upload a test image.
    """
    test_img_path = "PXL_20260624_015031568.jpg"
    
    send_status(emulator, "Connecting to server...")
    
    try:
        with httpx.Client(timeout=30.0) as client:
            with open(test_img_path, "rb") as f:
                logger.info(f"Uploading {test_img_path} to backend...")
                files = {"file": ("scan.jpg", f, "image/jpeg")}
                with client.stream("POST", API_BASE + "/api/v1/search_by_image", files=files) as response:
                    response.raise_for_status()
                    for line in response.iter_lines():
                        if not line: continue
                        chunk = json.loads(line)
                        if chunk.get("type") == "status":
                            send_status(emulator, chunk["message"])
                        elif chunk.get("type") == "result":
                            results = chunk["data"]["search_items"]
                            logger.info(f"Found {len(results)} items.")
                            
                            global last_search_results
                            last_search_results = results
                            
                            if len(results) > 0:
                                payload = pack_search_items(results)
                                emulator.inject_bluetooth_data(payload)
                                logger.info("Search items injected.")
                            else:
                                send_status(emulator, "No results found.")
                        elif chunk.get("type") == "error":
                            logger.error(f"Backend error: {chunk['message']}")
                            send_status(emulator, "Error: " + chunk["message"][:20])

    except Exception as e:
        logger.error(f"Failed to fetch search results: {e}")
        send_status(emulator, "Connection failed.")


def fetch_card_data(idx: int, emulator):
    """
    Called when user selects a specific search item (1-indexed).
    """
    global last_search_results
    if not last_search_results or idx < 1 or idx > len(last_search_results):
        logger.error(f"Invalid selection index: {idx}")
        send_status(emulator, "Invalid selection.")
        return

    item = last_search_results[idx - 1]
    logger.info(f"Scraping data for {item['name']}...")
    send_status(emulator, "Connecting to server...")

    try:
        with httpx.Client(timeout=60.0) as client:
            req_data = {"url": item["url"], "name": item["name"]}
            with client.stream("POST", API_BASE + "/api/v1/scrape_card", json=req_data) as response:
                response.raise_for_status()
                for line in response.iter_lines():
                    if not line: continue
                    chunk = json.loads(line)
                    if chunk.get("type") == "status":
                        send_status(emulator, chunk["message"])
                    elif chunk.get("type") == "result":
                        card_data = chunk["data"]
                        payload = pack_card_data(card_data)
                        emulator.inject_bluetooth_data(payload)
                        logger.info("Card data injected.")
                    elif chunk.get("type") == "error":
                        logger.error(f"Backend error: {chunk['message']}")
                        send_status(emulator, "Error: " + chunk["message"][:20])
                        
    except Exception as e:
        logger.error(f"Failed to fetch card data: {e}")
        send_status(emulator, "Connection failed.")


def run_pygame_window(emulator: HaloEmulator) -> None:
    import pygame

    SCALE = 2
    W, H = 256 * SCALE, 256 * SCALE

    pygame.display.init()
    screen = pygame.display.set_mode((W, H))
    pygame.display.set_caption("PKMN_VAL_V1.0 — Halo Emulator")
    clock = pygame.time.Clock()

    mask = pygame.Surface((W, H), pygame.SRCALPHA)
    mask.fill((18, 18, 18, 255))
    pygame.draw.circle(mask, (0, 0, 0, 0), (W // 2, H // 2), W // 2)

    ring = pygame.Surface((W, H), pygame.SRCALPHA)
    ring.fill((0, 0, 0, 0))
    pygame.draw.circle(ring, (50, 50, 50, 255), (W // 2, H // 2), W // 2,     width=6)
    pygame.draw.circle(ring, (30, 30, 30, 255), (W // 2, H // 2), W // 2 - 6, width=4)

    key_map = {
        pygame.K_SPACE: emulator.inject_button_single,
        pygame.K_t:     emulator.inject_imu_tap,
        pygame.K_l:     emulator.inject_button_long,
        pygame.K_d:     emulator.inject_button_double,
    }

    while emulator.is_running():
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                emulator.stop()
                return
            if event.type == pygame.KEYDOWN:
                fn = key_map.get(event.key)
                if fn:
                    fn()

        # Handle Bluetooth messages from Lua
        sent_data = emulator.get_bluetooth_sent()
        emulator.clear_bluetooth_sent()
        for data in sent_data:
            if len(data) > 0:
                msg_type = data[0]
                if msg_type == 0x03 and len(data) >= 2:
                    # Search result selected
                    idx = data[1]
                    logger.info(f"Received selection index: {idx} from Lua")
                    threading.Thread(target=fetch_card_data, args=(idx, emulator), daemon=True).start()
                elif msg_type == 0x04:
                    # Scan requested
                    logger.info("Received scan request from Lua")
                    threading.Thread(target=fetch_search_results, args=(emulator,), daemon=True).start()

        img     = emulator.get_framebuffer()
        surface = pygame.image.fromstring(img.tobytes(), (256, 256), img.mode)
        scaled  = pygame.transform.scale(surface, (W, H))
        scaled.blit(mask, (0, 0))
        scaled.blit(ring, (0, 0))
        screen.blit(scaled, (0, 0))
        pygame.display.flip()
        clock.tick(30)

    pygame.quit()


def main() -> None:
    emu = HaloEmulator(sandbox_dir=APP_DIR)
    emu.load_directory(APP_DIR)
    emu.set_battery_level(82)
    emu.set_battery_charging(False)
    emu.start("main.lua")

    time.sleep(0.3)

    print("=" * 52)
    print("  PKMN_VAL_V1.0 — Halo Emulator")
    print("=" * 52)
    print("  SPACE  ->  Button single  (scan / select)")
    print("  T      ->  IMU tap        (navigate / next cond)")
    print("  L      ->  Long press     (-> reticle home)")
    print("  Close window or Ctrl+C to quit")
    print("=" * 52)
    print()

    run_pygame_window(emu)
    emu.stop()
    logger.info("Emulator stopped.")


if __name__ == "__main__":
    main()
