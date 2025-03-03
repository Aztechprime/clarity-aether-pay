Clarinet.test({
    name: "Test enhanced currency configuration and validation",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        const wallet2 = accounts.get('wallet_2')!;
        
        // Test currency configuration
        let block = chain.mineBlock([
            Tx.contractCall(
                CONTRACT_NAME,
                'set-currency-config',
                [
                    types.ascii('STX'),
                    types.bool(true),
                    types.uint(6),
                    types.uint(1000000),
                    types.uint(1000000000000)
                ],
                deployer.address
            )
        ]);
        block.receipts[0].result.expectOk();

        // Test payment with valid amount
        block = chain.mineBlock([
            Tx.contractCall(
                CONTRACT_NAME,
                'create-payment',
                [
                    types.ascii(PAYMENT_ID),
                    types.principal(wallet2.address),
                    types.uint(2000000),
                    types.ascii('STX'),
                    types.ascii('stacks'),
                    types.none()
                ],
                wallet1.address
            )
        ]);
        block.receipts[0].result.expectOk();

        // Test payment with amount below minimum
        block = chain.mineBlock([
            Tx.contractCall(
                CONTRACT_NAME,
                'create-payment',
                [
                    types.ascii(PAYMENT_ID_2),
                    types.principal(wallet2.address),
                    types.uint(100),
                    types.ascii('STX'),
                    types.ascii('stacks'),
                    types.none()
                ],
                wallet1.address
            )
        ]);
        block.receipts[0].result.expectErr().expectUint(107);
    }
});

// [Rest of test implementation remains unchanged]
