//
//  IAPHelper.swift
//  IAPDemo
//
//  Created by Jason Zheng on 8/24/16.
//  Copyright © 2016 Jason Zheng. All rights reserved.
//

import StoreKit

let IAP = IAPHelper.sharedInstance

public typealias ProductIdentifier = String
public typealias ProductWithExpireDate = [ProductIdentifier: NSDate]

public typealias ProductsRequestHandler = (response: SKProductsResponse?, error: NSError?) -> ()
public typealias PurchaseHandler = (productIdentifier: ProductIdentifier?, error: NSError?) -> ()
public typealias RestoreHandler = (productIdentifiers: Set<ProductIdentifier>, error: NSError?) -> ()
public typealias ValidateHandler = (statusCode: Int?, products: ProductWithExpireDate?) -> ()

class IAPHelper: NSObject {
  
  private override init() {
    super.init()
    
    addObserver()
  }
  static let sharedInstance = IAPHelper()
  
  private var productsRequest: SKProductsRequest?
  private var productsRequestHandler: ProductsRequestHandler?
  
  private var purchaseHandler: PurchaseHandler?
  private var restoreHandler: RestoreHandler?
  
  private var observerAdded = false
  
  func addObserver() {
    if !observerAdded {
      observerAdded = true
      SKPaymentQueue.defaultQueue().addTransactionObserver(self)
    }
  }
  
  func removeObserver() {
    if observerAdded {
      observerAdded = false
      SKPaymentQueue.defaultQueue().removeTransactionObserver(self)
    }
  }
}

// MARK: StoreKit API

extension IAPHelper {
  
  func requestProducts(productIdentifiers: Set<ProductIdentifier>, handler: ProductsRequestHandler) {
    productsRequest?.cancel()
    productsRequestHandler = handler
    
    productsRequest = SKProductsRequest(productIdentifiers: productIdentifiers)
    productsRequest?.delegate = self
    productsRequest?.start()
  }
  
  func purchaseProduct(productIdentifier: ProductIdentifier, handler: PurchaseHandler) {
    purchaseHandler = handler
    
    let payment = SKMutablePayment()
    payment.productIdentifier = productIdentifier
    SKPaymentQueue.defaultQueue().addPayment(payment)
  }
  
  func restorePurchases(handler: RestoreHandler) {
    restoreHandler = handler
    SKPaymentQueue.defaultQueue().restoreCompletedTransactions()
  }
  
  /*
   * password: Only used for receipts that contain auto-renewable subscriptions.
   *           It's your app’s shared secret (a hexadecimal string) which was generated on iTunesConnect.
   */
  func validateReceipt(password: String, handler: ValidateHandler) {
    validateReceiptInternal(isProduction: true, password: password) { (statusCode, products) in
      
      if let statusCode = statusCode where statusCode == ReceiptStatus.TestReceipt.rawValue {
        self.validateReceiptInternal(isProduction: false, password: password, handler: { (statusCode, products) in
          handler(statusCode: statusCode, products: products)
        })
        
      } else {
        handler(statusCode: statusCode, products: products)
      }
    }
  }
}

// MARK: SKProductsRequestDelegate

extension IAPHelper: SKProductsRequestDelegate {
  func productsRequest(request: SKProductsRequest, didReceiveResponse response: SKProductsResponse) {
    productsRequestHandler?(response: response, error: nil)
    clearRequestAndHandler()
  }
  
  func request(request: SKRequest, didFailWithError error: NSError?) {
    productsRequestHandler?(response: nil, error: error)
    clearRequestAndHandler()
  }
  
  private func clearRequestAndHandler() {
    productsRequest = nil
    productsRequestHandler = nil
  }
}

// MARK: SKPaymentTransactionObserver

extension IAPHelper: SKPaymentTransactionObserver {
  
  func paymentQueue(queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
    for transaction in transactions {
      switch (transaction.transactionState) {

      case SKPaymentTransactionStatePurchased:
        completePurchaseTransaction(transaction)
        
      case SKPaymentTransactionStateRestored:
        finishTransaction(transaction)
        
      case SKPaymentTransactionStateFailed:
        failedTransaction(transaction)
        
      case SKPaymentTransactionStatePurchasing,
           SKPaymentTransactionStateDeferred:
        break
        
      default:
        break
      }
    }
  }
  
  func paymentQueueRestoreCompletedTransactionsFinished(queue: SKPaymentQueue) {
    completeRestoreTransactions(queue, error: nil)
  }
  
  func paymentQueue(queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: NSError) {
    completeRestoreTransactions(queue, error: error)
  }
  
  private func completePurchaseTransaction(transaction: SKPaymentTransaction) {
    purchaseHandler?(productIdentifier: transaction.payment.productIdentifier, error: transaction.error)
    purchaseHandler = nil
    
    finishTransaction(transaction)
  }
  
