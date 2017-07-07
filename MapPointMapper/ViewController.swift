//
//  ViewController.swift
//  MapPointMapper
//
//  Created by Daniel on 11/18/14.
//  Copyright (c) 2014 dmiedema. All rights reserved.
//

import Cocoa
import MapKit

class ViewController: NSViewController, MKMapViewDelegate, NSTextFieldDelegate {
  // MARK: - Properties
  // MARK: Buttons
  @IBOutlet weak var loadFileButton: NSButton!
  @IBOutlet weak var removeLastLineButton: NSButton!
  @IBOutlet weak var removeAllLinesButton: NSButton!
  @IBOutlet weak var addLineFromTextButton: NSButton!
  @IBOutlet weak var switchLatLngButton: NSButton!
  @IBOutlet weak var centerUSButton: NSButton!
  @IBOutlet weak var centerAllLinesButton: NSButton!
  @IBOutlet weak var colorWell: NSColorWell!
  // MARK: Views
  @IBOutlet weak var mapview: MKMapView!
  @IBOutlet weak var textfield: NSTextField!
  @IBOutlet weak var latlngLabel: NSTextField!
  @IBOutlet weak var searchfield: NSTextField!

  var parseLongitudeFirst = false
  // MARK: - Methods
  // MARK: View life cycle
  override func viewDidLoad() {
    super.viewDidLoad()
    mapview.delegate = self
    textfield.delegate = self
  }

  // MARK: Actions
  @IBAction func loadFileButtonPressed(_ sender: NSButton!) {
    let openPanel = NSOpenPanel()
    openPanel.canChooseDirectories = false
    
    openPanel.beginSheetModal(for: NSApplication.shared().keyWindow!, completionHandler: { (result) -> Void in
      self.readFileAtURL(openPanel.url)
    })
  }

  @IBAction func addLineFromTextPressed(_ sender: NSObject) {
    if textfield.stringValue.isEmpty { return }
    if renderInput(textfield.stringValue as NSString) {
      textfield.stringValue = ""
    } else {
      // TODO: dont wipe out string field and stop event from propagating!
      textfield.stringValue = ""
    }
  }
  
  @IBAction func removeLastLinePressed(_ sender: NSButton) {
    if let overlay: AnyObject = mapview.overlays.last {
      mapview.remove(overlay as! MKOverlay)
    }
  }
  
  @IBAction func removeAllLinesPressed(_ sender: NSButton) {
    mapview.removeOverlays(mapview.overlays)
  }
  
  @IBAction func switchLatLngPressed(_ sender: NSButton) {
    parseLongitudeFirst = !parseLongitudeFirst
    if self.parseLongitudeFirst {
      self.latlngLabel.stringValue = "Lng/Lat"
    } else {
      self.latlngLabel.stringValue = "Lat/Lng"
    }
  }
  
  @IBAction func centerUSPressed(_ sender: NSButton) {
    let centerUS = CLLocationCoordinate2D(
      latitude: 37.09024,
      longitude: -95.712891
    )
    let northeastUS = CLLocationCoordinate2D(
      latitude: 49.38,
      longitude: -66.94
    )
    let southwestUS = CLLocationCoordinate2D(
      latitude: 25.82,
      longitude: -124.39
    )
    let latDelta = northeastUS.latitude - southwestUS.latitude
    let lngDelta = northeastUS.longitude - southwestUS.longitude
    let span = MKCoordinateSpanMake(latDelta, lngDelta)

    let usRegion = MKCoordinateRegion(center: centerUS, span: span)
    mapview.setRegion(usRegion, animated: true)
  }

  @IBAction func centerAllLinesPressed(_ sender: NSButton) {
    let polylines = mapview.overlays as [MKOverlay]
    let boundingMapRect = boundingMapRectForPolylines(polylines)
    mapview.setVisibleMapRect(boundingMapRect, edgePadding: EdgeInsets(top: 10, left: 10, bottom: 10, right: 10), animated: true)
  }
  
