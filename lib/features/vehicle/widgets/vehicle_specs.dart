import 'package:flutter/material.dart';

import '../../../models/vehicle_model.dart';
import 'spec_card.dart';

class VehicleSpecs extends StatelessWidget {
  final VehicleModel vehicle;

  const VehicleSpecs({super.key, required this.vehicle});

  @override
  Widget build(BuildContext context) {
    final specs = [
      (Icons.local_gas_station, "Fuel Type", vehicle.fuelType),
      (Icons.speed, "Km Driven", vehicle.kmDriven),
      (Icons.calendar_today, "Year", vehicle.year),
      (Icons.settings, "Transmission", vehicle.transmission),
      (Icons.person_outline, "Owners", vehicle.owners),
      (Icons.check_circle_outline, "Condition", vehicle.condition),
      (Icons.shield_outlined, "Insurance", vehicle.insurance),
      (Icons.description_outlined, "RC Status", vehicle.rcStatus),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: specs.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.6,
      ),
      itemBuilder: (context, index) {
        final spec = specs[index];
        return SpecCard(icon: spec.$1, label: spec.$2, value: spec.$3);
      },
    );
  }
}
