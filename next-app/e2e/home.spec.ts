import { expect, test } from "@playwright/test";

test("home page offers entry points for users and administrators", async ({ page }) => {
  await page.goto("/");

  await expect(page.getByRole("heading", { name: "Motorist Traffic Control System" })).toBeVisible();
  await expect(page.getByRole("link", { name: "Motorist login" })).toHaveAttribute("href", "/login");
  await expect(page.getByRole("link", { name: "Admin console" })).toHaveAttribute("href", "/admin/login");
});
