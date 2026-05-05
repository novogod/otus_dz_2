// Widget tests for the shared photo-picker bottom sheet.
//
// `showPhotoPickerSheet` is the reusable UI surface used by both
// `AddRecipePage` (recipe photo) and the upcoming user-card / avatar
// flow (see docs/user-card-and-social-signals.md chunk A).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_list/ui/photo_picker_sheet.dart';

void main() {
  Widget harness({
    required void Function(BuildContext) onTrigger,
    required ValueChanged<PhotoPickerAction?> onResult,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => Center(
            child: ElevatedButton(
              onPressed: () async {
                final action = await showPhotoPickerSheet(
                  ctx,
                  title: 'Pick a photo',
                  cameraLabel: 'Take photo',
                  galleryLabel: 'From gallery',
                  removeLabel: 'Remove photo',
                );
                onResult(action);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets(
    'shows camera, gallery and remove options when removeLabel given',
    (tester) async {
      PhotoPickerAction? result;
      await tester.pumpWidget(
        harness(onTrigger: (_) {}, onResult: (r) => result = r),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Pick a photo'), findsOneWidget);
      expect(find.text('Take photo'), findsOneWidget);
      expect(find.text('From gallery'), findsOneWidget);
      expect(find.text('Remove photo'), findsOneWidget);
      result; // suppress unused-var lint until the next test branch
    },
  );

  testWidgets('camera tap returns PhotoPickerAction.camera', (tester) async {
    PhotoPickerAction? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await showPhotoPickerSheet(
                    ctx,
                    title: 't',
                    cameraLabel: 'Camera',
                    galleryLabel: 'Gallery',
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Camera'));
    await tester.pumpAndSettle();
    expect(result, PhotoPickerAction.camera);
  });

  testWidgets('gallery tap returns PhotoPickerAction.gallery', (tester) async {
    PhotoPickerAction? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await showPhotoPickerSheet(
                    ctx,
                    title: 't',
                    cameraLabel: 'Camera',
                    galleryLabel: 'Gallery',
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gallery'));
    await tester.pumpAndSettle();
    expect(result, PhotoPickerAction.gallery);
  });

  testWidgets('remove tap returns PhotoPickerAction.remove', (tester) async {
    PhotoPickerAction? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await showPhotoPickerSheet(
                    ctx,
                    title: 't',
                    cameraLabel: 'Camera',
                    galleryLabel: 'Gallery',
                    removeLabel: 'Remove',
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(result, PhotoPickerAction.remove);
  });

  testWidgets('removeLabel omitted hides the remove tile', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () => showPhotoPickerSheet(
                  ctx,
                  title: 't',
                  cameraLabel: 'Camera',
                  galleryLabel: 'Gallery',
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });
}
