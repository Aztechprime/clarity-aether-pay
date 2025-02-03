;; AetherPay - Cross-chain Payment Platform

;; Constants 
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-invalid-payment (err u101)) 
(define-constant err-payment-exists (err u102))
(define-constant err-invalid-state (err u103))
(define-constant err-unauthorized (err u104))
(define-constant err-invalid-batch (err u105))
(define-constant err-batch-exists (err u106))
(define-constant err-invalid-amount (err u107))
(define-constant err-invalid-recipient (err u108))

;; Payment States
(define-constant STATE_PENDING u1)
(define-constant STATE_PROCESSING u2) 
(define-constant STATE_COMPLETED u3)
(define-constant STATE_DISPUTED u4)
(define-constant STATE_REFUNDED u5)

;; Data Structures
(define-map Payments
    { payment-id: (string-ascii 36) }
    {
        sender: principal,
        recipient: principal,
        amount: uint,
        currency: (string-ascii 10),
        state: uint,
        timestamp: uint,
        chain-id: (string-ascii 10),
        batch-id: (optional (string-ascii 36))
    }
)

(define-map PaymentBatches
    { batch-id: (string-ascii 36) }
    {
        sender: principal,
        payments: (list 100 (string-ascii 36)),
        state: uint,
        timestamp: uint
    }
)

(define-map PaymentDisputes
    { payment-id: (string-ascii 36) }
    {
        initiator: principal,
        reason: (string-ascii 100),
        timestamp: uint,
        resolved: bool
    }
)

;; Validation functions
(define-private (validate-payment-amount (amount uint))
    (if (> amount u0)
        (ok true)
        err-invalid-amount))

(define-private (validate-recipient (recipient principal))
    (if (not (is-eq tx-sender recipient))
        (ok true)
        err-invalid-recipient))

;; Public Functions

;; Create a payment batch
(define-public (create-payment-batch 
                (batch-id (string-ascii 36))
                (payment-ids (list 100 (string-ascii 36))))
    (let ((batch-exists (get-batch batch-id)))
        (asserts! (is-none batch-exists) err-batch-exists)
        (asserts! (> (len payment-ids) u0) err-invalid-batch)
        (map-set PaymentBatches
            { batch-id: batch-id }
            {
                sender: tx-sender,
                payments: payment-ids,
                state: STATE_PENDING,
                timestamp: block-height
            }
        )
        (ok true)
    )
)

;; Initialize a new payment with validation
(define-public (create-payment (payment-id (string-ascii 36)) 
                         (recipient principal)
                         (amount uint)
                         (currency (string-ascii 10))
                         (chain-id (string-ascii 10))
                         (batch-id (optional (string-ascii 36))))
    (let ((payment-exists (get-payment payment-id)))
        (asserts! (is-none payment-exists) err-payment-exists)
        (try! (validate-payment-amount amount))
        (try! (validate-recipient recipient))
        (begin
            (map-set Payments
                { payment-id: payment-id }
                {
                    sender: tx-sender,
                    recipient: recipient,
                    amount: amount,
                    currency: currency,
                    state: STATE_PENDING,
                    timestamp: block-height,
                    chain-id: chain-id,
                    batch-id: batch-id
                }
            )
            (ok true)
        )
    )
)

[Rest of contract code remains unchanged]
