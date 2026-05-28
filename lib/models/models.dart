import 'dart:convert';

class Product {
  final String id;
  final String code;
  final String name;
  final double price;
  final double costPrice;
  final double salePrice;
  final double stock;
  final String? category;
  final String? unit;
  final double? minStock;
  final String? supplierId;
  final String userId;
  final DateTime addedAt;
  final String pricingMode; // 'weight' or 'pcs'

  Product({
    required this.id,
    required this.code,
    required this.name,
    required this.price,
    required this.costPrice,
    required this.salePrice,
    required this.stock,
    this.category,
    this.unit,
    this.minStock,
    this.supplierId,
    required this.userId,
    required this.addedAt,
    this.pricingMode = 'pcs',
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      costPrice: (json['cost_price'] as num?)?.toDouble() ?? 0.0,
      salePrice: (json['sale_price'] as num?)?.toDouble() ?? (json['price'] as num?)?.toDouble() ?? 0.0,
      stock: (json['stock'] as num?)?.toDouble() ?? 0.0,
      category: json['category']?.toString(),
      unit: json['unit']?.toString(),
      minStock: (json['min_stock'] as num?)?.toDouble(),
      supplierId: json['supplier_id']?.toString(),
      userId: json['user_id']?.toString() ?? '',
      addedAt: json['added_at'] != null ? DateTime.parse(json['added_at']) : DateTime.now(),
      pricingMode: json['pricing_mode']?.toString() ?? 'pcs',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'price': price,
      'cost_price': costPrice,
      'sale_price': salePrice,
      'stock': stock,
      'category': category,
      'unit': unit,
      'min_stock': minStock,
      'supplier_id': supplierId,
      'user_id': userId,
      'added_at': addedAt.toIso8601String(),
      'pricing_mode': pricingMode,
    };
  }

  Product copyWith({
    String? id,
    String? code,
    String? name,
    double? price,
    double? costPrice,
    double? salePrice,
    double? stock,
    String? category,
    String? unit,
    double? minStock,
    String? supplierId,
    String? userId,
    DateTime? addedAt,
    String? pricingMode,
  }) {
    return Product(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      price: price ?? this.price,
      costPrice: costPrice ?? this.costPrice,
      salePrice: salePrice ?? this.salePrice,
      stock: stock ?? this.stock,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      minStock: minStock ?? this.minStock,
      supplierId: supplierId ?? this.supplierId,
      userId: userId ?? this.userId,
      addedAt: addedAt ?? this.addedAt,
      pricingMode: pricingMode ?? this.pricingMode,
    );
  }
}

class CartItem {
  final Product product;
  double quantity;

  CartItem({
    required this.product,
    required this.quantity,
  });

  double get subtotal => product.salePrice * quantity;

  Map<String, dynamic> toJson() {
    return {
      'id': product.id,
      'code': product.code,
      'name': product.name,
      'price': product.salePrice,
      'quantity': quantity,
    };
  }
}

class Sale {
  final String id;
  final String date;
  final String time;
  final String customer;
  final String? customerPhone;
  final String? customerAddress;
  final List<dynamic> items;
  final double subtotal;
  final double discount;
  final double discountAmount;
  final double taxRate;
  final double tax;
  final double total;
  final String paymentMethod;
  final double amountReceived;
  final double changeDue;
  final double cost;
  final double profit;
  final String userId;

  Sale({
    required this.id,
    required this.date,
    required this.time,
    required this.customer,
    this.customerPhone,
    this.customerAddress,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.discountAmount,
    required this.taxRate,
    required this.tax,
    required this.total,
    required this.paymentMethod,
    required this.amountReceived,
    required this.changeDue,
    required this.cost,
    required this.profit,
    required this.userId,
  });

  factory Sale.fromJson(Map<String, dynamic> json) {
    List<dynamic> parsedItems = [];
    if (json['items'] != null) {
      if (json['items'] is String) {
        try {
          parsedItems = jsonDecode(json['items']);
        } catch (_) {}
      } else {
        parsedItems = json['items'] as List<dynamic>;
      }
    }
    return Sale(
      id: json['id']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      time: json['time']?.toString() ?? '',
      customer: json['customer']?.toString() ?? 'Walk-in Customer',
      customerPhone: json['customer_phone']?.toString(),
      customerAddress: json['customer_address']?.toString(),
      items: parsedItems,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0.0,
      taxRate: (json['tax_rate'] as num?)?.toDouble() ?? 0.0,
      tax: (json['tax'] as num?)?.toDouble() ?? 0.0,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['payment_method']?.toString() ?? 'Cash',
      amountReceived: (json['amount_received'] as num?)?.toDouble() ?? 0.0,
      changeDue: (json['change_due'] as num?)?.toDouble() ?? 0.0,
      cost: (json['cost'] as num?)?.toDouble() ?? 0.0,
      profit: (json['profit'] as num?)?.toDouble() ?? 0.0,
      userId: json['user_id']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date,
      'time': time,
      'customer': customer,
      'customer_phone': customerPhone,
      'customer_address': customerAddress,
      'items': items,
      'subtotal': subtotal,
      'discount': discount,
      'discount_amount': discountAmount,
      'tax_rate': taxRate,
      'tax': tax,
      'total': total,
      'payment_method': paymentMethod,
      'amount_received': amountReceived,
      'change_due': changeDue,
      'cost': cost,
      'profit': profit,
      'user_id': userId,
    };
  }
}

