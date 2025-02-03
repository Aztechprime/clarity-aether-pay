# AetherPay

A cross-chain payment platform built on the Stacks blockchain that enables secure transactions across different blockchain networks.

## Features
- Process cross-chain payments
- Track payment states 
- Verify payment completions
- Handle payment disputes
- Support multiple currencies
- Batch payment processing
- Automatic batch state management
- Atomic batch operations
- Input validation for payments

## Technical Details
The smart contract implements:
- Payment processing logic
- State management
- Security controls
- Multi-currency support
- Dispute resolution mechanism
- Payment batching system
- Batch state tracking 
- Batch completion verification
- Payment amount validation
- Recipient address validation

## Getting Started
1. Clone the repository
2. Install dependencies
3. Run tests using Clarinet
4. Deploy using Stacks CLI

## Payment Validation
The contract now includes enhanced payment validation:
- Ensures payment amounts are greater than 0
- Prevents self-payments (sender cannot be recipient)
- Validates payment parameters before processing

[Rest of README remains unchanged]
