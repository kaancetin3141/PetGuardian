import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Shared display helpers.
///
/// These lived as private duplicates inside three pages, which meant a fix had
/// to be repeated in each copy. `tr_TR` formatting requires
/// `initializeDateFormatting('tr_TR')` to have run (see `main.dart`); without it
/// every call below throws a `LocaleDataException`.
class AppFormatters {
  const AppFormatters._();

  /// Compact stamp for list rows: time today, "Dün", weekday name, then a date.
  static String relativeTimestamp(DateTime timestamp, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final today = DateTime(reference.year, reference.month, reference.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate =
        DateTime(timestamp.year, timestamp.month, timestamp.day);

    if (messageDate == today) {
      return DateFormat('HH:mm').format(timestamp);
    }
    if (messageDate == yesterday) {
      return 'Dün';
    }
    if (reference.difference(timestamp).inDays < 7) {
      return DateFormat('EEEE', 'tr_TR').format(timestamp);
    }
    return DateFormat('dd.MM.yy', 'tr_TR').format(timestamp);
  }

  /// Divider label between message groups in a conversation.
  static String dayHeader(DateTime date, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final today = DateTime(reference.year, reference.month, reference.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final target = DateTime(date.year, date.month, date.day);

    if (target == today) return 'Bugün';
    if (target == yesterday) return 'Dün';
    return DateFormat('d MMMM yyyy', 'tr_TR').format(date);
  }

  /// Human readable summary for a non-text message.
  static String messageTypeLabel(String type) {
    switch (type) {
      case 'image':
        return '📷 Fotoğraf';
      case 'location':
        return '📍 Konum paylaşıldı';
      case 'pet_card':
        return '🐾 Hayvan kartı paylaşıldı';
      case 'product_card':
        return '🛍️ Ürün kartı paylaşıldı';
      default:
        return 'Mesaj';
    }
  }

  /// Icon for a non-text message type, or null when the message is plain text.
  static IconData? messageTypeIcon(String type) {
    switch (type) {
      case 'image':
        return Icons.image;
      case 'location':
        return Icons.location_on;
      case 'pet_card':
        return Icons.pets;
      case 'product_card':
        return Icons.shopping_bag;
      default:
        return null;
    }
  }

  /// Parses the `"<lat>,<lng>"` payload written by the chat's location share.
  /// Returns null for anything else (legacy placeholder messages carried no
  /// coordinates and render as plain text).
  static (double, double)? parseLocationPayload(String payload) {
    final parts = payload.split(',');
    if (parts.length != 2) return null;
    final lat = double.tryParse(parts[0].trim());
    final lng = double.tryParse(parts[1].trim());
    if (lat == null || lng == null) return null;
    return (lat, lng);
  }

  /// Parses the JSON product-card payload into an `(img, title, price)`
  /// record, or null when the payload is not valid product data (older
  /// placeholder messages are plain text; corrupted data is tolerated).
  static (String, String, double)? parseProductPayload(String payload) {
    try {
      final map = jsonDecode(payload);
      if (map is! Map<String, dynamic>) return null;
      final img = map['img']?.toString() ?? '';
      final title = map['title']?.toString() ?? '';
      final price = (map['price'] as num?)?.toDouble();
      if (img.isEmpty || title.isEmpty || price == null) return null;
      return (img, title, price);
    } catch (_) {
      return null;
    }
  }
}