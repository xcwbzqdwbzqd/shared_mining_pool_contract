import { OperatorGate } from "@/components/OperatorGate";
import { getDashboardSnapshot } from "@/lib/server/dashboardSnapshot";

export const dynamic = "force-dynamic";

export default async function OperatorPage() {
  const initialDashboard = await getDashboardSnapshot();

  return <OperatorGate initialDashboard={initialDashboard} />;
}
