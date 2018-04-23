//
//  SlackUser.swift
//  App
//
//  Created by Tyler Milner on 11/16/17.
//

import Foundation
import JSON

/// Represents a user in a Slack workspace.
struct SlackUser {
    let id: String
    let profile: SlackProfile
}

extension SlackUser: JSONInitializable {
    init(json: JSON) throws {
        id = try json.get("id")
        profile = try json.get("profile")
    }
}
