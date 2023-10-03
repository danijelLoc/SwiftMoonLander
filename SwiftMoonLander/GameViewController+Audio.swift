import RxSwift
import AVFAudio

extension GameViewController {
    func setupLanderThrustAudioPlayer() {
        guard let rocketUrl = Bundle.main.url(forResource: "rocket_sound", withExtension: ".m4a") else { return }
        moonLanderThrustAudioPlayer = try? AVAudioPlayer(contentsOf: rocketUrl)
        moonLanderThrustAudioPlayer?.numberOfLoops = -1
    }
    
    func subscribeAudioPlayers(moonLanderThrusterFiredStatus: Observable<Bool>, touchDownNotification: Observable<Bool>, disposeBag: DisposeBag) {
        moonLanderThrusterFiredStatus.subscribe(onNext: { isFired in
            if isFired {
                self.moonLanderThrustAudioPlayer?.play()
            } else {
                self.moonLanderThrustAudioPlayer?.stop()
            }
        }).disposed(by: disposeBag)
        
        touchDownNotification.subscribe(onNext: { landedSafely in
            guard let failedLandingUrl = Bundle.main.url(forResource: "negative_beeps", withExtension: ".mp3") else { return }
            guard let successfulLandingUrl = Bundle.main.url(forResource: "success", withExtension: ".mp3") else { return }
            self.touchDownAudioPlayer = try? AVAudioPlayer(contentsOf: landedSafely ? successfulLandingUrl : failedLandingUrl)
            self.touchDownAudioPlayer?.play()
        }).disposed(by: disposeBag)
    }
}
