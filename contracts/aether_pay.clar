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
(define-constant err-currency-inactive (err u112))
(define-constant err-invalid-decimal (err u113))

;; Configuration Constants
(define-constant MAX_PAYMENT_AMOUNT u1000000000000)
(define-constant PAYMENT_TIMEOUT_BLOCKS u144) ;; ~24 hours
(define-constant MAX_TIMEOUT_EXTENSION u72) ;; ~12 hours

;; Contract State
(define-data-var contract-paused bool false)

;; Enhanced Currency Configuration
(define-map CurrencyConfig
    { currency: (string-ascii 10) }
    {
        active: bool,
        decimals: uint,
        min-amount: uint,
        max-amount: uint
    }
)

;; Payment States
(define-constant STATE_PENDING u1)
(define-constant STATE_PROCESSING u2) 
(define-constant STATE_COMPLETED u3)
(define-constant STATE_DISPUTED u4)
(define-constant STATE_REFUNDED u5)
(define-constant STATE_TIMEOUT u6)

;; Enhanced Validation Functions
(define-private (validate-payment-amount (amount uint) (currency (string-ascii 10)))
    (match (map-get? CurrencyConfig { currency: currency })
        config (if (and 
                    (>= amount (get min-amount config))
                    (<= amount (get max-amount config)))
                (ok true)
                err-invalid-amount)
        err-invalid-currency))

(define-private (validate-recipient (recipient principal))
    (if (not (is-eq tx-sender recipient))
        (ok true)
        err-invalid-recipient))

(define-private (validate-currency (currency (string-ascii 10)))
    (match (map-get? CurrencyConfig { currency: currency })
        config (if (get active config)
                (ok true)
                err-currency-inactive)
        err-invalid-currency))

(define-private (validate-payment-timeout (timestamp uint))
    (if (< (- block-height timestamp) PAYMENT_TIMEOUT_BLOCKS)
        (ok true)
        err-payment-timeout))

;; Enhanced Admin Functions
(define-public (set-currency-config 
    (currency (string-ascii 10)) 
    (active bool)
    (decimals uint)
    (min-amount uint)
    (max-amount uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (<= decimals u18) err-invalid-decimal)
        (asserts! (<= max-amount MAX_PAYMENT_AMOUNT) err-invalid-amount)
        (ok (map-set CurrencyConfig
            { currency: currency }
            {
                active: active,
                decimals: decimals,
                min-amount: min-amount,
                max-amount: max-amount
            }))
    ))

;; [Rest of contract implementation remains unchanged]
