import Routing
import Vapor

/// Register your application's routes here.
///
/// [Learn More →](https://docs.vapor.codes/3.0/getting-started/structure/#routesswift)
public func routes(_ router: Router) throws {
    
    // GET /info
        // Return request description
    router.get("info") { request in
        return request.description
    }
    
    // POST /slack/events
        // This endpoint is triggered by editing the Slack app's "Request URL" of the "Event Subscriptions" section in Slack app configuration portal
        // For more info, see Slack API documentation - https://api.slack.com/events/url_verification
            // Slack sends a "SlackResponse" to first authenticate with the server
                // Incoming payload from Slack looks like:
                //
                //    {
                //            "token": "kgs0ur776H4W29l9nk8cvJ4x",
                //            "challenge": "kVVx1pKB5PoeTnEjN5d7DJ3cnwNCadDMm1YUmzH9owq43fY6mh3U",
                //            "type": "url_verification"
                //    }
                //
            // We need to respond with the value of the 'challenge' parameter
                // Simplely return the value as plaintext:
                // HTTP 200 OK
                // Content-type: text/plain
                // <value_of_challenge>
        // This endpoint is also triggered (after the "url_verification" event) when changes are made in the Slack workspace
            // If the type of the event is "user_change", then we need to check if that user changed their status text to "Available to Help"
                // When this happens, we need to issue a POST request to the Slack webhook URL so that we post a message into the room to notify users that someone is "Available to Help"
    router.post("slack/events") { request -> Future<String> in
        let logger = try request.make(Logger.self)
        let environmentConfig = try request.make(EnvironmentConfig.self)
        
        return try request.content.decode(SlackResponse.self).flatMap { slackResponse in
            try verifySlackToken(slackResponse.token, for: environmentConfig, logger: logger)
            
            switch slackResponse.type {
            case .urlVerification:
                return try handleSlackURLVerification(for: slackResponse, request: request, logger: logger)
            case .eventCallback:
                return try handleSlackEventCallback(for: slackResponse, request: request, environmentConfig: environmentConfig, logger: logger)
            }
        }
    }
    
    // POST /slack/commands/availableToHelp
        // This command is triggered when a user types "/availabletohelp"
            // Slack will send a URL-encoded form containing details about the origin of the command
            // Incoming payload from Slack looks something like:
            //        channel_id    UBBGD8OBQ
            //        channel_name    xtest-raiseyourhand
            //        command    /availabletohelp
            //        response_url    https://hooks.slack.com/commands/T5GHV71RY/361569732863/mKywyu8MEUnUPZ2LkgQnY7M3
            //        team_domain    bottlerocketstudios
            //        team_id    T5HHV94RZ
            //        text
            //        token    kgs0ur776H4W29l9nk8cvJ4x
            //        trigger_id    359624058792.181617306883.23143941fb118591836c13a13a90e9e4
            //        user_id    U82CGLEFZ
            //        user_name    tyler.milner
        // Things to note are the 'token' (to verify the request actually came from Slack) and the 'response_url' (where you should send your response to the user's slash command)
    router.post("slack/commands/availableToHelp") { (request) -> Future<SlackCommandResponse> in
        let logger = try request.make(Logger.self)
        let environmentConfig = try request.make(EnvironmentConfig.self)
        
        logger.info("Handling 'availableToHelp' command...")
        
        return try request.content.decode(SlackCommand.self).flatMap { slackCommand in
            try verifySlackToken(slackCommand.token, for: environmentConfig, logger: logger)
            
            let client = try request.make(Client.self)
            
            // TODO: Fix the async aspect of this. We should immediately respond with a "Checking for users..." message and then perform the actual Slack "users.list" query. Fulfill the slash command by performing a POST on the command's 'response_url'.
            //       Slack will consider the slash command as having failed if we don't respond within 3 seconds. Luckily, querying the Slack API seems to be fast enough that we don't have to worry about this for now.
            return try getSlackUsers(using: client, environmentConfig: environmentConfig, logger: logger).flatMap { response in
                // TODO: Implement support for pagination on this response. By default, Slack will currently try to include everyone's profile in the response.
                //          Eventually, pagination will be required - https://api.slack.com/methods/users.list#pagination
                return try response.content.decode(SlackListUsersResponse.self).flatMap { slackListUsersResponse in
                    logger.info("Slack list users response: '\(slackListUsersResponse)'")
                    
                    let raiseHandStatusText = environmentConfig.raiseHandStatusText
                    let availableToHelpProfiles = filterAvailableToHelpProfiles(from: slackListUsersResponse, raiseHandStatusText: raiseHandStatusText, logger: logger)
                    
                    let availableToHelpResponseMessage = buildAvailableToHelpListResponseMessage(from: availableToHelpProfiles, raiseHandStatusText: raiseHandStatusText)
                    let slashCommandResponse = SlackCommandResponse(responseType: .inChannel, text: availableToHelpResponseMessage)
                    
                    logger.info("Responding to Slack with response: '\(slashCommandResponse)'")
                    
                    return request.eventLoop.newSucceededFuture(result: slashCommandResponse)
                }
            }
        }
    }
}

