const mongoose = require('mongoose');

const componentSchema = new mongoose.Schema({
  active: {
    type: Boolean,
    default: true
  },
  name: {
    type: String,
    required: true
  },
  code: {
    type: String,
    required: true,
    unique: true
  },
  description: {
    type: String
  },
  customerPrice: {
    type: Number,
    required: true
  },
  aspPrice: {
    type: Number
  },
  stockQuantity: {
    type: Number,
    default: 10
  }
}, { timestamps: true });

module.exports = mongoose.model('Component', componentSchema);
