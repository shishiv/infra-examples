import { expect, test } from '@playwright/test';

const publicRoutes = ['/', '/sobre', '/contato', '/politica-privacidade'];

test.describe('public route smoke', () => {
  for (const route of publicRoutes) {
    test(`${route} responds without a server error`, async ({ page }) => {
      const response = await page.goto(route, { waitUntil: 'domcontentloaded' });
      expect(response?.status()).toBeLessThan(400);
    });
  }

  test('home exposes canonical metadata', async ({ page }) => {
    await page.goto('/', { waitUntil: 'domcontentloaded' });

    await expect(page.locator('html')).toHaveAttribute('lang', 'pt-BR');
    await expect(page.locator('link[rel="canonical"]')).toHaveAttribute(
      'href',
      /http:\/\/localhost:3000\/?/,
    );
    await expect(page.locator('meta[property="og:title"]')).toHaveCount(1);
    await expect(page.locator('meta[property="og:description"]')).toHaveCount(1);
  });
});
