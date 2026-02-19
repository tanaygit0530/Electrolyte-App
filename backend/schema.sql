-- Create spare_parts table
CREATE TABLE spare_parts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  part_name TEXT NOT NULL,
  part_code TEXT UNIQUE NOT NULL,
  model TEXT NOT NULL,
  price NUMERIC(10, 2) NOT NULL,
  stock_quantity INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL, -- Available, Low, Out of Stock
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create orders table
CREATE TABLE orders (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  part_code TEXT NOT NULL,
  part_name TEXT NOT NULL,
  quantity INTEGER NOT NULL,
  price NUMERIC(10, 2) NOT NULL,
  gst NUMERIC(10, 2) NOT NULL,
  total_amount NUMERIC(10, 2) NOT NULL,
  status TEXT NOT NULL, -- Confirmed, Cancelled
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Insert Dummy Data for spare_parts
INSERT INTO spare_parts (part_name, part_code, model, price, stock_quantity, status)
VALUES 
('PCB Board Main', 'PCB1234', 'X-Series 2024', 2500.00, 10, 'Available'),
('Display Panel', 'DISP9988', 'Ultra-V', 4500.50, 2, 'Low'),
('Power Supply Unit', 'PSU5566', 'Universal', 1200.00, 15, 'Available'),
('Cooling Fan', 'FAN1122', 'Compact', 350.00, 0, 'Out of Stock');
