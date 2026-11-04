import 'dart:math';

import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../services/budget_engine.dart';
import '../services/date_utils.dart';
import '../theme.dart';
import 'common.dart';

/// The day's money on one line: what is spent, where the target sits, where
/// the limit is, and (when over) what spills into tomorrow, hatched.
///
/// On first reveal the fill runs from zero to today's spending: the one
/// authored motion in the app, and it explains the number above it.
class TodayMeter extends StatelessWidget {
  const TodayMeter({super.key, required this.day, required this.s});
  final DayBudget day;
  final S s;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final revealed = RevealScope.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final scaleMax = max(day.allowance, day.spent) * 1.0;
    final color = tk.forStatus(day.status);

    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      double x(double v) {
        final p = scaleMax <= 0 ? 0.0 : (v / scaleMax).clamp(0.0, 1.0) * w;
        return rtl ? w - p : p;
      }

      Widget tickLabel(String text, double value, {bool end = false}) {
        // Keep labels inside the track's width.
        const lw = 96.0;
        var left = x(value) - lw / 2;
        left = left.clamp(0.0, w - lw);
        return Positioned(
          left: left,
          width: lw,
          top: 0,
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: AppType.meta.copyWith(color: tk.ink3),
            maxLines: 1,
            overflow: TextOverflow.fade,
          ),
        );
      }

      return Column(
        children: [
          SizedBox(
            height: 22,
            width: w,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: revealed ? day.spent : 0),
              duration: Duration(milliseconds: reduceMotion(context) ? 0 : 900),
              curve: easeOutExpo,
              builder: (context, spent, _) => CustomPaint(
                painter: _MeterPainter(
                  spent: spent,
                  allowance: day.allowance,
                  target: day.target,
                  scaleMax: scaleMax,
                  fill: color,
                  track: tk.raised,
                  tick: tk.ink2,
                  over: tk.danger,
                  rtl: rtl,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 18,
            width: w,
            child: Stack(
              children: [
                if (day.target < day.allowance) tickLabel('${s.t('target')} ${s.num0(day.target)}', day.target),
                tickLabel('${s.t('limit')} ${s.num0(day.allowance)}', day.allowance, end: true),
              ],
            ),
          ),
        ],
      );
    });
  }
}

class _MeterPainter extends CustomPainter {
  _MeterPainter({
    required this.spent,
    required this.allowance,
    required this.target,
    required this.scaleMax,
    required this.fill,
    required this.track,
    required this.tick,
    required this.over,
    required this.rtl,
  });

  final double spent, allowance, target, scaleMax;
  final Color fill, track, tick, over;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    const h = 12.0;
    final top = (size.height - h) / 2;
    final w = size.width;
    double px(double v) => scaleMax <= 0 ? 0 : (v / scaleMax).clamp(0.0, 1.0) * w;
    Rect span(double a, double b) {
      final l = px(a), r = px(b);
      return rtl ? Rect.fromLTRB(w - r, top, w - l, top + h) : Rect.fromLTRB(l, top, r, top + h);
    }

    final full = RRect.fromRectAndRadius(Rect.fromLTWH(0, top, w, h), const Radius.circular(h / 2));
    canvas.save();
    canvas.clipRRect(full);
    canvas.drawRect(span(0, scaleMax), Paint()..color = track);

    // Spent within the allowance.
    final within = min(spent, allowance);
    if (within > 0) canvas.drawRect(span(0, within), Paint()..color = fill);

    // Spill over the allowance: hatched, it comes off tomorrow.
    if (spent > allowance) {
      final r = span(allowance, spent);
      canvas.drawRect(r, Paint()..color = over.withValues(alpha: 0.28));
      canvas.save();
      canvas.clipRect(r);
      final p = Paint()
        ..color = over
        ..strokeWidth = 2;
      for (var x = r.left - h; x < r.right + h; x += 6) {
        canvas.drawLine(Offset(x, r.bottom), Offset(x + h, r.top), p);
      }
      canvas.restore();
    }
    canvas.restore();

    // Ticks for target and limit.
    void tickAt(double v) {
      final x = rtl ? w - px(v) : px(v);
      canvas.drawLine(
        Offset(x.clamp(1.0, w - 1), 0),
        Offset(x.clamp(1.0, w - 1), size.height),
        Paint()
          ..color = tick
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }

    if (target > 0 && target < allowance) tickAt(target);
    if (spent > allowance) tickAt(allowance);
  }

  @override
  bool shouldRepaint(_MeterPainter o) =>
      o.spent != spent || o.allowance != allowance || o.target != target || o.fill != fill || o.rtl != rtl;
}

/// Seven bars with the daily limit as a faint line. Neutral bars; today in
/// the accent; days over the limit in red.
class WeekBars extends StatelessWidget {
  const WeekBars({super.key, required this.days, required this.limit, required this.s});
  final List<DayBudget> days;
  final double limit;
  final S s;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final revealed = RevealScope.of(context);
    final maxVal = [limit, ...days.map((d) => d.spent)].reduce(max);
    const h = 96.0;
    final now = DateTime.now();

    return Column(
      children: [
        SizedBox(
          height: h + 18,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: limit / maxVal * h,
                child: Container(height: 1, color: tk.lineStrong),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final d in days)
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (sameDay(d.day, now) && d.spent > 0)
                            Text(s.num0(d.spent), style: AppType.meta.copyWith(color: tk.ink, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Semantics(
                            label: '${s.weekdayLong(d.day)} ${s.money(d.spent)}',
                            child: AnimatedContainer(
                              duration: Duration(milliseconds: reduceMotion(context) ? 0 : 600),
                              curve: easeOutExpo,
                              height: revealed ? max(3.0, d.spent / maxVal * h) : 3,
                              margin: const EdgeInsets.symmetric(horizontal: 7),
                              decoration: BoxDecoration(
                                color: d.status == BudgetStatus.over
                                    ? tk.danger
                                    : sameDay(d.day, now)
                                        ? tk.accent
                                        : tk.lineStrong,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final d in days)
              Expanded(
                child: Text(
                  s.weekday(d.day),
                  textAlign: TextAlign.center,
                  style: AppType.meta.copyWith(
                    color: sameDay(d.day, now) ? tk.ink : tk.ink3,
                    fontWeight: sameDay(d.day, now) ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
