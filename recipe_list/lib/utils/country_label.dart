// Helper for rendering an author's `(<City>/<Country>)` suffix on
// recipe cards / "Added by" rows. The user picks a country from
// `country_picker` so the database stores the ISO 3166-1 alpha-2
// code (e.g. "TR"); the city stays a free-form string the user
// types in their own language. We localize the country name here
// based on the current UI locale so a Russian viewer sees
// "Москва/Россия" while a French viewer sees "Moscou/Russie" for
// the same author profile (city remains as the author typed it).

import 'package:country_picker/country_picker.dart';
import 'package:flutter/widgets.dart';

/// Returns the localized country name for the given ISO alpha-2
/// [code] (case-insensitive), or `null` when the code is empty,
/// invalid, or [CountryLocalizations] is not yet wired into
/// [context].
String? localizedCountryName(BuildContext context, String? code) {
  if (code == null) return null;
  final trimmed = code.trim();
  if (trimmed.length != 2) return null;
  final upper = trimmed.toUpperCase();
  final loc = CountryLocalizations.of(context);
  if (loc == null) return null;
  final name = loc.countryName(countryCode: upper);
  if (name == null || name.isEmpty) return null;
  return name;
}

/// Joins a free-form `city` with a localized country name (from the
/// ISO `countryCode`) using a `/` separator. Returns the empty
/// string when nothing is available.
String formatCityCountry(
  BuildContext context, {
  required String? city,
  required String? countryCode,
}) {
  final parts = <String>[];
  final c = city?.trim();
  if (c != null && c.isNotEmpty) parts.add(c);
  final co = localizedCountryName(context, countryCode);
  if (co != null && co.isNotEmpty) parts.add(co);
  return parts.join('/');
}
