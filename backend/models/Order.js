const mongoose = require('mongoose');

const orderSchema = new mongoose.Schema({
  part_code: { type: String, required: true },
  part_name: { type: String, required: true },
  quantity: { type: Number, required: true },
  price: { type: Number, required: true },
  gst: { type: Number, required: true },
  total_amount: { type: Number, required: true },
  status: { type: String, default: 'Confirmed' }
}, {
  timestamps: { createdAt: 'created_at', updatedAt: 'updated_at' }
});

// Map _id to id virtual and serialize properly
orderSchema.virtual('id').get(function() {
  return this._id.toHexString();
});

orderSchema.set('toJSON', {
  virtuals: true,
  transform: function(doc, ret) {
    ret.id = ret._id.toString();
    delete ret._id;
    delete ret.__v;
    return ret;
  }
});

module.exports = mongoose.models.Order || mongoose.model('Order', orderSchema);
