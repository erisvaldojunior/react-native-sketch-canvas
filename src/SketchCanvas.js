'use strict';

import React from 'react'
import PropTypes from 'prop-types'
import ReactNative, {
  requireNativeComponent,
  NativeModules,
  UIManager,
  View,
  Text,
  TouchableOpacity,
  PanResponder,
  PixelRatio,
  Platform,
  ViewPropTypes,
  processColor
} from 'react-native'

const RNSketchCanvas = requireNativeComponent('RNSketchCanvas', SketchCanvas, {
  nativeOnly: {
    nativeID: true,
    onChange: true
  }
});
const SketchCanvasManager = NativeModules.RNSketchCanvasManager || {};

class SketchCanvas extends React.Component {
  static propTypes = {
    style: ViewPropTypes.style,
    strokeColor: PropTypes.string,
    strokeWidth: PropTypes.number,
    onPathsChange: PropTypes.func,
    onStrokeStart: PropTypes.func,
    onStrokeChanged: PropTypes.func,
    onStrokeEnd: PropTypes.func,
    onSketchSaved: PropTypes.func,
    user: PropTypes.string,
    touchEnabled: PropTypes.bool,
    localSourceImagePath: PropTypes.string
  };

  static defaultProps = {
    style: null,
    strokeColor: '#000000',
    strokeWidth: 3,
    onPathsChange: () => {},
    onStrokeStart: () => {},
    onStrokeChanged: () => {},
    onStrokeEnd: () => {},
    onSketchSaved: () => {},
    user: null,
    touchEnabled: true,
    localSourceImagePath: null
  };

  constructor(props) {
    super(props)
    this._pathsToProcess = []
    this._pathsById = {}
    this._paths = []
    this._points = []
    this._currentPath = null
    this._handle = null
    this._screenScale = Platform.OS === 'ios' ? 1 : PixelRatio.get()
    this._size = { width: 0, height: 0 }
    this._initialized = false
  }

  clear() {
    this._pathsById = {}
    this._paths = []
    this._points = []
    this._currentPath = null
    UIManager.dispatchViewManagerCommand(this._handle, UIManager.RNSketchCanvas.Commands.clear, [])
  }

  undo() {
    const pathData = [...this._paths].reverse().find(d => d.finished === true && d.drawer === this.props.user)
    if (pathData) { this.deletePath(pathData.path.id) }
    return pathData && pathData.path.id
  }

  newPath(strokeColor, strokeWidth) {
    const path = {
      id: parseInt(Math.random() * 100000000), color: strokeColor,
      width: strokeWidth, data: []
    }

    UIManager.dispatchViewManagerCommand(
      this._handle,
      UIManager.RNSketchCanvas.Commands.newPath,
      [
        path.id,
        processColor(path.color),
        path.width * this._screenScale
      ]
    )

    const pathData = { path: path, size: this._size, finished: false, drawer: this.props.user }
    this._pathsById[path.id] = pathData
    this._paths.push(pathData)

    return path;
  }

  addPoint(pathId, x, y) {
    const pathData = this._pathsById[pathId]
    if (!pathData) { return };

    UIManager.dispatchViewManagerCommand(
      this._handle,
      UIManager.RNSketchCanvas.Commands.addPoint,
      [
        pathId,
        parseFloat(x.toFixed(2) * this._screenScale),
        parseFloat(y.toFixed(2) * this._screenScale)
      ]
    )

    const point = `${parseFloat(x).toFixed(2)},${parseFloat(y).toFixed(2)}`
    pathData.path.data.push(point)
    this._points.push([pathId, point])
  }

  endPath(pathId) {
    const path = this._pathsById[pathId]
    if (!path) { return };

    UIManager.dispatchViewManagerCommand(this._handle, UIManager.RNSketchCanvas.Commands.endPath, [pathId])

    path.finished = true;
  }

  addPath(data) {
    if (this._initialized) {
      const pathId = data.path.id
      if (this._pathsById[pathId]) { return }

      const pathData = data.path.data.map(p => {
        const coor = p.split(',').map(pp => parseFloat(pp).toFixed(2))
        return `${coor[0] * this._screenScale * this._size.width / data.size.width },${coor[1] * this._screenScale * this._size.height / data.size.height }`;
      })
      UIManager.dispatchViewManagerCommand(this._handle, UIManager.RNSketchCanvas.Commands.addPath, [
        pathId, processColor(data.path.color), data.path.width * this._screenScale , pathData
      ])

      this._pathsById[pathId] = data
      this._paths.push(data)
      data.path.data.forEach(p => {
        this._points.push([pathId, p])
      })
    } else {
      this._pathsToProcess.filter(p => p.path.id === pathId).length === 0 && this._pathsToProcess.push(data)
    }
  }

