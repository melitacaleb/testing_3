-- Seed data for local development / initial demo data.
-- Applied via `supabase db reset` (local) or manually — NOT run automatically
-- against remote/production databases by the GitHub integration.

INSERT INTO motorists (full_name, license_number, phone_number, email, address) VALUES
('John Doe', 'DL123456', '0712345678', 'john@email.com', '123 Main St, Nairobi'),
('Jane Smith', 'DL789012', '0723456789', 'jane@email.com', '456 Park Ave, Mombasa'),
('Bob Johnson', 'DL345678', '0734567890', 'bob@email.com', '789 Oak Rd, Kisumu')
ON CONFLICT DO NOTHING;

INSERT INTO motorbikes (motorist_id, registration_number, brand, model, color, manufacture_year, purpose) VALUES
(1, 'KBA 123A', 'Honda', 'CBR 150', 'Red', 2022, 'personal_transport'),
(1, 'KBB 456B', 'Yamaha', 'MT-15', 'Blue', 2023, 'commercial'),
(2, 'KBC 789C', 'Bajaj', 'Pulsar', 'Black', 2021, 'hire')
ON CONFLICT DO NOTHING;

-- Default admin password below is a bcrypt hash of "melita@123" - CHANGE THIS
-- before using in any real/shared environment by generating your own hash,
-- e.g. from next-app/:
--   node -e "console.log(require('bcryptjs').hashSync('your-new-password', 10))"
INSERT INTO users (full_name, email, password, role) VALUES
('System Administrator', 'admin@example.com', '$2b$10$qGfcGeqaWIYLMQ6aTihdducWBhv5WPZgwMsEt8MO20av9uWSNkBNC', 'admin')
ON CONFLICT DO NOTHING;

INSERT INTO hire_details (motorbike_id, owner_name, owner_phone, owner_email, owner_address, hire_rate, hire_start_date, hire_end_date) VALUES
(3, 'Mike Wilson', '0745678901', 'mike@email.com', '321 Beach Rd, Mombasa', 1500.00, '2024-01-01', '2024-12-31')
ON CONFLICT DO NOTHING;
