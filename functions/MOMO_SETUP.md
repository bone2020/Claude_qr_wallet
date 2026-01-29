# MTN MoMo API Setup Guide

This guide explains how to configure MTN Mobile Money API integration for the QR Wallet app.

## Overview

The app uses MTN MoMo Open API for direct mobile money payments in supported African countries:
- Ghana, Uganda, Rwanda, Cameroon, Benin, Ivory Coast, Congo, Guinea, Liberia, Zambia, South Africa, Eswatini, South Sudan, Guinea-Bissau

### Two Payment Flows:
1. **Collections (Add Money)** - Request payment from user's MoMo wallet
2. **Disbursements (Withdraw)** - Transfer money to user's MoMo wallet

---

## Step 1: Create MTN MoMo Developer Account

1. Go to [MTN MoMo Developer Portal](https://momodeveloper.mtn.com/)
2. Click "Sign Up" and create an account
3. Verify your email address
4. Log in to the developer portal

---

## Step 2: Subscribe to Products

In the developer portal:

1. Go to **Products** section
2. Subscribe to these products:
   - **Collections** - For receiving payments (Add Money)
   - **Disbursements** - For sending payments (Withdraw)

3. After subscribing, you'll receive:
   - **Primary Key** (Subscription Key) for each product
   - **Secondary Key** (backup, optional)

---

## Step 3: Create API User (Sandbox)

For sandbox testing, create an API user:

```bash
# Generate a UUID for your API User
API_USER=$(uuidgen)
echo "Your API User: $API_USER"

# Create API User for Collections
curl -X POST "https://sandbox.momodeveloper.mtn.com/v1_0/apiuser" \
  -H "X-Reference-Id: $API_USER" \
  -H "Ocp-Apim-Subscription-Key: YOUR_COLLECTIONS_SUBSCRIPTION_KEY" \
  -H "Content-Type: application/json" \
  -d '{"providerCallbackHost": "https://us-central1-qr-wallet-1993.cloudfunctions.net"}'

# Get API Key for Collections
curl -X POST "https://sandbox.momodeveloper.mtn.com/v1_0/apiuser/$API_USER/apikey" \
  -H "Ocp-Apim-Subscription-Key: YOUR_COLLECTIONS_SUBSCRIPTION_KEY"
```

Repeat for Disbursements with a different API User UUID.

---

## Step 4: Configure Firebase Functions

Set all required configuration values:

```bash
# Collections (Add Money) - Required
firebase functions:config:set \
  momo.collections_subscription_key="YOUR_COLLECTIONS_PRIMARY_KEY" \
  momo.collections_api_user="YOUR_COLLECTIONS_API_USER_UUID" \
  momo.collections_api_key="YOUR_COLLECTIONS_API_KEY"

# Disbursements (Withdraw) - Required
firebase functions:config:set \
  momo.disbursements_subscription_key="YOUR_DISBURSEMENTS_PRIMARY_KEY" \
  momo.disbursements_api_user="YOUR_DISBURSEMENTS_API_USER_UUID" \
  momo.disbursements_api_key="YOUR_DISBURSEMENTS_API_KEY"

# Environment (sandbox or production)
firebase functions:config:set momo.environment="sandbox"

# Webhook Secret (optional but recommended for production)
firebase functions:config:set momo.webhook_secret="YOUR_RANDOM_SECRET_STRING"
```

### Verify Configuration

```bash
firebase functions:config:get
```

---

## Step 5: Deploy Functions

```bash
# Deploy all functions
firebase deploy --only functions

# Or deploy specific MoMo functions
firebase deploy --only functions:momoRequestToPay,functions:momoTransfer,functions:momoCheckStatus
```

---

## Configuration Reference

| Config Key | Description | Required |
|------------|-------------|----------|
| `momo.collections_subscription_key` | Primary key from Collections subscription | Yes (for Add Money) |
| `momo.collections_api_user` | API User UUID for Collections | Yes (for Add Money) |
| `momo.collections_api_key` | API Key for Collections | Yes (for Add Money) |
| `momo.disbursements_subscription_key` | Primary key from Disbursements subscription | Yes (for Withdraw) |
| `momo.disbursements_api_user` | API User UUID for Disbursements | Yes (for Withdraw) |
| `momo.disbursements_api_key` | API Key for Disbursements | Yes (for Withdraw) |
| `momo.environment` | `sandbox` or `production` | Recommended |
| `momo.webhook_secret` | Secret for webhook authentication | Recommended |

---

## Sandbox Testing

### Test Phone Numbers (Sandbox)
MTN sandbox accepts any phone number in format: `46733123XXX` (Swedish format)

Example test numbers:
- `46733123450` - Will succeed
- `46733123451` - Will fail (insufficient funds)
- `46733123452` - Will be pending

### Test Currency
Sandbox uses **EUR** as currency regardless of what you send.

---

## Production Setup

For production:

1. Complete MTN's KYC/verification process
2. Get production API credentials
3. Update Firebase config:
   ```bash
   firebase functions:config:set momo.environment="production"
   # Update all keys with production values
   ```

4. **Important**: Never use sandbox credentials in production!

---

## Troubleshooting

### "Service unavailable: momo_collections is not configured"
Run the config commands in Step 4 and redeploy functions.

### "Failed to get MoMo access token"
Check that:
- API User and API Key are correct
- Subscription Key is valid
- You're using the correct environment (sandbox vs production)

### "CRITICAL CONFIG MISSING" in logs
Check Firebase Functions logs for which keys are missing:
```bash
firebase functions:log
```

### Webhook not receiving callbacks
1. Verify webhook URL is accessible
2. Check `momo.webhook_secret` is set
3. Ensure Cloud Functions are deployed

---

## API Endpoints Used

| Function | MoMo Endpoint | Purpose |
|----------|---------------|---------|
| `momoRequestToPay` | `POST /collection/v1_0/requesttopay` | Request payment from user |
| `momoCheckStatus` | `GET /collection/v1_0/requesttopay/{referenceId}` | Check payment status |
| `momoTransfer` | `POST /disbursement/v1_0/transfer` | Send money to user |
| `momoWebhook` | (incoming) | Receive payment notifications |

---

## Security Notes

1. **Never commit API keys** to version control
2. Use Firebase Functions Config for all secrets
3. Rotate API keys periodically
4. Monitor for unusual activity
5. Use webhook secret in production

---

## Related Files

- `functions/index.js` - Cloud Functions implementation (search for "MOMO")
- `lib/core/services/momo_service.dart` - Flutter client
- `lib/core/services/payment_service.dart` - Payment orchestration
- `lib/features/wallet/screens/add_money_screen.dart` - Add Money UI
- `lib/features/wallet/screens/withdraw_screen.dart` - Withdraw UI
