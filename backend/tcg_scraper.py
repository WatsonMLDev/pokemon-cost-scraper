import sys
import os
import asyncio
import re
import urllib.parse
import logging
from pathlib import Path
from bs4 import BeautifulSoup

logger = logging.getLogger(__name__)

try:
    import patchright
    sys.modules["playwright"] = patchright
except ImportError:
    pass

from crawl4ai import AsyncWebCrawler, BrowserConfig, CrawlerRunConfig, CacheMode

# Persistent browser profile — login once, reuse the session for all scrapes
PROFILE_DIR = str(Path(__file__).resolve().parent / "browser_profile")

browser_config = BrowserConfig(
    user_data_dir=PROFILE_DIR,
    use_managed_browser=True,
    headless=True,
    browser_type="chromium",
)

GLOBAL_CRAWLER = AsyncWebCrawler(config=browser_config)

async def init_crawler():
    logger.info(f"Initializing AsyncWebCrawler with profile: {PROFILE_DIR}")
    await GLOBAL_CRAWLER.start()
    logged_in = os.path.exists(os.path.join(PROFILE_DIR, "Default", "Cookies")) or \
                os.path.exists(os.path.join(PROFILE_DIR, "Cookies"))
    if logged_in:
        logger.info("Browser profile found — session cookies will be reused.")
    else:
        logger.warning("No browser profile cookies found. Run 'python login_helper.py' to log in.")
    logger.info("Global AsyncWebCrawler ready.")

async def close_crawler():
    logger.info("Closing global AsyncWebCrawler...")
    await GLOBAL_CRAWLER.close()

# ── Parsing helpers ────────────────────────────────────────────────────────────

def parse_conditions(html: str) -> list[str]:
    """Extract available condition names from a product page's filter sidebar."""
    soup = BeautifulSoup(html, "html.parser")
    container = soup.find(attrs={"data-testid": "searchFilterCondition"})
    if not container:
        logger.warning("Could not find conditions filter container in HTML.")
        return []
    conditions = []
    for facet in container.find_all(class_="search-filter__facet"):
        label = facet.find(class_="tcg-input-checkbox__label-text")
        if label:
            conditions.append(label.get_text(strip=True))
    logger.info(f"Parsed {len(conditions)} conditions from page: {conditions}")
    return conditions


def parse_sales_snapshot(html: str, cond_name: str) -> dict:
    """Parse a condition-specific product page into a structured dict."""
    soup = BeautifulSoup(html, "html.parser")

    cond_short = cond_name
    cond_upper = cond_name.upper()
    if "NEAR MINT" in cond_upper: cond_short = "NM"
    elif "LIGHTLY PLAYED" in cond_upper: cond_short = "LP"
    elif "MODERATELY PLAYED" in cond_upper: cond_short = "MP"
    elif "HEAVILY PLAYED" in cond_upper: cond_short = "HP"
    elif "DAMAGED" in cond_upper: cond_short = "DMG"

    sales = []
    table = soup.find("table", class_="latest-sales-table")
    
    if table:
        for tr in table.find_all("tr"):
            cells = tr.find_all(["td", "th"])
            if len(cells) >= 4:
                date = cells[0].get_text(strip=True)
                for cls in ["latest-sales-table__tbody__condition__custom-listing",
                            "tcg-base-overlay", "tcg-tooltip__content"]:
                    el = cells[1].find(class_=cls)
                    if el: el.decompose()
                cond_type = cells[1].get_text(strip=True)
                cond_type = cond_type.replace("Reverse Holofoil", "Rev Holo")
                cond_type = cond_type.replace("Holofoil", "Holo")
                cond_type = cond_type.replace("Japanese", "JP")
                if len(cond_type) > 15: cond_type = cond_type[:12] + "..."
                qty_str = cells[2].get_text(strip=True)
                price = cells[3].get_text(strip=True)
                
                qty = f"Q{qty_str}" if qty_str.isdigit() else qty_str
                
                sales.append({
                    "date": date,
                    "type": cond_type,
                    "qty": qty,
                    "price": price
                })
    logger.debug(f"Parsed {len(sales)} sales for condition: {cond_name}")
    return {
        "short": cond_short,
        "long": cond_name.upper(),
        "sales": sales
    }


