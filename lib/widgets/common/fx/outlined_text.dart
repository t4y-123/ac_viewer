import 'package:flutter/material.dart';

typedef OutlinedWidgetBuilder = Widget Function(BuildContext context, bool isShadow);

class OutlinedText extends StatelessWidget {
  final OutlinedWidgetBuilder leadingBuilder;
  final String text;
  final TextStyle style;
  final double outlineWidth;
  final Color outlineColor;

  static const leadingAlignment = PlaceholderAlignment.middle;

  const OutlinedText({
    Key key,
    this.leadingBuilder,
    @required this.text,
    @required this.style,
    double outlineWidth,
    Color outlineColor,
  })  : outlineWidth = outlineWidth ?? 1,
        outlineColor = outlineColor ?? Colors.black,
        super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RichText(
          text: TextSpan(
            children: [
              if (leadingBuilder != null)
                WidgetSpan(
                  alignment: leadingAlignment,
                  child: leadingBuilder(context, true),
                ),
              TextSpan(
                text: text,
                style: style.copyWith(
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = outlineWidth
                    ..color = outlineColor,
                ),
              ),
            ],
          ),
        ),
        RichText(
          text: TextSpan(
            children: [
              if (leadingBuilder != null)
                WidgetSpan(
                  alignment: leadingAlignment,
                  child: leadingBuilder(context, false),
                ),
              TextSpan(
                text: text,
                style: style,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
