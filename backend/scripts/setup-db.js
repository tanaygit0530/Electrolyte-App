const { pool } = require('../config/neondb');
const bcrypt = require('bcrypt');

const setup = async () => {
  try {
    console.log('Connecting to NeonDB and running setup migrations...');

    // 0. Enable extensions
    await pool.query(`CREATE EXTENSION IF NOT EXISTS "pgcrypto";`);
    console.log('- pgcrypto extension verified/enabled');
    await pool.query(`CREATE EXTENSION IF NOT EXISTS "pg_trgm";`);
    console.log('- pg_trgm extension verified/enabled');

    // 1. Create tables
    await pool.query(`
      CREATE TABLE IF NOT EXISTS products (
        id SERIAL PRIMARY KEY,
        product_code VARCHAR(255) UNIQUE NOT NULL,
        product_name VARCHAR(255) NOT NULL,
        description TEXT,
        stock_quantity INTEGER NOT NULL DEFAULT 0,
        product_price NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
      );
    `);
    console.log('- products table verified/created');

    await pool.query(`CREATE INDEX IF NOT EXISTS idx_products_name_trgm ON products USING gin (product_name gin_trgm_ops);`);
    await pool.query(`CREATE INDEX IF NOT EXISTS idx_products_code_trgm ON products USING gin (product_code gin_trgm_ops);`);
    await pool.query(`CREATE INDEX IF NOT EXISTS idx_products_desc_trgm ON products USING gin (description gin_trgm_ops);`);
    console.log('- products trigram GIN indexes verified/created');

    await pool.query(`
      CREATE TABLE IF NOT EXISTS admins (
        id SERIAL PRIMARY KEY,
        email VARCHAR(255) UNIQUE NOT NULL,
        password_hash VARCHAR(255) NOT NULL,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
      );
    `);
    console.log('- admins table verified/created');

    await pool.query(`
      CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        email VARCHAR(255) UNIQUE NOT NULL,
        password_hash VARCHAR(255) NOT NULL,
        role VARCHAR(50) DEFAULT 'technician',
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
      );
    `);
    console.log('- users table verified/created');

    await pool.query(`
      CREATE TABLE IF NOT EXISTS stock_upload_history (
        id SERIAL PRIMARY KEY,
        file_name VARCHAR(255) NOT NULL,
        uploaded_by VARCHAR(255) NOT NULL,
        total_rows INTEGER NOT NULL,
        updated_rows INTEGER NOT NULL,
        failed_rows INTEGER NOT NULL,
        uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
      );
    `);
    console.log('- stock_upload_history table verified/created');

    await pool.query(`
      CREATE TABLE IF NOT EXISTS price_upload_history (
        id SERIAL PRIMARY KEY,
        file_name VARCHAR(255) NOT NULL,
        uploaded_by VARCHAR(255) NOT NULL,
        total_rows INTEGER NOT NULL,
        updated_rows INTEGER NOT NULL,
        failed_rows INTEGER NOT NULL,
        uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
      );
    `);
    console.log('- price_upload_history table verified/created');

    await pool.query(`
      CREATE TABLE IF NOT EXISTS orders (
        id SERIAL PRIMARY KEY,
        part_code VARCHAR(255) NOT NULL,
        part_name VARCHAR(255) NOT NULL,
        quantity INTEGER NOT NULL,
        price NUMERIC(10, 2) NOT NULL,
        gst NUMERIC(10, 2) NOT NULL,
        total_amount NUMERIC(10, 2) NOT NULL,
        status VARCHAR(50) DEFAULT 'Confirmed',
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
      );
    `);
    console.log('- orders table verified/created');

    await pool.query(`
      CREATE TABLE IF NOT EXISTS chat_sessions (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        title VARCHAR(255) DEFAULT 'New Chat',
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
      );
    `);
    console.log('- chat_sessions table verified/created');

    await pool.query(`
      CREATE TABLE IF NOT EXISTS chat_messages (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        session_id UUID REFERENCES chat_sessions(id) ON DELETE CASCADE,
        role VARCHAR(50) NOT NULL,
        content TEXT NOT NULL,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
      );
    `);
    console.log('- chat_messages table verified/created');

    await pool.query(`
      CREATE TABLE IF NOT EXISTS invoices (
        id SERIAL PRIMARY KEY,
        invoice_number VARCHAR(255) UNIQUE NOT NULL,
        technician_name VARCHAR(255) NOT NULL,
        customer_name VARCHAR(255) NOT NULL,
        customer_email VARCHAR(255),
        customer_phone VARCHAR(255),
        items JSONB NOT NULL,
        sub_total NUMERIC(10, 2) NOT NULL,
        gst_amount NUMERIC(10, 2) DEFAULT 0.00,
        service_charge NUMERIC(10, 2) DEFAULT 0.00,
        total_amount NUMERIC(10, 2) NOT NULL,
        pdf_url TEXT,
        status VARCHAR(50) DEFAULT 'Generated',
        brand VARCHAR(255),
        serial_number VARCHAR(255),
        case_id VARCHAR(255),
        warranty_type VARCHAR(255),
        prepared_by VARCHAR(255),
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
      );
    `);
    console.log('- invoices table verified/created');

    // 2. Seed default admin if not exists
    const adminEmail = 'admin@electrolyte.com';
    const adminPassword = 'admin123';

    const checkAdmin = await pool.query('SELECT * FROM admins WHERE email = $1', [adminEmail]);
    if (checkAdmin.rows.length === 0) {
      const passwordHash = await bcrypt.hash(adminPassword, 10);
      await pool.query(
        'INSERT INTO admins (email, password_hash) VALUES ($1, $2)',
        [adminEmail, passwordHash]
      );
      console.log(`- Default admin seeded successfully: ${adminEmail} / ${adminPassword}`);
    } else {
      console.log('- Admin user already exists');
    }

    // 3. Seed default technician user if not exists
    const techEmail = 'technician@example.com';
    const techPassword = 'password123';

    const checkTech = await pool.query('SELECT * FROM users WHERE email = $1', [techEmail]);
    if (checkTech.rows.length === 0) {
      const passwordHash = await bcrypt.hash(techPassword, 10);
      await pool.query(
        "INSERT INTO users (email, password_hash, role) VALUES ($1, $2, 'technician')",
        [techEmail, passwordHash]
      );
      console.log(`- Default technician seeded successfully: ${techEmail} / ${techPassword}`);
    } else {
      console.log('- Technician user already exists');
    }

    // 4. Seed initial products if not exists
    const dummyProducts = [
      { code: 'EA01701', name: 'Main PCB Controller Board', desc: 'Central microprocessor motherboard for electrical inventory systems', stock: 12, price: 1500.00 },
      { code: 'EA08001', name: 'Universal Power Supply Unit Module', desc: 'AC/DC regulator power board 12V/24V compatible', stock: 5, price: 850.50 },
      { code: 'EA03402', name: 'High Speed Cooling Fan', desc: 'Brushless dual bearing cooling system 120mm', stock: 25, price: 299.00 },
      { code: 'EA09901', name: 'Alphanumeric LCD Display Panel', desc: 'Interface panel screen 16x2 backlight display', stock: 0, price: 420.00 }
    ];

    for (const prod of dummyProducts) {
      const checkProd = await pool.query('SELECT * FROM products WHERE product_code = $1', [prod.code]);
      if (checkProd.rows.length === 0) {
        await pool.query(
          'INSERT INTO products (product_code, product_name, description, stock_quantity, product_price) VALUES ($1, $2, $3, $4, $5)',
          [prod.code, prod.name, prod.desc, prod.stock, prod.price]
        );
        console.log(`- Seeded product: ${prod.code} (${prod.name})`);
      }
    }

    console.log('Database migrations completed successfully!');
  } catch (error) {
    console.error('Error setting up database:', error);
  } finally {
    await pool.end();
    process.exit(0);
  }
};

setup();
