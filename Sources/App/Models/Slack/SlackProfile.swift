//
//  SlackProfile.swift
//  App
//
//  Created by Tyler Milner on 11/16/17.
//

import Vapor

/// Represents a Slack user's profile.
/// Currently, we're only interested in the profile's name and status text.
struct SlackProfile: Content {
    let realName: String
    let statusText: String?
    
    enum CodingKeys: String, CodingKey {
        case realName = "real_name"
        case statusText = "status_text"
    }
}
