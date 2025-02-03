[Previous test content]

Clarinet.test({
    name: "Test payment validation",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;
        
        // Test invalid amount (0)
        let block = chain.mineBlock([
            Tx.contractCall(
                CONTRACT_NAME,
                'create-payment',
                [
                    types.ascii(PAYMENT_ID),
                    types.principal(wallet1.address),
                    types.uint(0),
                    types.ascii('STX'),
                    types.ascii('stacks'),
                    types.none()
                ],
                wallet1.address
            )
        ]);
        block.receipts[0].result.expectErr().expectUint(107);

        // Test self-payment
        block = chain.mineBlock([
            Tx.contractCall(
                CONTRACT_NAME,
                'create-payment',
                [
                    types.ascii(PAYMENT_ID),
                    types.principal(wallet1.address),
                    types.uint(1000),
                    types.ascii('STX'),
                    types.ascii('stacks'),
                    types.none()
                ],
                wallet1.address
            )
        ]);
        block.receipts[0].result.expectErr().expectUint(108);
    }
});
