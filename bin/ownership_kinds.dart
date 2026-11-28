/// Prints the kinds that decide chain ownership in the is_logbook source it
/// runs from, one per line, so a deploy can refuse a sender table that names
/// another release's ownership kind:
///
///     dart run is_logbook:ownership_kinds
library;

import 'package:is_logbook/service.dart';

void main() {
  for (final ownership in OwnershipKind.values) {
    print(ownership.kind.name);
  }
}
