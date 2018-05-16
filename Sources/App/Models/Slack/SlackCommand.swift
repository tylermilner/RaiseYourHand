//
//  SlackCommand.swift
//  App
//
//  Created by Tyler Milner on 5/14/18.
//

import Vapor

/// Represents the data sent to our app when the user invokes a Slack "slash command".
struct SlackCommand: Content {
    let token: String
    let responseURL: String
    
    enum CodingKeys: String, CodingKey {
        case token
        case responseURL = "response_url"
    }
}
