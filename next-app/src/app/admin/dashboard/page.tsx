import AppShell from "@/components/app-shell";
import { requireServerRole } from "@/lib/auth";
import { getAdminDashboardStats } from "@/lib/server-data";

export default async function AdminDashboardPage() {
  const session = await requireServerRole("admin");
  const stats = await getAdminDashboardStats();

  return (
    <AppShell role="admin" title={`Welcome, ${session.name}`}>
      <div className="stat-grid">
        <article className="stat-card">
          <h3>Total Motorists</h3>
          <p>{stats.totalMotorists}</p>
        </article>
        <article className="stat-card">
          <h3>Total Motorbikes</h3>
          <p>{stats.totalMotorbikes}</p>
        </article>
        <article className="stat-card">
          <h3>Commercial Bikes</h3>
          <p>{stats.commercialCount}</p>
        </article>
        <article className="stat-card">
          <h3>On Hire</h3>
          <p>{stats.hireCount}</p>
        </article>
      </div>
    </AppShell>
  );
}
