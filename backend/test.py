"""
Quick test: verifies the sales modal scraper returns all rows for a card.
Run from the project root:
    python -m backend.test_sales_scrape
"""
import asyncio
import logging
import os
from backend.tcg_scraper import init_crawler, close_crawler, scrape_card_data, PROFILE_DIR
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
# ── Confirm browser profile ────────────────────────────────────────────────────
print(f"\n🗂  Browser profile: {PROFILE_DIR}")
cookies_path = os.path.join(PROFILE_DIR, "Default", "Cookies")
if os.path.exists(cookies_path):
    print("✅  Cookies found — session will be authenticated")
else:
    print("⚠️   No cookies found — run login_helper.py first!")
# ──────────────────────────────────────────────────────────────────────────────
TEST_URL  = "/product/85963/pokemon-legendary-treasures-radiant-collection-growlithe"
TEST_NAME = "Growlithe"
# ──────────────────────────────────────────────────────────────────────────────
async def run():
    await init_crawler()
    try:
        print(f"\n{'='*60}")
        print(f"  Scraping: {TEST_NAME}")
        print(f"  URL:      {TEST_URL}")
        print(f"{'='*60}\n")
        async for chunk in scrape_card_data(TEST_URL, TEST_NAME):
            if chunk["type"] == "status":
                print(f"[STATUS] {chunk['message']}")
            elif chunk["type"] == "result":
                data = chunk["data"]
                conditions = data.get("conditions", [])
                print(f"\n✅  Got {len(conditions)} condition(s)\n")
                for cond in conditions:
                    sales = cond.get("sales", [])
                    print(f"  [{cond['short']}] {cond['long']}  →  {len(sales)} sale(s)")
                    for s in sales[:5]:   # preview first 5
                        print(f"       {s['date']:10s}  {s['type']:20s}  {s['qty']:4s}  {s['price']}")
                    if len(sales) > 5:
                        print(f"       ... and {len(sales) - 5} more")
            elif chunk["type"] == "error":
                print(f"[ERROR] {chunk['message']}")
    finally:
        await close_crawler()
if __name__ == "__main__":
    asyncio.run(run())
