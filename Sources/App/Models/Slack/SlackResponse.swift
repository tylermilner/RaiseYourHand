//
//  SlackResponse.swift
//  App
//
//  Created by Tyler Milner on 11/16/17.
//

import Vapor

/// Represents a response from the Slack web API.
/// This is the payload object that's delivered to our server when Slack sends it a message.
/// This is used for the initial server URL verification (when our Slack app is installed into the workspace).
/// This is also used for Slack event callbacks (when Slack notifies our server that something in the workspace changed - like a user's status message update).
struct SlackResponse: Content {
    enum EventType: String, Content {
        case urlVerification = "url_verification"
        case eventCallback = "event_callback"
    }
    
    let type: EventType
    let token: String
    let challenge: String?
    let event: SlackEvent?
}
