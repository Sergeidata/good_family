const { chromium } = require('C:/Users/Sergei/AppData/Roaming/npm/node_modules/@playwright/mcp/node_modules/playwright');

(async () => {
  const exe = 'C:/Users/Sergei/AppData/Local/ms-playwright/chromium-1234/chrome-win64/chrome.exe';
  let browser;
  try {
    browser = await chromium.launch({
      executablePath: exe,
      headless: true,
      args: ['--no-sandbox', '--disable-dev-shm-usage', '--disable-blink-features=AutomationControlled'],
    });
    const ctx = await browser.newContext({ viewport: { width: 1366, height: 900 } });
    const page = await ctx.newPage();
    await page.goto('https://example.com', { waitUntil: 'domcontentloaded', timeout: 60000 });
    const title = await page.title();
    console.log('EXAMPLECOM_TITLE=' + title);

    // Try VK search
    const url = 'https://vk.com/search?c%5Bsection%5D=communities&c%5Bq%5D=' + encodeURIComponent('ЖК Краснодар');
    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 60000 });
    await page.waitForTimeout(5000);
    const body = await page.evaluate(() => document.body.innerText.slice(0, 4000));
    console.log('VK_BODY_START>>>');
    console.log(body);
    console.log('<<<VK_BODY_END');
    const title2 = await page.title();
    console.log('VK_TITLE=' + title2);
  } catch (e) {
    console.log('ERROR: ' + (e && e.message ? e.message : String(e)));
  } finally {
    if (browser) await browser.close().catch(()=>{});
  }
})();
