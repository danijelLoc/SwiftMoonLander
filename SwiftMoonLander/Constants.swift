//
// Created by Danijel on 22.11.2022..
//

import Foundation

public let moonLanderHeight = 55.0, moonLanderWidth = 55.0 // in points, used for UI
public let moonLanderRealWorldHeight = 5.5 // in m
public let meterToPointFactor = moonLanderHeight / moonLanderRealWorldHeight

public let moonGravitationalAcceleration: SIMD2<Double> = .init(x: 0, y: -1.62) // in m/s**2
public let moonLanderMass = 7103.0 // in kg (launch mass) // TODO: FIX to real value and add fuel reduction
public let moonLanderMaxThrust = 16000.0 // in N
public let moonLanderRotationPerSecond = (45.0 / 180) * Double.pi // in radians TODO: change closer to real world value from NASA
public let moonSurfaceElevationHeight = 200.0 // in points, used for UI
