//
//  IAPHelper.swift
//  IAPDemo
//
//  Created by Jason Zheng on 8/24/16.
//  Copyright © 2016 Jason Zheng. All rights reserved.
//

import StoreKit

extension SKProduct {
  public func localizedPrice() -> String? {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.locale = self.priceLocale
    return formatter.string(from: self.price)
  }
}

public let IAP = IAPHelper.sharedInstance

public typealias ProductIdentifier = String
public typealias ProductWithExpireDate = [ProductIdentifier: Date]

public typealias ProductsRequestHandler = (_ response: SKProductsResponse?, _ error: Error?) -> ()
public typealias PurchaseHandler = (_ productIdentifier: ProductIdentifier?, _ error: Error?) -> ()
public typealias RestoreHandler = (_ productIdentifiers: Set<ProductIdentifier>, _ error: Error?) -> ()
public typealias ValidateHandler = (_ statusCode: Int?, _ products: ProductWithExpireDate?, _ json: [String: Any]?) -> ()

public class IAPHelper: NSObject {
  
  private override init() {
    super.init()
    
    addObserver()
  }
  static let sharedInstance = IAPHelper()
  
  fileprivate var productsRequest: SKProductsRequest?
  fileprivate var productsRequestHandler: ProductsRequestHandler?
  
  fileprivate var purchaseHandler: PurchaseHandler?
  fileprivate var restoreHandler: RestoreHandler?
  
  private var observerAdded = false
  
  public func addObserver() {
    if !observerAdded {
      observerAdded = true
      SKPaymentQueue.default().add(self)
    }
  }
  
  public func removeObserver() {
    if observerAdded {
      observerAdded = false
      SKPaymentQueue.default().remove(self)
    }
  }
}

// MARK: StoreKit API

extension IAPHelper {
  
  public func requestProducts(_ productIdentifiers: Set<ProductIdentifier>, handler: @escaping ProductsRequestHandler) {
    productsRequest?.cancel()
    productsRequestHandler = handler
    
    productsRequest = SKProductsRequest(productIdentifiers: productIdentifiers)
    productsRequest?.delegate = self
    productsRequest?.start()
  }
  
  public func purchaseProduct(_ productIdentifier: ProductIdentifier, handler: @escaping PurchaseHandler) {
    purchaseHandler = handler
    
    let payment = SKMutablePayment()
    payment.productIdentifier = productIdentifier
    SKPaymentQueue.default().add(payment)
  }
  
  public func restorePurchases(_ handler: @escaping RestoreHandler) {
    restoreHandler = handler
    SKPaymentQueue.default().restoreCompletedTransactions()
  }
  
  /*
   * password: Only used for receipts that contain auto-renewable subscriptions.
   *           It's your app’s shared secret (a hexadecimal string) which was generated on iTunesConnect.
   */
  public func validateReceipt(_ password: String? = nil, handler: @escaping ValidateHandler) {
    validateReceiptInternal(true, password: password) { (statusCode, products, json) in
      
      if let statusCode = statusCode , statusCode == ReceiptStatus.testReceipt.rawValue {
        self.validateReceiptInternal(false, password: password, handler: { (statusCode, products, json) in
          handler(statusCode, products, json)
        })
        
      } else {
        handler(statusCode, products, json)
      }
    }
  }
}

// MARK: SKProductsRequestDelegate

extension IAPHelper: SKProductsRequestDelegate {
  public func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
    productsRequestHandler?(response, nil)
    clearRequestAndHandler()
  }
  
  public func request(_ request: SKRequest, didFailWithError error: Error) {
    productsRequestHandler?(nil, error)
    clearRequestAndHandler()
  }
  
  private func clearRequestAndHandler() {
    productsRequest = nil
    productsRequestHandler = nil
  }
}

// MARK: SKPaymentTransactionObserver

extension IAPHelper: SKPaymentTransactionObserver {
  
  public func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
    for transaction in transactions {
      switch (transaction.transactionState) {

      case SKPaymentTransactionState.purchased:
        completePurchaseTransaction(transaction)
        
      case SKPaymentTransactionState.restored:
        finishTransaction(transaction)
        
      case SKPaymentTransactionState.failed:
        failedTransaction(transaction)
        
      case SKPaymentTransactionState.purchasing,
           SKPaymentTransactionState.deferred:
        break
      }
    }
  }
  
  public func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
    completeRestoreTransactions(queue, error: nil)
  }
  
  public func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
    completeRestoreTransactions(queue, error: error)
  }
  
  private func completePurchaseTransaction(_ transaction: SKPaymentTransaction) {
    purchaseHandler?(transaction.payment.productIdentifier, transaction.error)
    purchaseHandler = nil
    
    finishTransaction(transaction)
  }
  
  private func completeRestoreTransactions(_ queue: SKPaymentQueue, error: Error?) {
    var productIdentifiers = Set<ProductIdentifier>()
    
    for transaction in queue.transactions {
      if let productIdentifier = transaction.original?.payment.productIdentifier {
        productIdentifiers.insert(productIdentifier)
      }
      
      finishTransaction(transaction)
    }
    
    restoreHandler?(productIdentifiers, error)
    restoreHandler = nil
  }
  
  private func failedTransaction(_ transaction: SKPaymentTransaction) {
    // NOTE: Both purchase and restore may come to this state. So need to deal with both handlers.
    
    purchaseHandler?(nil, transaction.error)
    purchaseHandler = nil
    
    restoreHandler?(Set<ProductIdentifier>(), transaction.error)
    restoreHandler = nil
    
    finishTransaction(transaction)
  }
  
  // MARK: Helper
  
  private func finishTransaction(_ transaction: SKPaymentTransaction) {
    switch transaction.transactionState {
    case SKPaymentTransactionState.purchased,
         SKPaymentTransactionState.restored,
         SKPaymentTransactionState.failed:
      
      SKPaymentQueue.default().finishTransaction(transaction)
      
    default:
      break
    }
  }
}

