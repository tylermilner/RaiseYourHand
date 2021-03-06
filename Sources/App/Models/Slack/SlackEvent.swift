//
//  SlackEvent.swift
//  App
//
//  Created by Tyler Milner on 11/16/17.
//

import Vapor

/// Represents a Slack event.
/// This is an event that Slack sends to our server when something in the workspace changes.
/// Currently, we're only interested in the 'user_change' event.
struct SlackEvent: Content {
    enum EventType: String, Content {
        case userChange = "user_change"
    }
    
    let type: EventType
    let user: SlackUser
}
