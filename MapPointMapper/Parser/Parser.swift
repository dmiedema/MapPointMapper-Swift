//
//  Parser.swift
//  MapPointMapper
//
//  Created by Daniel on 11/20/14.
//  Copyright (c) 2014 dmiedema. All rights reserved.
//

import Foundation
import MapKit

extension NSString {
  /**
  Convenience so `isEmpty` can be performed on an `NSString` instance just as if it were a `String`
  
  - returns: `true` if the string is empty, `false` if not
  */
  var isEmpty: Bool {
    get { return self.length == 0 || self.isEqual(to: "") }
  }
}
extension String {
  /**
  Strip all leading and trailing whitespace from a given `String` instance.
  
  - returns: a newly stripped string instance.
  */
  func stringByStrippingLeadingAndTrailingWhiteSpace() -> String {
    let mutable = self.mutableCopy() as! NSMutableString
    CFStringTrimWhitespace(mutable)
    return mutable.copy() as! String
  }
}

enum ParseError : Error {
  case invalidWktString(description: String)
}

class Parser {
  // MARK: - Public
  /**
  Parse a given string of Lat/Lng values to return a collection of `CLLocationCoordinate2D` arrays.

  - note: The preferred way/format of the input string is `Well-Known Text` as the parser supports that for multipolygons and such

  - parameter input:          String to parse
  - parameter longitudeFirst: Only used if it is determined to not be `Well-Known Text` format.

  - returns: An array of `CLLocationCoordinate2D` arrays representing the parsed areas/lines
  */
  class func parseString(_ input: NSString, longitudeFirst: Bool) throws -> [[CLLocationCoordinate2D]] {
    let coordinate_set = Parser(longitudeFirst: longitudeFirst).parseInput(input)

    guard coordinate_set.count > 0 else {
      throw ParseError.invalidWktString(description: "Unable to parse input string")
    }

    return coordinate_set
  }

  var longitudeFirst = false
  convenience init(longitudeFirst: Bool) {
    self.init()
    self.longitudeFirst = longitudeFirst
  }
  init() {}
  
  // MARK: - Private
  
  // MARK: Parsing

  /**
  Parse input string into a collection of `CLLocationCoordinate2D` arrays that can be drawn on a map

  - note: This method supports (and really works best with/prefers) `Well-Known Text` format

  - parameter input: `NSString` to parse

  - returns: Collection of `CLLocationCoordinate2D` arrays
  */
  internal func parseInput(_ input: NSString) ->  [[CLLocationCoordinate2D]] {
    var array = [[NSString]]()
    
    let line = input as String

    if isProbablyGeoString(line) {
      self.longitudeFirst = true
      var items = [NSString]()
      
      if isMultiItem(line) {
        items = stripExtraneousCharacters(line as NSString).components(separatedBy: "),")
      } else {
        items = [stripExtraneousCharacters(line as NSString)]
      }
      
      array = items.map({ self.formatStandardGeoDataString($0) })
    }

    let results = convertStringArraysToTuples(array)
    
    return results.filter({ !$0.isEmpty }).map{ self.convertToCoordinates($0, longitudeFirst: self.longitudeFirst) }
  }

  /**
  Convert an array of strings into tuple pairs.
  
  - note: the number of values passed in should probably be even, since it creates pairs.

  - parameter array: of `[NSString]` array to create tuples from

  - returns: array of collections of tuple pairs where the tuples are lat/lng values as `NSString`s
  */
  internal func convertStringArraysToTuples(_ array: [[NSString]]) -> [[(NSString, NSString)]] {
    var tmpResults = [(NSString, NSString)]()
    var results = [[(NSString, NSString)]]()
    for arr in array {
      for i in stride(from: 0, to: arr.count - 1, by: 2) {
        let elem = (arr[i], arr[i + 1])
        tmpResults.append(elem)
      }
      
      if tmpResults.count == 1 {
        tmpResults.append(tmpResults.first!)
      }
      
      results.append(tmpResults)
      tmpResults.removeAll(keepingCapacity: false)
    } // end for arr in array
    return results
  }

