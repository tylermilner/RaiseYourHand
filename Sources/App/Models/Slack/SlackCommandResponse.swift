//
//  SlackCommandResponse.swift
//  App
//
//  Created by Tyler Milner on 11/21/17.
//

import Vapor

/// Represents a server response to a Slack slash command.
/// This is the response object that our server sends back to Slack after being invoked by the slash command.
struct SlackCommandResponse: Content {
    // TODO: Might be able to remove the manual 'rawValue' definitions here since the ContentConfig is configured to convert to snake_case
    enum ResponseType: String, Content {
        case inChannel = "in_channel"
        case ephemeral = "ephemeral"
    }
    
    let responseType: ResponseType
    let text: String?
}
