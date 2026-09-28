//
//  ReactorBindingTests.swift
//  PlystTests
//
//  Created by opfic on 9/28/26.
//

import ReactorKit
import RxSwift
import UIKit
import XCTest
@testable import Plyst

@MainActor
final class ReactorBindingTests: XCTestCase {

    func testStateIsRenderedAndObservationIsCancelledWhenControllerIsReleased() async {
        let rendered = expectation(description: "Updated state is rendered")
        let disposed = expectation(description: "State observation is disposed")
        let spy = StateSubscriptionReactorSpy(onDispose: { disposed.fulfill() })
        var controller: StateSubscriptionTestViewController? = StateSubscriptionTestViewController(reactor: spy) { state in
            if state.isReady {
                rendered.fulfill()
            }
        }
        weak let weakController = controller

        controller?.loadViewIfNeeded()
        spy.states.onNext(.init(isReady: true))
        await fulfillment(of: [rendered], timeout: 2)
        XCTAssertEqual(controller?.states, [.init(), .init(isReady: true)])

        controller = nil
        XCTAssertNil(weakController)
        await fulfillment(of: [disposed], timeout: 2)
    }
}

private final class StateSubscriptionReactorSpy: Reactorable {

    typealias Action = Never

    struct State: Equatable, Sendable {
        var isReady = false
    }

    let initialState = State()
    let states = BehaviorSubject(value: State())
    private let onDispose: () -> Void

    var state: Observable<State> {
        states.do(onDispose: onDispose)
    }

    init(onDispose: @escaping () -> Void) {
        self.onDispose = onDispose
    }
}

@MainActor
private final class StateSubscriptionTestViewController: ReactorViewController<StateSubscriptionReactorSpy> {

    private(set) var states = [StateSubscriptionReactorSpy.State]()
    private let onRender: (StateSubscriptionReactorSpy.State) -> Void

    init(reactor: StateSubscriptionReactorSpy, onRender: @escaping (StateSubscriptionReactorSpy.State) -> Void) {
        self.onRender = onRender
        super.init(reactor: reactor)
    }

    override func render(state: StateSubscriptionReactorSpy.State) {
        states.append(state)
        onRender(state)
    }
}
