import 'dart:ui';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../../theme.dart';

/// Height of the custom tab bar in app.dart (excluding the bottom safe
/// inset). Screens that float content above it need this offset.
const double kSvTabBarHeight = 50;

/// iOS back chevron — replaces Material's arrow on every pushed route.
class SvBackButton extends StatelessWidget {
  const SvBackButton({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => Navigator.of(context).maybePop(),
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      icon: Icon(
        CupertinoIcons.chevron_back,
        size: 28,
        color: color ?? context.colors.accent,
      ),
    );
  }
}

/// Small centered-title navigation bar (a real [AppBar] underneath, so
/// existing tests and semantics hold) with an iOS frost: blurred, tinted
/// with the scaffold background, finished with a bottom hairline.
class SvNavBar extends StatelessWidget implements PreferredSizeWidget {
  const SvNavBar({
    super.key,
    required this.title,
    this.actions,
    this.overCamera = false,
  });

  final String title;
  final List<Widget>? actions;

  /// True on screens whose body is a full-bleed camera: chrome goes white.
  final bool overCamera;

  @override
  Size get preferredSize => const Size.fromHeight(52);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    return AppBar(
      title: Text(title),
      leadingWidth: 56,
      leading: canPop
          ? SvBackButton(color: overCamera ? Colors.white : null)
          : null,
      actions: actions,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: (overCamera ? Colors.black : colors.groupedBg).withValues(
                alpha: 0.72,
              ),
              border: Border(
                bottom: BorderSide(color: colors.separator, width: 0.33),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The iOS large-title pattern: a 34pt bold title in the scroll content that
/// slides under a pinned frosted bar, whose own centered small title fades in
/// exactly as the large one disappears.
class SvLargeTitleScaffold extends StatefulWidget {
  const SvLargeTitleScaffold({
    super.key,
    required this.title,
    required this.slivers,
    this.actions = const [],
    this.padForTabBar = false,
  });

  final String title;
  final List<Widget> slivers;
  final List<Widget> actions;

  /// True for the four root tab screens, whose content scrolls behind the
  /// translucent tab bar and must end above it.
  final bool padForTabBar;

  @override
  State<SvLargeTitleScaffold> createState() => _SvLargeTitleScaffoldState();
}

class _SvLargeTitleScaffoldState extends State<SvLargeTitleScaffold> {
  final ScrollController _controller = ScrollController();

  double get _offset => _controller.hasClients ? _controller.offset : 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    final bottomPad =
        MediaQuery.paddingOf(context).bottom +
        (widget.padForTabBar ? kSvTabBarHeight + 28 : 28);

    return Scaffold(
      body: CustomScrollView(
        controller: _controller,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverAppBar(
            pinned: true,
            leadingWidth: 56,
            leading: canPop ? const SvBackButton() : null,
            actions: widget.actions,
            title: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => Opacity(
                opacity: ((_offset - 30) / 14).clamp(0.0, 1.0),
                child: Text(widget.title),
              ),
            ),
            flexibleSpace: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final t = ((_offset - 30) / 14).clamp(0.0, 1.0);
                // No BackdropFilter while the bar is transparent: an always-on
                // blur samples the large title just below the bar's bounds and
                // smears a gray halo across it at rest.
                if (t == 0) return const SizedBox.expand();
                final pane = Container(
                  decoration: BoxDecoration(
                    color: colors.groupedBg.withValues(alpha: 0.85 * t),
                    border: Border(
                      bottom: BorderSide(
                        color: colors.separator.withValues(
                          alpha: colors.separator.a * t,
                        ),
                        width: 0.33,
                      ),
                    ),
                  ),
                );
                return ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: pane,
                  ),
                );
              },
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 10),
              child: Text(
                widget.title,
                style: Theme.of(context).textTheme.displaySmall,
              ),
            ),
          ),
          ...widget.slivers,
          SliverPadding(padding: EdgeInsets.only(bottom: bottomPad)),
        ],
      ),
    );
  }
}
