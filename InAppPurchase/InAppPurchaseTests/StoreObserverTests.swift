//
//  StoreObserverTests.swift
//  InAppPurchaseTests
//
//  Created by Vinicius Moreira Leal on 28/01/2021.
//  For end to end test: https://www.revenuecat.com/blog/storekit-testing-in-xcode

import InAppPurchase
import StoreKit
import XCTest

class StoreObserverTests: XCTestCase {
    
    func test_buy_addsPaymentRequestToQueue() {
        let queue = PaymentQueueSpy()
        let sut = StoreObserver(queue: queue)
        
        let product = TestProduct(identifier: "a product")
        sut.buy(product)
        
        XCTAssertEqual(queue.messages, [.add])
        XCTAssertEqual(queue.addedProducts, ["a product"])
    }
    
    func test_restore_restoresCompletedTransactionsToQueue() {
        let queue = PaymentQueueSpy()
        let sut = StoreObserver(queue: queue)
        
        sut.restore()
        
        XCTAssertEqual(queue.messages, [.restore])
    }
    
    func test_updatedTransactions_purchasingOrDeferred_doNotMessageQueue() {
        let queue = PaymentQueueSpy()
        let sut = StoreObserver(queue: queue)
        
        sut.paymentQueue(queue, updatedTransactions: [.purchasing, .deferred])
        
        XCTAssertTrue(queue.messages.isEmpty)
    }
    
    func test_updatedTransactions_purchased_messagesQueue() {
        let queue = PaymentQueueSpy()
        let sut = StoreObserver(queue: queue)
        
        sut.paymentQueue(queue, updatedTransactions: [.purchased])
        
        XCTAssertEqual(queue.messages, [.finish])
    }
    
    // MARK: Helpers
    
    private class PaymentQueueSpy: SKPaymentQueue {
        enum Message {
            case add, restore, finish
        }
        
        private(set) var messages = [Message]()
        private(set) var addedProducts = [String]()
 
        override func add(_ payment: SKPayment) {
            messages.append(.add)
            addedProducts.append(payment.productIdentifier)
        }
        
        override func restoreCompletedTransactions() {
            messages.append(.restore)
        }
        
        override func finishTransaction(_ transaction: SKPaymentTransaction) {
            messages.append(.finish)
        }
    }
    
    private class TestProduct: SKProduct {
        
        let identifier: String
        
        init(identifier: String) {
            self.identifier = identifier
        }
        
        override var productIdentifier: String {
            identifier
        }
    }
}

extension SKPaymentTransaction {
    static var purchasing: SKPaymentTransaction {
        TestTransaction(state: .purchasing)
    }
    
    static var deferred: SKPaymentTransaction {
        TestTransaction(state: .deferred)
    }
    
    static var purchased: SKPaymentTransaction {
        TestTransaction(state: .purchased)
    }
    
    private class TestTransaction: SKPaymentTransaction {
        
        let state: SKPaymentTransactionState
        
        init(state: SKPaymentTransactionState) {
            self.state = state
        }
        
        override var transactionState: SKPaymentTransactionState {
            state
        }
    }
}