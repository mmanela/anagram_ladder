import 'dart:async';
import 'dart:isolate';

/// The *main* process for the spawned isolates.
void _process(_Processor processor) async {
  final receivePort = ReceivePort();
  processor.sendPort.send(receivePort.sendPort);
  await for (dynamic input in receivePort) {
    processor.process(input);
  }
}

/// An object representing all the data a worker [Isolate] needs to perform its work.
class _Processor<T, U> {
  final SendPort sendPort;
  final Future<U> Function(T input) mapper;

  void process(dynamic input) async {
    MapEntry<int, T> enumeratedInput = input;
    final res = await mapper(enumeratedInput.value);
    sendPort.send(MapEntry(enumeratedInput.key, res));
  }

  _Processor(this.mapper, this.sendPort);
}

/// A worker [Isolate] that will execute the `mapper` function on all items it receives.
/// via the [receivePort].\
/// Including all the relevant data to manage it.
class _ProcessorIsolate<T, U> {
  final Isolate isolate;
  final ReceivePort receivePort;
  final completer = Completer();
  SendPort? sendPort;

  _ProcessorIsolate({
    required this.isolate,
    required this.receivePort,
  });

  static Future<_ProcessorIsolate<T, U>> spawn<T, U>(
      Future<U> Function(T input) mapper, int i) async {
    final receivePort = ReceivePort();

    //print("Spawning #$i");
    final isolate = await Isolate.spawn(
        _process, _Processor(mapper, receivePort.sendPort),
        debugName: "Isolate_$i");
    //print("Done Spawning #$i");
    return _ProcessorIsolate(isolate: isolate, receivePort: receivePort);
  }
}

/// Operates like [Iterable.map] except performs the function [mapper] on a
/// background isolate. [parallel] denotes how many background isolates to use
/// (so it must be a positive number).
///
/// This is only useful if the computation time of [mapper] out paces the
/// overhead in coordination.
///
/// If preserving the order of the [iterable] is not required,
/// the [preserveOrder] setting can be set to `false`, reducing memory and
/// returning results as soon as available.
///
/// Note: [mapper] must be a static method or a top-level function.
Stream<U> pmap<T, U>(
  Iterable<T> iterable,
  Future<U> Function(T input) mapper, {
  int parallel = 1,
  bool preserveOrder = true,
}) {
  assert(
    parallel > 0,
    'There need to be at least one worker, but got $parallel',
  );

  final controller = StreamController<U>();

  // If the iterable was a list, the `currentIterableIndex` would be the
  // index of the element in `iterable.iterator`.
  var currentIterableIndex = -1;
  final it = iterable.iterator;
  bool nextInputElement() {
    final hasNext = it.moveNext();
    if (hasNext) currentIterableIndex++;
    return hasNext;
  }

  // The number of already emitted elements.
  var nextPublishIndex = 0;
  void publishElement(U result) {
    controller.add(result);
    nextPublishIndex++;
  }

  // Did we emit a value for all elements gotten from iterable.
  var allElementsPublished = false;

  // This is late, so it does not get initialized for `preserveOrder == false`.
  late final buffer = <int, U>{};
  final isolates = List.generate(
    parallel,
    (i) async {
      final isolate = await _ProcessorIsolate.spawn(mapper, i);
      isolate.receivePort.listen(
        (dynamic result) {
          if (isolate.sendPort == null) {
            isolate.sendPort = result as SendPort;
          } else {
            final enumeratedResult = result as MapEntry<int, U>;
            if (preserveOrder) {
              if (enumeratedResult.key == nextPublishIndex) {
                publishElement(enumeratedResult.value);
                var containsNext = buffer.containsKey(nextPublishIndex);
                while (containsNext) {
                  publishElement(buffer.remove(nextPublishIndex)
                      as U); // The `as U` makes sure that this could be null if U is nullable, but the publishElement gets U and not U?
                  containsNext = buffer.containsKey(nextPublishIndex);
                }
              } else {
                buffer[enumeratedResult.key] = enumeratedResult.value;
              }
            } else {
              publishElement(enumeratedResult.value);
            }
          }
          if (nextInputElement()) {
            // Either sendPort was not [null] to begin with or it was set as the first message
            isolate.sendPort!.send(MapEntry(currentIterableIndex, it.current));
          } else {
            if (currentIterableIndex == nextPublishIndex - 1) {
              allElementsPublished = true;
            }
            isolate.completer.complete();
          }
        },
      );
      return isolate;
    },
    growable: false,
  );

  Future.wait(isolates).then((isolatesSync) =>
      Future.wait(isolatesSync.map((isolate) => isolate.completer.future)).then(
        (_) {
          for (final isolate in isolatesSync) {
            isolate.receivePort.close();
            isolate.isolate.kill();
          }
          if (!allElementsPublished) {
            throw StateError(
                'For the $currentIterableIndex iterable elements there where only ${nextPublishIndex - 1} stream events published.\n'
                'This means one of the isolates had issues.');
          }
          controller.close();
        },
      ));

  return controller.stream;
}

extension PMapIterable<T> on Iterable<T> {
  /// Operates like [Iterable.map] except performs the function [mapper] on a
  /// background isolate. [parallel] denotes how many background isolates to use
  /// (so it must be a positive number).
  ///
  /// This is only useful if the computation time of [mapper] out paces the
  /// overhead in coordination.
  ///
  /// If preserving the order of the [iterable] is not required,
  /// the [preserveOrder] setting can be set to `false`, reducing memory and
  /// returning results as soon as available.
  ///
  /// Note: [mapper] must be a static method or a top-level function.
  Stream<U> mapParallel<U>(
    Future<U> Function(T input) mapper, {
    int parallel = 1,
    bool preserveOrder = true,
  }) =>
      pmap(
        this,
        mapper,
        parallel: parallel,
        preserveOrder: preserveOrder,
      );
}
