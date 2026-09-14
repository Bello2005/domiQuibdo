import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

double _toDouble(Object? value) => (value as num).toDouble();

LatLng _latLng(Map<String, dynamic> json, [String lat = 'latitude', String lng = 'longitude']) =>
    LatLng(_toDouble(json[lat]), _toDouble(json[lng]));

enum UserRole {
  cliente('Cliente'),
  restaurante('Restaurante'),
  repartidor('Repartidor'),
  admin('Administrador');

  const UserRole(this.label);
  final String label;
}

class AppUser {
  const AppUser({required this.id, required this.name, required this.email, required this.role, this.phone});

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as int,
        name: json['name'] as String,
        email: json['email'] as String,
        phone: json['phone'] as String?,
        role: UserRole.values.byName(json['role'] as String),
      );

  final int id;
  final String name;
  final String email;
  final String? phone;
  final UserRole role;

  bool get isDriver => role == UserRole.repartidor;
  String get firstName => name.split(' ').first;
  String get initials => name.split(' ').where((p) => p.isNotEmpty).take(2).map((p) => p[0].toUpperCase()).join();
}

class Zone {
  const Zone({required this.id, required this.name, required this.center, required this.radiusM});

  factory Zone.fromJson(Map<String, dynamic> json) => Zone(
        id: json['id'] as int,
        name: json['name'] as String,
        center: _latLng(json, 'center_lat', 'center_lng'),
        radiusM: json['radius_m'] as int,
      );

  final int id;
  final String name;
  final LatLng center;
  final int radiusM;

  bool contains(LatLng point) => const Distance().as(LengthUnit.Meter, center, point) <= radiusM;
}

enum AddressType {
  casa('Casa', Icons.home_outlined, 'Ej: casa de dos pisos, portón verde'),
  apartamento('Apartamento', Icons.apartment_outlined, 'Ej: Torre 2, apto 301'),
  hotel('Hotel', Icons.hotel_outlined, 'Ej: nombre del hotel, habitación 204'),
  residencia('Residencia', Icons.night_shelter_outlined, 'Ej: residencia estudiantil, cuarto 12'),
  oficina('Oficina', Icons.business_center_outlined, 'Ej: edificio, piso 3, oficina 302'),
  otro('Otro', Icons.place_outlined, 'Punto de referencia para encontrarte');

  const AddressType(this.label, this.icon, this.hint);
  final String label;
  final IconData icon;
  final String hint;
}

class Address {
  const Address({
    required this.id,
    required this.position,
    required this.tipo,
    required this.esPredeterminada,
    this.detalle,
    this.zoneId,
    this.zoneName,
  });

  factory Address.fromJson(Map<String, dynamic> json) {
    final zone = json['zone'] as Map<String, dynamic>?;
    return Address(
      id: json['id'] as int,
      position: _latLng(json),
      tipo: AddressType.values.byName(json['tipo'] as String),
      detalle: json['detalle'] as String?,
      esPredeterminada: json['es_predeterminada'] as bool? ?? false,
      zoneId: zone?['id'] as int?,
      zoneName: zone?['name'] as String?,
    );
  }

  final int id;
  final LatLng position;
  final AddressType tipo;
  final String? detalle;
  final bool esPredeterminada;
  final int? zoneId;
  final String? zoneName;

  String get title => zoneName == null ? tipo.label : '${tipo.label} · $zoneName';
}

/// Plato del menú (se evita el nombre `MenuItem`, que ya existe en Flutter).
class Dish {
  const Dish({required this.id, required this.restaurantId, required this.name, required this.price, this.description});

  factory Dish.fromJson(Map<String, dynamic> json) => Dish(
        id: json['id'] as int,
        restaurantId: json['restaurant_id'] as int,
        name: json['name'] as String,
        description: json['description'] as String?,
        price: _toDouble(json['price']),
      );

  final int id;
  final int restaurantId;
  final String name;
  final String? description;
  final double price;
}

class Restaurant {
  const Restaurant({
    required this.id,
    required this.name,
    required this.category,
    required this.position,
    required this.addressText,
    required this.rating,
    required this.deliveryTimeMin,
    this.description,
    this.phone,
    this.menu = const [],
  });

