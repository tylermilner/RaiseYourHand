//
//  SlackMessage.swift
//  App
//
//  Created by Tyler Milner on 11/16/17.
//

import Vapor

/// Represents a Slack chat message.
/// Used to post messages into Slack channels via the app's "Incoming Webhooks".
struct SlackMessage: Content {
    let text: String
}
