#!/usr/bin/env python3
"""
Login Helper — opens a visible browser for manual TCGPlayer login.

Usage:
    python login_helper.py

What this does:
  1. Opens a Chromium window using the SAME browser profile that the scraper uses.
  2. Navigates to TCGPlayer's login page.
  3. You log in manually (handle any captcha/2FA as needed).
  4. Close the browser window when done.
  5. Your session cookies are saved — the scraper will now run as a logged-in user.

To refresh/re-login, just run this script again.
"""

import sys
import asyncio
from pathlib import Path

# Swap playwright for patchright (same as the scraper does)
try:
    import patchright
    sys.modules["playwright"] = patchright
except ImportError:
    pass

from crawl4ai import AsyncWebCrawler, BrowserConfig, CrawlerRunConfig, CacheMode

PROFILE_DIR = str(Path(__file__).resolve().parent / "browser_profile")
TCGPLAYER_LOGIN_URL = "https://www.tcgplayer.com/login"


async def main():
    print("=" * 60)
    print("  TCGPlayer Login Helper")
    print("=" * 60)
    print()
    print(f"  Profile directory: {PROFILE_DIR}")
    print()
    print("  A browser window will open to TCGPlayer's login page.")
    print("  1. Log in with your TCGPlayer account.")
    print("  2. Wait for the page to fully load after login.")
    print("  3. Press ENTER here when you're done.")
    print()

    browser_config = BrowserConfig(
        user_data_dir=PROFILE_DIR,
        use_managed_browser=True,
        headless=False,  # Visible so you can interact
        browser_type="chromium",
        extra_args=["--password-store=basic"]
    )

    crawler = AsyncWebCrawler(config=browser_config)
    await crawler.start()

    print("  Opening TCGPlayer login page...")
    result = await crawler.arun(
        url=TCGPLAYER_LOGIN_URL,
        config=CrawlerRunConfig(
            cache_mode=CacheMode.BYPASS,
            delay_before_return_html=1.0,
        ),
    )

    if result.success:
        print("  ✓ Page loaded successfully.")
    else:
        print("  ✗ Page failed to load, but the browser should still be open.")

    print()
    input("  >>> Log in, then press ENTER here to save & close... ")

    # Take a final snapshot of the page to ensure cookies are flushed
    try:
        await crawler.arun(
            url="https://www.tcgplayer.com",
            config=CrawlerRunConfig(
                cache_mode=CacheMode.BYPASS,
                delay_before_return_html=2.0,
            ),
        )
    except Exception:
        pass

    await crawler.close()

    print()
    print("  ✓ Session saved! The scraper will now use your logged-in session.")
    print("  ✓ You can restart the backend server and it will pick up the cookies.")
    print()


if __name__ == "__main__":
    asyncio.run(main())
