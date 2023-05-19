import UIKit
import Foundation
import MapboxCoreNavigation
import MapboxNavigation
import MapboxDirections
import MapboxMaps
import Turf

// // adapted from https://pspdfkit.com/blog/2017/native-view-controllers-and-react-native/ and https://github.com/mslabenyak/react-native-mapbox-navigation/blob/master/ios/Mapbox/MapboxNavigationView.swift
extension UIView {
  var parentViewController: UIViewController? {
    var parentResponder: UIResponder? = self
    while parentResponder != nil {
      parentResponder = parentResponder!.next
      if let viewController = parentResponder as? UIViewController {
        return viewController
      }
    }
    return nil
  }
}

class MapboxNavigationFreeDriveView: UIView, NavigationMapViewDelegate {
  @objc var followZoomLevel: NSNumber = 16.0
  @objc var onLocationChange: RCTDirectEventBlock?
  @objc var onError: RCTDirectEventBlock?
  @objc var onTrackingStateChange: RCTDirectEventBlock?
  @objc var onRouteChange: RCTDirectEventBlock?
  @objc var showSpeedLimit: Bool = true {
    didSet {
      if (embedded == true && oldValue != showSpeedLimit) {
        if (showSpeedLimit) {
          showSpeedLimitView()
        } else {
          hideSpeedLimitView()
        }
      }
    }
  }
  @objc var speedLimitAnchor: [NSNumber] = [] {
    didSet {
      if (embedded == true && oldValue.count != speedLimitAnchor.count || oldValue != speedLimitAnchor) {
        if (showSpeedLimit) {
          showSpeedLimitView()
        } else {
          hideSpeedLimitView()
        }
      }
    }
  }
  @objc var maneuverAnchor: [NSNumber] = []
  @objc var maneuverRadius: NSNumber = 26
  @objc var maneuverBackgroundColor: NSString = "#303030"
  @objc var userPuckImage: UIImage?
  @objc var userPuckScale: NSNumber = 1.0
  @objc var originImage: UIImage?
  @objc var destinationImage: UIImage?
  @objc var mapPadding: [NSNumber] = []
  @objc var routeColor: NSString = "#56A8FB"
  @objc var routeCasingColor: NSString = "#2F7AC6" {
    didSet {
      if (embedded == true) {
        navigationMapView.routeCasingColor = UIColor(hex: routeCasingColor as String)
      }
    }
  }
  @objc var routeClosureColor: NSString = "#000000"
  @objc var alternateRouteColor: NSString = "#8694A5" {
    didSet {
      if (embedded == true) {
        navigationMapView.routeAlternateColor = UIColor(hex: alternateRouteColor as String)
      }
    }
  }
  @objc var alternateRouteCasingColor: NSString = "#727E8D" {
    didSet {
      if (embedded == true) {
        navigationMapView.routeAlternateCasingColor = UIColor(hex: alternateRouteCasingColor as String)
      }
    }
  }
  @objc var traversedRouteColor: NSString? {
    didSet {
      if (embedded == true) {
        if (traversedRouteColor != nil) {
          navigationMapView.traversedRouteColor = UIColor(hex: traversedRouteColor! as String)
        } else {
          navigationMapView.traversedRouteColor = UIColor.clear
        }
      }
    }
  }
  @objc var traversedRouteCasingColor: NSString?
  @objc var trafficUnknownColor: NSString = "#56A8FB" {
    didSet {
      if (embedded == true) {
        navigationMapView.trafficUnknownColor = UIColor(hex: trafficUnknownColor as String)
      }
    }
  }
  @objc var trafficLowColor: NSString = "#56A8FB" {
    didSet {
      if (embedded == true) {
        navigationMapView.trafficLowColor = UIColor(hex: trafficLowColor as String)
      }
    }
  }
  @objc var trafficModerateColor: NSString = "#ff9500" {
    didSet {
      if (embedded == true) {
        navigationMapView.trafficModerateColor = UIColor(hex: trafficModerateColor as String)
      }
    }
  }
  @objc var trafficHeavyColor: NSString = "#ff4d4d" {
    didSet {
      if (embedded == true) {
        navigationMapView.trafficHeavyColor = UIColor(hex: trafficHeavyColor as String)
      }
    }
  }
  @objc var trafficSevereColor: NSString = "#8f2447" {
    didSet {
      if (embedded == true) {
        navigationMapView.trafficSevereColor = UIColor(hex: trafficSevereColor as String)
      }
    }
  }
  @objc var restrictedRoadColor: NSString = "#000000" {
    didSet {
      if (embedded == true) {
        navigationMapView.routeRestrictedAreaColor = UIColor(hex: restrictedRoadColor as String)
      }
    }
  }
  @objc var routeArrowColor: NSString = "#FFFFFF" {
    didSet {
      if (embedded == true) {
        navigationMapView.maneuverArrowColor = UIColor(hex: routeArrowColor as String)
      }
    }
  }
  @objc var routeArrowCasingColor: NSString = "#2D3F53" {
    didSet {
      if (embedded == true) {
        navigationMapView.maneuverArrowStrokeColor = UIColor(hex: routeArrowCasingColor as String)
      }
    }
  }
  @objc var waypointColor: NSString = "#2F7AC6"
  @objc var waypointRadius: NSNumber = 8
  @objc var waypointOpacity: NSNumber = 1
  @objc var waypointStrokeWidth: NSNumber = 2
  @objc var waypointStrokeOpacity: NSNumber = 1
  @objc var waypointStrokeColor: NSString = "#FFFFFF"
  @objc var logoVisible: Bool = true
  @objc var logoPadding: [NSNumber] = [] {
    didSet {
      if (embedded == true && oldValue.count != logoPadding.count || oldValue != logoPadding) {
        setLogoPadding()
      }
    }
  }
  @objc var attributionVisible: Bool = true
  @objc var attributionPadding: [NSNumber] = [] {
    didSet {
      if (embedded == true && oldValue.count != attributionPadding.count || oldValue != attributionPadding) {
        setAttributionPadding()
      }
    }
  }
  @objc var mute: Bool = false
  @objc var darkMode: Bool = false {
    didSet {
      if (embedded == true) {
        if (darkMode) {
          navigationMapView.mapView.mapboxMap.loadStyleURI(StyleURI.dark)
        } else {
          navigationMapView.mapView.mapboxMap.loadStyleURI(StyleURI.light)
        }
      }
    }
  }
  @objc var debug: Bool = false