class CashTransaction {
  final String? id;
  final String type; // IN or OUT
  final double amount;
  final String purpose;
  final DateTime date;
  final double balanceAfter;
  final String userId;

  CashTransaction({
    this.id,
    required this.type,
    required this.amount,
    required this.purpose,
    required this.date,
    required this.balanceAfter,
    required this.userId,
  });

  factory CashTransaction.fromJson(Map<String, dynamic> json) {
    return CashTransaction(
      id: json['id']?.toString(),
      type: json['type']?.toString() ?? 'IN',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      purpose: json['purpose']?.toString() ?? '',
      date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      balanceAfter: (json['balance_after'] as num?)?.toDouble() ?? 0.0,
      userId: json['user_id']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'type': type,
      'amount': amount,
      'purpose': purpose,
      'date': date.toIso8601String(),
      'balance_after': balanceAfter,
      'user_id': userId,
    };
  }
}

class Customer {
  final String id;
  final String name;
  final String phone;
  final String? address;
  final int totalOrders;
  final double totalSpent;
  final double creditBalance;
  final double creditLimit;
  final String userId;

  Customer({
    required this.id,
    required this.name,
    required this.phone,
    this.address,
    required this.totalOrders,
    required this.totalSpent,
    this.creditBalance = 0.0,
    this.creditLimit = 50000.0,
    required this.userId,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      address: json['address']?.toString(),
      totalOrders: json['total_orders'] as int? ?? 0,
      totalSpent: (json['total_spent'] as num?)?.toDouble() ?? 0.0,
      creditBalance: (json['credit_balance'] as num?)?.toDouble() ?? 0.0,
      creditLimit: (json['credit_limit'] as num?)?.toDouble() ?? 50000.0,
      userId: json['user_id']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'address': address,
      'total_orders': totalOrders,
      'total_spent': totalSpent,
      'credit_balance': creditBalance,
      'credit_limit': creditLimit,
      'user_id': userId,
    };
  }

  Customer copyWith({
    String? id,
    String? name,
    String? phone,
    String? address,
    int? totalOrders,
    double? totalSpent,
    double? creditBalance,
    double? creditLimit,
    String? userId,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      totalOrders: totalOrders ?? this.totalOrders,
      totalSpent: totalSpent ?? this.totalSpent,
      creditBalance: creditBalance ?? this.creditBalance,
      creditLimit: creditLimit ?? this.creditLimit,
      userId: userId ?? this.userId,
    );
  }
}

class CreditTransaction {
  final String id;
  final String customerId;
  final String type; // 'PURCHASE' or 'PAYMENT'
  final double amount;
  final String date;
  final String? saleId;
  final String userId;
  final String? details;
  final String? paymentMethod;

  CreditTransaction({
    required this.id,
    required this.customerId,
    required this.type,
    required this.amount,
    required this.date,
    this.saleId,
    required this.userId,
    this.details,
    this.paymentMethod,
  });

  factory CreditTransaction.fromJson(Map<String, dynamic> json) {
    return CreditTransaction(
      id: json['id']?.toString() ?? '',
      customerId: json['customer_id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'PURCHASE',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      date: json['date']?.toString() ?? '',
      saleId: json['sale_id']?.toString(),
      userId: json['user_id']?.toString() ?? '',
      details: json['details']?.toString(),
      paymentMethod: json['payment_method']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer_id': customerId,
      'type': type,
      'amount': amount,
      'date': date,
      if (saleId != null) 'sale_id': saleId,
      'user_id': userId,
      if (details != null) 'details': details,
      if (paymentMethod != null) 'payment_method': paymentMethod,
    };
  }
}

class Supplier {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final String? address;
  final int totalOrders;
  final double totalSpent;
  final String userId;

  Supplier({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.address,
    required this.totalOrders,
    required this.totalSpent,
    required this.userId,
  });

  factory Supplier.fromJson(Map<String, dynamic> json) {
    return Supplier(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString(),
      address: json['address']?.toString(),
      totalOrders: json['total_orders'] as int? ?? 0,
      totalSpent: (json['total_spent'] as num?)?.toDouble() ?? 0.0,
      userId: json['user_id']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'total_orders': totalOrders,
      'total_spent': totalSpent,
      'user_id': userId,
    };
  }
}
