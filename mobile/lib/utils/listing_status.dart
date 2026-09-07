import 'package:flutter/material.dart';

/// Shared status → color/label mapping for listing status chips across the app.
Color listingStatusColor(String status) => switch (status) {
  'active'  => const Color(0xFF34C759),
  'pending' => const Color(0xFFFFCC00),
  _         => const Color(0xFFFF3B30), // offMarket (sold / removed)
};

String listingStatusLabel(String status) => switch (status) {
  'active'  => 'Available',
  'pending' => 'Meetup Scheduled',
  _         => 'Sold',
};
