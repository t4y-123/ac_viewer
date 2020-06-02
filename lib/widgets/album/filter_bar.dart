import 'package:aves/model/collection_lens.dart';
import 'package:aves/widgets/common/aves_filter_chip.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FilterBar extends StatelessWidget implements PreferredSizeWidget {
  static const double verticalPadding = 16;
  static const double preferredHeight = AvesFilterChip.minChipHeight + verticalPadding;

  @override
  final Size preferredSize = const Size.fromHeight(preferredHeight);

  @override
  Widget build(BuildContext context) {
    final collection = Provider.of<CollectionLens>(context);
    final filters = collection.filters.toList()..sort();

    return Container(
      // specify transparent as a workaround to prevent
      // chip border clipping when the floating app bar is fading
      color: Colors.transparent,
      height: preferredSize.height,
      child: NotificationListener<ScrollNotification>(
        // cancel notification bubbling so that the draggable scrollbar
        // does not misinterpret filter bar scrolling for collection scrolling
        onNotification: (notification) => true,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          itemBuilder: (context, index) {
            if (index >= filters.length) return null;
            final filter = filters[index];
            return Center(
              child: AvesFilterChip(
                key: ValueKey(filter),
                filter: filter,
                removable: true,
                heroType: HeroType.always,
                onPressed: collection.removeFilter,
              ),
            );
          },
          separatorBuilder: (context, index) => const SizedBox(width: 8),
          itemCount: filters.length,
        ),
      ),
    );
  }
}
