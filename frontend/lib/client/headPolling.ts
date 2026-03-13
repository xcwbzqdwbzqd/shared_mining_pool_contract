"use client";

import { startTransition, useEffect, useRef } from "react";
import { useQuery } from "@tanstack/react-query";
import { APP_CONFIG } from "@/config";
import type { HeadSnapshot } from "@/lib/types";

async function fetchHead() {
  const response = await fetch("/api/head", {
    cache: "no-store",
  });

  if (!response.ok) {
    throw new Error("Failed to fetch head");
  }

  return (await response.json()) as HeadSnapshot;
}

export function useHeadAwareRefresh(onNewHead: () => void) {
  const previousBlock = useRef<string | null>(null);
  const headQuery = useQuery({
    queryKey: ["head"],
    queryFn: fetchHead,
    refetchInterval: APP_CONFIG.polling.headMs,
    staleTime: 0,
  });

  useEffect(() => {
    if (!headQuery.data) {
      return;
    }

    if (previousBlock.current === null) {
      previousBlock.current = headQuery.data.blockNumber;
      return;
    }

    if (headQuery.data.blockNumber !== previousBlock.current) {
      previousBlock.current = headQuery.data.blockNumber;
      startTransition(() => {
        onNewHead();
      });
    }
  }, [headQuery.data, onNewHead]);
}
