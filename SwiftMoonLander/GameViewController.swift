import UIKit
import RxSwift
import RxCocoa
import RxGesture
import RxRelay
import AVFoundation
import AVFAudio


class GameViewController: UIViewController {
    let moonLander = UIImageView(image: UIImage(systemName: "rectangle.roundedtop.fill"))
    let moonLanderThrust = UIImageView(image: UIImage(systemName: "drop.fill"))
    var moonLanderThrustAudioPlayer: AVAudioPlayer?

    let moonSurface = UIView()
    let leftArrow = UIButton()
    let rightArrow = UIButton()
    let engineThrustArrow = UIButton()

    let frameRateLabel = UILabel()
    let moonLanderAngleLabel = UILabel()
    let moonLanderVelocityLabel = UILabel()
    let moonLanderAccelerationLabel = UILabel()
    let infoStackView = UIStackView()

    private var moonLanderAngle = BehaviorRelay<Float>(value: Float.pi / 2) // in radians
    private var moonLanderAcceleration = BehaviorRelay<SIMD2<Float>>(value: moonGravitationalAcceleration) // in m/s**2
    private var moonLanderVelocity = BehaviorRelay<SIMD2<Float>>(value: .init(x: 0, y: 0)) // in m/s
    private var moonLanderPosition = BehaviorRelay<SIMD2<Float>>(value: .init(x: 200, y: 200))
    
    private var moonLanderTouchdownStatus = BehaviorRelay<Bool>(value: false)
    private var moonLanderThrusterFiredStatus = BehaviorRelay<Bool>(value: false)
    private var moonLanderControlRotationDirection = BehaviorRelay<RotationControlDirection>(value: .straight)
    
    private var deltaT = BehaviorRelay<Float>(value: 0.0) // in seconds
    private var lastFrameTime: Date = .distantPast
    private let disposeBag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupMoonLanderInterface()
        subscribeMoonLanderToItsAngleAndPosition()
        
        setupMoonSurfaceInterface()
        
        setupDirectionalControlsInterface()
        subscribeMoonLanderToDirectionalControls()
        
        setupEngineThrustControlInterface()
        subscribeEngineToEngineThrustControls()
        
        setupThrustAudioPlayer()
        subscribeAudioPlayerToThrustStatus()
        
        setupInfoLabelsInterface()
        subscribeInfoLabelsToGameInformation()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
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
        // Cartesian coordinate system to screen points
        let newPosition = moonLanderPosition.value + SIMD2(x: deltaPath.x, y: -deltaPath.y) * meterToPointFactor
        moonLanderVelocity.accept(newVelocity)
        moonLanderPosition.accept(newPosition)
        lastFrameTime = currentTime
    }

    private func setNewMoonLanderAcceleration() {
        let thrustDirection: SIMD2<Float> = .init(x: cos(moonLanderAngle.value), y: sin(moonLanderAngle.value)).normalised()
        let thrustForce: SIMD2<Float> = moonLanderMaxThrust * moonLanderThrusterFiredStatus.value.toFloat * thrustDirection
        let gravitationalForce: SIMD2<Float> = moonLanderMass * moonGravitationalAcceleration
        let groundVerticalReactionForce: SIMD2<Float> = .init(x: 0, y: -min((thrustForce + gravitationalForce).y, 0)) * moonLanderTouchdownStatus.value.toFloat
        let resultingForce: SIMD2<Float> = gravitationalForce + thrustForce + groundVerticalReactionForce
        let resultingAcceleration = resultingForce / moonLanderMass
        moonLanderAcceleration.accept(resultingAcceleration)
    }

    private func subscribeMoonLanderToItsAngleAndPosition() {
        moonLanderAngle.subscribe(onNext: {angle in
            // Transform from cartesian coordinate system to UI. 0 degrees is at (0, 1) instead of (1,0)
            let uiAngle: Float = (angle - Float.pi / 2)
            // CGAffineTransformMakeRotation rotates clockwise instead of anti clockwise
            self.moonLander.transform = CGAffineTransformMakeRotation(-uiAngle.toCGFloat)
            
            let angleInDegrees = angle / Float.pi * 180
            self.moonLanderAngleLabel.text = String(format: "Angle: %.2f°", angleInDegrees)
        }).disposed(by: disposeBag)
        
        moonLanderPosition.subscribe(onNext: { position in
            self.moonLander.center = .init(x: position.x.toCGFloat, y: position.y.toCGFloat)
            let moonLanderBottomY = self.moonLander.center.y + moonLanderHeight.toCGFloat / 2

            // Collision detection with moon surface TODO: Improve :::::::
            if moonLanderBottomY >= self.view.frame.height - moonSurfaceElevationHeight.toCGFloat {
                // Touchdown
                // Simple ground friction instant horizontal halt
                // TODO: Friction force, dynamic μ - the coefficient of friction, due to heat between materials etc...
                self.moonLanderVelocity.accept(.init(x: 0, y: max(self.moonLanderVelocity.value.y, 0)))
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
                    arrow.tintColor = .gray
                }).disposed(by: disposeBag)
                arrow.rx.longPressGesture().when(.ended).subscribe(onNext: { _ in
                    self.moonLanderControlRotationDirection.accept(.straight)
                    arrow.tintColor = .white
                }).disposed(by: disposeBag)
            }
        [(leftArrow, RotationControlDirection.left), (rightArrow, RotationControlDirection.right)]
            .forEach {(arrow, direction) in
                arrow.rx.tapGesture().when(.recognized).subscribe(onNext: { _ in
                    self.setNewMoonLanderAngle(direction: direction)
                }).disposed(by: disposeBag)
            }
    }

    private func subscribeEngineToEngineThrustControls() {
        engineThrustArrow.rx.longPressGesture().when(.began).subscribe(onNext: { _ in
            self.moonLanderThrusterFiredStatus.accept(true)
            self.engineThrustArrow.tintColor = .red
        }).disposed(by: disposeBag)
        
        engineThrustArrow.rx.longPressGesture().when(.ended).subscribe(onNext: { _ in
            self.moonLanderThrusterFiredStatus.accept(false)
            self.engineThrustArrow.tintColor = .white
        }).disposed(by: disposeBag)
        
        moonLanderThrusterFiredStatus.subscribe(onNext: {status in
            self.moonLanderThrust.isHidden = !status
        }).disposed(by: disposeBag)
    }
    
    private func setupThrustAudioPlayer() {
        guard let url = Bundle.main.url(forResource: "rocket_sound", withExtension: ".m4a") else { return }
        self.moonLanderThrustAudioPlayer = try? AVAudioPlayer(contentsOf: url)
        self.moonLanderThrustAudioPlayer?.numberOfLoops = -1
    }
    
    private func subscribeAudioPlayerToThrustStatus() {
        moonLanderThrusterFiredStatus.subscribe(onNext: { isFired in
            self.moonLanderThrust.isHidden = !isFired
            if isFired {
                self.moonLanderThrustAudioPlayer?.play()
            } else {
                self.moonLanderThrustAudioPlayer?.stop()
            }
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

enum RotationControlDirection: Int {
    case left = 1
    case straight = 0
    case right = -1
}
