import { expect, test } from "@playwright/test";

// These credentials come from supabase/seed.sql's default admin record.
// If you've changed the seeded admin password, update ADMIN_PASSWORD to match.
const ADMIN_EMAIL = "admin@example.com";
const ADMIN_PASSWORD = "melita@123";

test.describe("Admin: motorist CRUD", () => {
  test.beforeEach(async ({ page }) => {
    await page.goto("/admin/login");
    await page.getByLabel(/email/i).fill(ADMIN_EMAIL);
    await page.getByLabel(/password/i).fill(ADMIN_PASSWORD);
    await page.getByRole("button", { name: /log ?in|sign ?in/i }).click();
    await page.waitForURL("**/admin/dashboard");
  });

  test("admin can add, edit, and delete a motorist", async ({ page }) => {
    const uniqueSuffix = Date.now().toString().slice(-6);
    const fullName = `E2E Test Motorist ${uniqueSuffix}`;
    const licenseNumber = `E2E${uniqueSuffix}`;
    const updatedName = `${fullName} (Edited)`;

    await page.goto("/admin/motorists");

    // --- Add ---
    await page.getByRole("button", { name: "+ Add Motorist" }).click();
    await page.getByLabel(/full name/i).fill(fullName);
    await page.getByLabel(/license number/i).fill(licenseNumber);
    await page.getByLabel(/phone number/i).fill("0700000000");
    await page.getByRole("button", { name: /save motorist/i }).click();

    const row = page.getByRole("row", { name: new RegExp(fullName) });
    await expect(row).toBeVisible();
    await expect(row).toContainText(licenseNumber);

    // --- Edit ---
    await row.getByTitle("Edit").click();
    const editRow = page.locator("tr", { has: page.locator("form") });
    await editRow.getByLabel(/full name/i).fill(updatedName);
    await editRow.locator("button[type=submit]").click();

    const updatedRow = page.getByRole("row", { name: new RegExp(updatedName.replace(/[()]/g, "\\$&")) });
    await expect(updatedRow).toBeVisible();

    // --- Delete ---
    page.once("dialog", (dialog) => dialog.accept());
    await updatedRow.getByTitle("Delete").click();
    await expect(page.getByRole("row", { name: new RegExp(updatedName.replace(/[()]/g, "\\$&")) })).toHaveCount(0);
  });
});
