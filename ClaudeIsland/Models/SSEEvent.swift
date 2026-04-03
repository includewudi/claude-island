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
struct SSEEvent: Codable, Sendable {
    let type: SSEEventType
    let conversationId: String
    let paneKey: String
    let userMessage: String?
    let assistantMessage: String?
    let timestamp: String

    enum CodingKeys: String, CodingKey {
        case type
        case conversationId = "conversation_id"
        case paneKey = "pane_key"
        case userMessage = "user_message"
        case assistantMessage = "assistant_message"
        case timestamp
    }

    /// Derive a display-friendly project name from pane_key (e.g., "my-session:0:1" → "my-session")
    var projectName: String {
        let parts = paneKey.split(separator: ":")
        return parts.first.map(String.init) ?? paneKey
    }

    /// Map SSE event type to SessionPhase
    var sessionPhase: SessionPhase {
        switch type {
        case .taskStarted:
            return .processing
        case .taskCompleted, .taskFailed, .taskWaiting:
            return .waitingForInput
        }
    }

    /// The most relevant message to display
    var displayMessage: String? {
        switch type {
        case .taskStarted:
            return userMessage
        case .taskCompleted, .taskFailed, .taskWaiting:
            return assistantMessage ?? userMessage
        }
    }

    /// The role of the display message
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