// MARK: Validate Receipt

extension IAPHelper {
  
  fileprivate func validateReceiptInternal(_ isProduction: Bool, password: String?, handler: @escaping ValidateHandler) {
    
    let serverURL = isProduction
      ? "https://buy.itunes.apple.com/verifyReceipt"
      : "https://sandbox.itunes.apple.com/verifyReceipt"
    
    let appStoreReceiptURL = Bundle.main.appStoreReceiptURL
    guard let receiptData = receiptData(appStoreReceiptURL, password: password), let url = URL(string: serverURL) else {
      handler(ReceiptStatus.noRecipt.rawValue, nil, nil)
      return
    }
    
    let request = NSMutableURLRequest(url: url)
    request.httpMethod = "POST"
    request.httpBody = receiptData
    
    let task = URLSession.shared.dataTask(with: request as URLRequest) { (data, response, error) in
      
      guard let data = data, error == nil else {
        handler(nil, nil, nil)
        return
      }
      
      do {
        let json = try JSONSerialization.jsonObject(with: data, options:[]) as? [String: Any]
        
        let statusCode = json?["status"] as? Int
        let products = self.parseValidateResultJSON(json)
        handler(statusCode, products, json)
        
      } catch {
        handler(nil, nil, nil)
      }
    }
    task.resume()
  }
  
  private func parseValidateResultJSON(_ json: [String: Any]?) -> ProductWithExpireDate? {
    var products = ProductWithExpireDate()
    var cancelledProducts = ProductWithExpireDate()
    
    if let receiptList = json?["latest_receipt_info"] as? [AnyObject] {
      for receipt in receiptList {
        if let productID = receipt["product_id"] as? String {
          
          if let expiresDate = parseDate(receipt["expires_date"] as? String) {
            if let existingExpiresDate = products[productID], existingExpiresDate.timeIntervalSince1970 >= expiresDate.timeIntervalSince1970 {
              // Do nothing
            } else {
              products[productID] = expiresDate
            }
          }
          
          if let cancellationDate = parseDate(receipt["cancellation_date"] as? String) {
            if let existingExpiresDate = cancelledProducts[productID] , existingExpiresDate.timeIntervalSince1970 >= cancellationDate.timeIntervalSince1970 {
              // Do nothing
            } else {
              products[productID] = cancellationDate
            }
          }
        }
      }
    }
    
    // Set the expired date for cancelled product to 1970.
    for (productID, cancelledExpiresDate) in cancelledProducts {
      if let expiresDate = products[productID] , expiresDate.timeIntervalSince1970 <= cancelledExpiresDate.timeIntervalSince1970 {
        products[productID] = Date(timeIntervalSince1970: 0)
      }
    }
    
    return products.isEmpty ? nil : products
  }

  private func receiptData(_ appStoreReceiptURL: URL?, password: String?) -> Data? {
    guard let receiptURL = appStoreReceiptURL, let receipt = try? Data(contentsOf: receiptURL) else {
        return nil
    }
    
    do {
      let receiptData = receipt.base64EncodedString()
      var requestContents = ["receipt-data": receiptData]
      if let password = password {
        requestContents["password"] = password
      }
      let requestData = try JSONSerialization.data(withJSONObject: requestContents, options: [])
      return requestData
      
    } catch let error {
      NSLog("\(error)")
    }
    
    return nil
  }
  /*
   * dateString demo: "2016-08-24 09:42:11 Etc/GMT"
   * Need to remove "Etc/" to parse the date
   */
  private func parseDate(_ dateString: String?) -> Date? {
    guard let dateString = dateString else {
      return nil
    }
    
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss z"
    dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
    
    let newDateString = dateString.replacingOccurrences(of: "Etc/GMT", with: "GMT")
    return dateFormatter.date(from: newDateString)
  }
}

public enum ReceiptStatus: Int {
  case noRecipt = -999
  case valid = 0
  case testReceipt = 21007
}
