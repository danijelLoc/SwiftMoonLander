//
//  ViewController.swift
//  SwiftMoonLander
//
//  Created by Danijel on 21.11.2022..
//

import UIKit
import SnapKit
import RxSwift
import RxCocoa
import RxGesture
import RxRelay

enum RotationControlDirection: Int {
    case left = 1
    case straight = 0
    case right = -1
}

extension Bool {
    var toDouble: Double {
        self ? 1 : 0
    }
}

class GameViewController: UIViewController {
    private let moonLander = UIImageView(image: UIImage(systemName: "rectangle.roundedtop.fill"))
    private let moonSurface = UIView()
    private let leftArrow = UIImageView(image: UIImage(systemName: "arrowtriangle.left.circle.fill"))
    private let rightArrow = UIImageView(image: UIImage(systemName: "arrowtriangle.right.circle.fill"))
    private let engineThrustArrow = UIImageView(image: UIImage(systemName: "flame.circle.fill"))

    private let framerateLabel = UILabel()
    private let moonLanderAngleLabel = UILabel()
    private let moonLanderVelocityLabel = UILabel()
    private let moonLanderAccelerationLabel = UILabel()
    private let infoStackView = UIStackView()

    private var moonLanderAngle = BehaviorRelay<Double>(value: Double.pi / 2) // in radians
    private var moonLanderAcceleration = BehaviorRelay<SIMD2<Double>>(
            value: moonGravitationalAcceleration) // in m/s**2
    private var moonLanderVelocity = BehaviorRelay<SIMD2<Double>>(
            value: .init(x: 0, y: 0)) // in m/s
    private var moonLanderPosition = BehaviorRelay<SIMD2<Double>>(value: .init(x: 200, y: 200))
    private var lastFrameTime: Date = .distantPast
    private var deltaT = BehaviorRelay<Double>(value: 0.0) // in seconds
    private let disposeBag = DisposeBag()

    private var moonLanderLandedStatus = BehaviorRelay<Bool>(value: false)
    private var moonLanderThrusterFiredStatus = BehaviorRelay<Bool>(value: false)
    private var moonLanderControlRotationDirection = BehaviorRelay<RotationControlDirection>(value: .straight)


    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        setupInfoLabels()
        setupMoonSurface()
        setupMoonLander()
        setupDirectionalControls()
        setupEngineThrustControl()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        moonLander.bounds = .init(x: 0, y: 0, width: moonLanderWidth, height: moonLanderHeight)
        lastFrameTime = .now
        let gameUpdateTimer = Timer(timeInterval: 1.0 / 60, target: self, selector: #selector(update), userInfo: nil, repeats: true)
        RunLoop.current.add(gameUpdateTimer, forMode: .common)
    }

    @objc private func update() {
        let currentTime: Date = .now
        deltaT.accept(currentTime.timeIntervalSince(lastFrameTime))
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
        let thrustDirection: SIMD2<Double> = .init(x: cos(moonLanderAngle.value), y: sin(moonLanderAngle.value)) // TODO: NORMALISED VECTOR!
        let thrustForce: SIMD2<Double> = moonLanderMaxThrust * moonLanderThrusterFiredStatus.value.toDouble * thrustDirection
        let gravitationalForce: SIMD2<Double> = moonLanderMass * moonGravitationalAcceleration
        let groundReactionForce: SIMD2<Double> = .init(x: 0, y: -min((thrustForce + gravitationalForce).y, 0)) * moonLanderLandedStatus.value.toDouble
        let resultingForce: SIMD2<Double> = gravitationalForce + thrustForce + groundReactionForce
        let resultingAcceleration = resultingForce / moonLanderMass
        moonLanderAcceleration.accept(resultingAcceleration)
    }

