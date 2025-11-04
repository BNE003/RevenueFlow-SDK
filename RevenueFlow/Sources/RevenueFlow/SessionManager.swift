import Foundation

#if canImport(UIKit)
import UIKit
#endif

/// Manages active session tracking with heartbeat mechanism
internal final class SessionManager: @unchecked Sendable {

    // MARK: - Configuration

    /// Heartbeat interval in seconds (default: 60 seconds)
    private let heartbeatInterval: TimeInterval = 60

    /// Maximum retry attempts for failed heartbeats
    private let maxRetryAttempts = 3

    // MARK: - Properties

    private let appId: String
    private let supabaseClient: RFSupabaseClient
    private var deviceUUID: String?

    private var sessionId: String?
    private var heartbeatTimer: Timer?
    private var isActive = false

    // Thread-safe access to session state
    private let queue = DispatchQueue(label: "com.revenueflow.sessionmanager", attributes: .concurrent)

    // MARK: - Initialization

    init(appId: String, supabaseClient: RFSupabaseClient) {
        self.appId = appId
        self.supabaseClient = supabaseClient

        RFLogger.shared.debug("SessionManager initialized")
    }

    // MARK: - Lifecycle

    /// Set the device UUID (called after device registration)
    func setDeviceUUID(_ uuid: String) {
        queue.async(flags: .barrier) {
            self.deviceUUID = uuid
            RFLogger.shared.debug("SessionManager: Device UUID set to \(uuid)")
        }
    }

    /// Start session tracking
    func startSession() {
        queue.async(flags: .barrier) {
            guard !self.isActive else {
                RFLogger.shared.debug("Session tracking already active")
                return
            }

            guard let deviceUUID = self.deviceUUID else {
                RFLogger.shared.warning("⚠️ Cannot start session - device UUID not set yet")
                return
            }

            self.isActive = true
            RFLogger.shared.info("🚀 Starting session tracking...")

            // Start session in background task
            Task {
                await self.createSession(deviceUUID: deviceUUID)
            }

            // Setup app lifecycle observers
            self.setupLifecycleObservers()
        }
    }

    /// Stop session tracking
    func stopSession() {
        queue.async(flags: .barrier) {
            guard self.isActive else {
                RFLogger.shared.debug("Session tracking already stopped")
                return
            }

            self.isActive = false
            self.stopHeartbeat()
            self.removeLifecycleObservers()

            // End session in background
            if let sessionId = self.sessionId {
                Task {
                    await self.endActiveSession(sessionId: sessionId)
                }
            }

            RFLogger.shared.info("🛑 Session tracking stopped")
        }
    }

    // MARK: - Session Management

    /// Create a new session in the database
    private func createSession(deviceUUID: String) async {
        do {
            let sessionId = try await supabaseClient.startSession(
                deviceId: deviceUUID,
                appId: appId
            )

            queue.async(flags: .barrier) {
                self.sessionId = sessionId
                RFLogger.shared.info("✅ Session created with ID: \(sessionId)")
            }

            // Start heartbeat timer on main thread
            await MainActor.run {
                self.startHeartbeat()
            }

        } catch {
            RFLogger.shared.error("❌ Failed to create session", error: error)
            // Retry after delay
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            if isActive {
                await createSession(deviceUUID: deviceUUID)
            }
        }
    }

    /// End the active session
    private func endActiveSession(sessionId: String) async {
        do {
            try await supabaseClient.endSession(sessionId: sessionId)
            queue.async(flags: .barrier) {
                self.sessionId = nil
            }
        } catch {
            RFLogger.shared.error("❌ Failed to end session", error: error)
        }
    }

    // MARK: - Heartbeat

    /// Start the heartbeat timer
    @MainActor
    private func startHeartbeat() {
        // Cancel any existing timer
        heartbeatTimer?.invalidate()

        // Create new timer
        heartbeatTimer = Timer.scheduledTimer(
            withTimeInterval: heartbeatInterval,
            repeats: true
        ) { [weak self] _ in
            guard let self = self else { return }
            Task {
                await self.sendHeartbeat()
            }
        }

        // Ensure timer runs in all run loop modes
        if let timer = heartbeatTimer {
            RunLoop.main.add(timer, forMode: .common)
        }

        RFLogger.shared.debug("💓 Heartbeat timer started (interval: \(heartbeatInterval)s)")
    }

    /// Stop the heartbeat timer
    private func stopHeartbeat() {
        DispatchQueue.main.async {
            self.heartbeatTimer?.invalidate()
            self.heartbeatTimer = nil
            RFLogger.shared.debug("💔 Heartbeat timer stopped")
        }
    }

    /// Send heartbeat to server
    private func sendHeartbeat(retryCount: Int = 0) async {
        guard isActive, let sessionId = sessionId else { return }

        do {
            try await supabaseClient.sendHeartbeat(sessionId: sessionId)
        } catch {
            RFLogger.shared.error("❌ Heartbeat failed (attempt \(retryCount + 1)/\(maxRetryAttempts))", error: error)

            // Retry with exponential backoff
            if retryCount < maxRetryAttempts {
                let delay = pow(2.0, Double(retryCount)) // 1s, 2s, 4s
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                await sendHeartbeat(retryCount: retryCount + 1)
            }
        }
    }

    // MARK: - Lifecycle Observers

    private func setupLifecycleObservers() {
        #if canImport(UIKit) && !os(watchOS)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
        #endif

        RFLogger.shared.debug("Lifecycle observers registered")
    }

    private func removeLifecycleObservers() {
        #if canImport(UIKit) && !os(watchOS)
        NotificationCenter.default.removeObserver(self)
        RFLogger.shared.debug("Lifecycle observers removed")
        #endif
    }

    #if canImport(UIKit) && !os(watchOS)
    @objc private func appDidEnterBackground() {
        RFLogger.shared.debug("📱 App entered background - pausing heartbeat")
        stopHeartbeat()

        // Send one final heartbeat
        if let sessionId = sessionId {
            Task {
                try? await supabaseClient.sendHeartbeat(sessionId: sessionId)
            }
        }
    }

    @objc private func appWillEnterForeground() {
        RFLogger.shared.debug("📱 App entering foreground - resuming heartbeat")

        // Send immediate heartbeat
        if let sessionId = sessionId {
            Task {
                try? await supabaseClient.sendHeartbeat(sessionId: sessionId)
            }
        }

        // Restart timer on main thread
        Task { @MainActor in
            self.startHeartbeat()
        }
    }

    @objc private func appWillTerminate() {
        RFLogger.shared.debug("📱 App will terminate - ending session")
        stopSession()
    }
    #endif

    // MARK: - Public Helpers

    /// Get the current session ID
    var currentSessionId: String? {
        queue.sync { sessionId }
    }

    /// Check if session tracking is active
    var isSessionActive: Bool {
        queue.sync { isActive }
    }

    deinit {
        stopSession()
        removeLifecycleObservers()
    }
}
