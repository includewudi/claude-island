//
//  SSEClient.swift
//  ClaudeIsland
//
//  SSE (Server-Sent Events) client for TmuxWeb task notifications.
//  Connects to the TmuxWeb SSE endpoint, parses events, and feeds
//  them into the unified SessionStore state machine.
//

import Foundation
import os.log

/// SSE client that connects to TmuxWeb and streams task events
actor SSEClient {
    static let shared = SSEClient()

    private static let logger = Logger(subsystem: "com.claudeisland", category: "SSE")

    // MARK: - State

    private var task: Task<Void, Never>?
    private var isConnected = false
    private var reconnectAttempts = 0
    private let maxReconnectDelay: TimeInterval = 30

    // MARK: - Lifecycle

    func start() {
        guard task == nil else {
            Self.logger.debug("SSE client already running")
            return
        }

        guard AppSettings.sseEnabled,
              let urlString = AppSettings.sseEndpointURL,
              !urlString.isEmpty else {
            Self.logger.info("SSE not configured or disabled")
            return
        }

        Self.logger.info("Starting SSE client → \(urlString, privacy: .public)")
        task = Task { [weak self] in
            await self?.connectLoop()
        }
    }

    func stop() {
        Self.logger.info("Stopping SSE client")
        task?.cancel()
        task = nil
        isConnected = false
        reconnectAttempts = 0
    }

    var running: Bool {
        task != nil && isConnected
    }

    // MARK: - Connection Loop

    private func connectLoop() async {
        while !Task.isCancelled {
            do {
                try await connect()
            } catch is CancellationError {
                break
            } catch {
                Self.logger.error("SSE connection error: \(error.localizedDescription, privacy: .public)")
            }

            isConnected = false
            reconnectAttempts += 1
            let delay = min(pow(2.0, Double(reconnectAttempts)), maxReconnectDelay)
            Self.logger.info("SSE reconnecting in \(delay, privacy: .public)s (attempt \(self.reconnectAttempts, privacy: .public))")

            do {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            } catch {
                break  // Cancelled during sleep
            }
        }
    }

    // MARK: - SSE Connection

    private func connect() async throws {
        guard let urlString = AppSettings.sseEndpointURL,
              let url = URL(string: urlString) else {
            throw SSEError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.timeoutInterval = 0  // No timeout for SSE

        // Add auth token if configured
        if let token = AppSettings.sseAuthToken, !token.isEmpty {
            request.setValue(token, forHTTPHeaderField: "x-auth-token")
        }

        let session = URLSession(configuration: .default, delegate: SSESessionDelegate(), delegateQueue: nil)
        let (bytes, response) = try await session.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw SSEError.httpError(code)
        }

        Self.logger.info("SSE connected successfully")
        isConnected = true
        reconnectAttempts = 0

        // Parse SSE stream line by line
        var dataBuffer = ""
        for try await line in bytes.lines {
            if Task.isCancelled { break }

            if line.hasPrefix("data: ") {
                dataBuffer = String(line.dropFirst(6))
            } else if line.isEmpty && !dataBuffer.isEmpty {
                // Empty line = end of event
                await processSSEData(dataBuffer)
                dataBuffer = ""
            }
        }
    }

    // MARK: - Event Processing

    private func processSSEData(_ data: String) async {
        // Skip heartbeat/comment events
        guard !data.isEmpty, data != "heartbeat" else { return }

        guard let jsonData = data.data(using: .utf8) else {
            Self.logger.warning("SSE: invalid UTF-8 data")
            return
        }

        do {
            let event = try JSONDecoder().decode(SSEEvent.self, from: jsonData)
            Self.logger.debug("SSE event: \(String(describing: event), privacy: .public)")
            await SessionStore.shared.process(.sseEventReceived(event))
        } catch {
            Self.logger.warning("SSE: failed to decode event: \(error.localizedDescription, privacy: .public)")
        }
    }
}

// MARK: - SSL Delegate (trust self-signed certs for local TmuxWeb)

private class SSESessionDelegate: NSObject, URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // Trust self-signed certificates for local development
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

// MARK: - Errors

enum SSEError: LocalizedError {
    case invalidURL
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid SSE endpoint URL"
        case .httpError(let code):
            return "SSE HTTP error: \(code)"
        }
    }
}
