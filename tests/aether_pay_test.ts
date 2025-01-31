import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

const CONTRACT_NAME = 'aether_pay';
const PAYMENT_ID = 'test-payment-123';
const BATCH_ID = 'test-batch-123';

Clarinet.test({
    name: "Test payment lifecycle",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        const wallet2 = accounts.get('wallet_2')!;

        // Create payment
        let block = chain.mineBlock([
            Tx.contractCall(
                CONTRACT_NAME,
                'create-payment',
                [
                    types.ascii(PAYMENT_ID),
                    types.principal(wallet2.address),
                    types.uint(1000),
                    types.ascii('STX'),
                    types.ascii('stacks'),
                    types.none()
                ],
                wallet1.address
            )
        ]);
        block.receipts[0].result.expectOk().expectBool(true);

        // Process payment
        block = chain.mineBlock([
            Tx.contractCall(
                CONTRACT_NAME,
                'process-payment',
                [types.ascii(PAYMENT_ID)],
                wallet1.address
            )
        ]);
        block.receipts[0].result.expectOk().expectBool(true);

        // Complete payment
        block = chain.mineBlock([
            Tx.contractCall(
                CONTRACT_NAME,
                'complete-payment',
                [types.ascii(PAYMENT_ID)],
                wallet1.address
            )
        ]);
        block.receipts[0].result.expectOk().expectBool(true);

        // Verify payment state
        block = chain.mineBlock([
            Tx.contractCall(
                CONTRACT_NAME,
                'get-payment-state',
                [types.ascii(PAYMENT_ID)],
                wallet1.address
            )
        ]);
        block.receipts[0].result.expectOk().expectUint(3); // STATE_COMPLETED
    }
});

Clarinet.test({
    name: "Test payment batch processing",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        const wallet2 = accounts.get('wallet_2')!;

        const payment1 = 'batch-payment-1';
        const payment2 = 'batch-payment-2';

        // Create payments for batch
        let block = chain.mineBlock([
            Tx.contractCall(
                CONTRACT_NAME,
                'create-payment',
                [
                    types.ascii(payment1),
                    types.principal(wallet2.address),
                    types.uint(1000),
                    types.ascii('STX'),
                    types.ascii('stacks'),
                    types.some(types.ascii(BATCH_ID))
                ],
                wallet1.address
            ),
            Tx.contractCall(
                CONTRACT_NAME,
                'create-payment',
                [
                    types.ascii(payment2),
                    types.principal(wallet2.address),
                    types.uint(2000),
                    types.ascii('STX'),
                    types.ascii('stacks'),
                    types.some(types.ascii(BATCH_ID))
                ],
                wallet1.address
            )
        ]);

        // Create batch
        block = chain.mineBlock([
            Tx.contractCall(
                CONTRACT_NAME,
                'create-payment-batch',
                [
                    types.ascii(BATCH_ID),
                    types.list([types.ascii(payment1), types.ascii(payment2)])
                ],
                wallet1.address
            )
        ]);
        block.receipts[0].result.expectOk().expectBool(true);

        // Process batch
        block = chain.mineBlock([
            Tx.contractCall(
                CONTRACT_NAME,
                'process-batch',
                [types.ascii(BATCH_ID)],
                wallet1.address
            )
        ]);
        block.receipts[0].result.expectOk().expectBool(true);

        // Complete payments
        block = chain.mineBlock([
            Tx.contractCall(
                CONTRACT_NAME,
                'complete-payment',
                [types.ascii(payment1)],
                wallet1.address
            ),
            Tx.contractCall(
                CONTRACT_NAME,
                'complete-payment',
                [types.ascii(payment2)],
                wallet1.address
            )
        ]);

        // Verify batch state
        block = chain.mineBlock([
            Tx.contractCall(
                CONTRACT_NAME,
                'get-batch-state',
                [types.ascii(BATCH_ID)],
                wallet1.address
            )
        ]);
        block.receipts[0].result.expectOk().expectUint(3); // STATE_COMPLETED
    }
});

Clarinet.test({
    name: "Test dispute resolution flow",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        const wallet2 = accounts.get('wallet_2')!;

        // Create and complete payment
        let block = chain.mineBlock([
            Tx.contractCall(
                CONTRACT_NAME,
                'create-payment',
                [
                    types.ascii(PAYMENT_ID),
                    types.principal(wallet2.address),
                    types.uint(1000),
                    types.ascii('STX'),
                    types.ascii('stacks'),
                    types.none()
                ],
                wallet1.address
            ),
            Tx.contractCall(
                CONTRACT_NAME,
                'process-payment',
                [types.ascii(PAYMENT_ID)],
                wallet1.address
            ),
            Tx.contractCall(
                CONTRACT_NAME,
                'complete-payment',
                [types.ascii(PAYMENT_ID)],
                wallet1.address
            )
        ]);

        // Create dispute
        block = chain.mineBlock([
            Tx.contractCall(
                CONTRACT_NAME,
                'dispute-payment',
                [
                    types.ascii(PAYMENT_ID),
                    types.ascii('Payment not received')
                ],
                wallet2.address
            )
        ]);
        block.receipts[0].result.expectOk().expectBool(true);

        // Resolve dispute with refund
        block = chain.mineBlock([
            Tx.contractCall(
                CONTRACT_NAME,
                'resolve-dispute',
                [
                    types.ascii(PAYMENT_ID),
                    types.bool(true)
                ],
                deployer.address
            )
        ]);
        block.receipts[0].result.expectOk().expectBool(true);

        // Verify final state
        block = chain.mineBlock([
            Tx.contractCall(
                CONTRACT_NAME,
                'get-payment-state',
                [types.ascii(PAYMENT_ID)],
                wallet1.address
            )
        ]);
        block.receipts[0].result.expectOk().expectUint(5); // STATE_REFUNDED
    }
});