  deletePath(pathId) {
    if (!this._pathsById[pathId]) { return }
    this._pathsById[pathId] = undefined
    this._paths = this._paths.filter(p => p.path.id !== pathId)
    this._points = this._points.filter(p => p[0] !== pathId)
    UIManager.dispatchViewManagerCommand(this._handle, UIManager.RNSketchCanvas.Commands.deletePath, [ pathId ])
  }

  save(imageType, transparent, folder, filename) {
    UIManager.dispatchViewManagerCommand(this._handle, UIManager.RNSketchCanvas.Commands.save, [ imageType, folder, filename, transparent ])
  }

  getPaths() {
    return this._paths
  }

  getPoints() {
    return this._points
  }

  getSize() {
    return this._size
  }

  getBase64(imageType, transparent, callback) {
    if (Platform.OS === 'ios') {
      SketchCanvasManager.transferToBase64(this._handle, imageType, transparent, callback)
    } else {
      NativeModules.SketchCanvasModule.transferToBase64(this._handle, imageType, transparent, callback)
    }
  }

  componentWillMount() {
    this.panResponder = PanResponder.create({
      // Ask to be the responder:
      onStartShouldSetPanResponder: (evt, gestureState) => true,
      onStartShouldSetPanResponderCapture: (evt, gestureState) => true,
      onMoveShouldSetPanResponder: (evt, gestureState) => true,
      onMoveShouldSetPanResponderCapture: (evt, gestureState) => true,

      onPanResponderGrant: (evt, gestureState) => {
        if (!this.props.touchEnabled) return
        const e = evt.nativeEvent
        this._currentPath = this.newPath(this.props.strokeColor, this.props.strokeWidth)
        this.addPoint(this._currentPath.id, e.locationX, e.locationY)
        this.props.onStrokeStart({ path: this._currentPath, size: this._size, drawer: this.props.user })
      },
      onPanResponderMove: (evt, gestureState) => {
        if (!this.props.touchEnabled) return
        const currentPath = this._currentPath;
        if (!currentPath) { return }

        const e = evt.nativeEvent
        this.addPoint(currentPath.id, e.locationX, e.locationY)
        this.props.onStrokeChanged({ path: currentPath, size: this._size, drawer: this.props.user })

      },
      onPanResponderRelease: (evt, gestureState) => {
        if (!this.props.touchEnabled) return
        const currentPath = this._currentPath;
        if (!currentPath) { return }

        this._currentPath = null
        this.endPath(currentPath.id)
        this.props.onStrokeEnd({ path: currentPath, size: this._size, drawer: this.props.user })
      },

      onShouldBlockNativeResponder: (evt, gestureState) => {
        return true;
      },
    });
  }

  render() {
    return (
      <RNSketchCanvas
        ref={ref => {
          this._handle = ReactNative.findNodeHandle(ref)
        }}
        style={this.props.style}
        onLayout={e => {
          this._size={ width: e.nativeEvent.layout.width, height: e.nativeEvent.layout.height }
          this._initialized = true
          this._pathsToProcess.length > 0 && this._pathsToProcess.forEach(p => this.addPath(p))
        }}
        {...this.panResponder.panHandlers}
        onChange={(e) => {
          if (e.nativeEvent.hasOwnProperty('pathsUpdate')) {
            this.props.onPathsChange(e.nativeEvent.pathsUpdate)
          } else if (e.nativeEvent.hasOwnProperty('success') && e.nativeEvent.hasOwnProperty('path')) {
            this.props.onSketchSaved(e.nativeEvent.success, e.nativeEvent.path)
          }else if (e.nativeEvent.hasOwnProperty('success')) {
            this.props.onSketchSaved(e.nativeEvent.success)
          }
        }}
        localSourceImagePath={this.props.localSourceImagePath}
      />
    );
  }
}

module.exports = SketchCanvas;
