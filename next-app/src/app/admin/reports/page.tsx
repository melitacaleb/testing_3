import AppShell from "@/components/app-shell";
import { requireServerRole } from "@/lib/auth";
import { getAdminDashboardStats, getReportSummary } from "@/lib/server-data";

export default async function AdminReportsPage() {
  await requireServerRole("admin");
  const [stats, reports] = await Promise.all([getAdminDashboardStats(), getReportSummary()]);

  return (
    <AppShell role="admin" title="Reports & Analytics">
      <div className="stat-grid">
        <article className="stat-card"><h3>Total Motorists</h3><p>{stats.totalMotorists}</p></article>
        <article className="stat-card"><h3>Total Bikes</h3><p>{stats.totalMotorbikes}</p></article>
        <article className="stat-card"><h3>Hire Bikes</h3><p>{reports.hire.count}</p></article>
        <article className="stat-card"><h3>Avg Hire Rate</h3><p>KES {reports.hire.avgRate.toFixed(2)}</p></article>
      </div>

      <section className="two-col">
        <article className="card-lite">
          <h2>Purpose Distribution</h2>
          <ul>
            <li>Commercial: {reports.purpose.commercial}</li>
            <li>Personal Transport: {reports.purpose.personal_transport}</li>
            <li>On Hire: {reports.purpose.hire}</li>
          </ul>
        </article>

        <article className="card-lite">
          <h2>Top Motorists</h2>
          <ul>
            {reports.topMotorists.map((row) => (
              <li key={row.full_name}>{row.full_name} - {row.bike_count} bike(s)</li>
            ))}
          </ul>
        </article>
      </section>
    </AppShell>
  );
}
