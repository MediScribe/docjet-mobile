import 'package:custom_lint_builder/custom_lint_builder.dart';

import 'src/no_sl_in_logic_lint.dart'; // Import the lint rule

// TODO: Add lint rules here

PluginBase createPlugin() => _DocjetLintsPlugin();

class _DocjetLintsPlugin extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => [
        NoSlInLogicLint(), // Instantiate and return the lint rule
      ];
}
