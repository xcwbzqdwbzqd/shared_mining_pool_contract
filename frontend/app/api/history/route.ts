import { NextRequest, NextResponse } from "next/server";
import { getHistorySnapshot } from "@/lib/server/historySnapshot";

export const dynamic = "force-dynamic";

export async function GET(request: NextRequest) {
  const limitParam = request.nextUrl.searchParams.get("limit");
  const limit = limitParam ? Number(limitParam) : 60;
  const snapshot = await getHistorySnapshot(Number.isFinite(limit) ? limit : 60);

  return NextResponse.json(snapshot, {
    headers: {
      "Cache-Control": "no-store",
    },
  });
}