private func buildAvailableToHelpListResponseMessage(from availableToHelpProfiles: [SlackProfile], raiseHandStatusText: String) -> String {
    // Build the response message containing the names of people that are "Available to Help"
    let availableToHelpList: String = availableToHelpProfiles.reduce("", { (result, profile) -> String in
        let userName = profile.realName
        return result.isEmpty ? userName : "\(result)\n\(userName)"
    })
    return availableToHelpList.isEmpty ? "No one is '\(raiseHandStatusText)' :(" : "These people are '\(raiseHandStatusText)':\n\n\(availableToHelpList)"
}

private func filterAvailableToHelpProfiles(from slackListUsersResponse: SlackListUsersResponse, raiseHandStatusText: String, logger: Logger) -> [SlackProfile] {
    // Return user profiles who's status is "Available to Help"
    
    let userProfiles = slackListUsersResponse.members.compactMap { $0.profile }
    
    let availableToHelpProfiles = userProfiles.filter { $0.statusText == raiseHandStatusText }
    
    logger.info("Users '\(raiseHandStatusText)': '\(availableToHelpProfiles)'")
    
    return availableToHelpProfiles
}

private func handleSlackEventCallback(for slackResponse: SlackResponse, request: Request, environmentConfig: EnvironmentConfig, logger: Logger) throws -> Future<String> {
    guard let event = slackResponse.event else {
        throw Abort(.badRequest, reason: "Missing event")
    }
    
    logger.info("Handling Slack '\(event)' event...")
    
    // Only interested in the "user_change" event type (to observe status changes)
    let userChangeEventType: SlackEvent.EventType = .userChange
    guard event.type == userChangeEventType else {
        logger.info("Ignoring '\(event.type) event.")
        return request.eventLoop.newSucceededFuture(result: HTTPStatus.ok.reasonPhrase)
    }
    
    logger.info("Handling \(userChangeEventType.rawValue) event...")
    
    let user = event.user
    let profile = user.profile
    
    // Only interested in "user_change" events changing to the "Available to Help" status
    let raiseHandStatusText = environmentConfig.raiseHandStatusText
    guard profile.statusText == raiseHandStatusText  else {
        logger.info("Ignoring non-'\(raiseHandStatusText)' status text change.")
        return request.eventLoop.newSucceededFuture(result: HTTPStatus.ok.reasonPhrase)
    }
    
    logger.info("Handling '\(raiseHandStatusText)' status text change...")
    
    let client = try request.make(Client.self)
    
    // Get all slack users groups (usergroups.list slack API call)
    return try getSlackUserGroups(using: client, environmentConfig: environmentConfig, logger: logger).flatMap { response in
        return try response.content.decode(SlackListUserGroupsResponse.self).flatMap { listUserGroupsResponse in
            logger.info("Determining which group '\(profile.realName)' belongs to...")
            
            // Figure out the discipline that this user belongs to (which slack group they belong to)
            let group = userGroup(correspondingTo: user, in: listUserGroupsResponse.usergroups, environmentConfig: environmentConfig)
            
            logger.info("User '\(profile.realName)' belongs to group '\(group?.name ?? "<no group>")'.")
            
            // Post the "<user> is available to help" message into the room that corresponds to that slack group
            return try postAvailableToHelpMessage(forProfile: profile, group: group, using: client, environmentConfig: environmentConfig, logger: logger).flatMap { response in
                let slackResponse = response.http.body.description
                
                logger.info("Slack responded with: '\(slackResponse)'.")
                
                return request.eventLoop.newSucceededFuture(result: slackResponse)
            }
        }
    }
}

