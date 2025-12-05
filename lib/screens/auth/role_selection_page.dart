import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_routes.dart';
import '../../core/auth/auth_state.dart';

class RoleSelectionPage extends StatefulWidget {
  const RoleSelectionPage({super.key});

  @override
  State<RoleSelectionPage> createState() => _RoleSelectionPageState();
}

class _RoleSelectionPageState extends State<RoleSelectionPage> {
  bool _farmer = true;
  bool _florist = false;
  bool _submitting = false;

  Future<void> _submit() async {
    final List<String> roles = <String>[
      if (_farmer) 'farmer',
      if (_florist) 'florist',
    ];

    if (roles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one role')),
      );
      return;
    }

    setState(() {
      _submitting = true;
    });

    final AuthState authState = context.read<AuthState>();
    final bool ok = await authState.updateRoles(roles);

    if (!mounted) return;

    setState(() {
      _submitting = false;
    });

    if (!ok) {
      final String message = authState.errorMessage ?? 'Unable to update roles';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return;
    }

    Navigator.of(context).pushReplacementNamed(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select your roles'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Choose how you use SmartRose',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('Farmer'),
              subtitle: const Text('For growers monitoring crops'),
              value: _farmer,
              onChanged: (bool? value) {
                setState(() {
                  _farmer = value ?? false;
                });
              },
            ),
            CheckboxListTile(
              title: const Text('Florist'),
              subtitle: const Text('For handling post-harvest and retail'),
              value: _florist,
              onChanged: (bool? value) {
                setState(() {
                  _florist = value ?? false;
                });
              },
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text('Save roles'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

