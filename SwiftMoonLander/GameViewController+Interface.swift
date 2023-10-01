import UIKit
import SnapKit

extension GameViewController {
    
    func setupMoonSurfaceInterface() {
        view.backgroundColor = UIColor(red: 0, green: 0, blue: 0.2, alpha: 1)
        
        view.addSubview(moonSurface)
        moonSurface.backgroundColor = .lightGray
        moonSurface.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(moonSurfaceElevationHeight)
        }
    }
    
    func setupMoonLanderInterface() {
        view.addSubview(moonLander)
        moonLander.tintColor = .init(red: 1, green: 0.7, blue: 0, alpha: 1)
    }
    
    func setupDirectionalControlsInterface() {
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
    }
    
    func setupEngineThrustControlInterface() {
        view.addSubview(engineThrustArrow)
        engineThrustArrow.tintColor = .white
        engineThrustArrow.isUserInteractionEnabled = true
        
        engineThrustArrow.snp.makeConstraints { make in
            make.width.height.equalTo(70)
            make.trailing.equalToSuperview().offset(-32)
            make.bottom.equalToSuperview().offset(-64)
        }
    }

    func setupInfoLabelsInterface() {
        view.addSubview(infoStackView)
        infoStackView.axis = .vertical
        [frameRateLabel, moonLanderAngleLabel, moonLanderVelocityLabel, moonLanderAccelerationLabel].forEach { label in
            infoStackView.addArrangedSubview(label)
            label.textColor = .white
            label.font = .systemFont(ofSize: 14)
        }
        infoStackView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(8)
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
        }
    }
    

}
