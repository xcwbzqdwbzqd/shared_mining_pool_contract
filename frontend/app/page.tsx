import { DashboardClient } from "@/components/DashboardClient";
import { getDashboardSnapshot } from "@/lib/server/dashboardSnapshot";

export const dynamic = "force-dynamic";

export default async function Home() {
  const initialDashboard = await getDashboardSnapshot();

  return <DashboardClient initialDashboard={initialDashboard} />;
}
