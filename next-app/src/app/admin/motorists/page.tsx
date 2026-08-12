import AppShell from "@/components/app-shell";
import { requireServerRole } from "@/lib/auth";
import { getAdminMotorists } from "@/lib/server-data";

type Props = {
  searchParams: Promise<{ search?: string }>;
};

export default async function AdminMotoristsPage({ searchParams }: Props) {
  await requireServerRole("admin");
  const { search } = await searchParams;
  const motorists = await getAdminMotorists(search);

  return (
    <AppShell role="admin" title="Motorists">
      <form method="get" className="inline-form">
        <input name="search" defaultValue={search ?? ""} placeholder="Search by name, license, or email" />
        <button type="submit">Search</button>
      </form>

      <div className="table-wrap">
        <table>
          <thead>
            <tr>
              <th>ID</th>
              <th>Name</th>
              <th>License</th>
              <th>Phone</th>
              <th>Email</th>
              <th>Bikes</th>
            </tr>
          </thead>
          <tbody>
            {motorists.map((m) => (
              <tr key={m.id}>
                <td>#{m.id}</td>
                <td>{m.full_name}</td>
                <td>{m.license_number}</td>
                <td>{m.phone_number}</td>
                <td>{m.email ?? "-"}</td>
                <td>{m.bike_count}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </AppShell>
  );
}
