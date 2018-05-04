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
    
    // MARK: - Properties
    
    let webhookURL: String
    let oAuthAccessToken: String
    let verificationToken: String
    let hashKey: String
    let cipherKey: String
    
    // MARK: - Init
    
    init(container: Container) throws {
        let webhookURLKey = "WEBHOOK_URL"
        let oAuthAccessTokenKey = "OAUTH_ACCESS_TOKEN"
        let verificationTokenKey = "VERIFICATION_TOKEN"
        let hashKeyKey = "HASH_KEY"
        let cipherKeyKey = "CIPHER_KEY"
        
        guard let webhookURL = Environment.get(webhookURLKey) else { throw Error.missingEnvironmentVariable(webhookURLKey) }
        guard let oAuthAccessToken = Environment.get(oAuthAccessTokenKey) else { throw Error.missingEnvironmentVariable(oAuthAccessTokenKey) }
        guard let verificationToken = Environment.get(verificationTokenKey) else { throw Error.missingEnvironmentVariable(verificationTokenKey) }
        guard let hashKey = Environment.get(hashKeyKey) else { throw Error.missingEnvironmentVariable(hashKeyKey) }
        guard let cipherKey = Environment.get(cipherKeyKey) else { throw Error.missingEnvironmentVariable(cipherKeyKey) }
        
        self.webhookURL = webhookURL
        self.oAuthAccessToken = oAuthAccessToken
        self.verificationToken = verificationToken
        self.hashKey = hashKey
        self.cipherKey = cipherKey
    }
}

extension EnvironmentConfig: ServiceType {
    static var serviceSupports: [Any.Type] {
        return [type(of: self)]
    }
    
    static func makeService(for worker: Container) throws -> EnvironmentConfig {
        return try EnvironmentConfig(container: worker)
    }
}
