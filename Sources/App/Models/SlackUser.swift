//
//  SlackUser.swift
//  App
//
//  Created by Tyler Milner on 11/16/17.
//

import Vapor

/// Represents a user in a Slack workspace.
struct SlackUser: Content {
    let id: String
    let profile: SlackProfile
}
