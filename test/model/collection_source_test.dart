import 'dart:async';

import 'package:aves/model/availability.dart';
import 'package:aves/model/covers.dart';
import 'package:aves/model/favourites.dart';
import 'package:aves/model/filters/album.dart';
import 'package:aves/model/metadata_db.dart';
import 'package:aves/model/settings/settings.dart';
import 'package:aves/model/source/enums.dart';
import 'package:aves/model/source/media_store_source.dart';
import 'package:aves/services/image_file_service.dart';
import 'package:aves/services/media_store_service.dart';
import 'package:aves/services/metadata_service.dart';
import 'package:aves/services/services.dart';
import 'package:aves/services/storage_service.dart';
import 'package:aves/services/time_service.dart';
import 'package:aves/utils/android_file_utils.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../fake/availability.dart';
import '../fake/image_file_service.dart';
import '../fake/media_store_service.dart';
import '../fake/metadata_db.dart';
import '../fake/metadata_service.dart';
import '../fake/storage_service.dart';
import '../fake/time_service.dart';

void main() {
  const testAlbum = '${FakeStorageService.primaryPath}Pictures/test';
  const sourceAlbum = '${FakeStorageService.primaryPath}Pictures/source';
  const destinationAlbum = '${FakeStorageService.primaryPath}Pictures/destination';

  setUp(() async {
    // specify Posix style path context for consistent behaviour when running tests on Windows
    getIt.registerLazySingleton<p.Context>(() => p.Context(style: p.Style.posix));
    getIt.registerLazySingleton<AvesAvailability>(() => FakeAvesAvailability());
    getIt.registerLazySingleton<MetadataDb>(() => FakeMetadataDb());

    getIt.registerLazySingleton<ImageFileService>(() => FakeImageFileService());
    getIt.registerLazySingleton<MediaStoreService>(() => FakeMediaStoreService());
    getIt.registerLazySingleton<MetadataService>(() => FakeMetadataService());
    getIt.registerLazySingleton<StorageService>(() => FakeStorageService());
    getIt.registerLazySingleton<TimeService>(() => FakeTimeService());

    await settings.init();
  });

  tearDown(() async {
    await getIt.reset();
  });

  Future<MediaStoreSource> _initSource() async {
    final source = MediaStoreSource();
    final readyCompleter = Completer();
    source.stateNotifier.addListener(() {
      if (source.stateNotifier.value == SourceState.ready) {
        readyCompleter.complete();
      }
    });
    await source.init();
    await source.refresh();
    await readyCompleter.future;
    return source;
  }

  test('add/remove favourite entry', () async {
    final image1 = FakeMediaStoreService.newImage(testAlbum, 'image1');
    (mediaStoreService as FakeMediaStoreService).entries = {
      image1,
    };

    await _initSource();
    expect(favourites.count, 0);

    await image1.toggleFavourite();
    expect(favourites.count, 1);
    expect(image1.isFavourite, true);

    await image1.toggleFavourite();
    expect(favourites.count, 0);
    expect(image1.isFavourite, false);
  });

  test('set/unset entry as album cover', () async {
    final image1 = FakeMediaStoreService.newImage(testAlbum, 'image1');
    (mediaStoreService as FakeMediaStoreService).entries = {
      image1,
    };

    final source = await _initSource();
    expect(source.rawAlbums.length, 1);
    expect(covers.count, 0);

    final albumFilter = AlbumFilter(testAlbum, 'whatever');
    expect(albumFilter.test(image1), true);
    expect(covers.count, 0);
    expect(covers.coverContentId(albumFilter), null);

    await covers.set(albumFilter, image1.contentId);
    expect(covers.count, 1);
    expect(covers.coverContentId(albumFilter), image1.contentId);

    await covers.set(albumFilter, null);
    expect(covers.count, 0);
    expect(covers.coverContentId(albumFilter), null);
  });

  test('favourites and covers are kept when renaming entries', () async {
    final image1 = FakeMediaStoreService.newImage(testAlbum, 'image1');
    (mediaStoreService as FakeMediaStoreService).entries = {
      image1,
    };

    final source = await _initSource();
    await image1.toggleFavourite();
    final albumFilter = AlbumFilter(testAlbum, 'whatever');
    await covers.set(albumFilter, image1.contentId);
    await source.renameEntry(image1, 'image1b.jpg');

    expect(favourites.count, 1);
    expect(image1.isFavourite, true);
    expect(covers.count, 1);
    expect(covers.coverContentId(albumFilter), image1.contentId);
  });

  test('favourites and covers are cleared when removing entries', () async {
    final image1 = FakeMediaStoreService.newImage(testAlbum, 'image1');
    (mediaStoreService as FakeMediaStoreService).entries = {
      image1,
    };

    final source = await _initSource();
    await image1.toggleFavourite();
    final albumFilter = AlbumFilter(image1.directory, 'whatever');
    await covers.set(albumFilter, image1.contentId);
    await source.removeEntries({image1.uri});

    expect(source.rawAlbums.length, 0);
    expect(favourites.count, 0);
    expect(covers.count, 0);
    expect(covers.coverContentId(albumFilter), null);
  });

  test('albums are updated when moving entries', () async {
    final image1 = FakeMediaStoreService.newImage(sourceAlbum, 'image1');
    (mediaStoreService as FakeMediaStoreService).entries = {
      image1,
    };

    final source = await _initSource();
    expect(source.rawAlbums.contains(sourceAlbum), true);
    expect(source.rawAlbums.contains(destinationAlbum), false);

    final sourceAlbumFilter = AlbumFilter(sourceAlbum, 'whatever');
    final destinationAlbumFilter = AlbumFilter(destinationAlbum, 'whatever');
    expect(sourceAlbumFilter.test(image1), true);
    expect(destinationAlbumFilter.test(image1), false);

    await source.updateAfterMove(
      todoEntries: {image1},
      copy: false,
      destinationAlbum: destinationAlbum,
      movedOps: {
        FakeMediaStoreService.moveOpEventFor(image1, sourceAlbum, destinationAlbum),
      },
    );

    expect(source.rawAlbums.contains(sourceAlbum), false);
    expect(source.rawAlbums.contains(destinationAlbum), true);
    expect(sourceAlbumFilter.test(image1), false);
    expect(destinationAlbumFilter.test(image1), true);
  });

  test('favourites are kept when moving entries', () async {
    final image1 = FakeMediaStoreService.newImage(sourceAlbum, 'image1');
    (mediaStoreService as FakeMediaStoreService).entries = {
      image1,
    };

    final source = await _initSource();
    await image1.toggleFavourite();

    await source.updateAfterMove(
      todoEntries: {image1},
      copy: false,
      destinationAlbum: destinationAlbum,
      movedOps: {
        FakeMediaStoreService.moveOpEventFor(image1, sourceAlbum, destinationAlbum),
      },
    );

    expect(favourites.count, 1);
    expect(image1.isFavourite, true);
  });

  test('album cover is reset when moving cover entry', () async {
    final image1 = FakeMediaStoreService.newImage(sourceAlbum, 'image1');
    (mediaStoreService as FakeMediaStoreService).entries = {
      image1,
      FakeMediaStoreService.newImage(sourceAlbum, 'image2'),
    };

    final source = await _initSource();
    expect(source.rawAlbums.length, 1);
    final sourceAlbumFilter = AlbumFilter(sourceAlbum, 'whatever');
    await covers.set(sourceAlbumFilter, image1.contentId);

    await source.updateAfterMove(
      todoEntries: {image1},
      copy: false,
      destinationAlbum: destinationAlbum,
      movedOps: {
        FakeMediaStoreService.moveOpEventFor(image1, sourceAlbum, destinationAlbum),
      },
    );

    expect(source.rawAlbums.length, 2);
    expect(covers.count, 0);
    expect(covers.coverContentId(sourceAlbumFilter), null);
  });

  test('favourites and covers are kept when renaming albums', () async {
    final image1 = FakeMediaStoreService.newImage(sourceAlbum, 'image1');
    (mediaStoreService as FakeMediaStoreService).entries = {
      image1,
    };

    final source = await _initSource();
    await image1.toggleFavourite();
    var albumFilter = AlbumFilter(sourceAlbum, 'whatever');
    await covers.set(albumFilter, image1.contentId);
    await source.renameAlbum(sourceAlbum, destinationAlbum, {
      image1
    }, {
      FakeMediaStoreService.moveOpEventFor(image1, sourceAlbum, destinationAlbum),
    });
    albumFilter = AlbumFilter(destinationAlbum, 'whatever');

    expect(favourites.count, 1);
    expect(image1.isFavourite, true);
    expect(covers.count, 1);
    expect(covers.coverContentId(albumFilter), image1.contentId);
  });

  testWidgets('unique album names', (tester) async {
    (mediaStoreService as FakeMediaStoreService).entries = {
      FakeMediaStoreService.newImage('${FakeStorageService.primaryPath}Pictures/Elea/Zeno', '1'),
      FakeMediaStoreService.newImage('${FakeStorageService.primaryPath}Pictures/Citium/Zeno', '1'),
      FakeMediaStoreService.newImage('${FakeStorageService.primaryPath}Pictures/Cleanthes', '1'),
      FakeMediaStoreService.newImage('${FakeStorageService.primaryPath}Pictures/Chrysippus', '1'),
      FakeMediaStoreService.newImage('${FakeStorageService.removablePath}Pictures/Chrysippus', '1'),
      FakeMediaStoreService.newImage('${FakeStorageService.primaryPath}', '1'),
      FakeMediaStoreService.newImage('${FakeStorageService.primaryPath}Pictures/Seneca', '1'),
      FakeMediaStoreService.newImage('${FakeStorageService.primaryPath}Seneca', '1'),
      FakeMediaStoreService.newImage('${FakeStorageService.removablePath}Pictures/Cicero', '1'),
      FakeMediaStoreService.newImage('${FakeStorageService.removablePath}Marcus Aurelius', '1'),
    };

    await androidFileUtils.init();
    final source = await _initSource();
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          expect(source.getAlbumDisplayName(context, '${FakeStorageService.primaryPath}Pictures/Elea/Zeno'), 'Elea/Zeno');
          expect(source.getAlbumDisplayName(context, '${FakeStorageService.primaryPath}Pictures/Citium/Zeno'), 'Citium/Zeno');
          expect(source.getAlbumDisplayName(context, '${FakeStorageService.primaryPath}Pictures/Cleanthes'), 'Cleanthes');
          expect(source.getAlbumDisplayName(context, '${FakeStorageService.primaryPath}Pictures/Chrysippus'), 'Chrysippus');
          expect(source.getAlbumDisplayName(context, '${FakeStorageService.removablePath}Pictures/Chrysippus'), 'Chrysippus (${FakeStorageService.removableDescription})');
          expect(source.getAlbumDisplayName(context, FakeStorageService.primaryRootAlbum), FakeStorageService.primaryDescription);
          expect(source.getAlbumDisplayName(context, '${FakeStorageService.primaryPath}Pictures/Seneca'), 'Pictures/Seneca');
          expect(source.getAlbumDisplayName(context, '${FakeStorageService.primaryPath}Seneca'), 'Seneca');
          expect(source.getAlbumDisplayName(context, '${FakeStorageService.removablePath}Pictures/Cicero'), 'Cicero');
          expect(source.getAlbumDisplayName(context, '${FakeStorageService.removablePath}Marcus Aurelius'), 'Marcus Aurelius');
          return Placeholder();
        },
      ),
    );
  });
}
