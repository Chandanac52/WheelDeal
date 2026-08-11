import 'package:flutter/material.dart';

class VehicleImage extends StatelessWidget {
  const VehicleImage({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          height: 320,
          width: double.infinity,
          color: Colors.grey.shade200,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Image.asset(
              "assets/images/cars/bmw_x5.png",
              fit: BoxFit.contain,
            ),
          ),
        ),

        Positioned(
          left: 20,
          top: 20,
          child: CircleAvatar(
            backgroundColor: Colors.white,
            child: IconButton(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: const Icon(Icons.arrow_back),
            ),
          ),
        ),

        Positioned(
          right: 20,
          top: 20,
          child: CircleAvatar(
            backgroundColor: Colors.white,
            child: IconButton(
              onPressed: () {},
              icon: const Icon(
                Icons.favorite_border,
                color: Colors.red,
              ),
            ),
          ),
        ),
      ],
    );
  }
}