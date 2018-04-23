//
//  SlackProfile.swift
//  App
//
//  Created by Tyler Milner on 11/16/17.
//

import Foundation
import JSON

/// Represents a Slack user's profile.
/// Currently, we're only interested in the profile's name and status text.
struct SlackProfile {
    let realName: String
    let statusText: String?
}

extension SlackProfile: JSONInitializable {
    init(json: JSON) throws {
        realName = try json.get("real_name")
        statusText = try json.get("status_text")
    }
}
