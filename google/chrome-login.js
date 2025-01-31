const puppeteer = require('puppeteer');

(async () => {
  const browser = await puppeteer.launch({
    headless: false,
    args: ['--no-sandbox', '--disable-setuid-sandbox'],
    userDataDir: '/home/gitpod/.config/google-chrome'
  });
  const page = await browser.newPage();
  await page.goto('https://accounts.google.com');

  // Check for CAPTCHA
  const captchaSelector = '#captcha-form';
  if (await page.$(captchaSelector) !== null) {
    console.log('CAPTCHA detected! Please manually resolve the CAPTCHA in the browser window.');
    await page.waitForNavigation({ timeout: 0 }); // Wait indefinitely for user to resolve CAPTCHA
  }

  console.log('Please log in to your Google account in the browser window...');
  await page.waitForNavigation({ timeout: 0 }); // Wait indefinitely for login

  await browser.close();
})();
