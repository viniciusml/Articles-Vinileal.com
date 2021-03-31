//
//  PaymentTransactionObserverTests.swift
//  InAppPurchaseTests
//
//  Created by Vinicius Moreira Leal on 28/01/2021.
//

import InAppPurchase
import StoreKit
import XCTest

class PaymentTransactionObserverTests: XCTestCase {
    
    override func tearDown() {
        PaymentQueueSpy.resetState()
        super.tearDown()
    }
    
    func test_init_addsObserverToQueue() {
        let (queue, sut) = makeSUT()
        
        XCTAssertTrue(queue.transactionObservers.first === sut)
    }
    
    func test_buy_addsPaymentRequestToQueue() {
        let (queue, sut) = makeSUT()
        
        let product = TestProduct(identifier: "a product")
        sut.buy(product)
        
        XCTAssertEqual(queue.messages, [.add])
        XCTAssertEqual(queue.addedProducts, ["a product"])
    }
    
    func test_updatedTransactions_purchasingOrDeferred_doNotMessageQueue() {
        let (queue, sut) = makeSUT()
        
        sut.paymentQueue(queue, updatedTransactions: [.purchasing, .deferred])
        
        XCTAssertTrue(queue.messages.isEmpty)
        XCTAssertNil(sut.onTransactionsUpdate)
    }
    
    func test_updatedTransactions_purchased_messagesQueue() {
        let (queue, sut) = makeSUT()
        let identifier = "a product identifier"
        
        expect(sut, toCompleteWith: .make(.purchased, with: identifier), when: {
            sut.paymentQueue(queue, updatedTransactions: [.purchased(identifier: identifier)])
        })
        
        XCTAssertEqual(queue.messages, [.finish])
    }
    
    func test_updatedTransactions_failed_messagesQueue() {
        let (queue, sut) = makeSUT()
        let identifier = "a failed product identifier"
        let error = NSError(domain: "test error", code: 0)
        
        expect(sut, toCompleteWith: .make(.failed, with: identifier), when: {
            sut.paymentQueue(queue, updatedTransactions: [.failed(error: error, identifier: identifier)])
        })
        
        XCTAssertEqual(queue.messages, [.finish])
    }
    
    func test_updatedTransactions_failedWithCancellation_doesNotMessageQueue() {
        let (queue, sut) = makeSUT()
        let identifier = "a failed product identifier"
        let error = NSError(domain: "test error", code: SKError.paymentCancelled.rawValue)
        
        expect(sut, toNotCompleteWhen: {
            sut.paymentQueue(queue, updatedTransactions: [.failed(error: error, identifier: identifier)])
        })
        
        XCTAssertTrue(queue.messages.isEmpty)
    }
    
    func test_restore_doesNotCompleteWithNoTransactions() {
        PaymentQueueSpy.stubbCompletedTransactions([
            .restored(originalIdentifier: nil)
        ])
        let (_, sut) = makeSUT()
        
        expect(sut, toNotCompleteWhen: sut.restore)
    }
    
    func test_restore_withoutOriginalIdentifier_doesNotMessageQueue() {
        PaymentQueueSpy.stubbCompletedTransactions([
            .restored(originalIdentifier: nil)
        ])
        let (queue, sut) = makeSUT()
        
        sut.restore()
        
        XCTAssertEqual(queue.messages, [.restore])
    }
    
    func test_restore_withMultipleTransactions_completesWithSuccess() {
        let transactions = makeRestoredTransactions("1", "2", "3")
        PaymentQueueSpy.stubbCompletedTransactions(transactions.sk)
        let (queue, sut) = makeSUT()
        
        expect(sut, toCompleteWith: .success(transactions.domain), when: sut.restore)
        
        XCTAssertEqual(queue.messages, [.restore, .finish, .finish, .finish])
    }
    
    func test_restore_twiceWithDifferentValues_completesWithSuccess() {
        let transactions = makeRestoredTransactions("1", "2", "3")
        PaymentQueueSpy.stubbCompletedTransactions(transactions.sk)
        let (_, sut) = makeSUT()
        
        expect(sut, toCompleteWith: .success(transactions.domain), when: sut.restore)
        
        let newTransactions = makeRestoredTransactions("4", "5", "6")
        PaymentQueueSpy.stubbCompletedTransactions(newTransactions.sk)
        
        expect(sut, toCompleteWith: .success(newTransactions.domain), when: sut.restore)
    }
    
    func test_restore_withError_completesWithFailure() {
        let error = NSError(domain: "test error", code: 0)
        PaymentQueueSpy.stubbError(error)
        let (_, sut) = makeSUT()
        
        expect(sut, toCompleteWith: .failure(error), when: sut.restore)
    }
    
    // MARK: Helpers
    
    private func makeSUT() -> (PaymentQueueSpy, PaymentTransactionObserver) {
        let queue = PaymentQueueSpy()
        let sut = PaymentTransactionObserver(queue: queue)
        return (queue, sut)
    }
    
    private func makeRestoredTransactions(_ identifiers: String?...) -> (sk: [SKPaymentTransaction], domain: [PaymentTransaction]) {
        let skTransactions = identifiers.map { SKPaymentTransaction.restored(originalIdentifier: $0) }
        let domainTransactions = identifiers.map { PaymentTransaction.make(.restored, with: $0 ?? "") }
        return (skTransactions, domainTransactions)
    }
    