  var navigationService: NavigationService!
  var navigationMapView: NavigationMapView!
  var speedLimitView: SpeedLimitView!
  var instructionsCardContainerView: InstructionsCardContainerView!
  var voiceController: RouteVoiceController!
  var pointAnnotationManager: PointAnnotationManager?
  var passiveLocationManager: PassiveLocationManager!
  var passiveLocationProvider: PassiveLocationProvider!
  var embedded: Bool
  var embedding: Bool
  var isMapStyleLoaded: Bool = false
  var currentLegIndex: Int = -1
  var currentActiveRoutes: [Route]? = nil
  var currentPreviewRoutes: [Route]? = nil
  var currentRouteResponse: RouteResponse? = nil
  var waypointStyles: [[String: Any]] = []

  @objc func showRoute(origin: [NSNumber], destination: [NSNumber], waypoints: [[NSNumber]], styles: [NSDictionary], legIndex: NSNumber, cameraType: NSString, padding: [NSNumber])  {
    if (embedded == false) {
      return
    }

    waypointStyles = (styles as? [[String: Any]]) ?? []

    var routeWaypoints: [Waypoint] = []
    var routeWaypointNames: [String] = []

    if (origin.isEmpty == false) {
      let originWaypoint = Waypoint(coordinate: CLLocationCoordinate2D(latitude: origin[1] as! CLLocationDegrees, longitude: origin[0] as! CLLocationDegrees))
      routeWaypoints.append(originWaypoint)
    }

    if (waypoints.isEmpty == false) {
      for waypoint: [NSNumber] in waypoints {
        if (waypoint.isEmpty == false) {
          routeWaypoints.append(Waypoint(coordinate: CLLocationCoordinate2D(latitude: waypoint[1] as! CLLocationDegrees, longitude: waypoint[0] as! CLLocationDegrees)))
        }
      }
    }

    if (destination.isEmpty == false) {
      let destinationWaypoint = Waypoint(coordinate: CLLocationCoordinate2D(latitude: destination[1] as! CLLocationDegrees, longitude: destination[0] as! CLLocationDegrees))
      routeWaypoints.append(destinationWaypoint)
    }

    if (waypointStyles.isEmpty == false) {
      for waypointStyle: [String : Any] in waypointStyles {
        routeWaypointNames.append(((waypointStyle["name"]! as? NSString) ?? "") as String)
      }
    }

    if (routeWaypoints.isEmpty == false) {
      fetchRoutes(routeWaypoints: routeWaypoints, routeWaypointNames: routeWaypointNames, onSuccess: {(routes: [Route]) -> Void in
        self.moveToOverview(padding: padding)
        self.previewRoutes(routes: routes)
        self.onRouteChange?(["distance": routes.first?.distance ?? 0, "expectedTravelTime": routes.first?.expectedTravelTime ?? 0, "typicalTravelTime": routes.first?.typicalTravelTime ?? 0])
      })
    }
  }

  @objc func clearRoute() {
    if (embedded == true) {
      clearRouteAndStopActiveGuidance()
    }
  }

  @objc func follow(padding: [NSNumber]) {
    if (embedded == true) {
      if let navigationViewportDataSource = navigationMapView.navigationCamera.viewportDataSource as? NavigationViewportDataSource {
        navigationViewportDataSource.followingMobileCamera.padding = getPadding(padding)
        navigationMapView.navigationCamera.follow()
      }
    }
  }

  @objc func moveToOverview(padding: [NSNumber]) {
    if (embedded == true) {
      if let navigationViewportDataSource = navigationMapView.navigationCamera.viewportDataSource as? NavigationViewportDataSource {
        navigationViewportDataSource.overviewMobileCamera.padding = getPadding(padding)
        navigationMapView.navigationCamera.moveToOverview()
      }
    }
  }

