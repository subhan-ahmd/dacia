// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'loading_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$loadingHash() => r'd4583de7db8ec677a3e3024c247673dcb4861275';

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

abstract class _$Loading extends BuildlessAutoDisposeNotifier<bool> {
  late final String id;

  bool build(
    String id,
  );
}

/// See also [Loading].
@ProviderFor(Loading)
const loadingProvider = LoadingFamily();

/// See also [Loading].
class LoadingFamily extends Family<bool> {
  /// See also [Loading].
  const LoadingFamily();

  /// See also [Loading].
  LoadingProvider call(
    String id,
  ) {
    return LoadingProvider(
      id,
    );
  }

  @override
  LoadingProvider getProviderOverride(
    covariant LoadingProvider provider,
  ) {
    return call(
      provider.id,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'loadingProvider';
}

/// See also [Loading].
class LoadingProvider extends AutoDisposeNotifierProviderImpl<Loading, bool> {
  /// See also [Loading].
  LoadingProvider(
    String id,
  ) : this._internal(
          () => Loading()..id = id,
          from: loadingProvider,
          name: r'loadingProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$loadingHash,
          dependencies: LoadingFamily._dependencies,
          allTransitiveDependencies: LoadingFamily._allTransitiveDependencies,
          id: id,
        );

  LoadingProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.id,
  }) : super.internal();

  final String id;

  @override
  bool runNotifierBuild(
    covariant Loading notifier,
  ) {
    return notifier.build(
      id,
    );
  }

  @override
  Override overrideWith(Loading Function() create) {
    return ProviderOverride(
      origin: this,
      override: LoadingProvider._internal(
        () => create()..id = id,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        id: id,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<Loading, bool> createElement() {
    return _LoadingProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is LoadingProvider && other.id == id;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, id.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin LoadingRef on AutoDisposeNotifierProviderRef<bool> {
  /// The parameter `id` of this provider.
  String get id;
}

class _LoadingProviderElement
    extends AutoDisposeNotifierProviderElement<Loading, bool> with LoadingRef {
  _LoadingProviderElement(super.provider);

  @override
  String get id => (origin as LoadingProvider).id;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
