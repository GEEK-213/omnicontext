// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'terminal_history_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$terminalHistoryHash() => r'dc5073c395612d46f0b2f82e75b935e33551a304';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

abstract class _$TerminalHistory
    extends BuildlessAutoDisposeNotifier<List<TerminalCommandLog>> {
  late final String projectPath;

  List<TerminalCommandLog> build(String projectPath);
}

/// See also [TerminalHistory].
@ProviderFor(TerminalHistory)
const terminalHistoryProvider = TerminalHistoryFamily();

/// See also [TerminalHistory].
class TerminalHistoryFamily extends Family<List<TerminalCommandLog>> {
  /// See also [TerminalHistory].
  const TerminalHistoryFamily();

  /// See also [TerminalHistory].
  TerminalHistoryProvider call(String projectPath) {
    return TerminalHistoryProvider(projectPath);
  }

  @override
  TerminalHistoryProvider getProviderOverride(
    covariant TerminalHistoryProvider provider,
  ) {
    return call(provider.projectPath);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'terminalHistoryProvider';
}

/// See also [TerminalHistory].
class TerminalHistoryProvider
    extends
        AutoDisposeNotifierProviderImpl<
          TerminalHistory,
          List<TerminalCommandLog>
        > {
  /// See also [TerminalHistory].
  TerminalHistoryProvider(String projectPath)
    : this._internal(
        () => TerminalHistory()..projectPath = projectPath,
        from: terminalHistoryProvider,
        name: r'terminalHistoryProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$terminalHistoryHash,
        dependencies: TerminalHistoryFamily._dependencies,
        allTransitiveDependencies:
            TerminalHistoryFamily._allTransitiveDependencies,
        projectPath: projectPath,
      );

  TerminalHistoryProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.projectPath,
  }) : super.internal();

  final String projectPath;

  @override
  List<TerminalCommandLog> runNotifierBuild(
    covariant TerminalHistory notifier,
  ) {
    return notifier.build(projectPath);
  }

  @override
  Override overrideWith(TerminalHistory Function() create) {
    return ProviderOverride(
      origin: this,
      override: TerminalHistoryProvider._internal(
        () => create()..projectPath = projectPath,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        projectPath: projectPath,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<TerminalHistory, List<TerminalCommandLog>>
  createElement() {
    return _TerminalHistoryProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is TerminalHistoryProvider && other.projectPath == projectPath;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, projectPath.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin TerminalHistoryRef
    on AutoDisposeNotifierProviderRef<List<TerminalCommandLog>> {
  /// The parameter `projectPath` of this provider.
  String get projectPath;
}

class _TerminalHistoryProviderElement
    extends
        AutoDisposeNotifierProviderElement<
          TerminalHistory,
          List<TerminalCommandLog>
        >
    with TerminalHistoryRef {
  _TerminalHistoryProviderElement(super.provider);

  @override
  String get projectPath => (origin as TerminalHistoryProvider).projectPath;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