  @objc func fitCamera(padding: [NSNumber]) {
    if (embedded == true) {
      if let navigationViewportDataSource = navigationMapView.navigationCamera.viewportDataSource as? NavigationViewportDataSource {
        navigationViewportDataSource.overviewMobileCamera.padding = getPadding(padding)
        navigationMapView.navigationCamera.moveToOverview()
      }
    }
  }

  @objc func startNavigation(origin: [NSNumber], destination: [NSNumber], waypoints: [[NSNumber]], styles: [NSDictionary], legIndex: NSNumber, cameraType: NSString, padding: [NSNumber])  {
    if (embedded == false || embedding == true) {
      return
    }
    
    if (currentActiveRoutes != nil) {
      startActiveGuidance(updateCamera: false)

      if (cameraType == "overview") {
        moveToOverview(padding: padding)
      } else {
        follow(padding: padding)
      }
    } else {
      waypointStyles = (styles as? [[String: Any]]) ?? []

      var routeWaypoints: [Waypoint] = []
      var routeWaypointNames: [String] = []

      if (origin.isEmpty == false) {
        let originWaypoint = Waypoint(coordinate: CLLocationCoordinate2D(latitude: origin[1] as! CLLocationDegrees, longitude: origin[0] as! CLLocationDegrees))
        routeWaypoints.append(originWaypoint)
      }

      if (waypoints.isEmpty == false) {
        for waypoint: [NSNumber] in waypoints {
          if (waypoint.isEmpty == false) {
            routeWaypoints.append(Waypoint(coordinate: CLLocationCoordinate2D(latitude: waypoint[1] as! CLLocationDegrees, longitude: waypoint[0] as! CLLocationDegrees)))
          }
        }
      }

      if (destination.isEmpty == false) {
        let destinationWaypoint = Waypoint(coordinate: CLLocationCoordinate2D(latitude: destination[1] as! CLLocationDegrees, longitude: destination[0] as! CLLocationDegrees))
        routeWaypoints.append(destinationWaypoint)
      }

      if (waypointStyles.isEmpty == false) {
        for waypointStyle: [String : Any] in waypointStyles {
          routeWaypointNames.append(((waypointStyle["name"]! as? NSString) ?? "") as String)
        }
      }

      fetchRoutes(routeWaypoints: routeWaypoints, routeWaypointNames: routeWaypointNames, onSuccess: {(routes: [Route]) -> Void in
          self.currentActiveRoutes = routes
          self.onRouteChange?(["distance": routes.first?.distance ?? 0, "expectedTravelTime": routes.first?.expectedTravelTime ?? 0, "typicalTravelTime": routes.first?.typicalTravelTime ?? 0])

          self.startActiveGuidance(updateCamera: false)
          self.follow(padding: padding)
      })
    }
  }

  @objc func pauseNavigation() {
    if (embedded == true) {
      clearActiveGuidance()
      clearMap()

      navigationMapView.navigationCamera.follow()
    }
  }

  @objc func stopNavigation() {
    if (embedded == true) {
      clearRouteAndStopActiveGuidance()
    }
  }
  
  @objc func didUpdatePassiveLocation(_ notification: Notification) {
    guard
      let location = notification.userInfo?[PassiveLocationManager.NotificationUserInfoKey.locationKey] as? CLLocation,
      let roadName = notification.userInfo?[PassiveLocationManager.NotificationUserInfoKey.roadNameKey] as? String
    else { return }
    
    speedLimitView?.signStandard = notification.userInfo?[PassiveLocationManager.NotificationUserInfoKey.signStandardKey] as? SignStandard
    speedLimitView?.speedLimit = notification.userInfo?[PassiveLocationManager.NotificationUserInfoKey.speedLimitKey] as? Measurement<UnitSpeed>
    speedLimitView?.currentSpeed = location.speed

    onLocationChange?(["longitude": location.coordinate.longitude, "latitude": location.coordinate.latitude, "roadName": roadName])
  }

