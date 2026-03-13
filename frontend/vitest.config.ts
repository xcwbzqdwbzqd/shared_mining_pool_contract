import path from "node:path";
import { defineConfig } from "vitest/config";
import react from "@vitejs/plugin-react";

export default defineConfig({
  root: path.resolve(__dirname, ".."),
  server: {
    fs: {
      allow: [path.resolve(__dirname, "..")],
    },
  },
  plugins: [react()],
  resolve: {
    alias: {
      "@": path.resolve(__dirname),
      react: path.resolve(__dirname, "node_modules/react"),
      "react/jsx-dev-runtime": path.resolve(
        __dirname,
        "node_modules/react/jsx-dev-runtime.js",
      ),
      "@testing-library/react": path.resolve(
        __dirname,
        "node_modules/@testing-library/react/dist/index.js",
      ),
    },
  },
  test: {
    environment: "jsdom",
    globals: true,
    include: [
      "test/frontend/unit/**/*.test.ts",
      "test/frontend/integration/**/*.test.ts",
      "test/frontend/component/**/*.test.tsx",
    ],
  },
});
