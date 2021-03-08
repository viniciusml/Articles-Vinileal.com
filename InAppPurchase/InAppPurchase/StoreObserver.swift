//
//  StoreObserver.swift
//  InAppPurchase
//
//  Created by Vinicius Moreira Leal on 07/02/2021.
//

import StoreKit

public class StoreObserver: NSObject {
    
    let queue: SKPaymentQueue
    
    public init(queue: SKPaymentQueue = .default()) {
        self.queue = queue
    }
    
    public func buy(_ product: SKProduct) {
        let payment = SKMutablePayment(product: product)
        queue.add(payment)
    }
    
    public func restore() {
        queue.restoreCompletedTransactions()
    }
    
    private func purchased(_ transaction: SKPaymentTransaction) {
        queue.finishTransaction(transaction)
    }
    
    private func failed(_ transaction: SKPaymentTransaction) {
        queue.finishTransaction(transaction)
    }
    
    private func restored(_ transaction: SKPaymentTransaction) {
        queue.finishTransaction(transaction)
    }
}

extension StoreObserver: SKPaymentTransactionObserver {
    
    public func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        
        transactions.handle(purchased, failed, restored)
    }
}
