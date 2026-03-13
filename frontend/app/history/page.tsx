import { HistoryClient } from "@/components/HistoryClient";
import { getHistorySnapshot } from "@/lib/server/historySnapshot";

export const dynamic = "force-dynamic";

export default async function HistoryPage() {
  const initialHistory = await getHistorySnapshot(120);

  return <HistoryClient initialHistory={initialHistory} />;
}
