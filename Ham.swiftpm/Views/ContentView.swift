//
//  ContentView.swift
//  Ham
//
//  Created by 길지훈 on 2/27/26.
//

/// Root view — owns SessionData and manages all screen transitions via explicit DI.

import SwiftUI

struct ContentView: View {

    @State private var session = SessionData()

    var body: some View {
        ZStack {
            (session.currentScreen == .result ? Theme.surface : Theme.bg)
                .ignoresSafeArea()

            switch session.currentScreen {
            case .onboarding:
                OnboardingView(session: session)

            case .scriptIntro:
                ScriptIntroView(session: session) {
                    session.currentScreen = .setup
                }

            case .setup:
                SetupView(
                    onSelect: { scene in
                        session.selectedScene = scene
                        session.resetResults()
                        session.currentScreen = .action
                    },
                    onRecalibrate: {
                        session.resetBaseline()
                        session.currentScreen = .onboarding
                    }
                )

            case .action:
                ActionView(session: session)

            case .wrap:
                WrapView {
                    session.currentScreen = .result
                }

            case .result:
                ResultView(
                    results: session.lineResults,
                    onTryAgain: {
                        session.resetResults()
                        session.currentScreen = .action
                    },
                    onNewScene: {
                        session.resetResults()
                        session.currentScreen = .setup
                    }
                )
            }
        }
        .animation(.easeInOut(duration: 0.4), value: session.currentScreen)
        .task {
            session.loadBaseline()
            if session.isCalibrated {
                session.currentScreen = .setup
            }
        }
    }
}
