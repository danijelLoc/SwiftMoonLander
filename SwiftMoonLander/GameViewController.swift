import UIKit
import RxSwift
import RxCocoa
import RxRelay
import AVFoundation
import AVFAudio


class GameViewController: UIViewController {
    let moonSurface = UIView()
    let leftArrow = UIButton()
    let rightArrow = UIButton()
    let engineThrustArrow = UIButton()
    let moonLander = UIImageView(image: UIImage(systemName: "rectangle.roundedtop.fill"))
    let moonLanderThrust = UIImageView(image: UIImage(systemName: "drop.fill"))
    
    let frameRateLabel = UILabel()
    let moonLanderAngleLabel = UILabel()
    let moonLanderVelocityLabel = UILabel()
    let moonLanderAccelerationLabel = UILabel()
    let landingStatusLabel = UILabel()
    let infoStackView = UIStackView()
    
    var moonLanderThrustAudioPlayer: AVAudioPlayer?
    var touchDownAudioPlayer: AVAudioPlayer?
    
    private var moonLanderAngle = BehaviorRelay<Float>(value: Float.pi / 2) // in radians
    private var moonLanderAcceleration = BehaviorRelay<SIMD2<Float>>(value: moonGravitationalAcceleration) // in m/s**2
    private var moonLanderVelocity = BehaviorRelay<SIMD2<Float>>(value: .init(x: 0, y: 0)) // in m/s
    private var moonLanderPosition = BehaviorRelay<SIMD2<Float>>(value: .init(x: 200, y: 200))

    private var moonLanderGroundedStatus = BehaviorRelay<Bool>(value: false)
    private var moonLanderThrusterFiredStatus = BehaviorRelay<Bool>(value: false)
    private var moonLanderControlRotationDirection = BehaviorRelay<RotationControlDirection>(value: .straight)
    
    private var touchDownNotification = PublishRelay<Bool>()
    
    private var deltaT = BehaviorRelay<Float>(value: 0.0) // in seconds
    private var lastFrameTime: Date = .distantPast
    private let disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupGameInterface()
        
        subscribeMoonLanderToItsAngleAndPosition()
        subscribeMoonLanderToControls()
        
        setupLanderThrustAudioPlayer()
        subscribeInformationLabelsAndAudioPlayersToGameState()
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
        
        checkForTouchdown()
        
        setNewMoonLanderAngle(direction: moonLanderControlRotationDirection.value)
        setNewMoonLanderAcceleration()
        setNewMoonlanderVelocityAndPosition()
        
        lastFrameTime = currentTime
    }
    
    private func setNewMoonLanderAngle(direction: RotationControlDirection) {
        guard direction != .straight else {
            return
        }
        var newAngle: Float = moonLanderAngle.value + Float(direction.rawValue) * moonLanderRotationPerSecond * deltaT.value
        newAngle = newAngle.truncatingRemainder(dividingBy: Float.pi * 2)
        moonLanderAngle.accept(newAngle)
    }
    
    private func checkForTouchdown() {
        let moonLanderBottomY = self.moonLander.center.y + moonLanderHeight.toCGFloat / 2
        
        // Collision detection with moon surface
        // TODO: Alternative, introduce position in meters from the ground for collision
        if moonLanderBottomY >= self.view.frame.height - moonSurfaceElevationHeight.toCGFloat {
            // Crash detection
            if !self.moonLanderGroundedStatus.value && (self.moonLanderVelocity.value.x.magnitude > maxMoonLandingVelocity.x || self.moonLanderVelocity.value.y.magnitude > maxMoonLandingVelocity.y) {
                self.touchDownNotification.accept(false)
            } else if !self.moonLanderGroundedStatus.value {
                self.touchDownNotification.accept(true)
            }
            
            self.moonLanderGroundedStatus.accept(true)
        } else if self.moonLanderGroundedStatus.value == true {
            self.moonLanderGroundedStatus.accept(false)
        }
    }
    
    private func setNewMoonLanderAcceleration() {
        let thrustDirection: SIMD2<Float> = .init(x: cos(moonLanderAngle.value), y: sin(moonLanderAngle.value)).normalised()
        let thrustForce: SIMD2<Float> = moonLanderMaxThrust * moonLanderThrusterFiredStatus.value.toFloat * thrustDirection
        let gravitationalForce: SIMD2<Float> = moonLanderMass * moonGravitationalAcceleration
        let groundVerticalReactionForce: SIMD2<Float> = .init(x: 0, y: -min((thrustForce + gravitationalForce).y, 0)) * moonLanderGroundedStatus.value.toFloat
        let resultingForce: SIMD2<Float> = gravitationalForce + thrustForce + groundVerticalReactionForce
        let resultingAcceleration = resultingForce / moonLanderMass
        moonLanderAcceleration.accept(resultingAcceleration)
    }
    
    func setNewMoonlanderVelocityAndPosition() {
        let deltaPath = moonLanderVelocity.value * deltaT.value + 0.5 * moonLanderAcceleration.value * pow(deltaT.value, 2)
        var newVelocity = moonLanderVelocity.value + moonLanderAcceleration.value * deltaT.value
        // Cartesian coordinate system to screen points
        let newPosition = moonLanderPosition.value + SIMD2(x: deltaPath.x, y: -deltaPath.y) * meterToPointFactor
        
        // Grounded halt horizontally and down vertically
        if moonLanderGroundedStatus.value {
            newVelocity = .init(x: 0, y: max(newVelocity.y, 0))
        }
        
        moonLanderVelocity.accept(newVelocity)
        moonLanderPosition.accept(newPosition)
    }
    
    private func subscribeMoonLanderToItsAngleAndPosition() {
        subscribePositionToFailedTouchdown()
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
        }).disposed(by: disposeBag)
    }
    
    private func subscribePositionToFailedTouchdown() {
        touchDownNotification.subscribe(onNext: { landedSafely in
            if !landedSafely {
                self.moonLanderPosition.accept(.init(x: 200, y: 200))
            }
        }).disposed(by: disposeBag)
    }
    
    private func subscribeMoonLanderToControls() {
        subscribeMoonLanderToDirectionalControls(moonLanderControlRotationDirection: moonLanderControlRotationDirection, disposeBag: disposeBag, onTap: setNewMoonLanderAngle)
        subscribeEngineToEngineThrustControls(moonLanderThrusterFiredStatus: moonLanderThrusterFiredStatus, disposeBag: disposeBag)
    }
    
    private func subscribeInformationLabelsAndAudioPlayersToGameState() {
        subscribeAudioPlayers(moonLanderThrusterFiredStatus: moonLanderThrusterFiredStatus.asObservable(), touchDownNotification: touchDownNotification.asObservable(), disposeBag: disposeBag)
        subscribeInfoLabelsToGameInformation(moonLanderAcceleration: moonLanderAcceleration.asObservable(), moonLanderVelocity: moonLanderVelocity.asObservable(), deltaT: deltaT.asObservable(), touchDownNotification: touchDownNotification.asObservable(), disposeBag: disposeBag)
    }
}

enum RotationControlDirection: Int {
    case left = 1
    case straight = 0
    case right = -1
}
