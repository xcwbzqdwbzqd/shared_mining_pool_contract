import { NextRequest, NextResponse } from "next/server";
import { getUserSnapshot } from "@/lib/server/userSnapshot";

export const dynamic = "force-dynamic";

export async function GET(
  _request: NextRequest,
  context: { params: Promise<{ address: string }> },
) {
  const { address } = await context.params;

  try {
    const snapshot = await getUserSnapshot(address);
    return NextResponse.json(snapshot, {
      headers: {
        "Cache-Control": "no-store",
      },
    });
  } catch {
    return NextResponse.json(
      {
        message: "Invalid address",
      },
      {
        status: 400,
      },
    );
  }
}
