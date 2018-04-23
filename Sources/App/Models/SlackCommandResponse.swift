//
//  SlackCommandResponse.swift
//  App
//
//  Created by Tyler Milner on 11/21/17.
//

import Foundation
import JSON

/// Represents a server response to a Slack slash command.
/// This is the response object that our server sends back to Slack after being invoked by the slash command.
struct SlackCommandResponse {
    enum ResponseType: String, Encodable {
        case inChannel = "in_channel"
        case ephemeral = "ephemeral"
    }
    
    let responseType: ResponseType
    let text: String?
}

extension SlackCommandResponse:  JSONRepresentable {
    func makeJSON() throws -> JSON {
        var json = JSON()
        try json.set("response_type", responseType.rawValue)
        try json.set("text", text)
        return json
    }
}