  /**
  _abstract_: Naively format a `Well-Known Text` string into array of string values, where each string is a single value
  
  _discussion_: This removes any lingering parens from the given string, breaks on `,` then breaks on ` ` while filtering out any empty strings.

  - parameter input: String to format, assumed `Well-Known Text` format

  - returns: array of strings where each string is one value from the string with all empty strings filtered out.
  */
  internal func formatStandardGeoDataString(_ input: NSString) -> [NSString] {
    // Remove Extra ()
    let stripped = input
      .replacingOccurrences(of: "(", with: "")
      .replacingOccurrences(of: ")", with: "")
    
    // Break on ',' to get pairs separated by ' '
    let pairs = stripped.components(separatedBy: ",")
    
    // break on " " and remove empties
    var filtered = [NSString]()
    
    for pair in pairs {
      pair.components(separatedBy: " ").filter({!$0.isEmpty}).forEach({filtered.append($0 as NSString)})
    }
    
    return filtered.filter({!$0.isEmpty})
  }
  
  fileprivate func formatCustomLatLongString(_ input: NSString) -> [NSString] {
    return input.replacingOccurrences(of: "\n", with: ",").components(separatedBy: ",") as [NSString]
  }
  
  fileprivate func splitLine(_ input: NSString, delimiter: NSString) -> (NSString, NSString) {
    let array = input.components(separatedBy: delimiter as String)
    return (array.first! as NSString, array.last! as NSString)
  }
  
  /**
  :abstract: Convert a given array of `(String, String)` tuples to array of `CLLocationCoordinate2D` values
  
  :discussion: This attempts to parse the string's double values but does no safety checks if they can be parsed as `double`s.

  - parameter pairs:          array of `String` tuples to parse as `Double`s
  - parameter longitudeFirst: boolean flag if the first item in the tuple should be the longitude value

  - returns: array of `CLLocationCoordinate2D` values
  */
  internal func convertToCoordinates(_ pairs: [(NSString, NSString)], longitudeFirst: Bool) -> [CLLocationCoordinate2D] {
    var coordinates = [CLLocationCoordinate2D]()
    for pair in pairs {
      var lat: Double = 0.0
      var lng: Double = 0.0
      if longitudeFirst {
        lat = pair.1.doubleValue
        lng = pair.0.doubleValue
      } else {
        lat = pair.0.doubleValue
        lng = pair.1.doubleValue
      }
      coordinates.append(CLLocationCoordinate2D(latitude: lat, longitude: lng))
    }
    return coordinates
  }

  /**
  Removes any text before lat long points as well as two outer sets of parens.
  
  Example:
  ```
  input  => "POLYGON(( 15 32 ))"
  output => "15 32"

  input  => "MULTIPOLYGON((( 15 32 )))"
  output => "( 15 32 )"
  ```
  
  - parameter input: NSString to strip extraneous characters from

  - returns: stripped string instance
  */
  internal func stripExtraneousCharacters(_ input: NSString) -> NSString {
    let regex: NSRegularExpression?
    do {
      regex = try NSRegularExpression(pattern: "\\w+\\s*\\((.*)\\)", options: .caseInsensitive)
    } catch _ {
      regex = nil
    }
    let match: AnyObject? = regex?.matches(in: input as String, options: .reportCompletion, range: NSMakeRange(0, input.length)).first
    let range = match?.rangeAt(1)

    let loc = range?.location as Int!
    let len = range?.length as Int!
    
    guard loc != nil && len != nil else { return "" }

    return input.substring(with: NSRange(location: loc!, length: len!)) as NSString
  }

  /**
  _abstract_: Attempt to determine if a given string is in `Well-Known Text` format (GeoString as its referred to internally)

  _discussion_: This strips any leading & trailing white space before checking for the existance of word characters at the start of the string.

  - parameter input: String to attempt determine if is in `Well-Known Text` format

  - returns: `true` if it thinks it is, `false` otherwise
  */
  internal func isProbablyGeoString(_ input: String) -> Bool {
    let stripped = input.stringByStrippingLeadingAndTrailingWhiteSpace()
    if stripped.range(of: "^\\w+", options: .regularExpression) != nil {
      return true
    }
    return false
  }

  /**
  Determine if a given string is a `MULTI*` item.

  - parameter input: String to check

  - returns: `true` if the string starts with `MULTI`. `false` otherwise
  */
  internal func isMultiItem(_ input: String) -> Bool {
    if input.range(of: "MULTI", options: .regularExpression) != nil {
      return true
    }
    return false
  }

  /**
  Determines if a the collection is space delimited or not
  
  - note: This function should only be passed a single entry or else it will probably have incorrect results
  
  - parameter input: a single entry from the collection as a string
  
  - returns: `true` if elements are space delimited, `false` otherwise
  */
  fileprivate func isSpaceDelimited(_ input: String) -> Bool {
    let array = input.components(separatedBy: " ")
    return array.count > 1
  }
}
