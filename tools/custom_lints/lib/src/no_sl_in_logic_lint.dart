import 'package:analyzer/error/error.dart' as analyzer;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as p;

/// Custom lint code for the no_sl_in_logic rule
const _slUsageErrorCode = LintCode(
  name: 'no_sl_in_logic',
  problemMessage: 'Do not use sl() directly in business logic, UI, or tests.',
  correctionMessage:
      'Use constructor injection. sl() is only allowed in main_*.dart, provider create blocks, and injection_container_test.dart.',
  errorSeverity: analyzer.ErrorSeverity.ERROR,
);

/// Lint rule that flags direct usage of the service locator (`sl()`) in disallowed contexts.
class NoSlInLogicLint extends DartLintRule {
  const NoSlInLogicLint() : super(code: _slUsageErrorCode);

  // Allowed file path patterns (relative paths)
  static const _allowedTestFile = 'test/core/di/injection_container_test.dart';
  static const _allowedMainFilesPrefix = 'main_';
  static const _allowedMainFilesDir = 'lib';

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    final absoluteFilePath = resolver.source.fullName;

    // Get the relative file path and file name
    final fileName = p.basename(absoluteFilePath);
    final relativePath = absoluteFilePath.split('/lib/').length > 1
        ? 'lib/${absoluteFilePath.split('/lib/')[1]}'
        : absoluteFilePath.split('/test/').length > 1
            ? 'test/${absoluteFilePath.split('/test/')[1]}'
            : absoluteFilePath;

    // Performance: Bail out early if the file itself is allowed
    if (relativePath == _allowedTestFile ||
        (fileName.startsWith(_allowedMainFilesPrefix) &&
            absoluteFilePath.contains('/$_allowedMainFilesDir/'))) {
      return;
    }

    // Register a visitor for method invocations (normal sl<Type>() calls)
    context.registry.addMethodInvocation((node) {
      // Check if the method being invoked is named 'sl'
      if (node.methodName.name == 'sl') {
        // Check if the call is inside an allowed context (e.g., Provider create)
        if (!_isAllowedContext(node)) {
          // Report the lint error
          reporter.atNode(node, _slUsageErrorCode);
        }
      }
    });

    // Register a visitor for property access (e.g., sl.call or di.sl)
    context.registry.addPropertyAccess((node) {
      final property = node.propertyName.name;
      final target = node.target;

      // Check for sl.call pattern
      if (property == 'call' &&
          target is SimpleIdentifier &&
          target.name == 'sl') {
        if (!_isAllowedContext(node)) {
          reporter.atNode(node, _slUsageErrorCode);
        }
      }

      // Check for di.sl pattern
      if (property == 'sl') {
        if (!_isAllowedContext(node)) {
          reporter.atNode(node, _slUsageErrorCode);
        }
      }
    });

    // Register a visitor for function expression invocations when `sl` is used as a top-level variable/function
    context.registry.addFunctionExpressionInvocation((node) {
      // Example: `sl<T>()` (no explicit receiver)
      final function = node.function;
      if (function is SimpleIdentifier && function.name == 'sl') {
        if (!_isAllowedContext(node)) {
          reporter.atNode(node, _slUsageErrorCode);
        }
      }
    });
  }

  // Check if the sl call is within an allowed context
  bool _isAllowedContext(AstNode slCallNode) {
    // Traverse up the AST from the sl() call
    AstNode? currentNode = slCallNode;
    while (currentNode != null) {
      // Check if inside a relevant Provider's `create` argument's FunctionExpression
      if (currentNode is FunctionExpression) {
        final parent = currentNode.parent;
        if (parent is NamedExpression && parent.name.label.name == 'create') {
          final grandParent = parent.parent;
          if (grandParent is ArgumentList) {
            final greatGrandParent = grandParent.parent;
            if (greatGrandParent is InstanceCreationExpression) {
              final type = greatGrandParent.constructorName.type;
              // Use the lexeme of the name token
              final constructorName = type.name2.lexeme;

              // Check for common Provider types
              if (constructorName == 'BlocProvider' ||
                  constructorName == 'Provider' ||
                  constructorName == 'ChangeNotifierProvider' ||
                  constructorName == 'RepositoryProvider' ||
                  constructorName == 'FutureProvider' ||
                  constructorName == 'StreamProvider' ||
                  constructorName == 'MultiProvider') {
                return true; // Found sl() inside a Provider create block
              }
            }
          }
        }
      }

      // Check for MultiProvider structure if this isn't already inside a single provider
      if (currentNode is NamedExpression &&
          currentNode.name.label.name == 'create') {
        // This could be inside a MultiProvider's builders list
        AstNode? providerParent = currentNode.parent;
        while (providerParent != null) {
          if (providerParent is InstanceCreationExpression) {
            final type = providerParent.constructorName.type;
            final typeName = type.name2.lexeme;

            if (typeName == 'MultiProvider') {
              return true; // Found sl() inside MultiProvider's builders
            }
          }
          providerParent = providerParent.parent;
        }
      }

      currentNode = currentNode.parent;
    }

    return false; // sl() call is not within an allowed context
  }
}