  private func completeRestoreTransactions(queue: SKPaymentQueue, error: NSError?) {
    var productIdentifiers = Set<ProductIdentifier>()
    
    if let transactions = queue.transactions {
      for transaction in transactions {
        if let productIdentifier = transaction.originalTransaction?.payment.productIdentifier {
          productIdentifiers.insert(productIdentifier)
        }
        
        finishTransaction(transaction)
      }
    }
    
    restoreHandler?(productIdentifiers: productIdentifiers, error: error)
    restoreHandler = nil
  }
  
  private func failedTransaction(transaction: SKPaymentTransaction) {
    // NOTE: Both purchase and restore may come to this state. So need to deal with both handlers.
    
    purchaseHandler?(productIdentifier: nil, error: transaction.error)
    purchaseHandler = nil
    
    restoreHandler?(productIdentifiers: Set<ProductIdentifier>(), error: transaction.error)
    restoreHandler = nil
    
    finishTransaction(transaction)
  }
  
  // MARK: Helper
  
  private func finishTransaction(transaction: SKPaymentTransaction) {
    switch transaction.transactionState {
    case SKPaymentTransactionStatePurchased,
         SKPaymentTransactionStateRestored,
         SKPaymentTransactionStateFailed:
      
      SKPaymentQueue.defaultQueue().finishTransaction(transaction)
      
    default:
      break
    }
  }
}

// MARK: Validate Receipt

extension IAPHelper {
  
  private func validateReceiptInternal(isProduction isProduction: Bool, password: String, handler: ValidateHandler) {
    
    let serverURL = isProduction
      ? "https://buy.itunes.apple.com/verifyReceipt"
      : "https://sandbox.itunes.apple.com/verifyReceipt"
    
    let appStoreReceiptURL = NSBundle.mainBundle().appStoreReceiptURL
    guard let receiptData = receiptData(appStoreReceiptURL, password: password), url = NSURL(string: serverURL) else {
      handler(statusCode: ReceiptStatus.NoRecipt.rawValue, products: nil)
      return
    }
    
    let request = NSMutableURLRequest(URL: url)
    request.HTTPMethod = "POST"
    request.HTTPBody = receiptData
    
    let task = NSURLSession.sharedSession().dataTaskWithRequest(request, completionHandler: { (data, response, error) in
      
      guard let data = data where error == nil else {
        handler(statusCode: nil, products: nil)
        return
      }
      
      do {
        let json = try NSJSONSerialization.JSONObjectWithData(data, options:[])
        
        let statusCode = json["status"] as? Int
        let products = self.parseValidateResultJSON(json)
        handler(statusCode: statusCode, products: products)
        
      } catch {
        handler(statusCode: nil, products: nil)
      }
    })
    task.resume()
  }
  
  private func parseValidateResultJSON(json: AnyObject) -> ProductWithExpireDate? {
    var products = ProductWithExpireDate()
    var cancelledProducts = ProductWithExpireDate()
    
    if let receiptList = json["latest_receipt_info"] as? [AnyObject] {
      for receipt in receiptList {
        if let productID = receipt["product_id"] as? String {
          
          if let expiresDate = parseDate(receipt["expires_date"] as? String) {
            if let existingExpiresDate = products[productID] where existingExpiresDate.timeIntervalSince1970 >= expiresDate.timeIntervalSince1970 {
              // Do nothing
            } else {
              products[productID] = expiresDate
            }
          }
          
          if let cancellationDate = parseDate(receipt["cancellation_date"] as? String) {
            if let existingExpiresDate = cancelledProducts[productID] where existingExpiresDate.timeIntervalSince1970 >= cancellationDate.timeIntervalSince1970 {
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
      if let expiresDate = products[productID] where expiresDate.timeIntervalSince1970 <= cancelledExpiresDate.timeIntervalSince1970 {
        products[productID] = NSDate(timeIntervalSince1970: 0)
      }
    }
    
    return products.isEmpty ? nil : products
  }

  private func receiptData(appStoreReceiptURL: NSURL?, password: String) -> NSData? {
    guard let receiptURL = appStoreReceiptURL, receipt = NSData(contentsOfURL: receiptURL) else {
        return nil
    }
    
    do {
      let receiptData = receipt.base64EncodedStringWithOptions(NSDataBase64EncodingOptions(rawValue: 0))
      let requestContents = ["receipt-data": receiptData, "password": password]
      let requestData = try NSJSONSerialization.dataWithJSONObject(requestContents, options: [])
      return requestData
    } catch let error as NSError {
      NSLog("\(error)")
    }
    
    return nil
  }
  /*
   * dateString demo: "2016-08-24 09:42:11 Etc/GMT"
   * Need to remove "Etc/" to parse the date
   */
  private func parseDate(dateString: String?) -> NSDate? {
    guard let dateString = dateString else {
      return nil
    }
    
    let dateFormatter = NSDateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss z"
    dateFormatter.timeZone = NSTimeZone(forSecondsFromGMT: 0)
    
    let newDateString = dateString.stringByReplacingOccurrencesOfString("Etc/GMT", withString: "GMT")
    return dateFormatter.dateFromString(newDateString)
  }
}

public enum ReceiptStatus: Int {
  case NoRecipt = -999
  case Valid = 0
  case TestReceipt = 21007
}