    private func expect(_ sut: PaymentTransactionObserver, toCompleteWith expectedTransaction: PaymentTransaction, when action: () -> Void, file: StaticString = #filePath, line: UInt = #line) {
        let exp = expectation(description: "wait for completion")
        var receivedTransaction: PaymentTransaction?
        
        sut.onTransactionsUpdate = { result in
            if let transactions = try? result.get() {
                receivedTransaction = transactions.first
            }
            exp.fulfill()
        }
        action()
        
        wait(for: [exp], timeout: 0.1)
        XCTAssertEqual(receivedTransaction, expectedTransaction)
    }
    
    private func expect(_ sut: PaymentTransactionObserver, toCompleteWith expectedResult: PaymentTransactionObserver.TransactionResult, when action: () -> Void, file: StaticString = #filePath, line: UInt = #line) {
        let exp = expectation(description: "wait for completion")
        
        sut.onTransactionsUpdate = { receivedResult in
            switch (receivedResult, expectedResult) {
            case (.success(let receivedTransactions), .success(let expectedTransactions)):
                XCTAssertEqual(receivedTransactions, expectedTransactions, file: file, line: line)
            case (.failure(let receivedError as NSError), .failure(let expectedError as NSError)):
                XCTAssertEqual(receivedError, expectedError, file: file, line: line)
            default:
                XCTFail("Expected \(expectedResult), got \(receivedResult) instead", file: file, line: line)
            }
            exp.fulfill()
        }
        action()
        
        wait(for: [exp], timeout: 0.1)
        
    }
    
    private func expect(_ sut: PaymentTransactionObserver, toNotCompleteWhen action: () -> Void, file: StaticString = #filePath, line: UInt = #line) {
        let exp = expectation(description: "wait for completion")
        exp.isInverted = true
        
        sut.onTransactionsUpdate = { _ in
            exp.fulfill()
        }
        action()
        
        wait(for: [exp], timeout: 0.1)
    }
    
    private class PaymentQueueSpy: SKPaymentQueue {
        enum Message {
            case add, restore, finish
        }
        
        private(set) var messages = [Message]()
        private(set) var addedProducts = [String]()
        private(set) static var completedTransactions = [SKPaymentTransaction]()
        private(set) static var completionError: Error?
        
        static func stubbCompletedTransactions(_ transactions: [SKPaymentTransaction]) {
            completedTransactions = transactions
        }
        
        static func stubbError(_ error: Error) {
            completionError = error
        }
        
        static func resetState() {
            completedTransactions = []
            completionError = nil
        }
 
        override func add(_ payment: SKPayment) {
            messages.append(.add)
            addedProducts.append(payment.productIdentifier)
        }
        
        override func restoreCompletedTransactions() {
            messages.append(.restore)
            
            transactionObservers.first?.paymentQueue(self, updatedTransactions: PaymentQueueSpy.completedTransactions)
            
            if let error = PaymentQueueSpy.completionError {
                transactionObservers.first?.paymentQueue?(self, restoreCompletedTransactionsFailedWithError: error)
            } else {
                transactionObservers.first?.paymentQueueRestoreCompletedTransactionsFinished?(self)
            }
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
    static let purchasing = makeTestTransaction(.purchasing)
    static let deferred = makeTestTransaction(.deferred)
    static func purchased(identifier: String) -> SKPaymentTransaction { makeTestTransaction(.purchased, identifier: identifier)
    }
    static func failed(error: Error, identifier: String) -> SKPaymentTransaction {
        makeTestTransaction(.failed, identifier: identifier, error: error)
    }
    static func restored(originalIdentifier: String?) -> SKPaymentTransaction {
        makeTestTransaction(.restored, originalIdentifier: originalIdentifier)
    }
    
    private static func makeTestTransaction(
        _ state: SKPaymentTransactionState,
        identifier: String = "test id",
        originalIdentifier: String? = nil,
        error: Error? = nil) -> SKPaymentTransaction
    {
        TestTransaction(stubbedState: state, stubbedProductIdentifier: identifier, stubbedOriginalIdentifier: originalIdentifier, stubbedError: error)
    }
    
    private class TestTransaction: SKPaymentTransaction {
        
        private let stubbedState: SKPaymentTransactionState
        private let stubbedOriginalIdentifier: String?
        private let stubbedProductIdentifier: String
        private let stubbedError: Error?
        
        init(stubbedState: SKPaymentTransactionState,
             stubbedProductIdentifier: String,
             stubbedOriginalIdentifier: String?,
             stubbedError: Error?) {
            self.stubbedState = stubbedState
            self.stubbedProductIdentifier = stubbedProductIdentifier
            self.stubbedOriginalIdentifier = stubbedOriginalIdentifier
            self.stubbedError = stubbedError
        }
        
        override var transactionState: SKPaymentTransactionState {
            stubbedState
        }
        
        override var error: Error? {
            stubbedError
        }
        
        override var original: SKPaymentTransaction? {
            guard let identifier = stubbedOriginalIdentifier else { return nil }
            return TestTransaction(stubbedState: .restored, stubbedProductIdentifier: identifier, stubbedOriginalIdentifier: identifier, stubbedError: nil)
        }
        
        override var payment: SKPayment {
            SKPayment(product: FakeProduct(fakeProductIdentifier: stubbedProductIdentifier))
        }
    }
}
