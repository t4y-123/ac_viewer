import 'package:aves/main_play.dart' as app;
import 'package:aves/model/filters/favourite.dart';
import 'package:aves/model/settings/defaults.dart';
import 'package:aves/model/settings/enums/enums.dart';
import 'package:aves/model/settings/settings.dart';
import 'package:aves/model/source/enums/enums.dart';
import 'package:aves/widgets/collection/collection_page.dart';
import 'package:aves/widgets/filter_grids/countries_page.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:flutter_test/flutter_test.dart';

void main() => configureAndLaunch();

Future<void> configureAndLaunch() async {
  enableFlutterDriverExtension();
  await settings.init(monitorPlatformSettings: false);
  settings
    // app
    ..hasAcceptedTerms = true
    ..isInstalledAppAccessAllowed = true
    ..isErrorReportingAllowed = false
    ..setTileExtent(CollectionPage.routeName, 69)
    ..setTileLayout(CollectionPage.routeName, TileLayout.mosaic)
    ..setTileExtent(CountryListPage.routeName, 112)
    ..setTileLayout(CountryListPage.routeName, TileLayout.grid)
    // display
    ..themeBrightness = AvesThemeBrightness.dark
    ..themeColorMode = AvesThemeColorMode.polychrome
    ..enableDynamicColor = false
    ..enableBlurEffect = true
    // navigation
    ..keepScreenOn = KeepScreenOn.always
    ..homePage = HomePageSetting.collection
    ..enableBottomNavigationBar = true
    ..drawerTypeBookmarks = [null, FavouriteFilter.instance]
    // collection
    ..collectionSectionFactor = EntryGroupFactor.month
    ..collectionSortFactor = EntrySortFactor.date
    ..collectionBrowsingQuickActions = SettingsDefaults.collectionBrowsingQuickActions
    ..showThumbnailFavourite = false
    ..showThumbnailTag = false
    ..showThumbnailLocation = false
    ..hiddenFilters = {}
    // viewer
    ..viewerQuickActions = SettingsDefaults.viewerQuickActions
    ..showOverlayOnOpening = true
    ..showOverlayMinimap = false
    ..showOverlayInfo = true
    ..showOverlayRatingTags = false
    ..showOverlayShootingDetails = false
    ..showOverlayThumbnailPreview = false
    ..viewerUseCutout = true
    // info
    ..infoMapZoom = 13
    ..coordinateFormat = CoordinateFormat.dms
    ..unitSystem = UnitSystem.metric;
  app.main();
}
