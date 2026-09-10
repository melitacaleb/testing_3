-- Initial schema migration for the Motorist Traffic Control System
-- Mirrors the root schema.postgres.sql (previously run directly against Neon).
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

-- complaints
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

-- activity_log
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
