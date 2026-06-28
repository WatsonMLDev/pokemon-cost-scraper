import asyncio
import logging
from bs4 import BeautifulSoup
from backend.tcg_scraper import (
    init_crawler, close_crawler, GLOBAL_CRAWLER,
    parse_sales_snapshot, parse_conditions,
)
from crawl4ai import CrawlerRunConfig, CacheMode

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")

TEST_URL = "https://www.tcgplayer.com/product/85963/pokemon-legendary-treasures-radiant-collection-growlithe?Language=English&page=1"

# Same JS as the real scraper — tests the actual code path
JS_CLICK_MODAL = """
return new Promise(async (resolve) => {
    let btn = null;
    for (let i = 0; i < 40; i++) {
        btn = document.querySelector('div.modal__activator');
        if (btn) break;
        await new Promise(r => setTimeout(r, 250));
    }
    if (!btn) { resolve('no_modal_activator'); return; }

    btn.click();

    let table = null;
    for (let i = 0; i < 40; i++) {
        table = document.querySelector('table.latest-sales-table');
        if (table && table.querySelector('tbody tr')) break;
        await new Promise(r => setTimeout(r, 250));
    }
    if (!table) { resolve('no_sales_table'); return; }

    let prevRowCount = 0;
    let staleRounds = 0;
    for (let i = 0; i < 30; i++) {
        const loadBtn = document.querySelector(
            '.sales-history-snapshot__load-more__button, ' +
            'button.sales-history-snapshot__load-more__button'
        );
        if (!loadBtn || loadBtn.disabled || loadBtn.offsetParent === null) break;

        loadBtn.scrollIntoView({block: 'center'});
        await new Promise(r => setTimeout(r, 200));
        loadBtn.click();
        await new Promise(r => setTimeout(r, 1200));

        const currentRows = table.querySelectorAll('tbody tr').length;
        if (currentRows === prevRowCount) {
            staleRounds++;
            if (staleRounds >= 3) break;
        } else {
            staleRounds = 0;
        }
        prevRowCount = currentRows;
    }

    const modalContent = document.querySelector('.modal__content');
    if (modalContent) modalContent.scrollTop = 0;
    await new Promise(r => setTimeout(r, 300));

    const finalRows = table.querySelectorAll('tbody tr').length;
    resolve({
        status: 'loaded_' + finalRows + '_rows',
        html: table.outerHTML
    });
});
"""

async def run():
    await init_crawler()
    try:
        print(f"\n{'='*60}")
        print(f"  Testing: {TEST_URL}")
        print(f"{'='*60}\n")

        r = await GLOBAL_CRAWLER.arun(
            url=TEST_URL,
            config=CrawlerRunConfig(
                cache_mode=CacheMode.BYPASS,
                js_code=[JS_CLICK_MODAL],
                delay_before_return_html=2.0,
            ),
        )

        if not r.success:
            print("❌ Crawl failed!")
            return

        print(f"✅ Crawl succeeded")
        
        js_res = r.js_execution_result or {}
        js_results_array = js_res.get("results", [])
        js_output = js_results_array[0] if js_results_array else {}
        
        print(f"   JS status: {js_output.get('status', 'unknown')}")

        # Use JS extracted HTML for the modal table if available, else fallback to full page HTML
        modal_html = js_output.get("html", "")
        if not modal_html:
            print("   ⚠️ No HTML returned from JS, falling back to full page HTML")
            modal_html = r.html
        else:
            print(f"   HTML from JS: {len(modal_html)} chars")

        # Parse conditions from the full page
        conditions = parse_conditions(r.html)
        print(f"\n📋 Conditions found: {conditions or ['(none — will default to Near Mint)']}")

        # Parse all sales using the modal HTML
        all_data = parse_sales_snapshot(modal_html, "ALL")
        sales = all_data["sales"]
        print(f"\n📊 Total sales rows parsed: {len(sales)}")

        if sales:
            # Show first 5 and last 5
            print("\n--- First 5 sales ---")
            for s in sales[:5]:
                print(f"  {s['date']:>10}  {s['type']:<15}  {s['qty']:<4}  {s['price']}")

            if len(sales) > 10:
                print(f"  ... ({len(sales) - 10} more rows) ...")

            if len(sales) > 5:
                print("\n--- Last 5 sales ---")
                for s in sales[-5:]:
                    print(f"  {s['date']:>10}  {s['type']:<15}  {s['qty']:<4}  {s['price']}")

            # Breakdown by condition
            print("\n--- Sales by Condition ---")
            cond_counts = {}
            for s in sales:
                c = s["type"].split()[0] if s["type"] else "?"
                cond_counts[c] = cond_counts.get(c, 0) + 1
            for c, n in sorted(cond_counts.items(), key=lambda x: -x[1]):
                print(f"  {c:<6}: {n} sales")
        else:
            print("\n⚠️  No sales data found! The modal may not have opened.")
            # Debug: check what tables exist
            soup = BeautifulSoup(r.html, "html.parser")
            tables = soup.find_all("table")
            print(f"  Tables in HTML: {len(tables)}")
            for i, t in enumerate(tables):
                cls = t.get("class", [])
                rows = len(t.find_all("tr"))
                print(f"    Table {i}: class={cls}, rows={rows}")

        print(f"\n{'='*60}")
        print(f"  TEST COMPLETE")
        print(f"{'='*60}")

    finally:
        await close_crawler()


if __name__ == "__main__":
    asyncio.run(run())
