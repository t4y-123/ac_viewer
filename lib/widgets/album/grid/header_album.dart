import 'package:aves/widgets/album/grid/header_generic.dart';
import 'package:aves/widgets/common/icons.dart';
import 'package:flutter/material.dart';

class AlbumSectionHeader extends StatelessWidget {
  final String folderPath, albumName;

  const AlbumSectionHeader({
    Key key,
    @required this.folderPath,
    @required this.albumName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var albumIcon = IconUtils.getAlbumIcon(context: context, album: folderPath);
    if (albumIcon != null) {
      albumIcon = Material(
        type: MaterialType.circle,
        elevation: 3,
        color: Colors.transparent,
        shadowColor: Colors.black,
        child: albumIcon,
      );
    }
    return TitleSectionHeader(
      leading: albumIcon,
      title: albumName,
    );
  }
}