//
//  SlackListUsersResponse.swift
//  App
//
//  Created by Tyler Milner on 11/21/17.
//

import Foundation
import JSON

/// Represents Slack's API response to a "list users" call.
struct SlackListUsersResponse {
    let ok: Bool
    let members: [SlackUser]
}

extension SlackListUsersResponse: JSONInitializable {
    init(json: JSON) throws {
        ok = try json.get("ok")
        members = try json.get("members")
    }
}
