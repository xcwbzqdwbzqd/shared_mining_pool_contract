"use client";

import { QueryClient } from "@tanstack/react-query";
import { createConfig as createPrivyWagmiConfig } from "@privy-io/wagmi";
import { createConfig as createCoreWagmiConfig, fallback, http } from "wagmi";
import { base } from "wagmi/chains";
import { APP_CONFIG } from "@/config";

const chains = [base] as const;
const batch = {
  multicall: {
    wait: 16,
  },
} as const;

function createBaseTransport() {
  return fallback(
    APP_CONFIG.rpcUrls.map((rpcUrl) =>
      http(rpcUrl, {
        retryCount: 0,
        timeout: 1_500,
      }),
    ),
  );
}

const transports = {
  [base.id]: createBaseTransport(),
};

export const wagmiConfig = createCoreWagmiConfig({
  batch,
  chains,
  transports,
  ssr: true,
});

export const privyWagmiConfig = createPrivyWagmiConfig({
  batch,
  chains,
  transports,
  ssr: true,
});

export function createQueryClient() {
  return new QueryClient({
    defaultOptions: {
      queries: {
        staleTime: 2_000,
        refetchOnWindowFocus: false,
      },
    },
  });
}
