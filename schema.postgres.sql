-- schema.postgres.sql
-- Run this against your Neon database (e.g. via `psql "$DATABASE_URL" -f schema.postgres.sql`)
-- Translated from MySQL: AUTO_INCREMENT -> SERIAL/GENERATED, ENUM -> VARCHAR+CHECK,
-- YEAR -> INTEGER, TIMESTAMP DEFAULT CURRENT_TIMESTAMP kept as-is (supported natively).

-- motorists
CREATE TABLE IF NOT EXISTS motorists (
    id SERIAL PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    license_number VARCHAR(50) NOT NULL,
    phone_number VARCHAR(15) NOT NULL,
    email VARCHAR(100),
    address TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'inactive', 'suspended')),
    date_registered TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- motorbikes
CREATE TABLE IF NOT EXISTS motorbikes (
    id SERIAL PRIMARY KEY,
    motorist_id INTEGER NOT NULL REFERENCES motorists(id) ON DELETE CASCADE,
    registration_number VARCHAR(20) UNIQUE NOT NULL,
    brand VARCHAR(50) NOT NULL,
    model VARCHAR(50) NOT NULL,
    color VARCHAR(30),
    manufacture_year INTEGER,
    purpose VARCHAR(30) NOT NULL
        CHECK (purpose IN ('commercial', 'personal_transport', 'hire')),
    status VARCHAR(20) NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'inactive', 'suspended')),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- users (admin accounts)
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    role VARCHAR(20) NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'admin')),
    status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- user_account (public user registrations)
CREATE TABLE IF NOT EXISTS user_account (
    id SERIAL PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    role VARCHAR(20) NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'admin')),
    status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
    motorist_id INTEGER,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- receipts
CREATE TABLE IF NOT EXISTS receipts (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES user_account(id) ON DELETE CASCADE,
    title VARCHAR(150) NOT NULL,
    amount NUMERIC(10,2) NOT NULL DEFAULT 0.00,
    description TEXT,
    issued_by VARCHAR(100) DEFAULT 'System Admin',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- citations
CREATE TABLE IF NOT EXISTS citations (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES user_account(id) ON DELETE CASCADE,
    violation VARCHAR(255) NOT NULL,
    amount NUMERIC(10,2) NOT NULL DEFAULT 0.00,
    issued_by VARCHAR(100) DEFAULT 'System Admin',
    issued_at DATE NOT NULL DEFAULT CURRENT_DATE,
    status VARCHAR(20) NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'resolved')),
    notes TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- hire_details
CREATE TABLE IF NOT EXISTS hire_details (
    id SERIAL PRIMARY KEY,
    motorbike_id INTEGER NOT NULL UNIQUE REFERENCES motorbikes(id) ON DELETE CASCADE,
    owner_name VARCHAR(100) NOT NULL,
    owner_phone VARCHAR(15) NOT NULL,
    owner_email VARCHAR(100),
    owner_address TEXT,
    hire_rate NUMERIC(10,2),
    hire_start_date DATE,
    hire_end_date DATE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- complaints (referenced throughout the admin/users code but missing from
-- the original .sql files - reconstructed from how the columns are used)
CREATE TABLE IF NOT EXISTS complaints (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES user_account(id) ON DELETE CASCADE,
    subject VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'open'
        CHECK (status IN ('open', 'in_progress', 'resolved', 'closed')),
    admin_response TEXT,
    responder_id INTEGER,
    responded_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- activity_log (referenced by logActivity() but missing from original .sql)
CREATE TABLE IF NOT EXISTS activity_log (
    id SERIAL PRIMARY KEY,
    user_id INTEGER,
    action VARCHAR(100) NOT NULL,
    description TEXT,
    ip_address VARCHAR(64),
    user_agent TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Helpful indexes
CREATE INDEX IF NOT EXISTS idx_motorbikes_motorist_id ON motorbikes(motorist_id);
CREATE INDEX IF NOT EXISTS idx_receipts_user_id ON receipts(user_id);
CREATE INDEX IF NOT EXISTS idx_citations_user_id ON citations(user_id);
CREATE INDEX IF NOT EXISTS idx_complaints_user_id ON complaints(user_id);

-- Sample data
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

-- Default admin password below is a bcrypt hash of "password" - CHANGE THIS
-- immediately after first login, or better, generate your own with
-- password_hash('your-password', PASSWORD_DEFAULT) and swap it in before running.
INSERT INTO users (full_name, email, password, role) VALUES
('System Administrator', 'admin@example.com', '$2y$10$6BnWlqJT3cVoTfJqwBcMBOyFa71hKyUzROCD0BlkBcfa7IWcIXm9q', 'admin')
ON CONFLICT DO NOTHING;

INSERT INTO hire_details (motorbike_id, owner_name, owner_phone, owner_email, owner_address, hire_rate, hire_start_date, hire_end_date) VALUES
(3, 'Mike Wilson', '0745678901', 'mike@email.com', '321 Beach Rd, Mombasa', 1500.00, '2024-01-01', '2024-12-31')
ON CONFLICT DO NOTHING;
