import asyncio
import logging
import os
from bs4 import BeautifulSoup
from backend.tcg_scraper import init_crawler, close_crawler, GLOBAL_CRAWLER, PROFILE_DIR
from crawl4ai import CrawlerRunConfig, CacheMode

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")

TEST_URL = "https://www.tcgplayer.com/product/85963/pokemon-legendary-treasures-radiant-collection-growlithe?Language=English&Condition=Lightly+Played&page=1"

JS_DEBUG_MODAL = """
return new Promise(async (resolve) => {
    let debugInfo = [];
    
    // 1. Wait for modal activator
    let btn = null;
    for (let i = 0; i < 40; i++) {
        btn = document.querySelector('div.modal__activator');
        if (btn) break;
        await new Promise(r => setTimeout(r, 200));
    }
    
    if (!btn) {
        debugInfo.push("Modal activator not found");
        resolve(debugInfo);
        return;
    }
    
    debugInfo.push("Modal activator found");
    
    // Try multiple click strategies
    btn.click();
    btn.dispatchEvent(new MouseEvent('mousedown', {bubbles: true}));
    btn.dispatchEvent(new MouseEvent('mouseup', {bubbles: true}));
    btn.dispatchEvent(new MouseEvent('click', {bubbles: true}));
    
    if (btn.firstElementChild) {
        btn.firstElementChild.click();
    }
    
    // 2. Wait for modal to actually appear in the DOM
    let modalAppeared = false;
    let modalEl = null;
    for (let i = 0; i < 30; i++) {
        modalEl = document.querySelector('.modal__content');
        if (modalEl) {
            modalAppeared = true;
            break;
        }
        await new Promise(r => setTimeout(r, 200));
    }
    debugInfo.push(`Modal appeared in DOM: ${modalAppeared}`);
    
    // Check what is inside the modal!
    if (modalEl) {
        // give it a moment to load network data
        await new Promise(r => setTimeout(r, 1500));
        debugInfo.push(`Modal HTML preview: ${modalEl.innerHTML.substring(0, 500)}`);
        
        // Let's also check if there are ANY tables inside it
        const innerTables = modalEl.querySelectorAll('table');
        debugInfo.push(`Tables inside modal: ${innerTables.length}`);
    }
    
    // 3. Scroll
    for (let step = 0; step < 12; step++) {
        // Query inside the loop so we get newly added elements!
        const scrollers = document.querySelectorAll('.modal__content, .modal__overlay, section');
        scrollers.forEach(s => {
            if (s) s.scrollTop += 800;
        });
        window.scrollTo(0, document.body.scrollHeight);
        
        const tables = modalEl ? modalEl.querySelectorAll('table') : document.querySelectorAll('table');
        tables.forEach(t => {
            const rows = t.querySelectorAll('tbody tr');
            if (rows.length > 0) {
                rows[rows.length - 1].scrollIntoView({ behavior: 'smooth', block: 'end' });
            }
        });
        await new Promise(r => setTimeout(r, 250));
    }
    
    // 4. Wait for stabilize
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
    
    debugInfo.push(`Final maxRows stabilized at: ${prevCount}`);
    resolve(debugInfo);
});
"""

async def run():
    await init_crawler()
    try:
        print(f"\n{'='*60}")
        print(f"  Debug Scraping URL: {TEST_URL}")
        print(f"{'='*60}\n")
        
        r = await GLOBAL_CRAWLER.arun(
            url=TEST_URL,
            config=CrawlerRunConfig(
                cache_mode=CacheMode.BYPASS,
                js_code=[JS_DEBUG_MODAL],
                delay_before_return_html=1.5,
            )
        )
        
        if not r.success:
            print("❌ Crawl failed!")
            return
            
        print("\n--- JS Execution Results ---")
        print(r.js_execution_result)
            
        print("\n--- Python DOM Parsing ---")
        soup = BeautifulSoup(r.html, "html.parser")
        tables = soup.find_all("table")
        
        print(f"Found {len(tables)} element(s) with tag 'table'")
        
        with open("debug_page.html", "w") as f:
            f.write(r.html)
        print("\nSaved full page HTML to debug_page.html")
        
        # Check what the JS sent back for modal HTML
        if len(r.js_execution_result['results']) > 0:
            for item in r.js_execution_result['results'][0]:
                if item.startswith('Modal HTML preview:'):
                    with open("debug_modal.html", "w") as f:
                        f.write(item[19:])
                    print("Saved modal HTML to debug_modal.html")

    finally:
        await close_crawler()

if __name__ == "__main__":
    asyncio.run(run())
