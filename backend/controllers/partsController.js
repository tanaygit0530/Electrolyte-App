const Component = require('../models/Component');

// Map MongoDB Component to match legacy format for the Flutter app
const formatComponent = (comp) => ({
  id: comp._id.toString(),
  part_name: comp.name,
  part_code: comp.code,
  model: comp.description || 'N/A',
  price: comp.customerPrice || 0,
  stock_quantity: 10, // Default fallback
  status: comp.active ? 'Available' : 'Out of Stock'
});

exports.getAllParts = async (req, res) => {
  try {
    const components = await Component.find({});
    const formattedData = components.map(formatComponent);
    res.status(200).json(formattedData);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

exports.getPartByCode = async (req, res) => {
  const { code } = req.params;
  try {
    const comp = await Component.findOne({ code });

    if (!comp) {
      return res.status(404).json({ message: 'Part not found' });
    }
    
    res.status(200).json(formatComponent(comp));
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

exports.searchParts = async (req, res) => {
  const { q } = req.query;
  
  if (!q) {
    return res.status(200).json([]);
  }

  try {
    const components = await Component.find({
      $or: [
        { name: { $regex: q, $options: 'i' } },
        { code: { $regex: q, $options: 'i' } }
      ]
    }).limit(5);

    const formattedData = components.map(formatComponent);
    res.status(200).json(formattedData);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};
