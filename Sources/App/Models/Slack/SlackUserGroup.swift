//
//  SlackUserGroup.swift
//  App
//
//  Created by Tyler Milner on 5/16/18.
//

import Vapor

struct SlackUserGroup: Content {
    let id: String
    let name: String
    let users: [String] // array of Slack user IDs
}
