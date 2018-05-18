//
//  EnvironmentConfig.swift
//  App
//
//  Created by Tyler Milner on 5/4/18.
//

import Vapor

/// Represents the environment variables necessary for the app to run.
struct EnvironmentConfig {
    
    // MARK: - Subtypes
    
    /// Represents an error that can occur with regard to the app's environment.
    enum Error: Swift.Error {
        case missingEnvironmentVariable(String)
    }
    
    /// Returns the default EnvironmentConfig based on the global Environment in which the app was launched.
    static func `default`() throws -> EnvironmentConfig {
        let generalWebhookURLKey = "GENERAL_WEBHOOK_URL"
        let engWebhookURLKey = "ENG_WEBHOOK_URL"
        let pmWebhookURLKey = "PM_WEBHOOK_URL"
        let qaWebhookURLKey = "QA_WEBHOOK_URL"
        let xdWebhookURLKey = "XD_WEBHOOK_URL"
        let engGroupIdKey = "ENG_GROUP_ID"
        let pmGroupIdKey = "PM_GROUP_ID"
        let qaGroupIdKey = "QA_GROUP_ID"
        let xdGroupIdKey = "XD_GROUP_ID"
        let adGroupIdKey = "AD_GROUP_ID"
        let oAuthAccessTokenKey = "OAUTH_ACCESS_TOKEN"
        let verificationTokenKey = "VERIFICATION_TOKEN"
        let raiseHandStatusTextKey = "RAISE_HAND_STATUS_TEXT"
        
        guard let generalWebhookURL = Environment.get(generalWebhookURLKey) else { throw Error.missingEnvironmentVariable(generalWebhookURLKey) }
        guard let engWebhookURL = Environment.get(engWebhookURLKey) else { throw Error.missingEnvironmentVariable(engWebhookURLKey) }
        guard let pmWebhookURL = Environment.get(pmWebhookURLKey) else { throw Error.missingEnvironmentVariable(pmWebhookURLKey) }
        guard let qaWebhookURL = Environment.get(qaWebhookURLKey) else { throw Error.missingEnvironmentVariable(qaWebhookURLKey) }
        guard let xdWebhookURL = Environment.get(xdWebhookURLKey) else { throw Error.missingEnvironmentVariable(xdWebhookURLKey) }
        guard let engGroupId = Environment.get(engGroupIdKey) else { throw Error.missingEnvironmentVariable(engGroupIdKey) }
        guard let pmGroupId = Environment.get(pmGroupIdKey) else { throw Error.missingEnvironmentVariable(pmGroupIdKey) }
        guard let qaGroupId = Environment.get(qaGroupIdKey) else { throw Error.missingEnvironmentVariable(qaGroupIdKey) }
        guard let xdGroupId = Environment.get(xdGroupIdKey) else { throw Error.missingEnvironmentVariable(xdGroupIdKey) }
        guard let adGroupId = Environment.get(adGroupIdKey) else { throw Error.missingEnvironmentVariable(adGroupIdKey) }
        guard let oAuthAccessToken = Environment.get(oAuthAccessTokenKey) else { throw Error.missingEnvironmentVariable(oAuthAccessTokenKey) }
        guard let verificationToken = Environment.get(verificationTokenKey) else { throw Error.missingEnvironmentVariable(verificationTokenKey) }
        guard let raiseHandStatusText = Environment.get(raiseHandStatusTextKey) else { throw Error.missingEnvironmentVariable(raiseHandStatusTextKey) }
        
        return EnvironmentConfig(generalWebhookURL: generalWebhookURL, engWebhookURL: engWebhookURL, pmWebhookURL: pmWebhookURL, qaWebhookURL: qaWebhookURL, xdWebhookURL: xdWebhookURL, engGroupId: engGroupId, pmGroupId: pmGroupId, qaGroupId: qaGroupId, xdGroupId: xdGroupId, adGroupId: adGroupId, oAuthAccessToken: oAuthAccessToken, verificationToken: verificationToken, raiseHandStatusText: raiseHandStatusText)
    }
    
    // MARK: - Properties
    
    let generalWebhookURL: String
    let engWebhookURL: String
    let pmWebhookURL: String
    let qaWebhookURL: String
    let xdWebhookURL: String
    let engGroupId: String
    let pmGroupId: String
    let qaGroupId: String
    let xdGroupId: String
    let adGroupId: String
    let oAuthAccessToken: String
    let verificationToken: String
    let raiseHandStatusText: String
}

extension EnvironmentConfig: ServiceType {
    static func makeService(for worker: Container) throws -> EnvironmentConfig {
        return try EnvironmentConfig.default()
    }
}
