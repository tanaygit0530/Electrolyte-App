class ExcelValidators {
  /// Validates a product code.
  static String? validateProductCode(dynamic value) {
    if (value == null) return 'Missing product code';
    final code = value.toString().trim();
    if (code.isEmpty) return 'Product code cannot be empty';
    return null;
  }

  /// Validates and parses stock quantity.
  /// Returns a Map containing either parsed [value] or [error].
  static Map<String, dynamic> validateAndParseStock(dynamic value) {
    if (value == null) {
      return {'error': 'Quantity is missing'};
    }
    
    final strVal = value.toString().trim();
    if (strVal.isEmpty) {
      return {'error': 'Quantity cannot be empty'};
    }

    try {
      // Sometimes excel double format parses as 10.0
      double dVal = double.parse(strVal);
      int iVal = dVal.round();
      
      if (dVal != iVal) {
        return {'error': 'Quantity must be a whole number: $strVal'};
      }

      if (iVal < 0) {
        return {'error': 'Quantity cannot be negative: $iVal'};
      }

      return {'value': iVal};
    } catch (e) {
      return {'error': 'Invalid quantity format: $strVal'};
    }
  }

  /// Validates and parses customer price, stripping out any 'INR', '$', commas, etc.
  /// Returns a Map containing either parsed [value] or [error].
  static Map<String, dynamic> validateAndParsePrice(dynamic value) {
    if (value == null) {
      return {'error': 'Price is missing'};
    }

    final strVal = value.toString().trim();
    if (strVal.isEmpty) {
      return {'error': 'Price cannot be empty'};
    }

    // Scrub the price: remove INR, commas, dollar signs, spaces
    String cleaned = strVal
        .toUpperCase()
        .replaceAll('INR', '')
        .replaceAll('\$', '')
        .replaceAll('₹', '')
        .replaceAll(',', '')
        .replaceAll(' ', '')
        .trim();

    try {
      double price = double.parse(cleaned);
      if (price < 0) {
        return {'error': 'Price cannot be negative: $strVal'};
      }
      return {'value': price};
    } catch (e) {
      return {'error': 'Invalid currency/price format: $strVal'};
    }
  }
}
