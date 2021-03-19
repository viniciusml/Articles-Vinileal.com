//
//  StoreObserver.swift
//  InAppPurchase
//
//  Created by Vinicius Moreira Leal on 07/02/2021.
//

import StoreKit

public struct PaymentTransaction: Equatable {
    public enum State: Equatable {
        case purchased
        case restored
        case failed
    }
    
    public let state: State
    public let identifier: String
}

// TODO: Add completion for this.
public class PaymentTransactionObserver: NSObject {
    
    private let queue: SKPaymentQueue
    public var completion: ((PaymentTransaction) -> Void)?
    
    public init(queue: SKPaymentQueue = .default()) {
        self.queue = queue
        super.init()
        
        queue.add(self)
    }
    
    public func buy(_ product: SKProduct) {
        let payment = SKMutablePayment(product: product)
        queue.add(payment)
    }
    
    public func restore() {
        queue.restoreCompletedTransactions()
    }
    
    private func purchased(_ transaction: SKPaymentTransaction) {
        completion?(PaymentTransaction(state: .purchased, identifier: transaction.payment.productIdentifier))
        queue.finishTransaction(transaction)
    }
    
    private func failed(_ transaction: SKPaymentTransaction) {
        guard let transactionError = transaction.error as NSError?,
              transactionError.code != SKError.paymentCancelled.rawValue else { return }
        
        completion?(PaymentTransaction(state: .failed, identifier: transaction.payment.productIdentifier))
        queue.finishTransaction(transaction)
    }
    
    private func restored(_ transaction: SKPaymentTransaction) {
        guard let productIdentifier = transaction.original?.payment.productIdentifier else { return }
        
        completion?(PaymentTransaction(state: .restored, identifier: productIdentifier))
        queue.finishTransaction(transaction)
    }
}

extension PaymentTransactionObserver: SKPaymentTransactionObserver {
    
    public func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        
        transactions.handle(purchased, failed, restored)
    }
}
