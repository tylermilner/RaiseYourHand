//
//  SlackListUsersResponse.swift
//  App
//
//  Created by Tyler Milner on 11/21/17.
//

import Vapor

/// Represents Slack's API response to a "list users" call.
struct SlackListUsersResponse: Content {
    let ok: Bool
    let members: [SlackUser]
}
