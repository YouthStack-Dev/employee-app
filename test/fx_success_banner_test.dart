import 'package:employee_flutter/constants/app_theme.dart';
import 'package:employee_flutter/widgets/fx_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _BannerHost extends StatefulWidget {
  const _BannerHost();

  @override
  State<_BannerHost> createState() => _BannerHostState();
}

class _BannerHostState extends State<_BannerHost> {
  String? _message = 'Login booking created successfully';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('tabs'),
            ),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: FxSuccessBanner(
                  message: _message!,
                  duration: const Duration(seconds: 2),
                  onDismissed: () => setState(() => _message = null),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

void main() {
  testWidgets('FxSuccessBanner renders inline below tabs and auto-dismisses',
      (tester) async {
    await tester.pumpWidget(const _BannerHost());

    final messageFinder = find.text('Login booking created successfully');
    expect(messageFinder, findsOneWidget);
    expect(
      tester.getBottomLeft(find.text('tabs')).dy,
      lessThan(tester.getTopLeft(messageFinder).dy),
    );

    final containerFinder = find.ancestor(
      of: messageFinder,
      matching: find.byWidgetPredicate(
        (widget) => widget is Container && widget.decoration is BoxDecoration,
      ),
    );
    final decoration =
        tester.widget<Container>(containerFinder.first).decoration
            as BoxDecoration;
    expect(decoration.color, FxColors.primary);
    expect(decoration.borderRadius, FxRadii.card);

    await tester.pump(const Duration(seconds: 2, milliseconds: 1));
    expect(messageFinder, findsNothing);
  });
}
