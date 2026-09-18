import 'package:flutter/material.dart';

/// Centra il contenuto e ne limita la larghezza su tablet/schermi larghi,
/// così l'interfaccia non si stira da bordo a bordo mantenendo comunque
/// il layout mobile-first sugli schermi stretti.
class ResponsiveContent extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveContent({
    super.key,
    required this.child,
    this.maxWidth = 640,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
