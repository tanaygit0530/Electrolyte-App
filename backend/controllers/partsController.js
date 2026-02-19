const supabase = require('../config/supabaseClient');

exports.getAllParts = async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('spare_parts')
      .select('*');

    if (error) throw error;
    res.status(200).json(data);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

exports.getPartByCode = async (req, res) => {
  const { code } = req.params;
  try {
    const { data, error } = await supabase
      .from('spare_parts')
      .select('*')
      .eq('part_code', code)
      .single();

    if (error) {
      if (error.code === 'PGRST116') {
        return res.status(404).json({ message: 'Part not found' });
      }
      throw error;
    }
    res.status(200).json(data);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};