  @objc func progressDidChange(_ notification: Notification) {
    guard
      let routeProgress = notification.userInfo?[RouteController.NotificationUserInfoKey.routeProgressKey] as? RouteProgress,
      let location = notification.userInfo?[RouteController.NotificationUserInfoKey.locationKey] as? CLLocation
    else { return }

    speedLimitView?.signStandard = notification.userInfo?[PassiveLocationManager.NotificationUserInfoKey.signStandardKey] as? SignStandard
    speedLimitView?.speedLimit = notification.userInfo?[PassiveLocationManager.NotificationUserInfoKey.speedLimitKey] as? Measurement<UnitSpeed>
    speedLimitView?.currentSpeed = location.speed

    // Add maneuver arrow
    if (routeProgress.currentLegProgress.followOnStep != nil) {
      navigationMapView.addArrow(route: routeProgress.route, legIndex: routeProgress.legIndex, stepIndex: routeProgress.currentLegProgress.stepIndex + 1)
    } else {
      navigationMapView.removeArrow()
    }
        
    if (routeProgress.legIndex != currentLegIndex) {
      navigationMapView.showWaypoints(on: routeProgress.route, legIndex: routeProgress.legIndex)
    }
        
    // Update the top banner with progress updates
    let distance = routeProgress.currentLegProgress.currentStepProgress.distanceRemaining
    let normalizedDistance = max(distance, 0)
    instructionsCardContainerView?.updateInstructionCard(distance: normalizedDistance, isCurrentCardStep: true)
    instructionsCardContainerView?.isHidden = false
        
    // Update `UserCourseView` to be placed on the most recent location.
    navigationMapView.moveUserLocation(to: location, animated: true)
        
    // Update the main route line during active navigation when `NavigationMapView.routeLineTracksTraversal` set to `true`
    // and route progress change, by calling `NavigationMapView.updateRouteLine(routeProgress:coordinate:shouldRedraw:)`
    // without redrawing the main route.
    navigationMapView.updateRouteLine(routeProgress: routeProgress, coordinate: location.coordinate, shouldRedraw: routeProgress.legIndex != currentLegIndex)
    currentLegIndex = routeProgress.legIndex
  }
  
  @objc func updateInstructionsBanner(notification: Notification) {
    guard let routeProgress = notification.userInfo?[RouteController.NotificationUserInfoKey.routeProgressKey] as? RouteProgress else {
      assertionFailure("RouteProgress should be available.")
    
      return
    }
        
    if let visualInstruction = routeProgress.currentLegProgress.currentStepProgress.currentVisualInstruction {
      instructionsCardContainerView?.updateInstruction(visualInstruction)
      instructionsCardContainerView?.isHidden = false
    }
  }
  
  @objc func rerouted(_ notification: Notification) {
    navigationMapView.removeWaypoints()
        
    // Update the main route line during active navigation when `NavigationMapView.routeLineTracksTraversal` set to `true`
    // and rerouting happens, by calling `NavigationMapView.updateRouteLine(routeProgress:coordinate:shouldRedraw:)`
    // with `shouldRedraw` as `true`.
    navigationMapView.updateRouteLine(
      routeProgress: navigationService.routeProgress,
      coordinate: navigationService.router.location?.coordinate,
      shouldRedraw: true
    )
  }
    
  @objc func refresh(_ notification: Notification) {
    // Update the main route line during active navigation when `NavigationMapView.routeLineTracksTraversal` set to `true`
    // and route refresh happens, by calling `NavigationMapView.updateRouteLine(routeProgress:coordinate:shouldRedraw:)`
    // with `shouldRedraw` as `true`.
    navigationMapView.updateRouteLine(
      routeProgress: navigationService.routeProgress,
      coordinate: navigationService.router.location?.coordinate,
      shouldRedraw: true
    )
  }

  @objc func navigationCameraStateDidChange(_ notification: Notification) {
    let navigationCameraState = notification.userInfo?[NavigationCamera.NotificationUserInfoKey.state] as? NavigationCameraState
    
    var stateStr: String = "idle"

    if (navigationCameraState != nil) {
      if (navigationCameraState == NavigationCameraState.transitionToFollowing) {
        stateStr = "transitionToFollowing"
      } else if (navigationCameraState == NavigationCameraState.following) {
        stateStr = "following"
      } else if (navigationCameraState == NavigationCameraState.transitionToOverview) {
        stateStr = "transitionToOverview"
      } else if (navigationCameraState == NavigationCameraState.overview) {
        stateStr = "overview"
      }
    }

    onTrackingStateChange?(["state": stateStr])
  }

  func getPadding(_ padding: [NSNumber]) -> UIEdgeInsets {
    let newPadding = UIEdgeInsets(
      top: padding.indices.contains(0) ? CGFloat(padding[0].floatValue) : (mapPadding.indices.contains(0) ? CGFloat(mapPadding[0].floatValue) : 0),
      left: padding.indices.contains(1) ? CGFloat(padding[1].floatValue) : (mapPadding.indices.contains(1) ? CGFloat(mapPadding[1].floatValue) : 0),
      bottom: padding.indices.contains(2) ? CGFloat(padding[2].floatValue) : (mapPadding.indices.contains(2) ? CGFloat(mapPadding[2].floatValue) : 0),
      right: padding.indices.contains(3) ? CGFloat(padding[3].floatValue) : (mapPadding.indices.contains(3) ? CGFloat(mapPadding[3].floatValue) : 0))

    return newPadding
  }

  func fetchRoutes(routeWaypoints: [Waypoint], routeWaypointNames: [String], onSuccess: @escaping (_ routes: [Route]) -> Void) {
    let options = NavigationRouteOptions(waypoints: routeWaypoints, profileIdentifier: .automobileAvoidingTraffic)
    options.includesAlternativeRoutes = true

    Directions.shared.calculate(options) { [weak self] (session, result) in
      switch result {
        case .failure(let error):
          self?.sendErrorToReact(error: error.localizedDescription)
        case .success(let response):
          guard let routes = response.routes, let strongSelf = self else {
            return
          }

          strongSelf.currentRouteResponse = response

          onSuccess(routes)
        }
      }
  }

