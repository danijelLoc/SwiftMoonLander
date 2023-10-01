//
//  ViewController.swift
//  SwiftMoonLander
//
//  Created by Danijel on 21.11.2022..
//

import UIKit
import RxSwift
import RxCocoa
import RxGesture
import RxRelay

enum RotationControlDirection: Int {
    case left = 1
    case straight = 0
    case right = -1
}

class GameViewController: UIViewController {
    let moonLander = UIImageView(image: UIImage(systemName: "rectangle.roundedtop.fill"))
    let moonSurface = UIView()
    let leftArrow = UIImageView(image: UIImage(systemName: "arrowtriangle.left.circle.fill"))
    let rightArrow = UIImageView(image: UIImage(systemName: "arrowtriangle.right.circle.fill"))
    let engineThrustArrow = UIImageView(image: UIImage(systemName: "flame.circle.fill"))

    let frameRateLabel = UILabel()
    let moonLanderAngleLabel = UILabel()
    let moonLanderVelocityLabel = UILabel()
    let moonLanderAccelerationLabel = UILabel()
    let infoStackView = UIStackView()

    private var moonLanderAngle = BehaviorRelay<Float>(value: Float.pi / 2) // in radians
    private var moonLanderAcceleration = BehaviorRelay<SIMD2<Float>>(
        value: moonGravitationalAcceleration) // in m/s**2
    private var moonLanderVelocity = BehaviorRelay<SIMD2<Float>>(
            value: .init(x: 0, y: 0)) // in m/s
    private var moonLanderPosition = BehaviorRelay<SIMD2<Float>>(value: .init(x: 200, y: 200))
    
    private var lastFrameTime: Date = .distantPast
    private var deltaT = BehaviorRelay<Float>(value: 0.0) // in seconds
    private let disposeBag = DisposeBag()

    private var moonLanderTouchdownStatus = BehaviorRelay<Bool>(value: false)
    private var moonLanderThrusterFiredStatus = BehaviorRelay<Bool>(value: false)
    private var moonLanderControlRotationDirection = BehaviorRelay<RotationControlDirection>(value: .straight)

    override func viewDidLoad() {
        super.viewDidLoad()
        setupMoonSurfaceInterface()
        
        setupMoonLanderInterface()
        subscribeMoonLanderToItsAngleAndPosition()
        
        setupDirectionalControlsInterface()
        subscribeMoonLanderToDirectionalControls()
        
        setupEngineThrustControlInterface()
        subscribeEngineToEngineThrustControls()
        
        setupInfoLabelsInterface()
        subscribeInfoLabelsToGameInformation()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        moonLander.bounds = .init(x: 0.0, y: 0.0, width: CGFloat(moonLanderWidth), height: CGFloat(moonLanderHeight))
        lastFrameTime = .now
        startGameLoop()
    }
    
