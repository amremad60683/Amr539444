import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// First screen while data loads: navy like the native launch screen, so
/// there is no flash. The mark settles, the name rises, a thin orange line
/// fills while loading runs.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      reduceMotion(context) ? _c.value = 1 : _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final ar = context.select<AppState, String>((a) => a.settings.lang) == 'ar';
    final mark = CurvedAnimation(parent: _c, curve: const Interval(0, 0.55, curve: easeOutExpo));
    final name = CurvedAnimation(parent: _c, curve: const Interval(0.25, 0.75, curve: easeOutExpo));
    final line = CurvedAnimation(parent: _c, curve: const Interval(0.35, 1, curve: Curves.easeInOut));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: tk.primary,
        body: Container(
          decoration: BoxDecoration(gradient: tk.hero),
          alignment: Alignment.center,
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Opacity(
                  opacity: mark.value,
                  child: Transform.scale(
                    scale: 0.86 + 0.14 * mark.value,
                    child: BrandMark(size: 84, isAr: ar, onHero: true),
                  ),
                ),
                const SizedBox(height: 22),
                Opacity(
                  opacity: name.value,
                  child: Transform.translate(
                    offset: Offset(0, 8 * (1 - name.value)),
                    child: Text(ar ? 'مصروفي' : 'Masrofy', style: AppType.page.copyWith(color: Colors.white, fontSize: 30)),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: 120,
                  height: 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: Stack(children: [
                      Container(color: Colors.white.withValues(alpha: 0.18)),
                      FractionallySizedBox(
                        widthFactor: line.value,
                        alignment: AlignmentDirectional.centerStart,
                        child: Container(color: tk.accent),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