def parse_search_results(html: str, card_name: str) -> list[dict]:
    """Extract matching product cards from a search results page."""
    soup = BeautifulSoup(html, "html.parser")
    cards = []
    for a in soup.find_all("a", href=True):
        href = a["href"]
        if not href.startswith("/product/"):
            continue
        clean = href.split("?")[0]
        if clean in [c["url"] for c in cards]:
            continue

        parent = a.find_parent(class_=lambda x: x and "product-card" in x)
        title = set_name = rarity_text = ""
        if parent:
            el = parent.find(class_=lambda x: x and "title" in x)
            if el: title = el.get_text(strip=True)
            el = parent.find(class_=lambda x: x and "set-name" in x)
            if el: set_name = el.get_text(strip=True)
            # Card number lives in the rarity section (e.g. "Common, #RC8/RC25")
            el = parent.find(class_=lambda x: x and "rarity" in x)
            if el: rarity_text = el.get_text(strip=True)
        if not title:
            title = a.get_text(strip=True) or clean.split("/")[-1].replace("-", " ").title()

        # Include rarity text (which contains the card number like #RC8/RC25)
        combined = f"{title} {set_name} {rarity_text}"

        def token_pattern(w: str) -> str:
            if "/" in w:
                # e.g. "RC9/RC32" → match if either side of the slash appears
                alts = "|".join(re.escape(part) for part in w.split("/") if part)
                return f"(?=.*(?:{alts}))"
            return f"(?=.*{re.escape(w)})"
        pattern = "".join(token_pattern(w) for w in card_name.split())
        if not re.search(pattern, combined, re.IGNORECASE):
            continue

        cards.append({"url": clean, "name": title, "num": set_name})
    logger.info(f"Parsed {len(cards)} search results matching '{card_name}'.")
    return cards


# ── API Functions ──────────────────────────────────────────────────────────────

async def search_cards(query: str) -> list[dict]:
    """Searches TCGPlayer and returns a list of matching cards."""
    encoded_name = urllib.parse.quote(query)
    search_url = f"https://www.tcgplayer.com/search/all/product?q={encoded_name}&view=grid"
    logger.info(f"Starting TCGPlayer search crawl for query: '{query}'")

    JS_WAIT_RESULTS = """
    return new Promise(async (resolve) => {
        for (let i = 0; i < 100; i++) {
            if (document.querySelectorAll("a[href*='/product/']").length > 0) break;
            if (document.body.innerText.includes("No results for")) break;
            await new Promise(r => setTimeout(r, 200));
        }
        resolve();
    });
    """

    try:
        res = await GLOBAL_CRAWLER.arun(
            url=search_url,
            config=CrawlerRunConfig(
                cache_mode=CacheMode.BYPASS,
                js_code=[JS_WAIT_RESULTS],
                delay_before_return_html=0.5,
            ),
        )
        if not res.success:
            logger.error(f"Search crawl failed for query: '{query}'")
            return []
    except Exception as e:
        logger.warning(f"Search crawl timed out or failed (likely no results) for '{query}': {e}")
        return []

    logger.info(f"Search crawl successful for query: '{query}'. Parsing results...")
    return parse_search_results(res.html, query)


