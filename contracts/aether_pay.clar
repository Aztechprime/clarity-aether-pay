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

;; Process payment batch
(define-public (process-batch (batch-id (string-ascii 36)))
    (let ((batch (get-batch batch-id)))
        (match batch
            batch-data (begin 
                (asserts! (is-eq (get state batch-data) STATE_PENDING) err-invalid-state)
                (map process-batch-payment (get payments batch-data))
                (map-set PaymentBatches
                    { batch-id: batch-id }
                    (merge batch-data { state: STATE_PROCESSING })
                )
                (ok true)
            )
            err-invalid-batch
        )
    )
)

;; Initialize a new payment
(define-public (create-payment (payment-id (string-ascii 36)) 
                         (recipient principal)
                         (amount uint)
                         (currency (string-ascii 10))
                         (chain-id (string-ascii 10))
                         (batch-id (optional (string-ascii 36))))
    (let ((payment-exists (get-payment payment-id)))
        (if (is-some payment-exists)
            err-payment-exists
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
)

;; Process payment
(define-public (process-payment (payment-id (string-ascii 36)))
    (let ((payment (get-payment payment-id)))
        (match payment
            payment-data (begin
                (asserts! (is-eq (get state payment-data) STATE_PENDING) err-invalid-state)
                (map-set Payments
                    { payment-id: payment-id }
                    (merge payment-data { state: STATE_PROCESSING })
                )
                (ok true)
            )
            err-invalid-payment
        )
    )
)

;; Private function to process batch payment
(define-private (process-batch-payment (payment-id (string-ascii 36)))
    (match (get-payment payment-id)
        payment-data (begin
            (map-set Payments
                { payment-id: payment-id }
                (merge payment-data { state: STATE_PROCESSING })
            )
            (ok true)
        )
        err-invalid-payment
    )
)

;; Complete payment
(define-public (complete-payment (payment-id (string-ascii 36)))
    (let ((payment (get-payment payment-id)))
        (match payment
            payment-data (begin
                (asserts! (is-eq (get state payment-data) STATE_PROCESSING) err-invalid-state)
                (try! (update-batch-if-needed payment-id payment-data))
                (map-set Payments
                    { payment-id: payment-id }
                    (merge payment-data { state: STATE_COMPLETED })
                )
                (ok true)
            )
            err-invalid-payment
        )
    )
)

;; Update batch state if all payments completed
(define-private (update-batch-if-needed (payment-id (string-ascii 36)) (payment-data (tuple (sender principal) (recipient principal) (amount uint) (currency (string-ascii 10)) (state uint) (timestamp uint) (chain-id (string-ascii 10)) (batch-id (optional (string-ascii 36))))))
    (match (get batch-id payment-data)
        batch-id (match (get-batch batch-id)
            batch-data (begin
                (if (all-payments-complete batch-data)
                    (map-set PaymentBatches
                        { batch-id: batch-id }
                        (merge batch-data { state: STATE_COMPLETED })
                    )
                    true
                )
                (ok true)
            )
            (ok true)
        )
        (ok true)
    )
)

;; Check if all payments in batch are complete
(define-private (all-payments-complete (batch-data (tuple (sender principal) (payments (list 100 (string-ascii 36))) (state uint) (timestamp uint))))
    (fold check-payment-complete (get payments batch-data) true)
)

(define-private (check-payment-complete (payment-id (string-ascii 36)) (all-complete bool))
    (match (get-payment payment-id)
        payment-data (is-eq (get state payment-data) STATE_COMPLETED)
        false
    )
)

;; Initiate dispute
(define-public (dispute-payment (payment-id (string-ascii 36)) (reason (string-ascii 100)))
    (let ((payment (get-payment payment-id)))
        (match payment
            payment-data (begin
                (asserts! (is-eq (get state payment-data) STATE_COMPLETED) err-invalid-state)
                (map-set PaymentDisputes
                    { payment-id: payment-id }
                    {
                        initiator: tx-sender,
                        reason: reason,
                        timestamp: block-height,
                        resolved: false
                    }
                )
                (map-set Payments
                    { payment-id: payment-id }
                    (merge payment-data { state: STATE_DISPUTED })
                )
                (ok true)
            )
            err-invalid-payment
        )
    )
)

;; Resolve dispute
(define-public (resolve-dispute (payment-id (string-ascii 36)) (refund bool))
    (let (
        (payment (get-payment payment-id))
        (dispute (get-dispute payment-id))
    )
        (match payment payment-data
            (match dispute dispute-data
                (begin
                    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
                    (asserts! (is-eq (get state payment-data) STATE_DISPUTED) err-invalid-state)
                    (map-set PaymentDisputes
                        { payment-id: payment-id }
                        (merge dispute-data { resolved: true })
                    )
                    (map-set Payments
                        { payment-id: payment-id }
                        (merge payment-data 
                            { state: (if refund STATE_REFUNDED STATE_COMPLETED) }
                        )
                    )
                    (ok true)
                )
                err-invalid-payment
            )
            err-invalid-payment
        )
    )
)

;; Read-only functions

(define-read-only (get-payment (payment-id (string-ascii 36)))
    (map-get? Payments { payment-id: payment-id })
)

(define-read-only (get-batch (batch-id (string-ascii 36)))
    (map-get? PaymentBatches { batch-id: batch-id })
)

(define-read-only (get-dispute (payment-id (string-ascii 36)))
    (map-get? PaymentDisputes { payment-id: payment-id })
)

(define-read-only (get-payment-state (payment-id (string-ascii 36)))
    (match (get-payment payment-id)
        payment (ok (get state payment))
        err-invalid-payment
    )
)

(define-read-only (get-batch-state (batch-id (string-ascii 36)))
    (match (get-batch batch-id)
        batch (ok (get state batch))
        err-invalid-batch
    )
)