  func previewRoutes(routes: [Route]) {
    pauseNavigation()

    currentPreviewRoutes = routes

    navigationMapView.showcase(routes)
    //navigationMapView.showRouteDurations(along: routes)
  }

  func startActiveGuidance(updateCamera: Bool) {
    currentPreviewRoutes = nil
    var response = currentRouteResponse

    if (response != nil) {
      let locationManager = NavigationLocationManager()
      navigationService = MapboxNavigationService(
        indexedRouteResponse: IndexedRouteResponse(routeResponse: response!, routeIndex: 0),
        credentials: NavigationSettings.shared.directions.credentials,
        locationSource: locationManager
      )

      let credentials = navigationService.credentials
      voiceController = RouteVoiceController(
        navigationService: navigationService,
        accessToken: credentials.accessToken,
        host: credentials.host.absoluteString
      )

      navigationService.start()

      navigationMapView.mapView.mapboxMap.onNext(event: .styleLoaded, handler: { [weak self] _ in
        guard let self = self else { return }
        
        self.navigationMapView.routeLineTracksTraversal = true

      let layerExists = self.navigationMapView.mapView.mapboxMap.style.layerExists(withId: "road-intersection")
          
          if (layerExists) {
          self.navigationMapView.show([self.navigationService.route], layerPosition: .below("road-intersection"), legIndex: 0)
        } else {
          self.navigationMapView.show([self.navigationService.route], legIndex: 0)
        }
      })

      let navigationViewportDataSource = NavigationViewportDataSource(navigationMapView.mapView, viewportDataSourceType: .active)
      navigationMapView.navigationCamera.viewportDataSource = navigationViewportDataSource

      NotificationCenter.default.addObserver(self, selector: #selector(progressDidChange(_ :)), name: .routeControllerProgressDidChange, object: nil)
      NotificationCenter.default.addObserver(self, selector: #selector(rerouted(_:)), name: .routeControllerDidReroute, object: nil)
      NotificationCenter.default.addObserver(self, selector: #selector(refresh(_:)), name: .routeControllerDidRefreshRoute, object: nil)
      NotificationCenter.default.addObserver(self, selector: #selector(updateInstructionsBanner(notification:)), name: .routeControllerDidPassVisualInstructionPoint, object: navigationService.router)

      NotificationCenter.default.removeObserver(self, name: .passiveLocationManagerDidUpdate, object: nil)
      passiveLocationProvider.stopUpdatingLocation()
      passiveLocationProvider.stopUpdatingHeading()

      navigationMapView.mapView.mapboxMap.onNext(event: .styleLoaded) { [weak self] _ in
        guard let self = self else { return }
        self.pointAnnotationManager = self.navigationMapView.mapView.annotations.makePointAnnotationManager()
      }

      if (updateCamera) {
        navigationMapView.navigationCamera.follow()
      }
    }
  }
  
  func clearRouteAndStopActiveGuidance() {
    // clear
    currentActiveRoutes = nil
    currentPreviewRoutes = nil
    currentRouteResponse = nil
    currentLegIndex = -1

    clearActiveGuidance()
    clearMap()

    moveToOverview(padding: [])
  }

  func clearActiveGuidance() {
    waypointStyles = []

    navigationService?.stop()

    navigationService = nil

    let navigationViewportDataSource = NavigationViewportDataSource(navigationMapView.mapView, viewportDataSourceType: .passive)

    navigationMapView.navigationCamera.viewportDataSource = navigationViewportDataSource

    instructionsCardContainerView?.isHidden = true

    NotificationCenter.default.removeObserver(self, name: .routeControllerProgressDidChange, object: nil)
    NotificationCenter.default.removeObserver(self, name: .routeControllerDidReroute, object: nil)
    NotificationCenter.default.removeObserver(self, name: .routeControllerDidRefreshRoute, object: nil)
    NotificationCenter.default.removeObserver(self, name: .routeControllerDidPassVisualInstructionPoint, object: nil)

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(didUpdatePassiveLocation),
      name: .passiveLocationManagerDidUpdate,
      object: nil
    )

    passiveLocationProvider.startUpdatingLocation()
    passiveLocationProvider.startUpdatingHeading()
  }

  func clearMap() {
    navigationMapView.unhighlightBuildings()
    navigationMapView.removeRoutes()
    navigationMapView.removeRouteDurations()
    navigationMapView.removeWaypoints()
  }

  func sendErrorToReact(error: String) {
    onError?(["message": error])
  }

  override init(frame: CGRect) {
    self.embedded = false
    self.embedding = false
    super.init(frame: frame)
  }
  
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    if (!embedding && !embedded) {
      embed()
    } else {
      navigationMapView.frame = bounds
    }
  }
  
  override func removeFromSuperview() {
    super.removeFromSuperview()
    // cleanup and teardown any existing resources
    NotificationCenter.default.removeObserver(self, name: .passiveLocationManagerDidUpdate, object: nil)
    NotificationCenter.default.removeObserver(self, name: .navigationCameraStateDidChange, object: navigationMapView.navigationCamera)
    NotificationCenter.default.removeObserver(self, name: .routeControllerProgressDidChange, object: nil)
    NotificationCenter.default.removeObserver(self, name: .routeControllerDidReroute, object: nil)
    NotificationCenter.default.removeObserver(self, name: .routeControllerDidRefreshRoute, object: nil)
    NotificationCenter.default.removeObserver(self, name: .routeControllerDidPassVisualInstructionPoint, object: nil)
    passiveLocationProvider?.stopUpdatingLocation()
    passiveLocationProvider?.stopUpdatingHeading()
    navigationMapView?.removeFromSuperview()
    speedLimitView?.removeFromSuperview()
  }

  private func embed() {
    guard let parentVC = parentViewController else {
      return
    }

    embedding = true

    navigationMapView = NavigationMapView(frame: bounds)
    navigationMapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    navigationMapView.delegate = self

    navigationMapView.routeLineTracksTraversal = true
    navigationMapView.showsCongestionForAlternativeRoutes = true
    navigationMapView.showsRestrictedAreasOnRoute = true
    navigationMapView.routeCasingColor = UIColor(hex: routeCasingColor as String)
    navigationMapView.routeAlternateColor = UIColor(hex: alternateRouteColor as String)
    navigationMapView.routeAlternateCasingColor = UIColor(hex: alternateRouteCasingColor as String)

    if (traversedRouteColor != nil) {
      navigationMapView.traversedRouteColor = UIColor(hex: traversedRouteColor! as String)
    } else {
      navigationMapView.traversedRouteColor = UIColor.clear
    }

    navigationMapView.trafficUnknownColor = UIColor(hex: trafficUnknownColor as String)
    navigationMapView.trafficLowColor = UIColor(hex: trafficLowColor as String)
    navigationMapView.trafficModerateColor = UIColor(hex: trafficModerateColor as String)
    navigationMapView.trafficHeavyColor = UIColor(hex: trafficHeavyColor as String)
    navigationMapView.trafficSevereColor = UIColor(hex: trafficSevereColor as String)
    navigationMapView.routeRestrictedAreaColor = UIColor(hex: restrictedRoadColor as String)
    navigationMapView.maneuverArrowColor = UIColor(hex: routeArrowColor as String)
    navigationMapView.maneuverArrowStrokeColor = UIColor(hex: routeArrowCasingColor as String)

    if (darkMode) {
      navigationMapView.mapView.mapboxMap.loadStyleURI(StyleURI.dark)
    } else {
      navigationMapView.mapView.mapboxMap.loadStyleURI(StyleURI.light)
    }

    navigationMapView.mapView.ornaments.options.compass.visibility = .hidden
    navigationMapView.mapView.ornaments.options.scaleBar.visibility = .hidden
    navigationMapView.mapView.gestures.options.rotateEnabled = false
    navigationMapView.mapView.gestures.options.pinchPanEnabled = false
    navigationMapView.mapView.gestures.options.pitchEnabled = false

    var puck2DConfiguration = Puck2DConfiguration()
    if (userPuckImage != nil) {
      puck2DConfiguration.topImage = userPuckImage
      puck2DConfiguration.scale = .constant(Double(exactly: userPuckScale)!)
    }
    navigationMapView.userLocationStyle = UserLocationStyle.puck2D(configuration: puck2DConfiguration)

    let navigationViewportDataSource = NavigationViewportDataSource(navigationMapView.mapView, viewportDataSourceType: .raw)
    navigationViewportDataSource.followingMobileCamera.padding = getPadding([])
    navigationViewportDataSource.overviewMobileCamera.padding = getPadding([])

    navigationMapView.navigationCamera.viewportDataSource = navigationViewportDataSource

    navigationMapView.navigationCamera.follow()

    addSubview(navigationMapView)

    instructionsCardContainerView = InstructionsCardContainerView()
    
    instructionsCardContainerView.translatesAutoresizingMaskIntoConstraints = false
    instructionsCardContainerView.isHidden = true
    instructionsCardContainerView.customBackgroundColor = UIColor(hex: "#303030")
    instructionsCardContainerView.highlightedBackgroundColor = UIColor(hex: "#303030")
    instructionsCardContainerView.separatorColor = UIColor(hex: "#707070")
    instructionsCardContainerView.highlightedSeparatorColor = UIColor(hex: "#707070")
    instructionsCardContainerView.cornerRadius = 26.0
    instructionsCardContainerView.layer.masksToBounds = true

    speedLimitView = SpeedLimitView()

    speedLimitView.shouldShowUnknownSpeedLimit = true
    speedLimitView.translatesAutoresizingMaskIntoConstraints = false
        
    if (showSpeedLimit == true) {
      showSpeedLimitView()
    } else {
      hideSpeedLimitView()
    }
      
    let stackView = UIStackView(arrangedSubviews: [instructionsCardContainerView, speedLimitView])
    stackView.axis = .vertical
    stackView.distribution = .fill
    stackView.alignment = .leading
    stackView.spacing = 10
    stackView.translatesAutoresizingMaskIntoConstraints = false
      
    addSubview(stackView)
      
    stackView.topAnchor.constraint(equalTo: self.topAnchor, constant: 0).isActive = true
    stackView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 0).isActive = true
    stackView.widthAnchor.constraint(equalTo: self.widthAnchor).isActive = true
    instructionsCardContainerView.topAnchor.constraint(equalTo: stackView.topAnchor, constant: 20.0).isActive = true
    instructionsCardContainerView.leadingAnchor.constraint(equalTo: stackView.leadingAnchor, constant: 20.0).isActive = true
    instructionsCardContainerView.trailingAnchor.constraint(equalTo: stackView.trailingAnchor, constant: -20.0).isActive = true
    speedLimitView.leadingAnchor.constraint(equalTo: stackView.leadingAnchor, constant: 10.0).isActive = true
      
    setLogoPadding()
    setAttributionPadding()

    //passiveLocationManager = PassiveLocationManager()
    //passiveLocationProvider = PassiveLocationProvider(locationManager: passiveLocationManager)
    //let locationProvider: LocationProvider = passiveLocationProvider

    //navigationMapView.mapView.location.overrideLocationProvider(with: locationProvider)
    
    //passiveLocationProvider.startUpdatingLocation()

    //NotificationCenter.default.addObserver(
      //self,
      //selector: #selector(didUpdatePassiveLocation),
      //name: .passiveLocationManagerDidUpdate,
      //object: nil
    //)

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(navigationCameraStateDidChange),
      name: .navigationCameraStateDidChange,
      object: navigationMapView.navigationCamera
    )

    embedding = false
    embedded = true
  }

