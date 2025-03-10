import 'package:country_coder/country_coder.dart';
import 'package:every_door/constants.dart';
import 'package:every_door/helpers/languages.dart';
import 'package:every_door/models/amenity.dart';
import 'package:every_door/models/field.dart';
import 'package:flutter/material.dart';
import 'package:responsive_grid_list/responsive_grid_list.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// Language-aware field editor. E.g. name + name:en + ...
class NamePresetField extends PresetField {
  final bool capitalize;

  const NamePresetField({
    required String key,
    required String label,
    IconData? icon,
    required String placeholder,
    FieldPrerequisite? prerequisite,
    this.capitalize = true,
  }) : super(
            key: key,
            label: label,
            icon: icon,
            placeholder: placeholder,
            prerequisite: prerequisite);

  @override
  buildWidget(OsmChange element) => NameInputField(this, element);
}

class NameInputField extends StatefulWidget {
  final NamePresetField field;
  final OsmChange element;

  const NameInputField(this.field, this.element);

  @override
  State<NameInputField> createState() => _NameInputFieldState();
}

class _NameInputFieldState extends State<NameInputField> {
  final _controllers = <String, TextEditingController>{};
  final _languages = <String>[];
  static final _langData = LanguageData();

  @override
  void initState() {
    super.initState();
    _controllers[''] =
        TextEditingController(text: widget.element[widget.field.key] ?? '');

    for (final k in getLanguageKeysForLocation()) addLanguage(k);
    for (final k in widget.element.getFullTags().keys) {
      if (k.startsWith(widget.field.key + ':')) addLanguage(k);
    }
  }

  Iterable<String> getLanguageKeysForLocation() {
    final countries = CountryCoder.instance.load();
    final countryId = countries.regionsContaining(
        lat: widget.element.location.latitude,
        lon: widget.element.location.longitude);
    final langLists = countryId
        .map((c) => _langData.dataForCountry(c.id))
        .where((list) => list.isNotEmpty)
        .toList();
    if (langLists.isEmpty) return const [];
    langLists.sort((a, b) => b.length.compareTo(a.length));
    return langLists.first.map((l) => l.key);
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  addLanguage(String key) {
    if (_controllers.containsKey(key)) return;
    _controllers[key] = TextEditingController(text: widget.element[key] ?? '');
    _languages.add(key);
  }

  copyForLanguageKey(String key) {
    if (widget.element[key] == null) {
      // Copy from name.
      setState(() {
        widget.element[key] = widget.element[widget.field.key];
        _controllers[key]!.text = widget.element[key] ?? '';
      });
    } else if (widget.element[widget.field.key] == null) {
      // Copy to name.
      setState(() {
        widget.element[widget.field.key] = widget.element[key];
        _controllers['']!.text = widget.element[widget.field.key] ?? '';
      });
    }
  }

  openLanguageChooser() async {
    final String? result = await showModalBottomSheet(
        context: context,
        builder: (context) {
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: ResponsiveGridList(
              minItemWidth: 130.0,
              children: [
                for (final lang in _langData.languages)
                ListTile(
                  visualDensity: VisualDensity.compact,
                  title: Text(lang.nameLoc, style: kFieldTextStyle),
                  subtitle: Text(lang.nameEn),
                  tileColor: kFieldColor.withOpacity(0.2),
                  onTap: () {
                    Navigator.pop(context, lang.key);
                  },
                ),
              ],
            ),
          );
        });
    if (result != null) {
      setState(() {
        addLanguage(result);
      });
    }
  }

  updateFromTags() {
    for (final kv in _controllers.entries) {
      final value = widget.element[kv.key.isEmpty ? widget.field.key : kv.key];
      if (value != kv.value.text.trim()) {
        // Hopefully that's not the time when we type a letter in the field.
        kv.value.text = value ?? '';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    // TODO: only update when page is back from inactive?
    updateFromTags();

    return Column(
      children: [
        // Main suffix-less field.
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controllers[''],
                textCapitalization: widget.field.capitalize
                    ? TextCapitalization.sentences
                    : TextCapitalization.none,
                decoration: InputDecoration(
                  hintText: widget.field.placeholder,
                  labelText:
                      widget.field.icon != null ? widget.field.label : null,
                ),
                style: kFieldTextStyle,
                onChanged: (value) {
                  // On every keypress, since the focus can change at any minute.
                  setState(() {
                    widget.element[widget.field.key] = value.trim();
                  });
                },
              ),
            ),
            IconButton(
              onPressed: openLanguageChooser,
              icon: Icon(Icons.language),
              tooltip: loc.fieldNameLanguages,
            ),
          ],
        ),
        for (final key in _languages.where((k) => k.isNotEmpty))
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10.0),
                  border: Border.all(color: Colors.grey),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 5.0, vertical: 1.0),
                child: Text(key.substring(key.indexOf(':') + 1),
                    style: kFieldTextStyle),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  child: TextField(
                    controller: _controllers[key],
                    textCapitalization: widget.field.capitalize
                        ? TextCapitalization.sentences
                        : TextCapitalization.none,
                    decoration: InputDecoration(
                      hintText: _langData.dataForKey(key)?.nameLoc ?? key,
                    ),
                    style: kFieldTextStyle,
                    onChanged: (value) {
                      // On every keypress, since the focus can change at any minute.
                      setState(() {
                        widget.element[key] = value.trim();
                      });
                    },
                  ),
                ),
              ),
              if (widget.element[key] == null ||
                  widget.element[widget.field.key] == null)
                IconButton(
                  icon: Icon(Icons.sync_alt),
                  tooltip: loc.fieldNameCopy,
                  onPressed: widget.element[key] != null &&
                          widget.element[widget.field.key] != null
                      ? null
                      : () {
                          copyForLanguageKey(key);
                        },
                ),
            ],
          ),
        SizedBox(height: 5.0),
      ],
    );
  }
}
