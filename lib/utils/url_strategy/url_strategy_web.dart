import 'package:flutter_web_plugins/url_strategy.dart';

/// Web implementation of URL strategy configuration to remove the '#' hash from the URL.
void configureUrlStrategy() {
  usePathUrlStrategy();
}
