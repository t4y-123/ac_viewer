import 'dart:async';
import 'dart:ui';

import 'package:aves/widgets/common/magnifier/controller/state.dart';
import 'package:aves/widgets/common/magnifier/scale/scale_boundaries.dart';
import 'package:aves/widgets/common/magnifier/scale/scale_level.dart';
import 'package:aves/widgets/common/magnifier/scale/state.dart';
import 'package:flutter/widgets.dart';

class MagnifierController {
  final StreamController<MagnifierState> _stateStreamController = StreamController.broadcast();
  final StreamController<ScaleBoundaries> _scaleBoundariesStreamController = StreamController.broadcast();
  final StreamController<ScaleStateChange> _scaleStateChangeStreamController = StreamController.broadcast();

  MagnifierState _currentState, initial, previousState;
  ScaleBoundaries _scaleBoundaries;
  ScaleStateChange _currentScaleState, previousScaleState;

  MagnifierController({
    Offset initialPosition = Offset.zero,
  }) : super() {
    initial = MagnifierState(
      position: initialPosition,
      scale: null,
      source: ChangeSource.internal,
    );
    previousState = initial;
    _setState(initial);

    final _initialScaleState = ScaleStateChange(state: ScaleState.initial, source: ChangeSource.internal);
    previousScaleState = _initialScaleState;
    _setScaleState(_initialScaleState);
  }

  Stream<MagnifierState> get stateStream => _stateStreamController.stream;

  Stream<ScaleBoundaries> get scaleBoundariesStream => _scaleBoundariesStreamController.stream;

  Stream<ScaleStateChange> get scaleStateChangeStream => _scaleStateChangeStreamController.stream;

  MagnifierState get currentState => _currentState;

  Offset get position => currentState.position;

  double get scale => currentState.scale;

  ScaleBoundaries get scaleBoundaries => _scaleBoundaries;

  ScaleStateChange get scaleState => _currentScaleState;

  bool get hasScaleSateChanged => previousScaleState != scaleState;

  bool get isZooming => scaleState.state == ScaleState.zoomedIn || scaleState.state == ScaleState.zoomedOut;

  /// Closes streams and removes eventual listeners.
  void dispose() {
    _stateStreamController.close();
    _scaleBoundariesStreamController.close();
    _scaleStateChangeStreamController.close();
  }

  void update({
    Offset position,
    double scale,
    @required ChangeSource source,
  }) {
    position = position ?? this.position;
    scale = scale ?? this.scale;
    if (this.position == position && this.scale == scale) return;

    previousState = currentState;
    _setState(MagnifierState(
      position: position,
      scale: scale,
      source: source,
    ));
  }

  void setScaleState(ScaleState newValue, ChangeSource source, {Offset childFocalPoint}) {
    if (_currentScaleState.state == newValue) return;

    previousScaleState = _currentScaleState;
    _currentScaleState = ScaleStateChange(state: newValue, source: source, childFocalPoint: childFocalPoint);
    _scaleStateChangeStreamController.sink.add(scaleState);
  }

  void _setState(MagnifierState state) {
    if (_currentState == state) return;
    _currentState = state;
    _stateStreamController.sink.add(state);
  }

  void setScaleBoundaries(ScaleBoundaries scaleBoundaries) {
    if (_scaleBoundaries == scaleBoundaries) return;
    _scaleBoundaries = scaleBoundaries;
    _scaleBoundariesStreamController.sink.add(scaleBoundaries);

    if (!isZooming) {
      update(
        scale: getScaleForScaleState(_currentScaleState.state),
        source: ChangeSource.internal,
      );
    }
  }

  void _setScaleState(ScaleStateChange scaleState) {
    if (_currentScaleState == scaleState) return;
    _currentScaleState = scaleState;
    _scaleStateChangeStreamController.sink.add(_currentScaleState);
  }

  double getScaleForScaleState(ScaleState scaleState) {
    double _clamp(double scale, ScaleBoundaries boundaries) => scale.clamp(boundaries.minScale, boundaries.maxScale);

    switch (scaleState) {
      case ScaleState.initial:
      case ScaleState.zoomedIn:
      case ScaleState.zoomedOut:
        return _clamp(scaleBoundaries.initialScale, scaleBoundaries);
      case ScaleState.covering:
        return _clamp(ScaleLevel.scaleForCovering(scaleBoundaries.viewportSize, scaleBoundaries.childSize), scaleBoundaries);
      case ScaleState.originalSize:
        return _clamp(1.0, scaleBoundaries);
      default:
        return null;
    }
  }
}