async def scrape_card_data(url_path: str, card_name: str):
    """Scrapes conditions and sales data for a specific card URL, yielding progress."""
    base_url = f"https://www.tcgplayer.com{url_path}" if url_path.startswith("/") else url_path
    
    JS_WAIT_CONDITIONS = """
    return new Promise(async (resolve) => {
        for (let i = 0; i < 25; i++) {
            if (document.querySelectorAll('.search-filter__facet').length > 0) break;
            await new Promise(r => setTimeout(r, 200));
        }
        resolve();
    });
    """
    
    logger.info(f"Loading base product page for {card_name} to discover conditions...")
    yield {"type": "status", "message": "Loading product page..."}
    
    res = await GLOBAL_CRAWLER.arun(
        url=f"{base_url}?Language=English&page=1",
        config=CrawlerRunConfig(
            cache_mode=CacheMode.BYPASS,
            js_code=[JS_WAIT_CONDITIONS],
            delay_before_return_html=0.1,
        ),
    )
    if not res.success:
        logger.error(f"Failed to load base page for {card_name}")
        yield {"type": "result", "data": {"name": card_name, "conditions": []}}
        return

    conditions = parse_conditions(res.html)
    if not conditions:
        logger.warning(f"No conditions found for {card_name}, defaulting to 'Near Mint'")
        conditions = ["Near Mint"]
    else:
        logger.info(f"Found {len(conditions)} conditions to scrape for {card_name}.")
        
    yield {"type": "status", "message": f"Found {len(conditions)} conditions..."}

    JS_CLICK_MODAL = """
    return new Promise(async (resolve) => {
        let btn = null;
        for (let i = 0; i < 40; i++) {
            btn = document.querySelector('div.modal__activator');
            if (btn) break;
            await new Promise(r => setTimeout(r, 200));
        }

        if (btn) {
            btn.click();
            btn.dispatchEvent(new MouseEvent('mousedown', {bubbles: true}));
            btn.dispatchEvent(new MouseEvent('mouseup', {bubbles: true}));
            btn.dispatchEvent(new MouseEvent('click', {bubbles: true}));
            if (btn.firstElementChild) btn.firstElementChild.click();
            
            for (let i = 0; i < 30; i++) {
                if (document.querySelector('.modal__content')) break;
                await new Promise(r => setTimeout(r, 200));
            }
            
            for (let step = 0; step < 12; step++) {
                const scrollers = document.querySelectorAll('.modal__content, .modal__overlay, section');
                scrollers.forEach(s => {
                    if (s) s.scrollTop += 800;
                });
                window.scrollTo(0, document.body.scrollHeight);
                
                document.querySelectorAll('table').forEach(t => {
                    const rows = t.querySelectorAll('tbody tr');
                    if (rows.length > 0) {
                        rows[rows.length - 1].scrollIntoView({ behavior: 'smooth', block: 'end' });
                    }
                });
                await new Promise(r => setTimeout(r, 250));
            }

            document.querySelectorAll('.modal__content, .modal__overlay, section').forEach(s => {
                if (s) s.scrollTop = 0;
            });
            window.scrollTo(0, 0);
            await new Promise(r => setTimeout(r, 400));

            // 4. Wait for row count to stabilize (two consecutive equal counts)
            let prevCount = -1;
            for (let i = 0; i < 15; i++) {
                let maxRows = 0;
                document.querySelectorAll('table').forEach(t => {
                    const rows = t.querySelectorAll('tbody tr');
                    if (rows.length > maxRows) maxRows = rows.length;
                });
                if (maxRows > 5 && maxRows === prevCount) break;
                prevCount = maxRows;
                await new Promise(r => setTimeout(r, 300));
            }
        }

        resolve();
    });
    """

    async def fetch_condition(cond_name: str, stagger: float) -> dict:
        if stagger > 0:
            await asyncio.sleep(stagger)
        encoded = cond_name.replace(" ", "+")
        url = f"{base_url}?Language=English&Condition={encoded}&page=1"
        logger.info(f"Scraping condition: '{cond_name}' for {card_name}...")
        r = await GLOBAL_CRAWLER.arun(
            url=url,
            config=CrawlerRunConfig(
                cache_mode=CacheMode.BYPASS,
                js_code=[JS_CLICK_MODAL],
                delay_before_return_html=1.5,
            ),
        )
        if not r.success:
            logger.error(f"Failed to scrape condition '{cond_name}' for {card_name}")
            return {"short": cond_name, "long": cond_name.upper(), "sales": []}
        
        sales_data = parse_sales_snapshot(r.html, cond_name)
        logger.info(f"Successfully scraped condition: '{cond_name}' (found {len(sales_data['sales'])} sales)")
        return sales_data

    yield {"type": "status", "message": "Scraping prices..."}
    
    tasks = [fetch_condition(c, stagger=i * 0.4) for i, c in enumerate(conditions)]
    condition_results = await asyncio.gather(*tasks)

    logger.info(f"Completed scraping all {len(conditions)} conditions for {card_name}.")
    yield {
        "type": "result",
        "data": {
            "name": card_name,
            "conditions": condition_results
        }
    }
