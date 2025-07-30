import SwiftUI
import UserNotifications
import Infrastructure

struct FirstDreamNotificationSetupView: View {
    @Binding var isPresented: Bool
    @State private var notificationsEnabled = false
    @State private var selectedTime: Date
    @State private var showingPermissionDenied = false
    let wakeTime: String?
    
    init(isPresented: Binding<Bool>, wakeTime: String? = nil) {
        self._isPresented = isPresented
        self.wakeTime = wakeTime
        
        // Calculate default time: 30 minutes after wake time
        let defaultTime: Date
        if let wakeTimeString = wakeTime {
            // Parse the wake time (format: "HH:MM:SS" or "HH:MM")
            let timeOnly = wakeTimeString.prefix(5) // Take first 5 chars (HH:MM)
            let components = timeOnly.split(separator: ":")
            if components.count == 2,
               let hour = Int(components[0]),
               let minute = Int(components[1]) {
                // Add 30 minutes to wake time
                let totalMinutes = hour * 60 + minute + 30
                let notificationHour = totalMinutes / 60
                let notificationMinute = totalMinutes % 60
                
                defaultTime = Calendar.current.date(from: DateComponents(
                    hour: notificationHour,
                    minute: notificationMinute
                )) ?? Date()
            } else {
                // Fallback to 7:30 AM if parsing fails
                defaultTime = Calendar.current.date(from: DateComponents(hour: 7, minute: 30)) ?? Date()
            }
        } else {
            // Default to 7:30 AM if no wake time is set
            defaultTime = Calendar.current.date(from: DateComponents(hour: 7, minute: 30)) ?? Date()
        }
        
        self._selectedTime = State(initialValue: defaultTime)
    }
    
    var body: some View {
        ZStack {
            // Background blur
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture { } // Prevent dismissal by tapping background
            
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 16) {
                    Text("✨")
                        .font(.system(size: 60))
                    
                    Text("Let's make this a daily practice")
                        .font(DesignSystem.Typography.title2())
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    Text("The best insights come from consistent dream journaling")
                        .font(DesignSystem.Typography.body())
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                // Notification toggle section
                VStack(spacing: 0) {
                    // Toggle that stays in place
                    Toggle(isOn: $notificationsEnabled.animation(.easeInOut(duration: 0.3))) {
                        HStack {
                            Image(systemName: "bell.fill")
                                .foregroundColor(DesignSystem.Colors.ember)
                            Text("Daily dream reminders")
                                .font(DesignSystem.Typography.subheadline())
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: DesignSystem.Colors.ember))
                    .padding(.horizontal, 32)
                    
                    // Options that appear below (without moving the toggle)
                    if notificationsEnabled {
                        VStack(spacing: 20) {
                            // Time picker
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Reminder time")
                                    .font(DesignSystem.Typography.caption())
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                    .padding(.horizontal, 32)
                                
                                DatePicker("", selection: $selectedTime, displayedComponents: .hourAndMinute)
                                    .datePickerStyle(WheelDatePickerStyle())
                                    .labelsHidden()
                                    .frame(height: 120)
                                    .clipped()
                            }
                            
                            Text("We'll remind you to record your dreams every day")
                                .font(DesignSystem.Typography.caption())
                                .foregroundColor(DesignSystem.Colors.textTertiary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        .transition(.asymmetric(
                            insertion: .push(from: .top).combined(with: .opacity),
                            removal: .push(from: .bottom).combined(with: .opacity)
                        ))
                        .padding(.top, 20)
                    }
                }
                
                // Action buttons
                VStack(spacing: 12) {
                    if notificationsEnabled {
                        Button {
                            Task { await setupNotifications() }
                        } label: {
                            Text("Set Reminder")
                                .font(DesignSystem.Typography.subheadline())
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    Capsule()
                                        .fill(DesignSystem.Gradients.dreamGradient)
                                )
                                .padding(.horizontal, 32)
                        }
                    }
                    
                    Button {
                        completeSetup(enabledNotifications: false)
                    } label: {
                        Text(notificationsEnabled ? "Cancel" : "Maybe Later")
                            .font(DesignSystem.Typography.subheadline())
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .padding(.horizontal, 32)
                    }
                }
                .padding(.top, notificationsEnabled ? 0 : 20)
            }
            .padding(.vertical, 40)
        }
        .alert("Notifications Disabled", isPresented: $showingPermissionDenied) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please enable notifications in Settings to receive dream reminders.")
        }
    }
    
    private func setupNotifications() async {
        let center = UNUserNotificationCenter.current()
        
        do {
            let authorized = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            
            if authorized {
                // Remove any existing notifications
                center.removeAllPendingNotificationRequests()
                
                // Create the notification content
                let content = UNMutableNotificationContent()
                content.title = "Time to Dream"
                content.body = "Take a moment to record your dreams before they fade"
                content.sound = .default
                
                // Create the trigger
                let dateComponents = Calendar.current.dateComponents([.hour, .minute], from: selectedTime)
                let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
                
                // Create the request
                let request = UNNotificationRequest(
                    identifier: "dream.reminder.daily",
                    content: content,
                    trigger: trigger
                )
                
                // Schedule the notification
                try await center.add(request)
                
                // Save preferences
                saveNotificationPreferences()
                
                // Track analytics
                AnalyticsService.shared.track(.notificationPermissionGranted, properties: [
                    "source": "first_dream_celebration",
                    "time": formatTime(selectedTime)
                ])
                
                // Complete setup
                completeSetup(enabledNotifications: true)
            } else {
                await MainActor.run {
                    showingPermissionDenied = true
                }
            }
        } catch {
            print("Error setting up notifications: \(error)")
            await MainActor.run {
                showingPermissionDenied = true
            }
        }
    }
    
    private func saveNotificationPreferences() {
        UserDefaults.standard.set(true, forKey: "notificationsEnabled")
        UserDefaults.standard.set(selectedTime, forKey: "notificationTime")
        UserDefaults.standard.set("daily", forKey: "notificationFrequency")
        UserDefaults.standard.set(true, forKey: "hasSetupFirstDreamNotifications")
    }
    
    private func completeSetup(enabledNotifications: Bool) {
        if !enabledNotifications {
            // Track that user skipped
            AnalyticsService.shared.track(.notificationPermissionDenied, properties: [
                "source": "first_dream_celebration",
                "action": "maybe_later"
            ])
            UserDefaults.standard.set(true, forKey: "hasSetupFirstDreamNotifications")
        }
        
        withAnimation(.easeOut(duration: 0.3)) {
            isPresented = false
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    FirstDreamNotificationSetupView(isPresented: .constant(true))
        .background(Color.black)
}