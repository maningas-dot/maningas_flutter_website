import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/responsive.dart';
import '../../app/theme.dart';
import 'profile_mock_data.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{
    for (final field in _fields)
      field.id: TextEditingController(text: _initialValue(field.id)),
  };

  String? _gender;
  String? _province;
  String? _city;
  String? _barangay;
  String? _status;

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _value(String id) => _controllers[id]!.text.trim();

  void _onChanged(String id, String value) {
    setState(() {
      if (id == 'dateOfBirth') {
        _controllers['age']!.text = _calculateAge(value)?.toString() ?? '';
      }
      _status = null;
    });
  }

  int? _calculateAge(String value) {
    final date = _parseDate(value);
    if (date == null) return null;
    final today = DateTime.now();
    var age = today.year - date.year;
    if (today.month < date.month ||
        (today.month == date.month && today.day < date.day)) {
      age--;
    }
    return age;
  }

  DateTime? _parseDate(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value.trim());
    if (match == null) return null;
    final year = int.parse(match[1]!);
    final month = int.parse(match[2]!);
    final day = int.parse(match[3]!);
    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  }

  String? _validateText(String id) {
    final value = _value(id);
    switch (id) {
      case 'firstName':
        return _requiredText(value, 'Please enter your first name.', 2);
      case 'middleName':
        return value.isNotEmpty && value.length < 2
            ? 'Enter at least 2 characters or leave this blank.'
            : null;
      case 'lastName':
        return _requiredText(value, 'Please enter your last name.', 2);
      case 'dateOfBirth':
        final date = _parseDate(value);
        if (value.isEmpty) return 'Please select your date of birth.';
        if (date == null) return 'Please enter a valid date (YYYY-MM-DD).';
        if (date.isAfter(DateTime.now())) {
          return 'Date of birth cannot be in the future.';
        }
        final age = _calculateAge(value);
        if (age == null || age < 10 || age > 99) {
          return 'Age must be between 10 and 99.';
        }
        return null;
      case 'contact':
        if (value.isEmpty) return 'Please enter your contact number.';
        if (!RegExp(r'^(\+63|0)9\d{9}$')
            .hasMatch(value.replaceAll(RegExp(r'[\s-]'), ''))) {
          return 'Please enter a valid Philippine mobile number.';
        }
        return null;
      case 'addressUnit':
        return _requiredText(
          value,
          'Please enter your house, unit, lot, or block.',
        );
      case 'addressStreet':
        return _requiredText(value, 'Please enter your street.');
      case 'addressZipCode':
        if (value.isEmpty) return 'Please enter your ZIP code.';
        if (!RegExp(r'^\d{4}$').hasMatch(value)) {
          return 'ZIP code must be exactly 4 digits.';
        }
        return null;
      default:
        return null;
    }
  }

  String? _requiredText(String value, String message, [int minLength = 1]) {
    if (value.isEmpty) return message;
    if (value.length < minLength) {
      return 'Please enter at least $minLength characters.';
    }
    return null;
  }

  void _savePreview() {
    final valid = _formKey.currentState!.validate();
    setState(() {
      _status = valid
          ? 'LOCAL PREVIEW ONLY: Changes are not saved to a patient record.'
          : null;
    });
  }

  void _cancel() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }

    _formKey.currentState?.reset();
    for (final field in _fields) {
      _controllers[field.id]!.text = _initialValue(field.id);
    }
    setState(() {
      _gender = null;
      _province = null;
      _city = null;
      _barangay = null;
      _status = 'Local preview: unsaved edits were discarded.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width <= PatientPortalBreakpoints.mobile;
    final pagePadding = compact
        ? 16.0
        : width <= 800
        ? 22.0
        : 30.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final stackedFields = constraints.maxWidth - pagePadding * 2 < 700;
        return SingleChildScrollView(
          key: const ValueKey('edit-profile-scroll'),
          padding: EdgeInsets.fromLTRB(
            pagePadding,
            compact ? 22 : 30,
            pagePadding,
            compact ? 32 : 45,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _PageHeader(compact: compact),
                    const SizedBox(height: 22),
                    _ProfileSection(
                      title: 'Personal Information',
                      description: 'Update your basic patient information.',
                      icon: Icons.person_outline,
                      child: Column(
                        children: [
                          _fieldRow([
                            _textField('firstName', 'First Name *'),
                            _textField('middleName', 'Middle Name'),
                            _textField('lastName', 'Last Name *'),
                          ], stackedFields),
                          const SizedBox(height: 16),
                          _fieldRow([
                            _textField(
                              'dateOfBirth',
                              'Date of Birth *',
                              hint: 'YYYY-MM-DD',
                              keyboardType: TextInputType.datetime,
                            ),
                            _textField(
                              'age',
                              'Age (calculated; read-only)',
                              readOnly: true,
                              hint: 'Calculated from date of birth',
                            ),
                            _dropdownField(
                              id: 'gender',
                              label: 'Gender *',
                              value: _gender,
                              hint: 'Select gender',
                              options: const ['Male', 'Female', 'Other'],
                              onChanged: (value) => setState(() {
                                _gender = value;
                                _status = null;
                              }),
                            ),
                          ], stackedFields),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _ProfileSection(
                      title: 'Contact Information',
                      description:
                          'Contact details associated with your account.',
                      icon: Icons.contact_mail_outlined,
                      child: _fieldRow([
                        _textField(
                          'contact',
                          'Contact Number *',
                          hint: '09XXXXXXXXX',
                          keyboardType: TextInputType.phone,
                        ),
                      ], stackedFields),
                    ),
                    const SizedBox(height: 18),
                    _ProfileSection(
                      title: 'Address',
                      description: 'Address choices are a small local sample, not a complete Philippine address directory.',
                      icon: Icons.location_on_outlined,
                      child: Column(
                        children: [
                          _fieldRow([
                            _textField(
                              'addressUnit',
                              'House / Unit / Lot / Block *',
                            ),
                            _textField('addressStreet', 'Street *'),
                          ], stackedFields),
                          const SizedBox(height: 16),
                          _fieldRow([
                            _dropdownField(
                              id: 'province',
                              label: 'Province *',
                              value: _province,
                              hint: 'Select Province',
                              options: _provinceNames,
                              onChanged: (value) => setState(() {
                                _province = value;
                                _city = null;
                                _barangay = null;
                                _status = null;
                              }),
                            ),
                            _dropdownField(
                              id: 'city',
                              label: 'City / Municipality *',
                              value: _city,
                              hint: _province == null
                                  ? 'Select Province First'
                                  : 'Select City / Municipality',
                              options: _cities[_province] ?? const [],
                              enabled: _province != null,
                              onChanged: (value) => setState(() {
                                _city = value;
                                _barangay = null;
                                _status = null;
                              }),
                            ),
                          ], stackedFields),
                          const SizedBox(height: 16),
                          _fieldRow([
                            _dropdownField(
                              id: 'barangay',
                              label: 'Barangay *',
                              value: _barangay,
                              hint: _city == null
                                  ? 'Select City / Municipality First'
                                  : 'Select Barangay',
                              options: _barangays[_city] ?? const [],
                              enabled: _city != null,
                              onChanged: (value) => setState(() {
                                _barangay = value;
                                _status = null;
                              }),
                            ),
                            _textField(
                              'addressZipCode',
                              'ZIP Code *',
                              hint: 'e.g. 3019',
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(4),
                              ],
                            ),
                          ], stackedFields),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_status != null) ...[
                      _StatusMessage(message: _status!),
                      const SizedBox(height: 14),
                    ],
                    LayoutBuilder(
                      builder: (context, buttonConstraints) {
                        final vertical = buttonConstraints.maxWidth < 430;
                        final save = FilledButton.icon(
                          key: const ValueKey('edit-profile-save'),
                          onPressed: _savePreview,
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('Save Changes'),
                        );
                        final cancel = OutlinedButton.icon(
                          key: const ValueKey('edit-profile-cancel'),
                          onPressed: _cancel,
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('Cancel'),
                        );
                        if (vertical) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(height: 48, child: save),
                              const SizedBox(height: 10),
                              SizedBox(height: 46, child: cancel),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: SizedBox(height: 48, child: save)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SizedBox(height: 48, child: cancel),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Preview only — changes are not saved to the clinic or a patient record.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .extension<PatientPortalTextColors>()!
                            .secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _fieldRow(List<Widget> fields, bool stacked) {
    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _withSpacing(fields, 14),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _withSpacing(
        fields.map((field) => Expanded(child: field)).toList(),
        14,
        horizontal: true,
      ),
    );
  }

  List<Widget> _withSpacing(
    List<Widget> children,
    double spacing, {
    bool horizontal = false,
  }) {
    final result = <Widget>[];
    for (var index = 0; index < children.length; index++) {
      if (index > 0) {
        result.add(
          horizontal ? SizedBox(width: spacing) : SizedBox(height: spacing),
        );
      }
      result.add(children[index]);
    }
    return result;
  }

  Widget _textField(
    String id,
    String label, {
    String? hint,
    TextInputType? keyboardType,
    bool readOnly = false,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return _LabeledField(
      label: label,
      child: TextFormField(
        key: ValueKey('edit-profile-$id'),
        controller: _controllers[id],
        readOnly: readOnly,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        onChanged: (value) => _onChanged(id, value),
        validator: (_) => _validateText(id),
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 13,
            vertical: 14,
          ),
          suffixIcon: id == 'age'
              ? const Icon(Icons.lock_outline_rounded, size: 17)
              : null,
        ),
      ),
    );
  }

  Widget _dropdownField({
    required String id,
    required String label,
    required String? value,
    required String hint,
    required List<String> options,
    required ValueChanged<String?> onChanged,
    bool enabled = true,
  }) {
    return _LabeledField(
      label: label,
      child: DropdownButtonFormField<String>(
        key: ValueKey('edit-profile-$id'),
        initialValue: value,
        isExpanded: true,
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 13, vertical: 14),
        ),
        hint: Text(hint, overflow: TextOverflow.ellipsis),
        items: options
            .map(
              (option) => DropdownMenuItem(
                value: option,
                child: Text(option, overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(),
        onChanged: enabled ? onChanged : null,
        validator: (_) {
          if (value != null) return null;
          return 'Please select ${label.replaceAll(' *', '').toLowerCase()}.';
        },
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.extension<PatientPortalTextColors>()!.secondary;
    final brand = Row(
      children: [
        Icon(Icons.circle, size: 7, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          'GONZALES VISION CLINIC',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'PREVIEW ONLY',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (compact) ...[
          brand,
          const SizedBox(height: 8),
          badge,
        ] else
          Row(children: [brand, const Spacer(), badge]),
        const SizedBox(height: 10),
        Text(
          'Edit Profile',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontSize: compact ? 26 : 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.7,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'Review and edit the demo information below. Changes stay in this '
          'preview and are not sent to the clinic.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: secondary,
            height: 1.55,
          ),
        ),
      ],
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.title,
    required this.description,
    required this.icon,
    required this.child,
  });

  final String title;
  final String description;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.extension<PatientPortalTextColors>()!.secondary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: theme.colorScheme.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: secondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
        child,
      ],
    );
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('edit-profile-status'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        border: Border.all(color: const Color(0xFFBFDBFE)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Color(0xFF1D4ED8),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

String _initialValue(String id) {
  switch (id) {
    case 'firstName':
      final parts = ProfileMockData.fullName.split(' ');
      return parts.isEmpty ? '' : parts.first;
    case 'lastName':
      final parts = ProfileMockData.fullName.split(' ');
      return parts.length < 2 ? '' : parts.last;
    case 'dateOfBirth':
      final date = ProfileMockData.dateOfBirth;
      return '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';
    case 'age':
      final today = DateTime.now();
      final date = ProfileMockData.dateOfBirth;
      var age = today.year - date.year;
      if (today.month < date.month ||
          (today.month == date.month && today.day < date.day)) {
        age--;
      }
      return age.toString();
    case 'contact':
      return ProfileMockData.contactNumber;
    case 'addressUnit':
      return ProfileMockData.addressUnit == '—'
          ? ''
          : ProfileMockData.addressUnit;
    case 'addressStreet':
      return ProfileMockData.addressStreet == '—'
          ? ''
          : ProfileMockData.addressStreet;
    case 'addressZipCode':
      return ProfileMockData.addressZipCode == '—'
          ? ''
          : ProfileMockData.addressZipCode;
    default:
      return '';
  }
}

const _fields = <_FieldDefinition>[
  _FieldDefinition('firstName'),
  _FieldDefinition('middleName'),
  _FieldDefinition('lastName'),
  _FieldDefinition('dateOfBirth'),
  _FieldDefinition('age'),
  _FieldDefinition('contact'),
  _FieldDefinition('addressUnit'),
  _FieldDefinition('addressStreet'),
  _FieldDefinition('addressZipCode'),
];

class _FieldDefinition {
  const _FieldDefinition(this.id);
  final String id;
}

const _provinceNames = ['Bulacan', 'Rizal', 'Metro Manila'];
const _cities = <String, List<String>>{
  'Bulacan': ['Meycauayan', 'Marilao', 'Bocaue'],
  'Rizal': ['Antipolo', 'Cainta', 'Taytay'],
  'Metro Manila': ['Quezon City', 'Manila', 'Makati'],
};
const _barangays = <String, List<String>>{
  'Meycauayan': ['Banga', 'Calvario', 'Langka'],
  'Marilao': ['Loma de Gato', 'Poblacion I', 'Santa Rosa I'],
  'Bocaue': ['Bambang', 'Batia', 'Poblacion'],
  'Antipolo': ['San Isidro', 'Cupang', 'Dela Paz'],
  'Cainta': ['San Andres', 'San Isidro', 'Sto. Domingo'],
  'Taytay': ['Dolores', 'San Juan', 'Santa Ana'],
  'Quezon City': ['Batasan Hills', 'Commonwealth', 'Holy Spirit'],
  'Manila': ['Ermita', 'Malate', 'Paco'],
  'Makati': ['Bel-Air', 'Poblacion', 'San Lorenzo'],
};
