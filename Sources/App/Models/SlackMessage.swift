//
//  SlackMessage.swift
//  App
//
//  Created by Tyler Milner on 11/16/17.
//

import Foundation

/// Represents a Slack chat message.
/// Used to post messages into Slack channels via the app's "Incoming Webhooks".
struct SlackMessage {
    let text: String
}

extension SlackMessage: JSONRepresentable {
    func makeJSON() throws -> JSON {
        var json = JSON()
        try json.set("text", text)
        return json
    }
}
