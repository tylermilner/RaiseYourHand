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
        // For the "Event Subscriptions" feature in the Slack App, we need to handle
        // Editing the "Request URL" in the "Event Subscriptions" feature in the configuration page for the Slack app
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
        // Once we respond to the "url_verification" event, we will begin to receive Slack events that are ocurring in the Slack workspace
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
                guard profile.statusText == raiseHandStatusText  else {
                    logger.info("Ignoring non-'\(raiseHandStatusText)' status text.")
                    return request.eventLoop.newSucceededFuture(result: HTTPStatus.ok.reasonPhrase)
                }
                
                logger.info("Handling '\(raiseHandStatusText)' status text...")
                
                let availableToHelpMessage = "<!here> \(profile.realName) is '\(raiseHandStatusText)'"
                
                logger.info("Posting to Slack: '\(availableToHelpMessage)'")
                
                let client = try request.make(Client.self)
                
                return try sendSlackMessage(message: availableToHelpMessage, using: client, environmentConfig: environmentConfig).flatMap(to: String.self, { response in
                    return try response.content.decode(String.self)
                })
            }
        }
    }
    
//    router.post(["slack", "events"]) { request in
//        guard let availableToHelpStatusText = self.config["slack", "availableToHelpStatusText"]?.string else {
//            throw Abort(.internalServerError, reason: "'availableToHelpStatusText' not properly configured in 'slack.json' config")
//        }
//        guard let json = request.json else {
//            throw Abort(.badRequest, reason: "Invalid JSON")
//        }
//
//        let response = try SlackResponse(json: json)
//        self.log.info("Received Slack response: '\(response)'")
//
//        try self.verifySlackToken(response.token)
//
//        switch response.type {
//        case .urlVerification:
//            guard let challenge = response.challenge else {
//                throw Abort(.badRequest, reason: "Missing challenge")
//            }
//
//            self.log.info("Handling Slack URL verification. Responding with challenge: '\(challenge)'")
//
//            return challenge
//        case .eventCallback:
//            guard let event = response.event else {
//                throw Abort(.badRequest, reason: "Missing event")
//            }
//
//            self.log.info("Handling Slack event callback: '\(event)'")
//
//            // Only interested in the "user_change" event type (to observe status changes)
//            guard event.type == .userChange else {
//                self.log.info("Not a '\(SlackEvent.EventType.userChange.rawValue)' event. Ignoring...")
//                return Response(status: .ok)
//            }
//
//            self.log.info("Handling '\(SlackEvent.EventType.userChange.rawValue)' event...")
//
//            let user = event.user
//            let profile = user.profile
//
//            // Only interested in "user_change" events changing to the "Available to Help" status
//            guard profile.statusText == availableToHelpStatusText else {
//                self.log.info("Status text was not '\(availableToHelpStatusText)'. Ignoring...")
//                return Response(status: .ok)
//            }
//
//            self.log.info("Detected '\(availableToHelpStatusText)' status.")
//
//            let availableToHelpMessage = "<!here> \(profile.realName) is '\(availableToHelpStatusText)'"
//
//            self.log.info("Posting to Slack: '\(availableToHelpMessage)'")
//
//            return try self.sendSlackMessage(message: availableToHelpMessage)
//        }
//    }
//
//    router.post("slack", "commands", "availableToHelp") { request in
//        guard let availableToHelpStatusText = self.config["slack", "availableToHelpStatusText"]?.string else {
//            throw Abort(.internalServerError, reason: "'availableToHelpStatusText' not properly configured in 'slack.json' config")
//        }
//        guard let formURLEncoded = request.formURLEncoded else {
//            throw Abort(.badRequest, reason: "Invalid URL encoded form")
//        }
//
//        let token: String = try formURLEncoded.get("token")
//
//        try self.verifySlackToken(token)
//
//        // TODO: Fix the async aspect of this. We should immediately respond with a "Checking for users..." message and then perform the actual Slack "users.list" query. Fulfill the slash command by performing a POST on the command's 'response_url'.
//        //          Slack will consider the slash command as having failed if we don't respond within 3 seconds. Luckily, querying the Slack API seems to be fast enough that we don't have to worry about this for now.
//        //            let responseURL: String = try formURLEncoded.get("response_url")
//        //            let responseText = "Checking for users that are '\(Slack.raiseHandStatusText)'..."
//        //            let commandResponse = SlackCommandResponse(responseType: .ephemeral, text: responseText)
//
//        self.log.info("Handling 'availableToHelp' command...")
//
//        return try Response.async({ (stream) in
//            let availableToHelpProfiles = try self.getSlackProfilesAvailableToHelp()
//            self.log.info("Users '\(availableToHelpStatusText)': '\(availableToHelpProfiles)'")
//
//            // Build the response message containing the names of people that are "Available to Help"
//            let availableToHelpList: String = availableToHelpProfiles.reduce("", { (result, profile) -> String in
//                let userName = profile.realName
//                return result.isEmpty ? userName : "\(result)\n\(userName)"
//            })
//            let availableToHelpResponseMessage: String = availableToHelpList.isEmpty ? "No one is '\(availableToHelpStatusText)' :(" : "These people are '\(availableToHelpStatusText)':\n\n\(availableToHelpList)"
//
//            let slashCommandResponse = try SlackCommandResponse(responseType: .inChannel, text: availableToHelpResponseMessage).makeJSON()
//
//            self.log.info("Responding to Slack with response: '\(slashCommandResponse)'")
//
//            stream.close(with: slashCommandResponse)
//        })
//    }
}

//private func getSlackProfilesAvailableToHelp() throws -> [SlackProfile] {
//    guard let availableToHelpStatusText = self.config["slack", "availableToHelpStatusText"]?.string else {
//        throw Abort(.internalServerError, reason: "'availableToHelpStatusText' not properly configured in 'slack.json' config")
//    }
//    guard let oAuthAccessToken = self.config["slack", "oAuthAccessToken"]?.string else {
//        throw Abort(.internalServerError, reason: "'oAuthAccessToken' not properly configured in 'slack.json' config")
//    }
//
//    log.info("Issuing '\(SlackAPI.listUsersURL)' command to Slack...")
//
//    // Query the Slack API with the "users.list" command
//    let listUsersSlackResponse = try client.get(SlackAPI.listUsersURL, query: [:], [.authorization: "Bearer \(oAuthAccessToken)"], nil, through: [])
//
//    // TODO: Implement support for pagination on this response. By default, Slack will currently try to include everyone's profile in the response.
//    //          Eventually, pagination will be required - https://api.slack.com/methods/users.list#pagination
//    guard let json = listUsersSlackResponse.json else {
//        throw Abort(.badRequest, reason: "Invalid response - expected JSON")
//    }
//
//    let slackResponse = try SlackListUsersResponse(json: json)
//
//    log.info("Slack list users response: '\(slackResponse)'")
//
//    // Return user profiles who's status is "Available to Help"
//    let userProfiles = slackResponse.members.compactMap { $0.profile }
//    return userProfiles.filter { $0.statusText == availableToHelpStatusText }
//}

private func verifySlackToken(_ token: String, for environmentConfig: EnvironmentConfig) throws {
    guard token == environmentConfig.verificationToken else {
        throw Abort(.badRequest, reason: "Invalid verification token")
    }
}

private func sendSlackMessage(message: String, using client: Client, environmentConfig: EnvironmentConfig) throws -> Future<Response> {
    let slackMessage = SlackMessage(text: message)
    return client.post(environmentConfig.webhookURL, content: slackMessage)
}
