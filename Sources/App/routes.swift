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
        
        return try request.content.decode(SlackResponse.self).flatMap(to: String.self) { slackResponse in
            logger.info("Verifying Slack token...")
            
            try verifySlackToken(slackResponse.token, for: environmentConfig)
            
            switch slackResponse.type {
            case .urlVerification:
                logger.info("Handling Slack URL verfication event...")
                
                guard let challenge = slackResponse.challenge else {
                    throw Abort(.badRequest, reason: "Missing challenge")
                }
                
                logger.info("Responding to Slack URL verification with challenge: '\(challenge)'.")
                
                return request.eventLoop.newSucceededFuture(result: challenge)
            case .eventCallback:
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
                guard profile.status_text == raiseHandStatusText  else {
                    logger.info("Ignoring non-'\(raiseHandStatusText)' status text change.")
                    return request.eventLoop.newSucceededFuture(result: HTTPStatus.ok.reasonPhrase)
                }
                
                logger.info("Handling '\(raiseHandStatusText)' status text change...")
                
                let availableToHelpMessage = "<!here> \(profile.real_name) is '\(raiseHandStatusText)'"
                
                logger.info("Posting to Slack: '\(availableToHelpMessage)'.")
                
                let client = try request.make(Client.self)
                
                return try sendSlackMessage(message: availableToHelpMessage, using: client, environmentConfig: environmentConfig).flatMap({ (response) -> Future<String> in
                    let slackResponse = response.http.body.description
                    
                    logger.info("Slack responded with: '\(slackResponse)'.")
                    
                    return request.eventLoop.newSucceededFuture(result: slackResponse)
                })
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
        
        return try request.content.decode(SlackCommand.self).flatMap(to: SlackCommandResponse.self) { slackCommand in
            logger.info("Verifying Slack token...")
            
            try verifySlackToken(slackCommand.token, for: environmentConfig)
            
            let client = try request.make(Client.self)
            
            logger.info("Issuing '\(SlackAPI.listUsersURL)' command to Slack...")
            
            // TODO: Fix the async aspect of this. We should immediately respond with a "Checking for users..." message and then perform the actual Slack "users.list" query. Fulfill the slash command by performing a POST on the command's 'response_url'.
            //       Slack will consider the slash command as having failed if we don't respond within 3 seconds. Luckily, querying the Slack API seems to be fast enough that we don't have to worry about this for now.
            return try getSlackProfilesAvailableToHelp(using: client, environmentConfig: environmentConfig).flatMap({ (response) -> Future<SlackCommandResponse> in
                // TODO: Implement support for pagination on this response. By default, Slack will currently try to include everyone's profile in the response.
                //          Eventually, pagination will be required - https://api.slack.com/methods/users.list#pagination
                return try response.content.decode(SlackListUsersResponse.self).flatMap({ (slackListUsersResponse) -> Future<SlackCommandResponse> in
                    logger.info("Slack list users response: '\(slackListUsersResponse)'")
                    
                    // Return user profiles who's status is "Available to Help"
                    let availableToHelpStatusText = environmentConfig.raiseHandStatusText
                    let userProfiles = slackListUsersResponse.members.compactMap { $0.profile }
                    
                    let availableToHelpProfiles = userProfiles.filter { $0.status_text == availableToHelpStatusText }
                    
                    logger.info("Users '\(availableToHelpStatusText)': '\(availableToHelpProfiles)'")
                    
                    // Build the response message containing the names of people that are "Available to Help"
                    let availableToHelpList: String = availableToHelpProfiles.reduce("", { (result, profile) -> String in
                        let userName = profile.real_name
                        return result.isEmpty ? userName : "\(result)\n\(userName)"
                    })
                    let availableToHelpResponseMessage: String = availableToHelpList.isEmpty ? "No one is '\(availableToHelpStatusText)' :(" : "These people are '\(availableToHelpStatusText)':\n\n\(availableToHelpList)"
                    
                    let slashCommandResponse = SlackCommandResponse(response_type: .inChannel, text: availableToHelpResponseMessage)
                    
                    logger.info("Responding to Slack with response: '\(slashCommandResponse)'")
                    
                    return request.eventLoop.newSucceededFuture(result: slashCommandResponse)
                })
            })
        }
    }
}

private func verifySlackToken(_ token: String, for environmentConfig: EnvironmentConfig) throws {
    guard token == environmentConfig.verificationToken else {
        throw Abort(.badRequest, reason: "Invalid verification token")
    }
}

private func sendSlackMessage(message: String, using client: Client, environmentConfig: EnvironmentConfig) throws -> Future<Response> {
    let slackMessage = SlackMessage(text: message)
    return client.post(environmentConfig.webhookURL, content: slackMessage)
}

private func getSlackProfilesAvailableToHelp(using client: Client, environmentConfig: EnvironmentConfig) throws -> Future<Response> {
    // Query the Slack API with the "users.list" command
    return client.post(SlackAPI.listUsersURL, headers: ["Authorization": "Bearer \(environmentConfig.oAuthAccessToken)"], beforeSend: { _ in })
}