  factory Restaurant.fromJson(Map<String, dynamic> json) => Restaurant(
        id: json['id'] as int,
        name: json['name'] as String,
        description: json['description'] as String?,
        category: json['category'] as String,
        position: _latLng(json),
        addressText: json['address_text'] as String,
        phone: json['phone'] as String?,
        rating: _toDouble(json['rating_avg']),
        deliveryTimeMin: json['delivery_time_min'] as int,
        menu: [
          for (final item in (json['menu_items'] as List<dynamic>? ?? const []))
            Dish.fromJson(item as Map<String, dynamic>),
        ],
      );

  final int id;
  final String name;
  final String? description;
  final String category;
  final LatLng position;
  final String addressText;
  final String? phone;
  final double rating;
  final int deliveryTimeMin;
  final List<Dish> menu;

  String get etaLabel => '$deliveryTimeMin-${deliveryTimeMin + 10} min';
}

enum OrderStatus {
  pendiente('pendiente', 'Recibido', Icons.receipt_long_outlined, 'Esperando confirmación del restaurante'),
  confirmado('confirmado', 'Confirmado', Icons.thumb_up_alt_outlined, 'El restaurante confirmó tu pedido'),
  preparando('preparando', 'Preparando', Icons.soup_kitchen_outlined, 'Están preparando tu pedido'),
  enCamino('en_camino', 'En camino', Icons.two_wheeler, 'Tu pedido va en camino'),
  entregado('entregado', 'Entregado', Icons.check_circle_outline, '¡Pedido entregado!'),
  cancelado('cancelado', 'Cancelado', Icons.cancel_outlined, 'Pedido cancelado');

  const OrderStatus(this.value, this.label, this.icon, this.headline);
  final String value;
  final String label;
  final IconData icon;
  final String headline;

  static const flow = [pendiente, confirmado, preparando, enCamino, entregado];

  static OrderStatus parse(String value) => values.firstWhere((s) => s.value == value);

  OrderStatus? get next => switch (this) {
        pendiente => confirmado,
        confirmado => preparando,
        preparando => enCamino,
        enCamino => entregado,
        _ => null,
      };

  bool get isActive => this != entregado && this != cancelado;
}

const paymentMethods = {
  'efectivo': ('Efectivo', Icons.payments_outlined),
  'transferencia': ('Transferencia', Icons.account_balance_outlined),
  'nequi': ('Nequi', Icons.phone_iphone),
};

class OrderItem {
  const OrderItem({required this.name, required this.quantity, required this.unitPrice, required this.subtotal});

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
        name: json['name'] as String? ?? 'Producto',
        quantity: json['quantity'] as int,
        unitPrice: _toDouble(json['unit_price']),
        subtotal: _toDouble(json['subtotal']),
      );

  final String name;
  final int quantity;
  final double unitPrice;
  final double subtotal;
}

class Contact {
  const Contact({required this.name, this.phone});

  static Contact? maybeFromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    return Contact(name: json['name'] as String, phone: json['phone'] as String?);
  }

  final String name;
  final String? phone;
}

class Order {
  const Order({
    required this.id,
    required this.status,
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
    required this.paymentMethod,
    required this.createdAt,
    this.notes,
    this.verificationCode,
    this.restaurant,
    this.address,
    this.items = const [],
    this.itemsCount,
    this.repartidor,
    this.customer,
  });

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: json['id'] as int,
        status: OrderStatus.parse(json['status'] as String),
        subtotal: _toDouble(json['subtotal']),
        deliveryFee: _toDouble(json['delivery_fee']),
        total: _toDouble(json['total']),
        paymentMethod: json['payment_method'] as String,
        notes: json['notes'] as String?,
        verificationCode: json['verification_code'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        restaurant: json['restaurant'] == null
            ? null
            : Restaurant.fromJson(json['restaurant'] as Map<String, dynamic>),
        address: json['address'] == null ? null : Address.fromJson(json['address'] as Map<String, dynamic>),
        items: [
          for (final item in (json['items'] as List<dynamic>? ?? const []))
            OrderItem.fromJson(item as Map<String, dynamic>),
        ],
        itemsCount: json['items_count'] as int?,
        repartidor: Contact.maybeFromJson(json['repartidor']),
        customer: Contact.maybeFromJson(json['customer']),
      );

  final int id;
  final OrderStatus status;
  final double subtotal;
  final double deliveryFee;
  final double total;
  final String paymentMethod;
  final String? notes;
  final String? verificationCode;
  final DateTime createdAt;
  final Restaurant? restaurant;
  final Address? address;
  final List<OrderItem> items;
  final int? itemsCount;
  final Contact? repartidor;
  final Contact? customer;

  String get paymentLabel => paymentMethods[paymentMethod]?.$1 ?? paymentMethod;
}
