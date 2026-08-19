import AppShell from "@/components/app-shell";
import RideBookingDraft from "@/components/ride-booking-draft";
import { requireServerRole } from "@/lib/auth";

export default async function CustomerRidePage() {
  await requireServerRole("user");

  return (
    <AppShell role="user" title="Book a ride">
      <RideBookingDraft />
    </AppShell>
  );
}
