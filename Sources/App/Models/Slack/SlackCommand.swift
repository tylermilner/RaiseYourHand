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
    
    // TODO: Convert this to camelCase.
    //       This is technically sent to us as a url-encoded form so I don't think Vapor applies the JSONDecoder's 'convertToSnakeCase' for the name of this property.
    let response_url: String
}
