import AppShell from "@/components/app-shell";
import AddMotoristForm from "@/components/add-motorist-form";
import MotoristsTable from "@/components/motorists-table";
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
      <AddMotoristForm />

      <form method="get" className="inline-form">
        <input name="search" defaultValue={search ?? ""} placeholder="Search by name, license, or email" />
        <button type="submit">Search</button>
      </form>

      <MotoristsTable motorists={motorists} />
    </AppShell>
  );
}
