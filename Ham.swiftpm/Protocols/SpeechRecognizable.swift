//
//  SpeechRecognizable.swift
//  Ham
//
//  Created by 길지훈 on 2/27/26.
//

/// Protocol abstracting speech recognition — enables mock injection for testing.

import Speech

protocol SpeechRecognizable: AnyObject {
    func startListening() -> AsyncStream<String>
    func stopListening()
    func requestAuthorization() async -> Bool
}
