import { NextResponse } from "next/server";
import { getDashboardSnapshot } from "@/lib/server/dashboardSnapshot";

export const dynamic = "force-dynamic";

export async function GET() {
  const snapshot = await getDashboardSnapshot();

  return NextResponse.json(snapshot, {
    headers: {
      "Cache-Control": "no-store",
    },
  });
}
