import AppShell from "@/components/app-shell";
import { requireServerRole } from "@/lib/auth";
import { query } from "@/lib/db";
import { revalidatePath } from "next/cache";

type Profile = {
  full_name: string;
  email: string;
  license_number?: string;
  phone_number?: string;
  address?: string | null;
  motorist_id?: number | null;
};

export default async function UserProfilePage() {
  const session = await requireServerRole("user");

  async function saveProfile(formData: FormData) {
    "use server";

    const current = await requireServerRole("user");
    const fullName = String(formData.get("fullName") ?? "").trim();
    const phoneNumber = String(formData.get("phoneNumber") ?? "").trim();
    const address = String(formData.get("address") ?? "").trim();

    if (!fullName || !phoneNumber) {
      return;
    }

    const account = await query<{ motorist_id: number | null }>(
      "SELECT motorist_id FROM user_account WHERE id = $1 LIMIT 1",
      [current.userId]
    );

    await query("UPDATE user_account SET full_name = $1 WHERE id = $2", [fullName, current.userId]);

    if (account.rows[0]?.motorist_id) {
      await query("UPDATE motorists SET full_name = $1, phone_number = $2, address = $3 WHERE id = $4", [
        fullName,
        phoneNumber,
        address || null,
        account.rows[0].motorist_id,
      ]);
    }

    revalidatePath("/user/profile");
  }

  const account = await query<Profile>(
    "SELECT full_name, email, motorist_id FROM user_account WHERE id = $1 LIMIT 1",
    [session.userId]
  );

  let profile: Profile = account.rows[0];

  if (profile?.motorist_id) {
    const motorist = await query<{ license_number: string; phone_number: string; address: string | null }>(
      "SELECT license_number, phone_number, address FROM motorists WHERE id = $1 LIMIT 1",
      [profile.motorist_id]
    );
    profile = { ...profile, ...motorist.rows[0] };
  }

  return (
    <AppShell role="user" title="My Profile">
      <form action={saveProfile} className="card">
        <label>
          Full name
          <input name="fullName" defaultValue={profile?.full_name ?? ""} required />
        </label>
        <label>
          Email
          <input value={profile?.email ?? ""} disabled />
        </label>
        <label>
          License number
          <input value={profile?.license_number ?? ""} disabled />
        </label>
        <label>
          Phone number
          <input name="phoneNumber" defaultValue={profile?.phone_number ?? ""} required />
        </label>
        <label>
          Address
          <textarea name="address" rows={3} defaultValue={profile?.address ?? ""} />
        </label>
        <button type="submit">Save changes</button>
      </form>
    </AppShell>
  );
}
