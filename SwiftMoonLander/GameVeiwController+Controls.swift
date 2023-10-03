import Foundation
import RxSwift
import RxCocoa
import RxGesture

extension GameViewController {
    func subscribeEngineToEngineThrustControls(moonLanderThrusterFiredStatus: BehaviorRelay<Bool>, disposeBag: DisposeBag) {
        engineThrustArrow.rx.longPressGesture().when(.began).subscribe(onNext: { _ in
            moonLanderThrusterFiredStatus.accept(true)
            self.engineThrustArrow.tintColor = .red
        }).disposed(by: disposeBag)
        
        engineThrustArrow.rx.longPressGesture().when(.ended).subscribe(onNext: { _ in
            moonLanderThrusterFiredStatus.accept(false)
            self.engineThrustArrow.tintColor = .white
        }).disposed(by: disposeBag)
        
        moonLanderThrusterFiredStatus.subscribe(onNext: {status in
            self.moonLanderThrust.isHidden = !status
        }).disposed(by: disposeBag)
    }
    
    func subscribeMoonLanderToDirectionalControls(moonLanderControlRotationDirection: BehaviorRelay<RotationControlDirection>, disposeBag: DisposeBag, onTap: @escaping (RotationControlDirection) -> (Void)) {
        [(leftArrow, RotationControlDirection.left), (rightArrow, RotationControlDirection.right)]
            .forEach { (arrow, direction) in
                arrow.rx.longPressGesture().when(.began).subscribe(onNext: { _ in
                    moonLanderControlRotationDirection.accept(direction)
                    arrow.tintColor = .gray
                }).disposed(by: disposeBag)
                arrow.rx.longPressGesture().when(.ended).subscribe(onNext: { _ in
                    moonLanderControlRotationDirection.accept(.straight)
                    arrow.tintColor = .white
                }).disposed(by: disposeBag)
            }
        [(leftArrow, RotationControlDirection.left), (rightArrow, RotationControlDirection.right)]
            .forEach {(arrow, direction) in
                arrow.rx.tapGesture().when(.recognized).subscribe(onNext: { _ in
                    onTap(direction)
                }).disposed(by: disposeBag)
            }
    }
}
