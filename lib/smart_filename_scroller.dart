import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';

class SmartFilenameScroller extends StatefulWidget {
  final String text;
  final TextStyle style;
  final double width;
  final bool scroll;

  const SmartFilenameScroller({
    super.key,
    required this.text,
    required this.style,
    required this.width,
    required this.scroll,
  });

  @override
  State<SmartFilenameScroller> createState() => _SmartFilenameScrollerState();
}

class _SmartFilenameScrollerState extends State<SmartFilenameScroller> {
  bool _overflowing = false;
  int _scrollCount = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOverflow());
  }

  void _checkOverflow() {
    if (!mounted) return;

    final safeText = widget.text.isNotEmpty ? widget.text : 'Untitled';
    final safeStyle = widget.style.copyWith(
      fontSize: widget.style.fontSize ?? 16,
    );

    final textPainter = TextPainter(
      text: TextSpan(text: safeText, style: safeStyle),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: widget.width > 0 ? widget.width : 100);

    setState(() {
      _overflowing = textPainter.didExceedMaxLines;
    });
  }

  void _handleTap() {
    if (!_overflowing) return;
    if (!widget.scroll && _scrollCount == 0) {
      setState(() => _scrollCount = 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final safeText = widget.text.isNotEmpty ? widget.text : 'Untitled';
    final safeStyle = widget.style.copyWith(
      fontSize: widget.style.fontSize ?? 16,
    );
    final effectiveHeight = safeStyle.fontSize! * 1.6;

    return GestureDetector(
      onTap: _handleTap,
      child: SizedBox(
        height: effectiveHeight,
        width: widget.width > 0 ? widget.width : 100,
        child: (_overflowing && (widget.scroll || _scrollCount > 0))
            ? Marquee(
                text: safeText,
                style: safeStyle,
                scrollAxis: Axis.horizontal,
                crossAxisAlignment: CrossAxisAlignment.start,
                blankSpace: 40.0,
                velocity: 30.0,
                startPadding: 0.0,
                pauseAfterRound: const Duration(seconds: 2),
                showFadingOnlyWhenScrolling: true,
                fadingEdgeStartFraction: 0.1,
                fadingEdgeEndFraction: 0.1,
                numberOfRounds: widget.scroll ? null : 1,
                onDone: () {
                  if (mounted && !widget.scroll) {
                    setState(() => _scrollCount = 0);
                  }
                },
              )
            : Text(
                safeText,
                style: safeStyle,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
      ),
    );
  }
}
