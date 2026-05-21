import 'package:flutter/material.dart';

import '../branding/app_logo_placeholder.dart';
import '../branding/scenolytics_branding.dart';
import '../theme/scenolytics_colors.dart';

class AuthFlowScaffold extends StatelessWidget {
  const AuthFlowScaffold({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.brandHighlights,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final List<AuthBrandHighlight>? brandHighlights;

  static const double _wideBreakpoint = 980;
  static const double _maxFormWidth = 460;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: ScenolyticsColors.pageBackdropGradientFor(brightness),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= _wideBreakpoint;
              if (isWide) {
                return _WideLayout(
                  title: title,
                  subtitle: subtitle,
                  brandHighlights: brandHighlights,
                  formChild: _FormCard(child: child),
                );
              }
              return _NarrowLayout(
                title: title,
                subtitle: subtitle,
                formChild: _FormCard(child: child),
              );
            },
          ),
        ),
      ),
    );
  }
}

class AuthBrandHighlight {
  const AuthBrandHighlight({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;
}

const List<AuthBrandHighlight> _defaultBrandHighlights = <AuthBrandHighlight>[
  AuthBrandHighlight(
    icon: Icons.theaters_outlined,
    title: 'Audition smarter',
    subtitle: 'Browse open castings and submit polished videos in minutes.',
  ),
  AuthBrandHighlight(
    icon: Icons.insights_outlined,
    title: 'AI-powered insights',
    subtitle: 'Tone, emotion, eye contact and script alignment — at a glance.',
  ),
  AuthBrandHighlight(
    icon: Icons.workspace_premium_outlined,
    title: 'Curated rankings',
    subtitle: 'Directors review the most promising performances first.',
  ),
];

class _WideLayout extends StatelessWidget {
  const _WideLayout({
    required this.title,
    required this.subtitle,
    required this.brandHighlights,
    required this.formChild,
  });

  final String title;
  final String? subtitle;
  final List<AuthBrandHighlight>? brandHighlights;
  final Widget formChild;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1160, maxHeight: 760),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 5,
                child: _BrandPanel(
                  highlights: brandHighlights ?? _defaultBrandHighlights,
                ),
              ),
              const SizedBox(width: 28),
              Expanded(
                flex: 6,
                child: _FormColumn(
                  title: title,
                  subtitle: subtitle,
                  child: formChild,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NarrowLayout extends StatelessWidget {
  const _NarrowLayout({
    required this.title,
    required this.subtitle,
    required this.formChild,
  });

  final String title;
  final String? subtitle;
  final Widget formChild;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          24,
          20,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AuthFlowScaffold._maxFormWidth,
          ),
          child: _FormColumn(
            title: title,
            subtitle: subtitle,
            showLogo: true,
            child: formChild,
          ),
        ),
      ),
    );
  }
}

class _FormColumn extends StatelessWidget {
  const _FormColumn({
    required this.title,
    required this.subtitle,
    required this.child,
    this.showLogo = false,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final bool showLogo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logo = ScenolyticsBranding.of(context).logo;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showLogo) ...[
          Align(
            alignment: Alignment.center,
            child: SizedBox(
              height: 44,
              child: FittedBox(fit: BoxFit.contain, child: logo),
            ),
          ),
          const SizedBox(height: 20),
        ],
        Text(
          title,
          textAlign: showLogo ? TextAlign.center : TextAlign.start,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
            height: 1.1,
          ),
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            subtitle!,
            textAlign: showLogo ? TextAlign.center : TextAlign.start,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 22),
        Flexible(child: child),
      ],
    );
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: ScenolyticsColors.cardSheenFor(brightness),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: ScenolyticsColors.outlineSoftFor(brightness)
              .withValues(alpha: 0.55),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(
              alpha: brightness == Brightness.dark ? 0.45 : 0.14,
            ),
            blurRadius: 32,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: child,
        ),
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel({required this.highlights});

  final List<AuthBrandHighlight> highlights;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const logo = ScenolyticsThemeAwareLogo(
      height: 40,
      onHeroBackground: true,
    );
    final onPrimary = Colors.white;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: ScenolyticsColors.heroBarGradientFor(theme.brightness),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: ScenolyticsColors.primaryDim.withValues(alpha: 0.35),
            blurRadius: 36,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -60,
            top: -60,
            child: _BlurBlob(
              color: ScenolyticsColors.accentCyan.withValues(alpha: 0.35),
              size: 240,
            ),
          ),
          Positioned(
            left: -40,
            bottom: -40,
            child: _BlurBlob(
              color: ScenolyticsColors.heroGradientStart
                  .withValues(alpha: 0.45),
              size: 260,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 32, 32, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: logo,
                ),
                const Spacer(),
                Text(
                  'The casting platform\nthat sees beyond the cut.',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: onPrimary,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Sign in to keep crafting auditions or join Scenolytics today.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: onPrimary.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 28),
                for (final h in highlights) ...[
                  _BrandHighlightRow(highlight: h, foreground: onPrimary),
                  const SizedBox(height: 16),
                ],
                const Spacer(),
                Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 18,
                      color: onPrimary.withValues(alpha: 0.85),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your data is encrypted in transit and at rest.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: onPrimary.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandHighlightRow extends StatelessWidget {
  const _BrandHighlightRow({
    required this.highlight,
    required this.foreground,
  });

  final AuthBrandHighlight highlight;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: foreground.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: foreground.withValues(alpha: 0.35),
            ),
          ),
          child: Icon(highlight.icon, color: foreground, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                highlight.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                highlight.subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: foreground.withValues(alpha: 0.82),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BlurBlob extends StatelessWidget {
  const _BlurBlob({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
            stops: const [0.0, 1.0],
          ),
        ),
      ),
    );
  }
}
