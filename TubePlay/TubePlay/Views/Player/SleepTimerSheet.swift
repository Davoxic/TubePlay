import SwiftUI

public struct SleepTimerSheet: View {
    @ObservedObject var sleepTimer = SleepTimerManager.shared
    @Environment(\.dismiss) var dismiss
    
    let timerOptions = [15, 30, 45, 60, 90]
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Sleep Timer Status")) {
                    HStack {
                        Image(systemName: "moon.fill")
                            .foregroundColor(.purple)
                            .font(.system(size: 20))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(sleepTimer.isRunning ? "Active: \(sleepTimer.formattedRemainingTime)" : "No Timer Set")
                                .font(.system(size: 16, weight: .semibold))
                            Text(sleepTimer.isRunning ? "Playback will pause automatically when time expires" : "Select a duration below")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if sleepTimer.isRunning {
                            Button("Stop") {
                                sleepTimer.stopTimer()
                            }
                            .foregroundColor(.red)
                            .font(.system(size: 14, weight: .bold))
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Section(header: Text("Set Duration")) {
                    ForEach(timerOptions, id: \.self) { minutes in
                        Button(action: {
                            sleepTimer.startTimer(minutes: minutes)
                            dismiss()
                        }) {
                            HStack {
                                Text("\(minutes) minutes")
                                    .foregroundColor(.primary)
                                Spacer()
                                if sleepTimer.isRunning && sleepTimer.remainingSeconds <= minutes * 60 && sleepTimer.remainingSeconds > (minutes - 15) * 60 {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Sleep Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
