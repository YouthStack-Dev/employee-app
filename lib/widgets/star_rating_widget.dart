import 'package:flutter/material.dart';

class StarRatingWidget extends StatelessWidget {
  final int rating;
  final Function(int) onRatingChanged;
  final double starSize;
  final Color activeColor;
  final Color inactiveColor;

  const StarRatingWidget({
    Key? key,
    required this.rating,
    required this.onRatingChanged,
    this.starSize = 36.0,
    this.activeColor = Colors.amber,
    this.inactiveColor = Colors.grey,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starValue = index + 1;
        return Semantics(
          label: 'Rate $starValue stars',
          button: true,
          child: GestureDetector(
            onTap: () => onRatingChanged(starValue),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Icon(
                index < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                color: index < rating ? activeColor : inactiveColor.withOpacity(0.5),
                size: starSize,
              ),
            ),
          ),
        );
      }),
    );
  }
}
