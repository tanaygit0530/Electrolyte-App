const { pool } = require('../config/neondb');
const bcrypt = require('bcrypt');

const setup = async () => {
  try {
    console.log('Connecting to NeonDB and running setup migrations...');

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

    // 2. Seed default admin if not exists
    const email = 'admin@electrolyte.com';
    const password = 'admin123';

    const checkAdmin = await pool.query('SELECT * FROM admins WHERE email = $1', [email]);
    if (checkAdmin.rows.length === 0) {
      const passwordHash = await bcrypt.hash(password, 10);
      await pool.query(
        'INSERT INTO admins (email, password_hash) VALUES ($1, $2)',
        [email, passwordHash]
      );
      console.log(`- Default admin seeded successfully: ${email} / ${password}`);
    } else {
      console.log('- Admin user already exists');
    }

    // 3. Seed initial products if not exists
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
