import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/models.dart';

class CartLine {
  const CartLine(this.dish, this.quantity);

  final Dish dish;
  final int quantity;

  double get subtotal => dish.price * quantity;
}

class CartState {
  const CartState({this.restaurant, this.lines = const {}});

  final Restaurant? restaurant;
  final Map<int, CartLine> lines;

  bool get isEmpty => lines.isEmpty;
  int get itemCount => lines.values.fold(0, (sum, line) => sum + line.quantity);
  double get subtotal => lines.values.fold(0, (sum, line) => sum + line.subtotal);
  int quantityOf(int dishId) => lines[dishId]?.quantity ?? 0;
}

/// Un pedido = un restaurante (igual que en el backend).
class CartController extends Notifier<CartState> {
  @override
  CartState build() => const CartState();

  bool canAddFrom(Restaurant restaurant) => state.restaurant == null || state.restaurant!.id == restaurant.id;

  void add(Restaurant restaurant, Dish dish) {
    final base = canAddFrom(restaurant) ? state : const CartState();
    final lines = {...base.lines, dish.id: CartLine(dish, base.quantityOf(dish.id) + 1)};
    state = CartState(restaurant: restaurant, lines: lines);
  }

  void decrement(int dishId) {
    final current = state.lines[dishId];
    if (current == null) return;
    final lines = {...state.lines};
    if (current.quantity <= 1) {
      lines.remove(dishId);
    } else {
      lines[dishId] = CartLine(current.dish, current.quantity - 1);
    }
    state = lines.isEmpty ? const CartState() : CartState(restaurant: state.restaurant, lines: lines);
  }

  void clear() => state = const CartState();
}

final cartProvider = NotifierProvider<CartController, CartState>(CartController.new);

/// Misma fórmula que el backend (OrderService::deliveryFee). El valor final lo fija el servidor.
double estimateDeliveryFee(LatLng from, LatLng to) {
  final km = const Distance().as(LengthUnit.Meter, from, to) / 1000;
  return math.max(3000, ((2000 + km * 1500) / 500).ceil() * 500).toDouble();
}
