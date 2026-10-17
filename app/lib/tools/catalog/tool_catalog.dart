/// Builds the default tool registry from the catalog batches.
///
/// One place to register everything, so adding a catalog is a single import
/// and one line here.
library;

import '../tool_descriptor.dart';
import '../tool_registry.dart';
import 'animator_catalog.dart';
import 'developer_catalog.dart';
import 'system_catalog.dart';
import 'text_catalog.dart';

/// Create a registry populated with every catalog batch.
ToolRegistry buildDefaultRegistry() {
  final registry = ToolRegistry();
  registry.registerAll(<ToolDescriptor>[
    ...developerTools(),
    ...textTools(),
    ...systemTools(),
    ...animatorTools(),
  ]);
  return registry;
}
