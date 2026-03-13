import path from "node:path";
import { defineConfig } from "@playwright/test";

export default defineConfig({
  testDir: path.resolve(__dirname, "../test/frontend/e2e"),
  use: {
    baseURL: "http://127.0.0.1:3000",
    trace: "on-first-retry",
  },
  webServer: {
    command: "pnpm dev",
    cwd: __dirname,
    port: 3000,
    reuseExistingServer: true,
  },
});