  func showSpeedLimitView() {
    speedLimitView.isAlwaysHidden = false
    speedLimitView.isHidden = false

    speedLimitView.widthAnchor.constraint(equalToConstant: speedLimitAnchor.indices.contains(2) ? CGFloat(speedLimitAnchor[2].floatValue) : 50).isActive = true
    speedLimitView.heightAnchor.constraint(equalToConstant: speedLimitAnchor.indices.contains(3) ? CGFloat(speedLimitAnchor[3].floatValue) : 50).isActive = true
  }

  func hideSpeedLimitView() {
    speedLimitView.isAlwaysHidden = true
    speedLimitView.isHidden = true
  }

  func setLogoPadding() {
    if (logoVisible) {
      navigationMapView.mapView.ornaments.options.logo.margins = CGPoint(
        x: logoPadding.indices.contains(0) ? CGFloat(logoPadding[0].floatValue) : 8.0,
        y: logoPadding.indices.contains(1) ? CGFloat(logoPadding[1].floatValue) : 8.0
      )
      navigationMapView.mapView.ornaments.logoView.isHidden = false
    } else {
      navigationMapView.mapView.ornaments.logoView.isHidden = true
    }
  }

  func setAttributionPadding() {
    if (attributionVisible) {
      navigationMapView.mapView.ornaments.options.attributionButton.margins = CGPoint(
        x: attributionPadding.indices.contains(0) ? CGFloat(attributionPadding[0].floatValue) : 8.0,
        y: attributionPadding.indices.contains(1) ? CGFloat(attributionPadding[1].floatValue) : 8.0
      )
      navigationMapView.mapView.ornaments.attributionButton.isHidden = false
    } else {
      navigationMapView.mapView.ornaments.attributionButton.isHidden = true
    }
  }

