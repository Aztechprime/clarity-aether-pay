;; AetherPay - Cross-chain Payment Platform

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-invalid-payment (err u101))
(define-constant err-payment-exists (err u102))
(define-constant err-invalid-state (err u103))
(define-constant err-unauthorized (err u104))

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
        chain-id: (string-ascii 10)
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

;; Initialize a new payment
(define-public (create-payment (payment-id (string-ascii 36)) 
                             (recipient principal)
                             (amount uint)
                             (currency (string-ascii 10))
                             (chain-id (string-ascii 10)))
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
                        chain-id: chain-id
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

;; Complete payment
(define-public (complete-payment (payment-id (string-ascii 36)))
    (let ((payment (get-payment payment-id)))
        (match payment
            payment-data (begin
                (asserts! (is-eq (get state payment-data) STATE_PROCESSING) err-invalid-state)
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

(define-read-only (get-dispute (payment-id (string-ascii 36)))
    (map-get? PaymentDisputes { payment-id: payment-id })
)

(define-read-only (get-payment-state (payment-id (string-ascii 36)))
    (match (get-payment payment-id)
        payment (ok (get state payment))
        err-invalid-payment
    )
)