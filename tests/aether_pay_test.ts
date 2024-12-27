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
                    types.ascii('stacks')
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
                    types.ascii('stacks')
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