//
//  SSEEvent.swift
//  ClaudeIsland
//
//  TmuxWeb SSE event model.
//  Maps events from the TmuxWeb /api/tasks/events/stream endpoint.
//

import Foundation

/// Event types from TmuxWeb SSE stream
enum SSEEventType: String, Codable, Sendable {
    case taskStarted = "task_started"
    case taskCompleted = "task_completed"
    case taskFailed = "task_failed"
    case taskWaiting = "task_waiting"
}

/// A single SSE event from TmuxWeb
struct SSEEvent: Sendable {
    let type: SSEEventType
    let conversationId: String
    let paneKey: String
    let userMessage: String?
    let assistantMessage: String?
    let timestamp: Int  // Unix epoch seconds

    enum CodingKeys: String, CodingKey {
        case type
        case conversationId = "conversation_id"
        case paneKey = "pane_key"
        case userMessage = "user_message"
        case assistantMessage = "assistant_message"
        case timestamp
    }
}

// MARK: - Codable (handles timestamp as Int or String)

extension SSEEvent: Codable {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        type = try c.decode(SSEEventType.self, forKey: .type)
        conversationId = try c.decode(String.self, forKey: .conversationId)
        paneKey = try c.decodeIfPresent(String.self, forKey: .paneKey) ?? ""
        userMessage = try c.decodeIfPresent(String.self, forKey: .userMessage)
        assistantMessage = try c.decodeIfPresent(String.self, forKey: .assistantMessage)
        // TmuxWeb sends timestamp as integer (unix epoch), but handle String too
        if let intVal = try? c.decode(Int.self, forKey: .timestamp) {
            timestamp = intVal
        } else if let strVal = try? c.decode(String.self, forKey: .timestamp),
                  let parsed = Int(strVal) {
            timestamp = parsed
        } else {
            timestamp = Int(Date().timeIntervalSince1970)
        }
    }
}

// MARK: - Computed Properties

extension SSEEvent {
    var projectName: String {
        let parts = paneKey.split(separator: ":")
        return parts.first.map(String.init) ?? paneKey
    }

    var sessionPhase: SessionPhase {
        switch type {
        case .taskStarted:
            return .processing
        case .taskCompleted, .taskFailed, .taskWaiting:
            return .waitingForInput
        }
    }

    var displayMessage: String? {
        switch type {
        case .taskStarted:
            return userMessage
        case .taskCompleted, .taskFailed, .taskWaiting:
            return assistantMessage ?? userMessage
        }
    }

    var displayMessageRole: String {
        switch type {
        case .taskStarted:
            return "user"
        case .taskCompleted, .taskFailed, .taskWaiting:
            return "assistant"
        }
    }
}

// MARK: - Debug Description

extension SSEEvent: CustomStringConvertible {
    var description: String {
        "SSEEvent(\(type.rawValue), conv: \(conversationId.prefix(8)), pane: \(paneKey))"
    }
}