    private func setupMoonSurface() {
        view.backgroundColor = .black
        view.addSubview(moonSurface)
        moonSurface.backgroundColor = .lightGray
        moonSurface.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(moonSurfaceElevationHeight)
        }
    }

    private func setupMoonLander() {
        view.addSubview(moonLander)
        moonLander.tintColor = .init(red: 1, green: 0.7, blue: 0, alpha: 1)

        moonLanderAngle.subscribe { angle in
                    let uiAngle = (angle - Double.pi / 2) // Transform from cartesian coordinate system to UI. 0 degrees is at (0, 1) instead of (1,0)
                    self.moonLander.transform = CGAffineTransformMakeRotation(-uiAngle) // Silly function rotates clockwise instead of anti clockwise
                    let angleInDegrees = angle / Double.pi * 180
                    self.moonLanderAngleLabel.text = String(format: "Angle: %.2f°", angleInDegrees)
                }
                .disposed(by: disposeBag)
        moonLanderPosition.subscribe(onNext: { position in
                    self.moonLander.center = .init(x: position.x, y: position.y)
                    let moonLanderBottomY = self.moonLander.center.y + moonLanderHeight / 2

                    // Collision detection with moon surface TODO: Improve :::::::
                    if moonLanderBottomY >= self.view.frame.height - moonSurfaceElevationHeight {
                        // touchdown
                        self.moonLanderVelocity.accept(.init(x: self.moonLanderVelocity.value.x, y: max(self.moonLanderVelocity.value.y, 0)))
                        self.moonLanderLandedStatus.accept(true)
                    } else if self.moonLanderLandedStatus.value == true {
                        self.moonLanderLandedStatus.accept(false)
                    }
                })
                .disposed(by: disposeBag)
        // TODO: In update() or here ??
//        deltaT.subscribe { delta in
//                    self.moonLander.center = .init(
//                            x: self.moonLander.center.x + self.deltaX,
//                            y: self.moonLander.center.y + self.deltaY)
//                }
//                .disposed(by: disposeBag)
    }

    private func setupDirectionalControls() {
        ([leftArrow, rightArrow] as [UIImageView]).enumerated().forEach { (index, arrow) in
            view.addSubview(arrow)
            arrow.tintColor = .white
            arrow.isUserInteractionEnabled = true
            arrow.snp.makeConstraints { make in
                make.width.height.equalTo(70)
                if index == 0 {
                    make.leading.equalToSuperview().offset(32)
                } else {
                    make.leading.equalTo(leftArrow.snp.trailing).offset(8)
                }
                make.bottom.equalToSuperview().offset(-64)
            }
        }

        [(leftArrow, RotationControlDirection.left), (rightArrow, RotationControlDirection.right)].forEach { (arrow, direction) in
            arrow.rx.longPressGesture().when(.began).subscribe(onNext: { _ in
                        self.moonLanderControlRotationDirection.accept(direction)
                    })
                    .disposed(by: disposeBag)
            arrow.rx.longPressGesture().when(.ended).subscribe(onNext: { _ in
                        self.moonLanderControlRotationDirection.accept(.straight)
                    })
                    .disposed(by: disposeBag)
        }
        [(leftArrow, RotationControlDirection.left), (rightArrow, RotationControlDirection.right)]
                .forEach { (arrow, direction) in
                    // TODO: Prevent rotation after touchdown
                    arrow.rx.tapGesture().when(.recognized).subscribe(onNext: { _ in
                                self.setNewMoonLanderAngle(direction: direction)
                            })
                            .disposed(by: disposeBag)
                }
    }

    private func setNewMoonLanderAngle(direction: RotationControlDirection) {
        guard direction != .straight else {
            return
        }
        var newAngle: Double = moonLanderAngle.value + Double(direction.rawValue) * moonLanderRotationPerSecond * deltaT.value
        newAngle = newAngle.truncatingRemainder(dividingBy: Double.pi * 2)
        moonLanderAngle.accept(newAngle)
    }

    private func setupEngineThrustControl() {
        view.addSubview(engineThrustArrow)
        engineThrustArrow.tintColor = .white
        engineThrustArrow.isUserInteractionEnabled = true
        engineThrustArrow.snp.makeConstraints { make in
            make.width.height.equalTo(70)
            make.trailing.equalToSuperview().offset(-32)
            make.bottom.equalToSuperview().offset(-64)
        }
        engineThrustArrow.rx.tapGesture().when(.recognized).subscribe(onNext: { _ in
                    self.moonLanderThrusterFiredStatus.accept(true)
                })
                .disposed(by: disposeBag)
        engineThrustArrow.rx.tapGesture().when(.ended).subscribe(onNext: { _ in
                    self.moonLanderThrusterFiredStatus.accept(false)
                })
                .disposed(by: disposeBag)
        engineThrustArrow.rx.longPressGesture().when(.began).subscribe(onNext: { _ in
                    self.moonLanderThrusterFiredStatus.accept(true)
                })
                .disposed(by: disposeBag)
        engineThrustArrow.rx.longPressGesture().when(.ended).subscribe(onNext: { _ in
                    self.moonLanderThrusterFiredStatus.accept(false)
                })
                .disposed(by: disposeBag)
    }

    private func setupInfoLabels() {
        view.addSubview(infoStackView)
        infoStackView.axis = .vertical
        [framerateLabel, moonLanderAngleLabel, moonLanderVelocityLabel, moonLanderAccelerationLabel].forEach { label in
            infoStackView.addArrangedSubview(label)
            label.textColor = .white
            label.font = .systemFont(ofSize: 14)
        }
        infoStackView.snp.makeConstraints { (make: ConstraintMaker) in
            make.leading.equalToSuperview().offset(8)
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
        }
        deltaT.subscribe { (delta: Double) in
                    self.framerateLabel.text = String(format: "FPS: %.2f", 1 / delta)
                }
                .disposed(by: disposeBag)
        moonLanderVelocity.subscribe { (velocity: SIMD2<Double>) in
                    self.moonLanderVelocityLabel.text = String(format: "Velocity x: %.2f y: %.2f m/s", velocity.x, velocity.y)
                }
                .disposed(by: disposeBag)
        moonLanderAcceleration.subscribe { (acceleration: SIMD2<Double>) in
                    self.moonLanderAccelerationLabel.text = String(format: "Acceleration x: %.2f y: %.2f m/s**2", acceleration.x, acceleration.y)
                }
                .disposed(by: disposeBag)
    }
}

