import Link from "next/link";
import { Users, Bike, Briefcase, Handshake, Car, Zap, Fuel, UserPlus, Receipt, FileBarChart } from "lucide-react";
import AppShell from "@/components/app-shell";
import { requireServerRole } from "@/lib/auth";
import { getAdminDashboardStats } from "@/lib/server-data";

export default async function AdminDashboardPage() {
  const session = await requireServerRole("admin");
  const stats = await getAdminDashboardStats();

  const purposeTotal = stats.commercialCount + stats.hireCount + stats.personalCount || 1;
  const commercialPct = (stats.commercialCount / purposeTotal) * 100;
  const hirePct = (stats.hireCount / purposeTotal) * 100;
  const commercialEnd = commercialPct;
  const hireEnd = commercialPct + hirePct;

  const powerTotal = stats.electricCount + stats.fuelCount || 1;
  const electricPct = (stats.electricCount / powerTotal) * 100;

  return (
    <AppShell role="admin" title={`Welcome, ${session.name}`}>
      <div className="stat-grid">
        <article className="stat-card">
          <span><Users size={14} style={{ display: "inline", marginRight: 6, verticalAlign: -2 }} />Total Motorists</span>
          <p>{stats.totalMotorists}</p>
        </article>
        <article className="stat-card">
          <span><Bike size={14} style={{ display: "inline", marginRight: 6, verticalAlign: -2 }} />Total Motorbikes</span>
          <p>{stats.totalMotorbikes}</p>
        </article>
        <article className="stat-card">
          <span><Briefcase size={14} style={{ display: "inline", marginRight: 6, verticalAlign: -2 }} />Commercial</span>
          <p>{stats.commercialCount}</p>
        </article>
        <article className="stat-card">
          <span><Handshake size={14} style={{ display: "inline", marginRight: 6, verticalAlign: -2 }} />On Hire</span>
          <p>{stats.hireCount}</p>
        </article>
        <article className="stat-card">
          <span><Car size={14} style={{ display: "inline", marginRight: 6, verticalAlign: -2 }} />Personal</span>
          <p>{stats.personalCount}</p>
        </article>
        <article className="stat-card">
          <span><Zap size={14} style={{ display: "inline", marginRight: 6, verticalAlign: -2 }} />Electric</span>
          <p>{stats.electricCount}</p>
        </article>
      </div>

      <div className="two-col" style={{ marginTop: "1.5rem" }}>
        <div className="card-lite" style={{ borderLeft: "3px solid var(--accent)" }}>
          <h3 style={{ marginTop: 0 }}>Fleet by purpose</h3>
          <div style={{ display: "flex", alignItems: "center", gap: "1.5rem", flexWrap: "wrap" }}>
            <div className="donut-wrap">
              <div
                className="donut"
                style={{
                  background: `conic-gradient(var(--accent) 0% ${commercialEnd}%, var(--glow) ${commercialEnd}% ${hireEnd}%, var(--amber) ${hireEnd}% 100%)`,
                }}
              />
              <div className="donut-hole">
                <strong>{stats.totalMotorbikes}</strong>
                <span>Bikes</span>
              </div>
            </div>
            <ul className="legend">
              <li><span className="dot" style={{ background: "var(--accent)" }} />Commercial — {stats.commercialCount}</li>
              <li><span className="dot" style={{ background: "var(--glow)" }} />On hire — {stats.hireCount}</li>
              <li><span className="dot" style={{ background: "var(--amber)" }} />Personal — {stats.personalCount}</li>
            </ul>
          </div>
        </div>

        <div className="card-lite" style={{ borderLeft: "3px solid var(--success)" }}>
          <h3 style={{ marginTop: 0 }}>Electric vs Fuel</h3>
          <div className="power-bar">
            <div className="power-bar-electric" style={{ width: `${electricPct}%` }} />
            <div className="power-bar-fuel" style={{ width: `${100 - electricPct}%` }} />
          </div>
          <ul className="legend" style={{ marginTop: "1rem" }}>
            <li><Zap size={14} style={{ color: "var(--success)" }} /> Electric — {stats.electricCount}</li>
            <li><Fuel size={14} style={{ color: "var(--ink-muted)" }} /> Fuel — {stats.fuelCount}</li>
          </ul>
        </div>
      </div>

      <h3 style={{ marginTop: "1.75rem" }}>Quick actions</h3>
      <div className="quick-actions">
        <Link href="/admin/motorists" className="quick-action">
          <span className="quick-action-icon"><UserPlus size={20} /></span>
          <div>
            <strong>Add Motorist</strong>
            <p className="muted" style={{ margin: 0, fontSize: "0.82rem" }}>Register a new motorist</p>
          </div>
        </Link>
        <Link href="/admin/motorbikes" className="quick-action">
          <span className="quick-action-icon"><Bike size={20} /></span>
          <div>
            <strong>Add Motorbike</strong>
            <p className="muted" style={{ margin: 0, fontSize: "0.82rem" }}>Register a bike or hire unit</p>
          </div>
        </Link>
        <Link href="/admin/receipts" className="quick-action">
          <span className="quick-action-icon"><Receipt size={20} /></span>
          <div>
            <strong>Send Receipt</strong>
            <p className="muted" style={{ margin: 0, fontSize: "0.82rem" }}>Issue a payment receipt</p>
          </div>
        </Link>
        <Link href="/admin/reports" className="quick-action">
          <span className="quick-action-icon"><FileBarChart size={20} /></span>
          <div>
            <strong>View Reports</strong>
            <p className="muted" style={{ margin: 0, fontSize: "0.82rem" }}>Full breakdowns and trends</p>
          </div>
        </Link>
      </div>
    </AppShell>
  );
}