private func webhookURL(forGroupId groupId: String, environmentConfig: EnvironmentConfig) -> String {
    switch groupId {
    case environmentConfig.engGroupId:
        return environmentConfig.engWebhookURL
    case environmentConfig.pmGroupId:
        return environmentConfig.pmWebhookURL
    case environmentConfig.qaGroupId:
        return environmentConfig.qaWebhookURL
    case environmentConfig.xdGroupId, environmentConfig.adGroupId:
        return environmentConfig.xdWebhookURL
    default:
        return environmentConfig.generalWebhookURL
    }
}

private func postAvailableToHelpMessage(forProfile profile: SlackProfile, group: SlackUserGroup?, using client: Client, environmentConfig: EnvironmentConfig, logger: Logger) throws -> Future<Response> {
    let url = group.flatMap { webhookURL(forGroupId: $0.id, environmentConfig: environmentConfig) } ?? environmentConfig.generalWebhookURL
    
    let availableToHelpMessage = "<!here> \(profile.realName) is '\(environmentConfig.raiseHandStatusText)'"
    
    logger.info("Posting to Slack: '\(availableToHelpMessage)'.")
    
    return try sendSlackMessage(message: availableToHelpMessage, toWebhookURL: url, using: client)
}

private func userGroup(correspondingTo user: SlackUser, in userGroups: [SlackUserGroup], environmentConfig: EnvironmentConfig) -> SlackUserGroup? {
    let disciplineUserGroups = userGroups.filter { userGroupIsDisciplineUserGroup($0, environmentConfig: environmentConfig) }
    return disciplineUserGroups.first(where: { $0.users.contains(user.id) })
}

private func userGroupIsDisciplineUserGroup(_ userGroup: SlackUserGroup, environmentConfig: EnvironmentConfig) -> Bool {
    let disciplineUserGroupIds = [environmentConfig.engGroupId,
                                  environmentConfig.qaGroupId,
                                  environmentConfig.pmGroupId,
                                  environmentConfig.xdGroupId,
                                  environmentConfig.adGroupId]
    return disciplineUserGroupIds.contains(userGroup.id)
}

private func getSlackUserGroups(using client: Client, environmentConfig: EnvironmentConfig, logger: Logger) throws -> Future<Response> {
    logger.info("Issuing '\(SlackAPI.listUserGroupsURL)' command to Slack...")
    
    // Query the Slack API with the "usergroups.list" command
    return client.get(SlackAPI.listUserGroupsURL, headers: ["Authorization": "Bearer \(environmentConfig.oAuthAccessToken)"], beforeSend: { _ in })
}

private func handleSlackURLVerification(for slackResponse: SlackResponse, request: Request, logger: Logger) throws -> Future<String> {
    logger.info("Handling Slack URL verfication event...")
    
    guard let challenge = slackResponse.challenge else {
        throw Abort(.badRequest, reason: "Missing challenge")
    }
    
    logger.info("Responding to Slack URL verification with challenge: '\(challenge)'.")
    
    return request.eventLoop.newSucceededFuture(result: challenge)
}

private func verifySlackToken(_ token: String, for environmentConfig: EnvironmentConfig, logger: Logger) throws {
    logger.info("Verifying Slack token...")
    
    guard token == environmentConfig.verificationToken else {
        throw Abort(.badRequest, reason: "Invalid verification token")
    }
}

private func sendSlackMessage(message: String, toWebhookURL webhookURL: String, using client: Client) throws -> Future<Response> {
    let slackMessage = SlackMessage(text: message)
    return client.post(webhookURL, content: slackMessage)
}

private func getSlackUsers(using client: Client, environmentConfig: EnvironmentConfig, logger: Logger) throws -> Future<Response> {
    logger.info("Issuing '\(SlackAPI.listUsersURL)' command to Slack...")
    
    // Query the Slack API with the "users.list" command
    return client.get(SlackAPI.listUsersURL, headers: ["Authorization": "Bearer \(environmentConfig.oAuthAccessToken)"], beforeSend: { _ in })
}
