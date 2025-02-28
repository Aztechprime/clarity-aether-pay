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
(define-constant err-invalid-currency (err u109))
(define-constant err-contract-paused (err u110))
(define-constant err-payment-timeout (err u111))

;; New Constants
(define-constant MAX_PAYMENT_AMOUNT u1000000000000)
(define-constant PAYMENT_TIMEOUT_BLOCKS u144) ;; ~24 hours

;; Contract State
(define-data-var contract-paused bool false)

;; Supported Currencies
(define-map SupportedCurrencies
    { currency: (string-ascii 10) }
    { active: bool }
)

;; Payment States
(define-constant STATE_PENDING u1)
(define-constant STATE_PROCESSING u2) 
(define-constant STATE_COMPLETED u3)
(define-constant STATE_DISPUTED u4)
(define-constant STATE_REFUNDED u5)
(define-constant STATE_TIMEOUT u6)

;; [Previous data structures remain unchanged]

;; Enhanced Validation functions
(define-private (validate-payment-amount (amount uint))
    (if (and (> amount u0) (<= amount MAX_PAYMENT_AMOUNT))
        (ok true)
        err-invalid-amount))

(define-private (validate-recipient (recipient principal))
    (if (not (is-eq tx-sender recipient))
        (ok true)
        err-invalid-recipient))

(define-private (validate-currency (currency (string-ascii 10)))
    (match (map-get? SupportedCurrencies { currency: currency })
        currency-data (ok true)
        err-invalid-currency))

(define-private (validate-payment-timeout (timestamp uint))
    (if (< (- block-height timestamp) PAYMENT_TIMEOUT_BLOCKS)
        (ok true)
        err-payment-timeout))

;; Admin Functions
(define-public (set-supported-currency (currency (string-ascii 10)) (active bool))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok (map-set SupportedCurrencies
            { currency: currency }
            { active: active }))
    ))

(define-public (toggle-contract-pause)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok (var-set contract-paused (not (var-get contract-paused))))
    ))

;; Enhanced create-payment function
(define-public (create-payment 
              (payment-id (string-ascii 36)) 
              (recipient principal)
              (amount uint)
              (currency (string-ascii 10))
              (chain-id (string-ascii 10))
              (batch-id (optional (string-ascii 36))))
    (let ((payment-exists (get-payment payment-id)))
        (asserts! (not (var-get contract-paused)) err-contract-paused)
        (asserts! (is-none payment-exists) err-payment-exists)
        (try! (validate-payment-amount amount))
        (try! (validate-recipient recipient))
        (try! (validate-currency currency))
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
    ))

[Rest of contract code remains unchanged]
