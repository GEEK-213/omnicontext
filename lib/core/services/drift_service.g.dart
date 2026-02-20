// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'drift_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$driftServiceHash() => r'7558867fa0dcc5117dd0f599bee7cb284c4a9c5c';

/// See also [driftService].
@ProviderFor(driftService)
final driftServiceProvider = Provider<DriftService>.internal(
  driftService,
  name: r'driftServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$driftServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef DriftServiceRef = ProviderRef<DriftService>;
String _$driftMonitorHash() => r'52821cdb8a59b0c496e0d5043058f94597ca4465';

/// See also [DriftMonitor].
@ProviderFor(DriftMonitor)
final driftMonitorProvider =
    AutoDisposeAsyncNotifierProvider<DriftMonitor, DriftStatus>.internal(
      DriftMonitor.new,
      name: r'driftMonitorProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$driftMonitorHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$DriftMonitor = AutoDisposeAsyncNotifier<DriftStatus>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
