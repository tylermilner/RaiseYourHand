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
    enum ResponseType: String, Content {
        case inChannel = "in_channel"
        case ephemeral = "ephemeral"
    }
    
    let responseType: ResponseType
    let text: String?
    
    enum CodingKeys: String, CodingKey {
        case responseType = "response_type"
        case text
    }
}
