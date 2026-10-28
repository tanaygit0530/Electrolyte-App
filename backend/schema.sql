-- ============================================================================
-- Electrolyte App - Complete PostgreSQL Production Database Schema
-- ============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- ----------------------------------------------------------------------------
-- 1. Users Table (Technicians and Administrators)
-- ----------------------------------------------------------------------------
CREATE SEQUENCE IF NOT EXISTS technician_id_seq START WITH 1001;

CREATE TABLE IF NOT EXISTS users (
  id SERIAL PRIMARY KEY,
  technician_id VARCHAR(50) UNIQUE NOT NULL DEFAULT ('TECH-' || nextval('technician_id_seq')),
  name VARCHAR(255) NOT NULL,
  email VARCHAR(255) UNIQUE NOT NULL,
  phone VARCHAR(50),
  password_hash VARCHAR(255) NOT NULL,
  role VARCHAR(50) NOT NULL DEFAULT 'technician', -- 'technician' or 'admin'
  is_active BOOLEAN NOT NULL DEFAULT true,
  failed_login_attempts INT NOT NULL DEFAULT 0,
  account_locked_until TIMESTAMP WITH TIME ZONE,
  reset_password_token VARCHAR(255),
  reset_password_expires TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_email ON users (LOWER(email));
CREATE INDEX IF NOT EXISTS idx_users_technician_id ON users (UPPER(technician_id));
CREATE INDEX IF NOT EXISTS idx_users_role ON users (role);
CREATE INDEX IF NOT EXISTS idx_users_reset_token ON users (reset_password_token) WHERE reset_password_token IS NOT NULL;

-- ----------------------------------------------------------------------------
-- 2. Legacy Admins Table (Maintained for backward compatibility)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS admins (
  id SERIAL PRIMARY KEY,
  email VARCHAR(255) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_admins_email ON admins (LOWER(email));

-- ----------------------------------------------------------------------------
-- 3. Products / Inventory Catalog
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS products (
  id SERIAL PRIMARY KEY,
  product_code VARCHAR(100) UNIQUE NOT NULL,
  product_name TEXT NOT NULL,
  description TEXT,
  product_price NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
  stock_quantity INT NOT NULL DEFAULT 0,
  location VARCHAR(255) DEFAULT 'Main Warehouse',
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_products_code ON products (product_code);
CREATE INDEX IF NOT EXISTS idx_products_name_trgm ON products USING gin (product_name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_products_desc_trgm ON products USING gin (description gin_trgm_ops);

-- ----------------------------------------------------------------------------
-- 4. Invoices Table
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS invoices (
  id SERIAL PRIMARY KEY,
  invoice_number VARCHAR(100) UNIQUE NOT NULL,
  user_id INT REFERENCES users(id) ON DELETE SET NULL,
  technician_name VARCHAR(255),
  technician_id VARCHAR(50),
  customer_name VARCHAR(255) NOT NULL,
  customer_email VARCHAR(255),
  customer_phone VARCHAR(50),
  items JSONB NOT NULL DEFAULT '[]',
  sub_total NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
  gst_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
  service_charge NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
  total_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
  pdf_url TEXT,
  status VARCHAR(50) NOT NULL DEFAULT 'Pending', -- 'Pending', 'Paid', 'Cancelled'
  brand VARCHAR(100),
  serial_number VARCHAR(100),
  case_id VARCHAR(100),
  warranty_type VARCHAR(100),
  prepared_by VARCHAR(255),
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_invoices_invoice_number ON invoices (invoice_number);
CREATE INDEX IF NOT EXISTS idx_invoices_user_id ON invoices (user_id);
CREATE INDEX IF NOT EXISTS idx_invoices_technician_id ON invoices (technician_id);
CREATE INDEX IF NOT EXISTS idx_invoices_created_at ON invoices (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_invoices_customer_name ON invoices (customer_name);

-- ----------------------------------------------------------------------------
-- 5. Service Records (60-Day Repeat Service Auditing)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS service_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  case_number VARCHAR(100),
  work_order_line_item VARCHAR(50),
  serial_no VARCHAR(255) NOT NULL,
  replacement_serial_no VARCHAR(255),
  customer_name VARCHAR(255),
  service_territory VARCHAR(255),
  street TEXT,
  city VARCHAR(100),
  state VARCHAR(100),
  zip_code VARCHAR(20),
  customer_complaint TEXT,
  wo_status VARCHAR(50),
  symptom TEXT,
  defect TEXT,
  repair TEXT,
  end_date VARCHAR(100),
  parsed_end_date TIMESTAMP WITH TIME ZONE,
  days VARCHAR(20),
  product_code VARCHAR(100),
  product_name VARCHAR(255),
  product_description TEXT,
  product_type VARCHAR(100),
  product_sub_type VARCHAR(100),
  warranty_status VARCHAR(50),
  type_of_work_order VARCHAR(100),
  line_item_status VARCHAR(50),
  sdr_status VARCHAR(50),
  invoice_date VARCHAR(100),
  technician_name VARCHAR(255),
  technician_remarks TEXT,
  type_of_resolution VARCHAR(100),
  closed_date VARCHAR(100),
  parsed_closed_date TIMESTAMP WITH TIME ZONE,
  is_active_60d BOOLEAN DEFAULT FALSE,
  created_date TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Unique composite constraint for idempotent upserts and cross-upload deduplication
CREATE UNIQUE INDEX IF NOT EXISTS idx_service_records_composite_key 
ON service_records (case_number, work_order_line_item, serial_no);

CREATE INDEX IF NOT EXISTS idx_service_records_serial_lookup 
ON service_records (UPPER(TRIM(serial_no)), parsed_end_date DESC NULLS LAST);

CREATE INDEX IF NOT EXISTS idx_service_records_repl_serial_lookup 
ON service_records (UPPER(TRIM(replacement_serial_no)), parsed_end_date DESC NULLS LAST)
WHERE replacement_serial_no IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_service_records_active_60d 
ON service_records (is_active_60d) 
WHERE is_active_60d = true;

CREATE INDEX IF NOT EXISTS idx_service_records_parsed_end_date 
ON service_records (parsed_end_date);


CREATE TABLE IF NOT EXISTS service_upload_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  file_name VARCHAR(255) NOT NULL,
  uploaded_by VARCHAR(255),
  total_records INT NOT NULL DEFAULT 0,
  valid_records INT NOT NULL DEFAULT 0,
  rejected_records INT NOT NULL DEFAULT 0,
  duplicates_in_file INT NOT NULL DEFAULT 0,
  found_within_60_days INT NOT NULL DEFAULT 0,
  older_than_60_days INT NOT NULL DEFAULT 0,
  inserted_records INT NOT NULL DEFAULT 0,
  updated_records INT NOT NULL DEFAULT 0,
  unchanged_records INT NOT NULL DEFAULT 0,
  processing_duration_ms INT NOT NULL DEFAULT 0,
  error_summary JSONB DEFAULT '[]'::jsonb,
  status VARCHAR(50) DEFAULT 'completed',
  uploaded_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- ----------------------------------------------------------------------------
-- 6. Audit Logs: Stock & Price Upload History
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS stock_upload_history (
  id SERIAL PRIMARY KEY,
  file_name VARCHAR(255) NOT NULL,
  total_rows INT NOT NULL DEFAULT 0,
  successful_rows INT NOT NULL DEFAULT 0,
  failed_rows INT NOT NULL DEFAULT 0,
  error_log JSONB DEFAULT '[]',
  uploaded_by VARCHAR(255),
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS price_upload_history (
  id SERIAL PRIMARY KEY,
  file_name VARCHAR(255) NOT NULL,
  total_rows INT NOT NULL DEFAULT 0,
  successful_rows INT NOT NULL DEFAULT 0,
  failed_rows INT NOT NULL DEFAULT 0,
  error_log JSONB DEFAULT '[]',
  uploaded_by VARCHAR(255),
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- ----------------------------------------------------------------------------
-- 7. Chat System (AI Assistant Sessions & Messages)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS chat_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id INT REFERENCES users(id) ON DELETE CASCADE,
  title TEXT DEFAULT 'New Chat',
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_chat_sessions_user_id ON chat_sessions (user_id);

CREATE TABLE IF NOT EXISTS chat_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES chat_sessions(id) ON DELETE CASCADE,
  role VARCHAR(50) NOT NULL, -- 'user' or 'assistant'
  content TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_chat_messages_session ON chat_messages (session_id, created_at ASC);

-- ----------------------------------------------------------------------------
-- 8. Orders Table
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id INT REFERENCES users(id) ON DELETE SET NULL,
  part_code VARCHAR(100) NOT NULL,
  part_name TEXT NOT NULL,
  quantity INT NOT NULL DEFAULT 1,
  price NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
  gst NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
  total_amount NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
  status VARCHAR(50) NOT NULL DEFAULT 'Confirmed',
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_orders_user_id ON orders (user_id);
