import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Docjet Mobile',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  // Get logger instance for this class
  static final Logger _logger = LoggerFactory.getLogger(MyHomePage);
  // Create standard log tag
  static final String _tag = logTag(MyHomePage);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Docjet Mobile')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end, // Align items to the bottom
          children: <Widget>[
            const Spacer(
              flex: 2,
            ), // Pushes the button down (takes 2/3rds of the space)
            // Record button
            GestureDetector(
              onTap: () {
                // TODO: Implement recording logic
                // logger.i('Record button tapped!'); // Use the deprecated logger
                _logger.i(
                  '$_tag Record button tapped!',
                ); // Use the new logger with tag
              },
              child: Container(
                width: 80.0, // Adjust size as needed
                height: 80.0, // Adjust size as needed
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10.0,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                // Optional: Add an icon inside the circle
                // child: const Icon(
                //   Icons.mic,
                //   color: Colors.white,
                //   size: 40.0, // Adjust icon size as needed
                // ),
              ),
            ),
            const Spacer(
              flex: 1,
            ), // Space below the button (takes 1/3rd of the space)
          ],
        ),
      ),
    );
  }
}
