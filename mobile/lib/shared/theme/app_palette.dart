import 'package:flutter/material.dart';

/// The one place colours are defined.
///
/// Flutter has no stylesheet, so this file plays the part CSS custom
/// properties would: screens name a role — heading, border, danger — and this
/// decides what that role looks like. Changing the app's look means editing
/// here, not hunting hex codes through forty screens, which is how the app
/// ended up with three different greys for the same input field.
///
/// Tone: light blue and white, with headings much darker than body text so a
/// screen reads as a hierarchy rather than a wall of even grey.
class AppPalette {
  AppPalette._();

  // --- Blues: the app's accent, lightest to darkest -----------------------

  /// Page wash. Almost white, just blue enough to lift the white cards off it.
  static const tint = Color(0xFFF2F8FD);

  /// Filled chips, selected states, quiet callouts.
  static const soft = Color(0xFFDCEDFB);

  /// Borders on anything blue-tinted.
  static const softBorder = Color(0xFFBBD9F0);

  /// Buttons, links, active icons.
  static const primary = Color(0xFF2E90D9);

  /// A pressed or disabled primary — same hue, drained.
  static const primaryDisabled = Color(0xFFAFD5F0);

  /// Headings. Deep enough to read as near-black at a glance while still
  /// belonging to the blue family.
  static const heading = Color(0xFF0B3D5C);

  // --- Neutrals -----------------------------------------------------------

  static const surface = Color(0xFFFFFFFF);

  /// Fill for text fields and inert tiles. Faintly blue so it sits in the
  /// same family as everything else instead of reading as dead grey.
  static const field = Color(0xFFF1F5F9);

  static const border = Color(0xFFDDE6EE);
  static const text = Color(0xFF10222E);
  static const textMuted = Color(0xFF5D7385);

  // --- Status: meaning first, tone second ---------------------------------
  //
  // These stay red and amber on purpose. They mark drug allergies and missed
  // doses, and recolouring them to match the palette would trade a warning
  // people recognise instantly for one that merely looks tidy.

  static const danger = Color(0xFFC0392B);
  static const dangerSoft = Color(0xFFFDECEC);
  static const dangerBorder = Color(0xFFF0B6B0);

  static const warning = Color(0xFFB26A00);
  static const warningSoft = Color(0xFFFFF4E5);
  static const warningBorder = Color(0xFFF0D6A8);

  static const success = Color(0xFF1E7F5C);
  static const successSoft = Color(0xFFE3F5EE);
}