  // MARK: MKMapDelegate
  func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
    let renderer = MKPolylineRenderer(overlay: overlay)
    renderer.alpha = 1.0
    renderer.lineWidth = 4.0
    renderer.strokeColor = colorWell.color
    return renderer
  }

  @IBAction func searchForLocation(_ sender: NSObject) {
    if searchfield.stringValue.isEmpty { return }
    renderLocationSearch(searchfield.stringValue)
    searchfield.stringValue = ""
  }


  fileprivate func renderLocationSearch(_ input: String) {
    let geocoder = CLGeocoder()
    geocoder.geocodeAddressString(input) { (placemarks, errors) in
      guard let placemark = placemarks?.first,
            let center = placemark.location?.coordinate else {
        print(errors ?? "")
        return
      }

      let region = MKCoordinateRegion(center: center,
          span: MKCoordinateSpan(latitudeDelta: 0.8, longitudeDelta: 0.8))
      self.mapview.setRegion(region, animated: true)
    }
  }

  // MARK: - Private

  /**
  Create an `MKOverlay` for a given array of `CLLocationCoordinate2D` instances

  - parameter mapPoints: array of `CLLocationCoordinate2D` instances to convert

  - returns: an MKOverlay created from array of `CLLocationCoordinate2D` instances
  */
  fileprivate func createPolylineForCoordinates(_ mapPoints: [CLLocationCoordinate2D]) -> MKOverlay {
    let coordinates = UnsafeMutablePointer<CLLocationCoordinate2D>.allocate(capacity: mapPoints.count)
    
    var count: Int = 0
    for coordinate in mapPoints {
      coordinates[count] = coordinate
      count += 1
    }
    
    let polyline = MKPolyline(coordinates: coordinates, count: count)
    
    free(coordinates)
    
    return polyline
  }

  /**
  Get the bounding `MKMapRect` that contains all given `MKOverlay` objects

  - warning: If no `MKOverlay` objects are included the resulting `MKMapRect` will be nonsensical and will results in a warning.
  
  - parameter polylines: array of `MKOverlay` objects.

  - returns: an `MKMapRect` that contains all the given `MKOverlay` objects
  */
  fileprivate func boundingMapRectForPolylines(_ polylines: [MKOverlay]) -> MKMapRect {
    var minX = Double.infinity
    var minY = Double.infinity
    var maxX = Double(0)
    var maxY = Double(0)
    
    for line in polylines {
      minX   = (line.boundingMapRect.origin.x < minX)      ? line.boundingMapRect.origin.x    : minX
      minY   = (line.boundingMapRect.origin.y < minY)      ? line.boundingMapRect.origin.y    : minY
      
      let width  = line.boundingMapRect.origin.x + line.boundingMapRect.size.width
      maxX = (width > maxX) ? width : maxX
      
      let height = line.boundingMapRect.origin.y + line.boundingMapRect.size.height
      maxY = (height > maxY) ? height : maxY
    }
    
    let mapWidth  = maxX - minX
    let mapHeight = maxY - minY
    
    return MKMapRect(origin: MKMapPoint(x: minX, y: minY), size: MKMapSize(width: mapWidth, height: mapHeight))
  }

  /**
  Read a given file at a url

  - parameter passedURL: `NSURL` to attempt to read
  */
  fileprivate func readFileAtURL(_ passedURL: URL?) {
    guard let url = passedURL else { return }

    do {
      let contents = try NSString(contentsOf: url, encoding: String.Encoding.utf8.rawValue) as String
      renderInput(contents as NSString)
    } catch {
      NSAlert(error: error as NSError).runModal()
    }
  } // end readFileAtURL

  fileprivate func randomizeColorWell() {
    colorWell.color = NSColor.randomColor()
  }

  fileprivate func renderInput(_ input: NSString) -> Bool {
    if parseInput(input) {
      randomizeColorWell()
      return true
    } else {
      return false
    }
  }

  /**
  Parse the given input.

  - parameter input: `NSString` to parse and draw on the map. If no string is given this is essentially a noop

  - warning: If invalid WKT input string, will result in `NSAlert()` and false return

  - returns: `Bool` on render success
  */
  fileprivate func parseInput(_ input: NSString) -> Bool {
    var coordinates = [[CLLocationCoordinate2D]()]

    do {
      coordinates = try Parser.parseString(input, longitudeFirst: parseLongitudeFirst).filter({!$0.isEmpty})
    } catch ParseError.invalidWktString {
      let error_msg = NSError(domain:String(), code:-1, userInfo:
        [NSLocalizedDescriptionKey: "Invalid WKT input string, unable to parse"])
      NSAlert(error: error_msg).runModal()
      return false
    } catch {
      NSAlert(error: error as NSError).runModal()
      return false
    }

    var polylines = [MKOverlay]()
    for coordinateSet in coordinates {
      let polyline = createPolylineForCoordinates(coordinateSet)
      mapview.add(polyline, level: .aboveRoads)
      polylines.append(polyline)
    }

    if !polylines.isEmpty {
      let boundingMapRect = boundingMapRectForPolylines(polylines)
      mapview.setVisibleMapRect(boundingMapRect, edgePadding: EdgeInsets(top: 10, left: 10, bottom: 10, right: 10), animated: true)
    }
    return true
  }
}