    private func startGameLoop() {
        let gameFrameUpdateTimer = Timer(timeInterval: 1.0 / 60, target: self, selector: #selector(onFramUpdate), userInfo: nil, repeats: true)
        RunLoop.current.add(gameFrameUpdateTimer, forMode: .common)
    }

    @objc private func onFramUpdate() {
        let currentTime: Date = .now
        
        deltaT.accept(Float(currentTime.timeIntervalSince(lastFrameTime)))
        setNewMoonLanderAngle(direction: moonLanderControlRotationDirection.value)
        setNewMoonLanderAcceleration()
        
        let newVelocity = moonLanderVelocity.value + moonLanderAcceleration.value * deltaT.value
        let deltaPath = moonLanderVelocity.value * deltaT.value + 0.5 * moonLanderAcceleration.value * pow(deltaT.value, 2)
        let newPosition = moonLanderPosition.value + SIMD2(x: deltaPath.x, y: -deltaPath.y) * meterToPointFactor // Cartesian coordinate system to screen points
        moonLanderVelocity.accept(newVelocity)
        moonLanderPosition.accept(newPosition)
        lastFrameTime = currentTime
    }

    private func setNewMoonLanderAcceleration() {
        // TODO: Find better way to do this
        let thrustDirection: SIMD2<Float> = .init(x: cos(moonLanderAngle.value), y: sin(moonLanderAngle.value)) // TODO: NORMALISED VECTOR!
        let thrustForce: SIMD2<Float> = moonLanderMaxThrust * moonLanderThrusterFiredStatus.value.toFloat * thrustDirection
        let gravitationalForce: SIMD2<Float> = moonLanderMass * moonGravitationalAcceleration
        let groundReactionForce: SIMD2<Float> = .init(x: 0, y: -min((thrustForce + gravitationalForce).y, 0)) * moonLanderTouchdownStatus.value.toFloat
        let resultingForce: SIMD2<Float> = gravitationalForce + thrustForce + groundReactionForce
        let resultingAcceleration = resultingForce / moonLanderMass
        moonLanderAcceleration.accept(resultingAcceleration)
    }

    private func subscribeMoonLanderToItsAngleAndPosition() {
        moonLanderAngle.subscribe(onNext: {angle in
            // Transform from cartesian coordinate system to UI. 0 degrees is at (0, 1) instead of (1,0)
            let uiAngle: Float = (angle - Float.pi / 2)
            // Silly function rotates clockwise instead of anti clockwise
            self.moonLander.transform = CGAffineTransformMakeRotation(-uiAngle.toCGFloat)
            let angleInDegrees = angle / Float.pi * 180
            self.moonLanderAngleLabel.text = String(format: "Angle: %.2f°", angleInDegrees)
        }).disposed(by: disposeBag)
        
        moonLanderPosition.subscribe(onNext: { position in
            self.moonLander.center = .init(x: position.x.toCGFloat, y: position.y.toCGFloat)
            let moonLanderBottomY = self.moonLander.center.y + moonLanderHeight.toCGFloat / 2

            // Collision detection with moon surface TODO: Improve :::::::
            if moonLanderBottomY >= self.view.frame.height - moonSurfaceElevationHeight.toCGFloat {
                // touchdown
                self.moonLanderVelocity.accept(.init(x: self.moonLanderVelocity.value.x, y: max(self.moonLanderVelocity.value.y, 0)))
                self.moonLanderTouchdownStatus.accept(true)
            } else if self.moonLanderTouchdownStatus.value == true {
                self.moonLanderTouchdownStatus.accept(false)
            }
        }).disposed(by: disposeBag)
    }

    private func setNewMoonLanderAngle(direction: RotationControlDirection) {
        guard direction != .straight else {
            return
        }
        var newAngle: Float = moonLanderAngle.value + Float(direction.rawValue) * moonLanderRotationPerSecond * deltaT.value
        newAngle = newAngle.truncatingRemainder(dividingBy: Float.pi * 2)
        moonLanderAngle.accept(newAngle)
    }
    
    private func subscribeMoonLanderToDirectionalControls() {
        [(leftArrow, RotationControlDirection.left), (rightArrow, RotationControlDirection.right)]
            .forEach { (arrow, direction) in
                arrow.rx.longPressGesture().when(.began).subscribe(onNext: { _ in
                            self.moonLanderControlRotationDirection.accept(direction)
                }).disposed(by: disposeBag)
                arrow.rx.longPressGesture().when(.ended).subscribe(onNext: { _ in
                            self.moonLanderControlRotationDirection.accept(.straight)
                }).disposed(by: disposeBag)
            }
        [(leftArrow, RotationControlDirection.left), (rightArrow, RotationControlDirection.right)]
            .forEach {(arrow, direction) in
                // TODO: Prevent rotation after touchdown
                arrow.rx.tapGesture().when(.recognized).subscribe(onNext: { _ in
                    self.setNewMoonLanderAngle(direction: direction)
                }).disposed(by: disposeBag)
            }
    }

    private func subscribeEngineToEngineThrustControls() {
        engineThrustArrow.rx.tapGesture().when(.recognized).subscribe(onNext: { _ in
            self.moonLanderThrusterFiredStatus.accept(true)
        }).disposed(by: disposeBag)
        
        engineThrustArrow.rx.tapGesture().when(.ended).subscribe(onNext: { _ in
            self.moonLanderThrusterFiredStatus.accept(false)
        }).disposed(by: disposeBag)
        
        engineThrustArrow.rx.longPressGesture().when(.began).subscribe(onNext: { _ in
            self.moonLanderThrusterFiredStatus.accept(true)
        }).disposed(by: disposeBag)
        
        engineThrustArrow.rx.longPressGesture().when(.ended).subscribe(onNext: { _ in
            self.moonLanderThrusterFiredStatus.accept(false)
        }).disposed(by: disposeBag)
    }
    
    private func subscribeInfoLabelsToGameInformation() {
        deltaT.subscribe { (delta: Float) in
            self.frameRateLabel.text = String(format: "FPS: %.2f", 1 / delta)
        }.disposed(by: disposeBag)
        
        moonLanderVelocity.subscribe { (velocity: SIMD2<Float>) in
            self.moonLanderVelocityLabel.text = String(format: "Velocity x: %.2f y: %.2f m/s", velocity.x, velocity.y)
        }.disposed(by: disposeBag)
        
        moonLanderAcceleration.subscribe { (acceleration: SIMD2<Float>) in
            self.moonLanderAccelerationLabel.text = String(
                format: "Acceleration x: %.2f y: %.2f m/s**2", acceleration.x, acceleration.y
            )
        }.disposed(by: disposeBag)
    }
}
