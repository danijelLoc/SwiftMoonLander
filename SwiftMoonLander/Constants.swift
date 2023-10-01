//
// Created by Danijel on 22.11.2022..
//

import Foundation

public let meterToPointFactor: Float = 10.0 // one meter is 10 points
public let moonLanderRealWorldHeight: Float = 5.5 // in m
public let moonLanderRealWorldWidth: Float = 5.5 // in m

public var moonLanderHeight: Float { moonLanderRealWorldHeight * meterToPointFactor }
public var moonLanderWidth: Float { moonLanderRealWorldWidth * meterToPointFactor }

public let moonGravitationalAcceleration: SIMD2<Float> = .init(x: 0, y: -1.62) // in m/s**2
public let moonLanderMass: Float = 5103.0 // in kg (launch mass) // TODO: Add fuel reduction
public let moonLanderMaxThrust: Float = 16000.0 // in N
public let moonLanderRotationPerSecond: Float = (70.0 / 180) * Float.pi // in radians
public let moonSurfaceElevationHeight: Float = 200.0 // in points, used for UI
