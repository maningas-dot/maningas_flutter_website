import 'package:flutter/material.dart';

import 'try_on_iframe.dart';

class TryOnPage extends StatefulWidget {
  const TryOnPage({required this.uri, super.key});

  final Uri uri;

  @override
  State<TryOnPage> createState() => _TryOnPageState();
}

class _TryOnPageState extends State<TryOnPage> {
  void _closeTryOn() {
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(child: TryOnIframe(uri: widget.uri)),
        SafeArea(
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: IconButton.filledTonal(
                tooltip: 'Close Try-On',
                onPressed: _closeTryOn,
                icon: const Icon(Icons.close),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
