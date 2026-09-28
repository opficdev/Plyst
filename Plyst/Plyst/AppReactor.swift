//
//  AppReactor.swift
//  Plyst
//
//  Created by opfic on 9/28/26.
//

import RxSwift

final class AppReactor: Reactorable {

    enum Action: Sendable {
        case viewDidLoad
        case reload
    }

    enum Mutation: Sendable {
        case setReady
    }

    struct State: Sendable {
        var isReady = false
    }

    let initialState = State()

    func mutate(action: Action) -> Observable<Mutation> {
        switch action {
        case .viewDidLoad, .reload:
            return .just(.setReady)
        }
    }

    func reduce(state: State, mutation: Mutation) -> State {
        var state = state
        switch mutation {
        case .setReady:
            state.isReady = true
        }
        return state
    }
}
