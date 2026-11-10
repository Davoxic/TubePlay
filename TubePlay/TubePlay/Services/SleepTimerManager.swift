import Foundation
import Combine

public final class SleepTimerManager: ObservableObject {
    public static let shared = SleepTimerManager()
    
    @Published public private(set) var remainingSeconds: Int = 0
    @Published public private(set) var isRunning: Bool = false
    
    public var onTimerFired: (() -> Void)?
    
    private var timer: AnyCancellable?
    
    private init() {}
    
    public func startTimer(minutes: Int) {
        stopTimer()
        guard minutes > 0 else { return }
        
        remainingSeconds = minutes * 60
        isRunning = true
        
        timer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.remainingSeconds > 1 {
                    self.remainingSeconds -= 1
                } else {
                    self.remainingSeconds = 0
                    self.stopTimer()
                    self.onTimerFired?()
                }
            }
    }
    
    public func stopTimer() {
        timer?.cancel()
        timer = nil
        remainingSeconds = 0
        isRunning = false
    }
    
    public var formattedRemainingTime: String {
        guard isRunning else { return "Off" }
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