  func navigationMapView(_ navigationMapView: NavigationMapView, didAdd finalDestinationAnnotation: PointAnnotation, pointAnnotationManager: PointAnnotationManager) {
    var finalDestinationAnnotation = finalDestinationAnnotation

    if (destinationImage != nil) {
      finalDestinationAnnotation.image = .init(image: destinationImage!, name: "marker")
    } else {
      let image = UIImage(named: "default_marker", in: .mapboxNavigation, compatibleWith: nil)!
      finalDestinationAnnotation.image = .init(image: image, name: "marker")
    }
 
    // `PointAnnotationManager` is used to manage `PointAnnotation`s and is also exposed as
    // a property in `NavigationMapView.pointAnnotationManager`. After any modifications to the
    // `PointAnnotation` changes must be applied to `PointAnnotationManager.annotations`
    // array. To remove all annotations for specific `PointAnnotationManager`, set an empty array.
    pointAnnotationManager.annotations = [finalDestinationAnnotation]
  }

  func navigationMapView(_ navigationMapView: NavigationMapView, waypointCircleLayerWithIdentifier identifier: String, sourceIdentifier: String) -> CircleLayer? {
    var circleLayer = CircleLayer(id: identifier)
    circleLayer.source = sourceIdentifier
    let opacity = Exp(.switchCase) {
      Exp(.any) {
        Exp(.get) {
          "waypointCompleted"
        }
      }
      0.6
      Exp(.toNumber) {
        Exp(.get) {
          "opacity"
        }
      }
    }
    let color = Exp(.toColor) {
      Exp(.get) {
        "color"
      }
    }
    let radius = Exp(.toNumber) {
      Exp(.get) {
        "radius"
      }
    }
    let strokeColor = Exp(.toColor) {
      Exp(.get) {
        "strokeColor"
      }
    }
    let strokeOpacity = Exp(.switchCase) {
      Exp(.any) {
        Exp(.get) {
          "waypointCompleted"
        }
      }
      0.6
      Exp(.toNumber) {
        Exp(.get) {
          "strokeOpacity"
        }
      }
    }
    let strokeWidth = Exp(.toNumber) {
      Exp(.get) {
        "strokeWidth"
      }
    }
    circleLayer.circleColor = .expression(color)
    circleLayer.circleOpacity = .expression(opacity)
    circleLayer.circleRadius = .expression(radius)
    circleLayer.circleStrokeColor = .expression(strokeColor)
    circleLayer.circleStrokeOpacity = .expression(strokeOpacity)
    circleLayer.circleStrokeWidth = .expression(strokeWidth)

    return circleLayer
  }
 
