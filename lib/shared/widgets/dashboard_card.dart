import 'package:flutter/material.dart';

class DashboardCard extends StatelessWidget {
  const DashboardCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double padding = constraints.maxWidth < 150 ? 12.0 : 20.0;
            final double iconSize = constraints.maxWidth < 150 ? 32.0 : 40.0;
            return Padding(
              padding: EdgeInsets.all(padding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    icon,
                    size: iconSize,
                    color: scheme.primary,
                  ),
                  SizedBox(height: padding * 0.8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
                  SizedBox(height: padding * 0.4),
                  Flexible(
                    child: Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(height: padding * 0.8),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: FilledButton.icon(
                      onPressed: onTap,
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      label: const Text('Open'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        minimumSize: const Size(0, 36),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}









