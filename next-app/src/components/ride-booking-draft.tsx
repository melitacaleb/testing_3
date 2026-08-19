"use client";

import { useState, type FormEvent } from "react";

type LocationStatus = "idle" | "loading" | "ready" | "unavailable";

export default function RideBookingDraft(): React.JSX.Element {
  const [pickup, setPickup] = useState("");
  const [destination, setDestination] = useState("");
  const [locationStatus, setLocationStatus] = useState<LocationStatus>("idle");
  const [message, setMessage] = useState("");
  const [submitted, setSubmitted] = useState(false);

  function useCurrentLocation(): void {
    if (!navigator.geolocation) {
      setLocationStatus("unavailable");
      setMessage("Location services are not available in this browser.");
      return;
    }

    setLocationStatus("loading");
    setMessage("Requesting your current location...");
    navigator.geolocation.getCurrentPosition(
      ({ coords }) => {
        setPickup(`Current location: ${coords.latitude.toFixed(6)}, ${coords.longitude.toFixed(6)}`);
        setLocationStatus("ready");
        setMessage("Pickup location added. You can refine it before requesting a ride.");
      },
      () => {
        setLocationStatus("unavailable");
        setMessage("Could not access your location. Enter your pickup point manually.");
      },
      { enableHighAccuracy: true, timeout: 10000, maximumAge: 30000 }
    );
  }

  function submitDraft(event: FormEvent<HTMLFormElement>): void {
    event.preventDefault();
    setSubmitted(true);
    setMessage("Ride requests are not live yet. Your pickup and destination remain on this screen only.");
  }

  return (
    <section className="ride-booking" aria-labelledby="ride-booking-heading">
      <div className="ride-route" aria-hidden="true">
        <span className="ride-stop ride-stop--start" />
        <span className="ride-route-line" />
        <span className="ride-stop ride-stop--end" />
      </div>

      <div className="ride-booking-copy">
        <p className="ride-kicker">Customer ride request</p>
        <h2 id="ride-booking-heading">Where are you heading?</h2>
        <p className="muted">Choose a pickup point and destination. This booking screen is in preview and does not contact a rider yet.</p>
      </div>

      <form className="ride-form" onSubmit={submitDraft}>
        <label>
          Pickup point
          <input
            name="pickup"
            value={pickup}
            onChange={(event) => setPickup(event.target.value)}
            placeholder="Add pickup location"
            required
          />
        </label>
        <button className="ride-location" type="button" onClick={useCurrentLocation} disabled={locationStatus === "loading"}>
          {locationStatus === "loading" ? "Finding location..." : "Use current location"}
        </button>
        <label>
          Destination
          <input
            name="destination"
            value={destination}
            onChange={(event) => setDestination(event.target.value)}
            placeholder="Search or enter destination"
            required
          />
        </label>
        <div className="ride-estimate" aria-live="polite">
          <span>Ride estimate</span>
          <strong>Available when rider dispatch is enabled</strong>
        </div>
        <button type="submit">Review ride request</button>
      </form>

      {message ? <p className={submitted ? "ride-message" : "muted"} role="status">{message}</p> : null}
    </section>
  );
}
