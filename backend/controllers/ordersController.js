const supabase = require('../config/supabaseClient');
const Component = require('../models/Component');
const Order = require('../models/Order');

exports.createOrder = async (req, res) => {
  const { part_code, quantity } = req.body;

  try {
    if (supabase) {
      // 1. Fetch part details
      const { data: part, error: fetchError } = await supabase
        .from('spare_parts')
        .select('*')
        .eq('part_code', part_code)
        .single();

      if (!fetchError && part) {
        // 2. Check stock
        if (part.stock_quantity < quantity) {
          return res.status(400).json({ message: `Insufficient stock. Only ${part.stock_quantity} available.` });
        }

        // 3. Calculate billing
        const price = parseFloat(part.price);
        const subtotal = price * quantity;
        const gst = subtotal * 0.18;
        const total_amount = subtotal + gst;

        // 4. Create order
        const { data: order, error: orderError } = await supabase
          .from('orders')
          .insert([
            {
              part_code: part.part_code,
              part_name: part.part_name,
              quantity: quantity,
              price: price,
              gst: gst,
              total_amount: total_amount,
              status: 'Confirmed'
            }
          ])
          .select()
          .single();

        if (orderError) throw orderError;

        // 5. Update stock
        const newStock = part.stock_quantity - quantity;
        const newStatus = newStock === 0 ? 'Out of Stock' : (newStock < 5 ? 'Low' : 'Available');

        const { error: updateError } = await supabase
          .from('spare_parts')
          .update({ stock_quantity: newStock, status: newStatus })
          .eq('part_code', part_code);

        if (updateError) throw updateError;

        return res.status(201).json({
          message: 'Order confirmed',
          order: order
        });
      }
    }

    // --- MongoDB Fallback ---
    console.log("Supabase unavailable or part not found in Supabase. Using MongoDB for order.");
    const part = await Component.findOne({ code: part_code });
    if (!part) {
      return res.status(404).json({ message: 'Part not found' });
    }

    const currentStock = part.stockQuantity !== undefined ? part.stockQuantity : 10;
    if (currentStock < quantity) {
      return res.status(400).json({ message: `Insufficient stock. Only ${currentStock} available.` });
    }

    // Calculate billing
    const price = parseFloat(part.customerPrice || 0);
    const subtotal = price * quantity;
    const gst = subtotal * 0.18;
    const total_amount = subtotal + gst;

    // Create order
    const order = new Order({
      part_code: part.code,
      part_name: part.name,
      quantity: quantity,
      price: price,
      gst: gst,
      total_amount: total_amount,
      status: 'Confirmed'
    });
    await order.save();

    // Update stock
    part.stockQuantity = currentStock - quantity;
    await part.save();

    res.status(201).json({
      message: 'Order confirmed',
      order: order
    });

  } catch (error) {
    console.error("Order Creation Error:", error);
    res.status(500).json({ error: error.message });
  }
};

exports.getAllOrders = async (req, res) => {
  try {
    if (supabase) {
      const { data, error } = await supabase
        .from('orders')
        .select('*')
        .order('created_at', { ascending: false });

      if (!error && data) {
        return res.status(200).json(data);
      }
    }

    // --- MongoDB Fallback ---
    console.log("Supabase unavailable. Fetching orders from MongoDB.");
    const orders = await Order.find({}).sort({ created_at: -1 });
    res.status(200).json(orders);
  } catch (error) {
    console.error("Get All Orders Error:", error);
    res.status(500).json({ error: error.message });
  }
};
