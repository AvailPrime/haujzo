import '../../../utils/constants/colors.dart';
import '../../../utils/device/device_utility.dart';
import '../../../utils/helpers/helper_functions.dart';
import 'package:flutter/material.dart';

class AvailTabBar extends StatelessWidget implements PreferredSizeWidget{
  /// If you want to add background color to the tab you have to wrap the Tabs with a Widgets
  /// In order to do that, you have to use [PreferredSizeWidget]
  const AvailTabBar({super.key, required this.tabs});

  final List<Widget> tabs;

  @override
  Widget build(BuildContext context) {
    final dark = AvailHelperFunctions.isDarkMode(context);
    return Material(
      color: dark ? AvailColors.dark : AvailColors.white,
      child: TabBar(
        tabAlignment: TabAlignment.start,
        tabs: tabs,
        isScrollable: true,
        indicatorColor: AvailColors.primary,
        labelColor: dark? AvailColors.white : AvailColors.primary,
        unselectedLabelColor: AvailColors.darkgrey,
      ),
    );
  }

  @override
  // Standard TabBar height is 48.0
  Size get preferredSize => const Size.fromHeight(48.0);
}
