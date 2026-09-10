import AppShell from "@/components/app-shell";
import AddMotorbikeForm from "@/components/add-motorbike-form";
import { requireServerRole } from "@/lib/auth";
import { getAdminMotorbikes, getMotoristOptions } from "@/lib/server-data";

export default async function AdminMotorbikesPage() {
  await requireServerRole("admin");
  const [motorbikes, motorists] = await Promise.all([getAdminMotorbikes(), getMotoristOptions()]);

  return (
    <AppShell role="admin" title="Motorbikes">
      <AddMotorbikeForm motorists={motorists} />

      <div className="table-wrap" style={{ marginTop: "1.5rem" }}>
        <table>
          <thead>
            <tr>
              <th>ID</th>
              <th>Registration</th>
              <th>Motorist</th>
              <th>Brand / Model</th>
              <th>Purpose</th>
              <th>Power</th>
              <th>Hire rate</th>
            </tr>
          </thead>
          <tbody>
            {motorbikes.map((mb) => (
              <tr key={mb.id}>
                <td>#{mb.id}</td>
                <td>{mb.registration_number}</td>
                <td>{mb.full_name}</td>
                <td>{mb.brand} {mb.model}</td>
                <td>{mb.purpose}</td>
                <td>
                  <span className={`badge ${mb.power_type === "electric" ? "badge-completed" : "badge-pending"}`}>
                    {mb.power_type === "electric" ? "Electric" : "Fuel"}
                  </span>
                </td>
                <td>{mb.hire_rate ? `KES ${mb.hire_rate}` : "-"}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </AppShell>
  );
}
