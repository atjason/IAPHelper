//
//  Account.swift
//  IAPDemo
//
//  Created by Jason Zheng on 8/24/16.
//  Copyright © 2016 Jason Zheng. All rights reserved.
//

import Foundation

class AccountType: NSObject {
  var productIdentifier = ""
  var localizedTitle = ""
  var localizedTitleSuffix = ""
  
  override var description: String {
    return localizedTitle + localizedTitleSuffix
  }
  
  private override init() {}
  
  private init(productIdentifier: String, localizedTitle: String, localizedTitleSuffix: String) {
    self.productIdentifier = productIdentifier
    self.localizedTitle = localizedTitle
    self.localizedTitleSuffix = localizedTitleSuffix
  }
  
  func equal(_ account: AccountType) -> Bool {
    return self.productIdentifier == account.productIdentifier
  }
  
  static func getAccountType(_ productIdentifier: String) -> AccountType? {
    switch productIdentifier {
    case Free.productIdentifier:
      return Free
    case Plus1Y.productIdentifier:
      return Plus1Y
    case Pro1Y.productIdentifier:
      return Pro1Y
    default:
      return nil
    }
  }
  
  static let Free = AccountType(productIdentifier: Constants.AppBundleIdentifier + ".free",
                                localizedTitle: NSLocalizedString("IAP Free", comment: "Account"),
                                localizedTitleSuffix: "")
  
  static let Plus1Y = AccountType(productIdentifier: Constants.AppBundleIdentifier + ".plus1y",
                                 localizedTitle: NSLocalizedString("IAP Plus", comment: "Account"),
                                 localizedTitleSuffix: NSLocalizedString(" / year", comment: "Account"))
  
  static let Pro1Y = AccountType(productIdentifier: Constants.AppBundleIdentifier + ".pro1y",
                                 localizedTitle: NSLocalizedString("IAP Pro", comment: "Account"),
                                 localizedTitleSuffix: NSLocalizedString(" / year", comment: "Account"))
}
