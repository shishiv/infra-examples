import { expect, test, type Page } from '@playwright/test';

const screenshotOptions = {
  fullPage: true,
  animations: 'disabled' as const,
  caret: 'hide' as const,
  maxDiffPixelRatio: 0.03,
};

async function freezeMotion(page: Page): Promise<void> {
  await page.addStyleTag({
    content: `
      *, *::before, *::after {
        transition-duration: 0ms !important;
        transition-delay: 0ms !important;
        animation-duration: 0ms !important;
        animation-delay: 0ms !important;
        animation-iteration-count: 1 !important;
        scroll-behavior: auto !important;
      }
    `,
  });
}

test.describe('visual contract', () => {
  test.use({ viewport: { width: 1440, height: 900 } });

  test('home has no horizontal overflow', async ({ page }) => {
    await page.goto('/', { waitUntil: 'domcontentloaded' });
    const bodyWidth = await page.evaluate(() => document.body.scrollWidth);
    const viewportWidth = await page.evaluate(() => window.innerWidth);

    expect(bodyWidth).toBeLessThanOrEqual(viewportWidth + 1);
  });

  test('home screenshot is deterministic after motion is frozen', async ({ page }) => {
    await page.goto('/', { waitUntil: 'domcontentloaded' });
    await freezeMotion(page);
    await expect(page).toHaveScreenshot('home.png', screenshotOptions);
  });
});