  func navigationMapView(_ navigationMapView: NavigationMapView, waypointSymbolLayerWithIdentifier identifier: String, sourceIdentifier: String) -> SymbolLayer? {
    var symbolLayer = SymbolLayer(id: identifier)
    symbolLayer.source = sourceIdentifier
    symbolLayer.textOpacity = .expression(Exp(.switchCase) {
      Exp(.any) {
        Exp(.get) {
          "waypointCompleted"
        }
      }
      0
      0
    })
    
    return symbolLayer
  }

  func navigationMapView(_ navigationMapView: NavigationMapView, shapeFor waypoints: [Waypoint], legIndex: Int) -> FeatureCollection? {
    var features = [Turf.Feature]()
    
    for (waypointIndex, waypoint) in waypoints.enumerated() {
      var feature = Feature(geometry: .point(Point(waypoint.coordinate)))
      feature.properties = [
        "waypointCompleted": .boolean(waypointIndex < legIndex),
        "color": .string(
          ((waypointStyles.indices.contains(waypointIndex) && waypointStyles[waypointIndex]["color"] != nil)
            ? ((waypointStyles[waypointIndex]["color"]! as? NSString) ?? waypointColor)
            : waypointColor) as String),
        "radius": .number(
          Double(exactly: (waypointStyles.indices.contains(waypointIndex) && waypointStyles[waypointIndex]["radius"] != nil)
            ? ((waypointStyles[waypointIndex]["radius"]! as? NSNumber) ?? waypointRadius)
            : waypointRadius)!),
        "opacity": .number(
          Double(exactly: (waypointStyles.indices.contains(waypointIndex) && waypointStyles[waypointIndex]["opacity"] != nil)
            ? ((waypointStyles[waypointIndex]["opacity"]! as? NSNumber) ?? waypointOpacity)
            : waypointOpacity)!),
        "strokeColor": .string(
          ((waypointStyles.indices.contains(waypointIndex) && waypointStyles[waypointIndex]["strokeColor"] != nil)
            ? ((waypointStyles[waypointIndex]["strokeColor"]! as? NSString) ?? waypointStrokeColor)
            : waypointStrokeColor) as String),
        "strokeWidth": .number(
          Double(exactly: (waypointStyles.indices.contains(waypointIndex) && waypointStyles[waypointIndex]["strokeWidth"] != nil)
            ? ((waypointStyles[waypointIndex]["strokeWidth"]! as? NSNumber) ?? waypointStrokeWidth)
            : waypointStrokeWidth)!),
        "strokeOpacity": .number(
          Double(exactly: (waypointStyles.indices.contains(waypointIndex) && waypointStyles[waypointIndex]["strokeOpacity"] != nil)
            ? ((waypointStyles[waypointIndex]["strokeOpacity"]! as? NSNumber) ?? waypointStrokeOpacity)
            : waypointStrokeOpacity)!),
        "name": .number(Double(waypointIndex + 1))
      ]
      features.append(feature)
    }

    return FeatureCollection(features: features)
  }
}

extension UIColor {
  convenience init(hex: String) {
    let hexString: String = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var int: UInt64 = UInt64()
    Scanner(string: hexString).scanHexInt64(&int)
    let a, r, g, b: UInt64
    switch hexString.count {
    case 3: // RGB (12-bit)
      (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
    case 6: // RGB (24-bit)
      (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
    case 8: // ARGB (32-bit)
      (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
    default:
      (a, r, g, b) = (255, 0, 0, 0)
    }
    self.init(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
  }

  var RGBAString: String {
    var red: CGFloat = 0.0
    var green: CGFloat = 0.0
    var blue: CGFloat = 0.0
    var alpha: CGFloat = 0.0

    guard self.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
      return "rgba(0,0,0,1)"
    }
    
    return "rgba(\(Double(red * 255)),\(Double(green * 255)),\(Double(blue * 255)),\(Double(alpha)))"
  }
}
