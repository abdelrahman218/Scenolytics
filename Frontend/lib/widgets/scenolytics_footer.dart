import 'package:flutter/material.dart';

import '../branding/scenolytics_branding.dart';
import '../theme/scenolytics_colors.dart';

class ScenolyticsFooter extends StatelessWidget {
  const ScenolyticsFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final year = DateTime.now().year;
    final theme = Theme.of(context);

    return Material(
      color: ScenolyticsColors.primaryDim,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: LayoutBuilder(
            builder: (context, c) {
              final narrow = c.maxWidth < 520;
              final logo = SizedBox(
                height: 28,
                child: FittedBox(
                  fit: BoxFit.contain,
                  alignment: Alignment.centerLeft,
                  child: ScenolyticsBranding.of(context).logo,
                ),
              );

              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    logo,
                    const SizedBox(height: 10),
                    Text(
                      '© $year Scenolytics',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: ScenolyticsColors.onPrimary.withValues(
                          alpha: 0.85,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        _footerLink(context, 'Privacy'),
                        _footerLink(context, 'Terms'),
                        _footerLink(context, 'Support'),
                      ],
                    ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  logo,
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      '© $year Scenolytics',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: ScenolyticsColors.onPrimary.withValues(
                          alpha: 0.85,
                        ),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: Text(
                      'Privacy',
                      style: TextStyle(color: ScenolyticsColors.accentCyanSoft),
                    ),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: Text(
                      'Terms',
                      style: TextStyle(color: ScenolyticsColors.accentCyanSoft),
                    ),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: Text(
                      'Support',
                      style: TextStyle(color: ScenolyticsColors.accentCyanSoft),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  static Widget _footerLink(BuildContext context, String label) {
    return GestureDetector(
      onTap: () {},
      child: Text(
        label,
        style: TextStyle(
          color: ScenolyticsColors.accentCyanSoft,
          fontSize: Theme.of(context).textTheme.bodySmall?.fontSize,
          decoration: TextDecoration.underline,
          decorationColor: ScenolyticsColors.accentCyanSoft.withValues(
            alpha: 0.5,
          ),
        ),
      ),
    );
  }
}
