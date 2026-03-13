import { createPublicClient, fallback, http } from "viem";
import { base } from "viem/chains";
import { APP_CONFIG } from "@/config";

let cachedPublicClient: ReturnType<typeof createPublicClient> | undefined;

export function getPublicClient() {
  if (!cachedPublicClient) {
    cachedPublicClient = createPublicClient({
      batch: {
        multicall: {
          wait: 16,
        },
      },
      chain: base,
      transport: fallback(
        APP_CONFIG.rpcUrls.map((rpcUrl) =>
          http(rpcUrl, {
            retryCount: 0,
            timeout: 1_500,
          }),
        ),
      ),
    }) as ReturnType<typeof createPublicClient>;
  }

  return cachedPublicClient as ReturnType<typeof createPublicClient>;
}
