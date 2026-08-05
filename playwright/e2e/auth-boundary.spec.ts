import { expect, test, type Page } from '@playwright/test';

type DashboardRole = 'administrator' | 'viewer';

const appUrl = process.env.BASE_URL || 'http://localhost:3000';
const tenantId = '11111111-1111-4111-8111-111111111111';

function createFixtureJwt(role: DashboardRole): string {
  const header = Buffer.from(JSON.stringify({ alg: 'HS256', typ: 'JWT' })).toString('base64url');
  const payload = Buffer.from(
    JSON.stringify({
      sub: 'fixture-user-1',
      tenantId,
      email: role === 'administrator' ? 'admin@example.com' : 'viewer@example.com',
      role,
      aud: 'portfolio-example-dashboard',
      iss: 'https://api.example.test',
      iat: Math.floor(Date.now() / 1000),
      exp: Math.floor(Date.now() / 1000) + 60 * 60,
    }),
  ).toString('base64url');

  return `${header}.${payload}.fixture-signature`;
}

async function seedFixtureSession(page: Page, role: DashboardRole): Promise<void> {
  await page.context().addCookies([
    {
      name: 'accessToken',
      value: createFixtureJwt(role),
      url: appUrl,
      httpOnly: true,
      sameSite: 'Lax',
    },
    {
      name: 'refreshToken',
      value: 'fixture-refresh',
      url: appUrl,
      httpOnly: true,
      sameSite: 'Strict',
    },
  ]);
}

test('protected page redirects an anonymous browser to login', async ({ page }) => {
  await page.goto('/painel', { waitUntil: 'domcontentloaded' });

  await expect(page).toHaveURL(/\/login$/);
  await expect(page.getByLabel(/e-mail/i)).toBeVisible();
  await expect(page.getByLabel(/senha/i)).toBeVisible();
});

test('viewer receives data but not administrator navigation', async ({ page }) => {
  await seedFixtureSession(page, 'viewer');
  await page.route('**/api/admin/items**', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        data: [{ id: 'item-1', status: 'open', title: 'Fixture item' }],
      }),
    });
  });

  await page.goto('/painel/itens', { waitUntil: 'domcontentloaded' });

  await expect(page.getByText('Fixture item')).toBeVisible();
  await expect(page.locator('aside')).not.toContainText('configuração');
});
