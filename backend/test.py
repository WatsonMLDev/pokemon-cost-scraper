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
    
    debugInfo.push("Modal activator found and clicked");
    btn.click();
    
    // 2. Wait for table
    for (let i = 0; i < 50; i++) {
        const table = document.querySelector('.latest-sales-table');
        if (table && !table.innerText.includes('12/12/12') && !table.innerText.includes('$0.00')) break;
        await new Promise(r => setTimeout(r, 200));
    }
    
    // 3. Scroll
    const scrollers = document.querySelectorAll('.modal__content, .latest-sales__table-wrapper, .latest-sales-table, [class*="modal"]');
    for (let step = 0; step < 12; step++) {
        scrollers.forEach(s => {
            if (s) s.scrollTop += 800;
        });
        window.scrollTo(0, document.body.scrollHeight);
        const rows = document.querySelectorAll('.latest-sales-table tbody tr');
        if (rows.length > 0) {
            rows[rows.length - 1].scrollIntoView({ behavior: 'smooth', block: 'end' });
        }
        await new Promise(r => setTimeout(r, 250));
    }
    
    // Scroll back to top
    scrollers.forEach(s => {
        if (s) s.scrollTop = 0;
    });
    window.scrollTo(0, 0);
    await new Promise(r => setTimeout(r, 400));
    
    // 4. Wait for stabilize
    let prevCount = -1;
    for (let i = 0; i < 15; i++) {
        let maxRows = 0;
        document.querySelectorAll('.latest-sales-table').forEach(t => {
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
        tables = soup.find_all(class_="latest-sales-table")
        
        print(f"Found {len(tables)} element(s) with class 'latest-sales-table'")
        for i, table in enumerate(tables):
            tbody = table.find("tbody")
            if tbody:
                rows = tbody.find_all("tr")
                print(f"  Table {i+1}: {len(rows)} rows")
            else:
                print(f"  Table {i+1}: No tbody found")
                
    finally:
        await close_crawler()

if __name__ == "__main__":
    asyncio.run(run())
