import 'package:flutter/material.dart';

import '../branding/scenolytics_branding.dart';
import '../theme/scenolytics_colors.dart';

class ScenolyticsFooter extends StatelessWidget {
  const ScenolyticsFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final year = DateTime.now().year;
    final theme = Theme.of(context);
    final b = theme.brightness;
    final bar = ScenolyticsColors.footerBarFor(b);
    final topAccent = ScenolyticsColors.footerTopAccent(b);
    final logoAndTitleColor =
        b == Brightness.dark ? ScenolyticsColors.onPrimary : ScenolyticsColors.textPrimary;
    final copyColor =
        b == Brightness.dark ? ScenolyticsColors.darkTextSecondary : ScenolyticsColors.textSecondary;
    final linkColor =
        b == Brightness.dark ? ScenolyticsColors.footerLink : ScenolyticsColors.primary;
    final dotColor = copyColor.withValues(alpha: 0.6);

    return Material(
      color: bar,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 1,
            width: double.infinity,
            color: topAccent,
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: LayoutBuilder(
                builder: (context, c) {
                  final narrow = c.maxWidth < 520;
                  final logo = SizedBox(
                    height: 22,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      alignment: Alignment.centerLeft,
                      child: IconTheme(
                        data: IconThemeData(
                          color: logoAndTitleColor,
                          size: 22,
                        ),
                        child: DefaultTextStyle(
                          style: TextStyle(
                            color: logoAndTitleColor,
                            fontWeight: FontWeight.w600,
                          ),
                          child: ScenolyticsBranding.of(context).logo,
                        ),
                      ),
                    ),
                  );

                  final copyright = Text(
                    '© $year Scenolytics',
                    style: (theme.textTheme.labelMedium ?? const TextStyle()).copyWith(
                      color: copyColor,
                      letterSpacing: 0.35,
                      height: 1.3,
                    ),
                  );

                  final links = _FooterLinks(
                    linkColor: linkColor,
                    dotColor: dotColor,
                    onPrivacy: () {},
                    onTerms: () {},
                    onSupport: () {},
                  );

                  if (narrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        logo,
                        const SizedBox(height: 8),
                        copyright,
                        const SizedBox(height: 8),
                        links,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      logo,
                      const SizedBox(width: 18),
                      Expanded(child: copyright),
                      links,
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterLinks extends StatelessWidget {
  const _FooterLinks({
    required this.linkColor,
    required this.dotColor,
    required this.onPrivacy,
    required this.onTerms,
    required this.onSupport,
  });

  final Color linkColor;
  final Color dotColor;
  final VoidCallback onPrivacy;
  final VoidCallback onTerms;
  final VoidCallback onSupport;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _footerTextButton(context, 'Privacy', onPrivacy, linkColor),
        _dot(dotColor),
        _footerTextButton(context, 'Terms', onTerms, linkColor),
        _dot(dotColor),
        _footerTextButton(context, 'Support', onSupport, linkColor),
      ],
    );
  }

  static Widget _dot(Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        '·',
        style: TextStyle(
          color: color,
          fontSize: 14,
          height: 1,
        ),
      ),
    );
  }

  static Widget _footerTextButton(
    BuildContext context,
    String label,
    VoidCallback onPressed,
    Color linkColor,
  ) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: linkColor,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: (Theme.of(context).textTheme.labelLarge ?? const TextStyle()).copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.15,
            ),
      ),
    );
  }
}
