import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Textové pole s viditelným popiskem nad ním.
///
/// Žádné plovoucí popisky uvnitř pole – uživatel má vědět, co vyplňuje,
/// i když je pole prázdné a i když do něj zrovna píše.
class PoleSPopiskem extends StatelessWidget {
  const PoleSPopiskem({
    super.key,
    required this.popisek,
    required this.ovladac,
    required this.onZmena,
    this.klavesnice,
    this.napoveda,
    this.skryty = false,
    this.fokus,
    this.dalsiPole,
    this.onOdeslat,
    this.pripona,
    this.velkaPismena = TextCapitalization.none,
    this.formatovace,
    this.maxZnaku,
  });

  final String popisek;
  final TextEditingController ovladac;
  final VoidCallback onZmena;
  final TextInputType? klavesnice;
  final String? napoveda;
  final bool skryty;
  final FocusNode? fokus;

  /// Kam skočit klávesou „další“. Když chybí, klávesa odešle formulář.
  final FocusNode? dalsiPole;
  final VoidCallback? onOdeslat;
  final Widget? pripona;
  final TextCapitalization velkaPismena;
  final List<TextInputFormatter>? formatovace;
  final int? maxZnaku;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(popisek, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 6),
        TextField(
          controller: ovladac,
          focusNode: fokus,
          obscureText: skryty,
          keyboardType: klavesnice,
          textCapitalization: velkaPismena,
          inputFormatters: formatovace,
          maxLength: maxZnaku,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: dalsiPole != null
              ? TextInputAction.next
              : TextInputAction.done,
          onChanged: (_) => onZmena(),
          onSubmitted: (_) {
            if (dalsiPole != null) {
              FocusScope.of(context).requestFocus(dalsiPole);
            } else {
              onOdeslat?.call();
            }
          },
          style: Theme.of(context).textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: napoveda,
            counterText: '',
            suffixIcon: pripona == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: pripona,
                  ),
          ),
        ),
      ],
    );
  }
}
