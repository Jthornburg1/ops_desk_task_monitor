//
//  AuthRepository.swift
//  OpsDesk
//
//  Created by jonathan thornburg on 11/3/26.
//

protocol AuthRepository {
    func hasSession() async -> Bool
}
