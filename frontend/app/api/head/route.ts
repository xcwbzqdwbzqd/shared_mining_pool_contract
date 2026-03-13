import { NextResponse } from "next/server";
import type { HeadSnapshot } from "@/lib/types";
import { getPublicClient } from "@/lib/server/publicClients";

export const dynamic = "force-dynamic";

export async function GET() {
  const client = getPublicClient();
  const blockNumber = await client.getBlockNumber();

  const payload: HeadSnapshot = {
    blockNumber: blockNumber.toString(),
    observedAt: new Date().toISOString(),
  };

  return NextResponse.json(payload, {
    headers: {
      "Cache-Control": "no-store",
    },
  });
}
