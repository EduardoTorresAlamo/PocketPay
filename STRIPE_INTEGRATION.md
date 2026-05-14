# Stripe Integration Guide for PRPay

## Overview
PRPay uses Stripe to process payments and simulate money transfers. This guide will help you integrate Stripe into the project.

## Prerequisites
1. A Stripe account (sign up at https://stripe.com)
2. Stripe API keys (available in your Stripe Dashboard)
3. Xcode 15.0 or later

## Step 1: Add Stripe SDK via Swift Package Manager

1. Open the `PocketPay.xcodeproj` in Xcode
2. Go to **File → Add Package Dependencies**
3. In the search bar, enter: `https://github.com/stripe/stripe-ios`
4. Select the latest version (recommended: 23.0.0 or higher)
5. Click **Add Package**
6. Select the following products:
   - `StripePaymentSheet`
   - `StripeCore`
   - `StripeUICore`
7. Click **Add Package**

## Step 2: Configure Your Stripe Keys

1. Log in to your Stripe Dashboard at https://dashboard.stripe.com
2. Navigate to **Developers → API Keys**
3. Copy your **Publishable key** and **Secret key** (use test keys for development)
4. Open `PocketPay/Config/APIKeys.swift`
5. Replace the placeholder values:

```swift
static let stripePublishableKey = "pk_test_YOUR_PUBLISHABLE_KEY_HERE"
static let stripeSecretKey = "sk_test_YOUR_SECRET_KEY_HERE"
```

## Step 3: Uncomment Stripe Code

Several files have commented-out Stripe code that needs to be activated:

### 3.1. Update StripeManager.swift

Open `PocketPay/Core/StripeManager.swift` and uncomment:
- The import statement at the top
- The `configureStripe()` implementation
- The `PaymentSheet` setup code in `preparePaymentSheet()`

### 3.2. Update Package Dependencies

If you prefer to use Package.swift instead of Xcode's UI:

```swift
// Add this to your Package.swift dependencies array
.package(url: "https://github.com/stripe/stripe-ios", from: "23.0.0")

// Add to your target dependencies
.product(name: "StripePaymentSheet", package: "stripe-ios")
```

## Step 4: Test the Integration

1. Build and run the app in Xcode
2. Log in with demo credentials (username: `demo`, password: `password`)
3. Try sending money to a contact
4. The Stripe payment sheet should appear

## Mock Mode vs Production Mode

### Mock Mode (Default)
- Set `APIKeys.useMockPayments = true` in `APIKeys.swift`
- No actual Stripe API calls are made
- Payments are simulated with a 90% success rate
- Perfect for testing UI/UX without Stripe setup

### Production Mode
- Set `APIKeys.useMockPayments = false` in `APIKeys.swift`
- Real Stripe API calls are made
- Requires valid Stripe keys
- Use test mode keys for development

## Backend Integration (Recommended for Production)

For production apps, you should NEVER expose your secret key in client code. Instead:

1. Create a backend server (Node.js, Python, Ruby, etc.)
2. Implement an endpoint to create Payment Intents:

```javascript
// Example Node.js endpoint
app.post('/create-payment-intent', async (req, res) => {
  const { amount } = req.body;

  const paymentIntent = await stripe.paymentIntents.create({
    amount: amount * 100, // Convert to cents
    currency: 'usd',
    automatic_payment_methods: {
      enabled: true,
    },
  });

  res.send({
    clientSecret: paymentIntent.client_secret,
  });
});
```

3. Update `StripeManager.swift` to call your backend:

```swift
func createPaymentIntent(amount: Double) async -> String? {
    let url = URL(string: "\(APIKeys.backendURL)/create-payment-intent")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let body: [String: Any] = [
        "amount": amount
    ]
    request.httpBody = try? JSONSerialization.data(withJSONObject: body)

    let (data, _) = try await URLSession.shared.data(for: request)
    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    return json?["clientSecret"] as? String
}
```

## Testing with Stripe Test Cards

Use these test card numbers in the payment sheet:

- **Success**: `4242 4242 4242 4242`
- **Decline**: `4000 0000 0000 0002`
- **3D Secure**: `4000 0027 6000 3184`

Use any future expiration date, any 3-digit CVC, and any zip code.

## Troubleshooting

### "Stripe not configured" warning
- Make sure you've added the Stripe SDK via Swift Package Manager
- Uncomment the Stripe import in `StripeManager.swift`

### Payment fails immediately
- Check that your Stripe keys are valid
- Ensure you're using test mode keys for development
- Check the Xcode console for error messages

### Build errors
- Clean build folder (Cmd+Shift+K)
- Delete derived data
- Restart Xcode

## Additional Resources

- [Stripe iOS SDK Documentation](https://stripe.com/docs/payments/accept-a-payment?platform=ios)
- [Stripe Payment Sheet Guide](https://stripe.com/docs/payments/accept-a-payment?platform=ios&ui=payment-sheet)
- [Stripe Testing Guide](https://stripe.com/docs/testing)

## Security Best Practices

1. **Never** commit API keys to version control
2. Use environment variables or secure key storage
3. Always use HTTPS for API calls
4. Implement server-side validation
5. Use webhook endpoints to verify payment status
6. Keep the Stripe SDK updated

## Next Steps

After integrating Stripe:
1. Implement error handling for declined cards
2. Add webhook handling for payment confirmations
3. Implement refund functionality
4. Add payment history sync with backend
5. Implement proper authentication with JWT tokens
6. Add KYC (Know Your Customer) verification
