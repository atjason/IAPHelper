# What's IAPHelper

IAPHelper simply wraps the API of Apple's In-App Purchase using Swift. Very lightweight and easy to use.

# IAPHelper Usage

## Request Product List

```swift
var productIdentifiers = Set<ProductIdentifier>()
productIdentifiers.insert("product_id_1")
productIdentifiers.insert("product_id_2")

IAP.requestProducts(productIdentifiers) { (response, error) in
	if let products = response?.products where !products.isEmpty {
		// Get the valid products
	   
	} else if let invalidProductIdentifiers = response?.invalidProductIdentifiers {
		// Some products id are invalid
	   
	} else {
		// Some error happened
	}
}
```

## Purchase Product

```swift
 IAP.purchaseProduct(productIdentifier, handler: { (productIdentifier, error) in
	if let identifier = productIdentifier {
		// The product of 'productIdentifier' purchased.
	     
	} else if let error = error as? NSError {
      if error.code == SKError.Code.paymentCancelled.rawValue {
		// User cancelled
        
      } else {
		// Some error happened
      }
    }
})
```

## Restore

```swift
 IAP.restorePurchases { (productIdentifiers, error) in
	 if !productIdentifiers.isEmpty {
	 	// Products restored
	   
	 } else if let error = error as? NSError {
       if error.code == SKError.Code.paymentCancelled.rawValue {
	  	// User cancelled
        
       } else {
	  	// Some error happened
       }
      
    } else {
      // No previous purchases were found.
    }
}
```

## Validate Receipt

```swift
IAP.validateReceipt(Constants.IAPSharedSecret) { (statusCode, products) in
	if statusCode == ReceiptStatus.NoRecipt.rawValue {
		// No Receipt in main bundle
	} else {
		// Get products with their expire date.
	}
})
```

**Note**: IAPHelper directly validate with Apple's server. It's simple, but has risk. You decide to use your own server or not. Here's what Apple suggested:

> Use a trusted server to communicate with the App Store. Using your own server lets you design your app to recognize and trust only your server, and lets you ensure that your server connects with the App Store server. It is not possible to build a trusted connection between a user’s device and the App Store directly because you don’t control either end of that connection.

## Integrate IAPHelper in Your Project

Just copy `IAPHelper.swift` to your project, and use it as the demo shows.

## IAPHelper Demo

**NOTE**: You need to change the app bundle id and product id to your own. And also set your shared secret in `Constants.swift`.

# Note

This library can't help you understand the basic concepts for IAP. For it, please refer to these documents.

- 	[In-App Purchase Programming Guide](https://developer.apple.com/library/ios/documentation/NetworkingInternet/Conceptual/StoreKitGuide/Introduction.html)
- 	[In-App Purchase Configuration Guide for iTunes Connect](https://developer.apple.com/library/ios/documentation/LanguagesUtilities/Conceptual/iTunesConnectInAppPurchase_Guide/Chapters/Introduction.html)
- 	[In-App Purchase Best Practices](https://developer.apple.com/library/ios/technotes/tn2387/_index.html)
- 	[Receipt Validation Programming Guide](https://developer.apple.com/library/ios/releasenotes/General/ValidateAppStoreReceipt/Introduction.html)
- 	[Adding In-App Purchase to your iOS and macOS Applications](https://developer.apple.com/library/ios/technotes/tn2259/_index.html)

## What's Test

It's mainly test on macOS 10.11 and Sierra with auto-renew subscription. Now it's used by my app of [iPaste](https://itunes.apple.com/app/id1056935452?ls=1&mt=12), [iTimer](https://itunes.apple.com/app/id1062139745?ls=1&mt=12), [iHosts](https://itunes.apple.com/app/id1102004240?ls=1&mt=12), [iPic](https://itunes.apple.com/app/id1101244278?ls=1&mt=12).

