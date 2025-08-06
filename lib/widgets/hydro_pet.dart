import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class HydroPet extends StatelessWidget {
  final double progress;
  final double size;

  const HydroPet({Key? key, required this.progress, required this.size}) : super(key: key);

  String _getPlantImage(double progress) {
    if (progress >= 1.0) {
      return 'assets/images/plant/plant_flowering.svg';
    } else if (progress >= 0.75) {
      return 'assets/images/plant/plant_adult.svg';
    } else if (progress >= 0.25) {
      return 'assets/images/plant/plant_young.svg';
    } else {
      return 'assets/images/plant/plant_sprout.svg';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      _getPlantImage(progress),
      height: size,
      width: size,
    );
  }
}
