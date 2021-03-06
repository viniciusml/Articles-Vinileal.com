//
//  ProductLoaderTests.swift
//  InAppPurchaseTests
//
//  Created by Vinicius Moreira Leal on 08/03/2021.
//

import InAppPurchase
import StoreKit
import XCTest

class ProductLoaderTests: XCTestCase {

    func test_init_setsDelegate() {
        let (request, sut, _) = makeSUT()

        XCTAssertTrue(request.delegate === sut)
    }
    
    func test_fetchProducts_startsRequest() {
        let (request, sut, _) = makeSUT()
        
        sut.fetchProducts()
        
        XCTAssertEqual(request.messages, [.start])
    }
    
    func test_completeWithError_onRequestFailure() {
        let (request, sut, delegate) = makeSUT()
        let expectedError = anyNSError()
        
        sut.fetchProducts()
        
        expect(delegate, toCompleteWith: .failure(expectedError), when: {
            request.completeWith(expectedError)
        })
    }
    
    func test_completesWithResponse_onRequestSuccess() {
        let (request, sut, delegate) = makeSUT()
        let expectedProductsResponse = makeProductsResponse(productIDs: Set(arrayLiteral: "product1", "product2"))
        let expectedProducts = [makeProduct(id: "product1"), makeProduct(id: "product2")]
        
        sut.fetchProducts()
        
        expect(delegate, toCompleteWith: .success(expectedProducts), when: {
            request.completeWith(expectedProductsResponse)
        })
    }
    
    func test_fetchProductsTwice_performsRequestTwice() {
        let (request, sut, _) = makeSUT()
        
        sut.fetchProducts()
        sut.fetchProducts()
        
        XCTAssertEqual(request.messages, [.start, .start])
    }
    
    func test_completeWithError_cancelsRequest() {
        let (request, sut, _) = makeSUT()
        let expectedError = anyNSError()
        
        sut.fetchProducts()
        request.completeWith(expectedError)
        
        XCTAssertEqual(request.messages, [.start, .cancel])
    }
    
    // MARK: - Helpers
    
    private func makeSUT() -> (request: ProductsRequestSpy, sut: ProductLoader, delegate: ProductLoaderDelegateSpy) {
        let request = ProductsRequestSpy()
        let sut = ProductLoader(request: request)
        let delegate = ProductLoaderDelegateSpy()
        sut.delegate = delegate
        return (request, sut, delegate)
    }
    
    private func expect(_ delegate: ProductLoaderDelegateSpy, toCompleteWith expectedResult: ProductLoader.ProductsResult, when action: () -> Void, file: StaticString = #filePath, line: UInt = #line) {
        
        action()
        let receivedResult = delegate.receivedResult!
        
        switch (receivedResult, expectedResult) {
        case let (.success(receivedProducts), .success(expectedProducts)):
            XCTAssertEqual(receivedProducts.sortedIDs, expectedProducts.sortedIDs, file: file, line: line)
            
        case let (.failure(receivedError as NSError), .failure(expectedError as NSError)):
            XCTAssertEqual(receivedError, expectedError, file: file, line: line)
            
        default:
            XCTFail("Expected \(expectedResult), got \(receivedResult) instead", file: file, line: line)
        }
    }
    
    private func anyNSError() -> NSError {
        NSError(domain: "test", code: 0)
    }
    
    private func makeProductsResponse(productIDs: Set<String>) -> SKProductsResponse {
        FakeProductsResponse(productIdentifiers: productIDs)
    }
    
    private func makeProduct(id: String) -> FakeProduct {
        FakeProduct(fakeProductIdentifier: id)
    }
}

private class ProductLoaderDelegateSpy: ProductLoaderDelegate {
    private(set) var receivedResult: Result<[SKProduct], Error>?
    
    func didFetchProducts(with result: ProductsResult) {
        receivedResult = result
    }
}

class FakeProductsResponse: SKProductsResponse {
    private let fakeProducts: [FakeProduct]
    
    init(productIdentifiers: Set<String>) {
        self.fakeProducts = productIdentifiers.map { FakeProduct(fakeProductIdentifier: $0) }
        super.init()
    }
    
    override var products: [SKProduct] {
        fakeProducts
    }
}

class FakeProduct: SKProduct {
    private let fakeProductIdentifier: String
    
    init(fakeProductIdentifier: String) {
        self.fakeProductIdentifier = fakeProductIdentifier
        super.init()
    }
    
    override var productIdentifier: String {
        fakeProductIdentifier
    }
}

class ProductsRequestSpy: SKProductsRequest {
    enum Message {
        case start, cancel
    }
    
    private var error: Error?
    private var response: SKProductsResponse?
    
    private(set) var messages = [Message]()
    private(set) var identifiers = Set<String>()
    
    override init(productIdentifiers: Set<String> = Set()) {
        identifiers = productIdentifiers
        super.init()
    }
    
    override func start() {
        messages.append(.start)
    }
    
    override func cancel() {
        messages.append(.cancel)
    }

    public func completeWith(_ error: Error) {
        delegate?.request!(self, didFailWithError: error)
    }
    
    public func completeWith(_ response: SKProductsResponse) {
        delegate?.productsRequest(self, didReceive: response)
    }
}

extension ProductsRequestSpy {
    static var any: ProductsRequestSpy {
        ProductsRequestSpy(productIdentifiers: Set<String>())
    }
}

private extension Array where Element == SKProduct {
    var sortedIDs: [String] {
        map { $0.productIdentifier }.sorted()
    }
}
