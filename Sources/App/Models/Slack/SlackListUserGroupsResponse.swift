//
//  SlackListUserGroupsResponse.swift
//  App
//
//  Created by Tyler Milner on 5/16/18.
//

import Vapor

struct SlackListUserGroupsResponse: Content {
    let usergroups: [SlackUserGroup]
}
