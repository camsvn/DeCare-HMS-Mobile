import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/features/tomogram/tomogram.dart';

import '../../helpers/pump_app.dart';

void main() {
  late Directory dir;

  /// The list the viewer is shown, as its owner would hold it: a removal is a
  /// shorter list on the next build, not something the viewer does itself.
  late ValueNotifier<List<ViewerPhoto>> list;

  /// Which index each callback was asked about.
  late List<int> edited;
  late List<int> removed;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('photo_viewer');
    edited = [];
    removed = [];
  });

  tearDown(() async {
    list.dispose();
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  /// A four-byte JPEG stub on disk. The viewer decodes it and lands in its
  /// `errorBuilder`, which is all these tests need of the image itself.
  ViewerPhoto photo(String name, {String caption = '', String? hint}) {
    final file = File('${dir.path}/$name')..writeAsBytesSync(const [0xFF, 0xD8, 0xFF, 0xD9]);
    return ViewerPhoto(path: file.path, caption: caption, captionHint: hint);
  }

  /// Pushes the viewer over a host route, rebuilding it from [list] the way an
  /// owner watching a provider would.
  Future<void> open(
    WidgetTester tester,
    List<ViewerPhoto> photos, {
    int initialIndex = 0,
    bool removeShortens = true,
  }) async {
    list = ValueNotifier(photos);
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(
      tester,
      Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ValueListenableBuilder<List<ViewerPhoto>>(
                  valueListenable: list,
                  builder: (_, value, __) => PhotoViewer(
                    photos: value,
                    initialIndex: initialIndex,
                    onEditCaption: (index) async => edited.add(index),
                    onRemove: (index) async {
                      removed.add(index);
                      if (removeShortens) list.value = [...value]..removeAt(index);
                    },
                  ),
                ),
              ),
            ),
            child: const Text('host'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('host'));
    await tester.pumpAndSettle();
  }

  Finder caption() => find.byKey(photoViewerCaptionKey);

  Finder bin() => find.byIcon(Icons.delete_outline);

  /// One page forward. Measured rather than flung: a fling on a 400 dp
  /// surface runs to the end of the set.
  Future<void> swipeForward(WidgetTester tester) async {
    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();
  }

  testWidgets('captions the photo it opens on', (tester) async {
    await open(tester, [photo('a.jpg', caption: 'Left forearm'), photo('b.jpg')]);

    expect(find.text('1 of 2'), findsOneWidget);
    expect(find.descendant(of: caption(), matching: find.text('Left forearm')), findsOneWidget);
  });

  testWidgets('an undescribed photo shows its hint, or the offer when it has none', (tester) async {
    await open(tester, [
      photo('a.jpg', hint: 'Same as previous photo: Left forearm'),
      photo('b.jpg'),
    ]);

    // The hint carries what a blank description actually means where the photo
    // came from; without one there is only the offer to write one.
    expect(
      find.descendant(of: caption(), matching: find.text('Same as previous photo: Left forearm')),
      findsOneWidget,
    );

    await swipeForward(tester);

    expect(find.descendant(of: caption(), matching: find.text('Add a label')), findsOneWidget);
  });

  testWidgets('the caption is a button that asks about the photo on screen', (tester) async {
    final handle = tester.ensureSemantics();
    await open(tester, [photo('a.jpg'), photo('b.jpg', caption: 'Scalp')]);

    await tester.tap(caption());
    await tester.pumpAndSettle();
    expect(edited, [0]);

    await swipeForward(tester);
    final row = tester.getSemantics(caption());
    expect(row.label, 'Scalp');
    expect(row.hasFlag(SemanticsFlag.isButton), isTrue);
    expect(row.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

    await tester.tap(caption());
    await tester.pumpAndSettle();

    expect(edited, [0, 1]);
    handle.dispose();
  });

  testWidgets('the bin asks about the photo on screen', (tester) async {
    await open(
      tester,
      [photo('a.jpg'), photo('b.jpg'), photo('c.jpg')],
      removeShortens: false,
    );

    await swipeForward(tester);
    expect(find.text('2 of 3'), findsOneWidget);
    expect(find.byTooltip('Remove'), findsOneWidget);

    await tester.tap(bin());
    await tester.pumpAndSettle();

    // Removing is the owner's to do: the viewer only says which one.
    expect(removed, [1]);
    expect(find.text('2 of 3'), findsOneWidget);
  });

  testWidgets('the counter follows a swipe', (tester) async {
    await open(tester, [photo('a.jpg'), photo('b.jpg'), photo('c.jpg')], initialIndex: 1);

    expect(find.text('2 of 3'), findsOneWidget);

    await swipeForward(tester);

    expect(find.text('3 of 3'), findsOneWidget);
  });

  testWidgets('a shorter list steps back onto the photo that took the slot', (tester) async {
    await open(tester, [photo('a.jpg'), photo('b.jpg'), photo('c.jpg')], initialIndex: 2);
    expect(find.text('3 of 3'), findsOneWidget);

    await tester.tap(bin());
    await tester.pumpAndSettle();

    expect(removed, [2]);
    expect(find.text('2 of 2'), findsOneWidget);
    expect(find.byType(PhotoViewer), findsOneWidget);
  });

  testWidgets('a removal from the middle keeps the page and shows the next photo', (tester) async {
    await open(tester, [
      photo('a.jpg', caption: 'One'),
      photo('b.jpg', caption: 'Two'),
      photo('c.jpg', caption: 'Three'),
    ], initialIndex: 1);

    await tester.tap(bin());
    await tester.pumpAndSettle();

    expect(find.text('2 of 2'), findsOneWidget);
    expect(find.descendant(of: caption(), matching: find.text('Three')), findsOneWidget);
  });

  testWidgets('an emptied list takes the viewer with it', (tester) async {
    await open(tester, [photo('a.jpg')]);

    await tester.tap(bin());
    await tester.pumpAndSettle();

    expect(removed, [0]);
    expect(find.byType(PhotoViewer), findsNothing);
    expect(find.text('host'), findsOneWidget);
  });

  testWidgets('close leaves without touching anything', (tester) async {
    await open(tester, [photo('a.jpg'), photo('b.jpg')]);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(find.byType(PhotoViewer), findsNothing);
    expect(edited, isEmpty);
    expect(removed, isEmpty);
  });
}
