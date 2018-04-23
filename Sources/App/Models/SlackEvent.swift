//
//  SlackEvent.swift
//  App
//
//  Created by Tyler Milner on 11/16/17.
//

import Foundation
import JSON

/// Represents a Slack event.
/// This is an event that Slack sends to our server when something in the workspace changes.
/// Currently, we're only interested in the 'user_change' event.
struct SlackEvent {
    enum EventType: String {
        case userChange = "user_change"
    }
    
    let type: EventType
    let user: SlackUser
}

extension SlackEvent: JSONInitializable {
    init(json: JSON) throws {
        type = try json.get("type")
        user = try json.get("user")
    }
}

extension SlackEvent.EventType: JSONInitializable {
    init(json: JSON) throws {
        guard let rawValue: String = json.string, let type = SlackEvent.EventType(rawValue: rawValue) else { throw JSONError.badValue(json.string) }
        self = type
    }
}
