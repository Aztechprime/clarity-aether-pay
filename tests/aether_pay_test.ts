Clarinet.test({
    name: "Test enhanced payment validation",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        const wallet2 = accounts.get('wallet_2')!;
        
        // Setup supported currency
        let block = chain.mineBlock([
            Tx.contractCall(
                CONTRACT_NAME,
                'set-supported-currency',
                [types.ascii('STX'), types.bool(true)],
                deployer.address
            )
        ]);
        block.receipts[0].result.expectOk();

        // Test invalid amount (0)
        block = chain.mineBlock([
            Tx.contractCall(
                CONTRACT_NAME,
                'create-payment',
                [
                    types.ascii(PAYMENT_ID),
                    types.principal(wallet2.address),
                    types.uint(0),
                    types.ascii('STX'),
                    types.ascii('stacks'),
                    types.none()
                ],
                wallet1.address
            )
        ]);
        block.receipts[0].result.expectErr().expectUint(107);

        // Test amount exceeding maximum
        block = chain.mineBlock([
            Tx.contractCall(
                CONTRACT_NAME,
                'create-payment',
                [
                    types.ascii(PAYMENT_ID),
                    types.principal(wallet2.address),
                    types.uint(1000000000001),
                    types.ascii('STX'),
                    types.ascii('stacks'),
                    types.none()
                ],
                wallet1.address
            )
        ]);
        block.receipts[0].result.expectErr().expectUint(107);

        // Test invalid currency
        block = chain.mineBlock([
            Tx.contractCall(
                CONTRACT_NAME,
                'create-payment',
                [
                    types.ascii(PAYMENT_ID),
                    types.principal(wallet2.address),
                    types.uint(1000),
                    types.ascii('INVALID'),
                    types.ascii('stacks'),
                    types.none()
                ],
                wallet1.address
            )
        ]);
        block.receipts[0].result.expectErr().expectUint(109);
    }
});

[Rest of test file remains unchanged]
