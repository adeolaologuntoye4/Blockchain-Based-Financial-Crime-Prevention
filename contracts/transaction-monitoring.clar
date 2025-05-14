;; Transaction Monitoring Contract
;; Analyzes payment patterns and transaction flows

(define-map transactions
  {tx-id: uint}
  {sender: principal,
   recipient: principal,
   amount: uint,
   timestamp: uint,
   tx-type: (string-ascii 20),
   metadata: (string-utf8 500)})

(define-map transaction-patterns
  {institution-id: uint}
  {daily-volume: uint,
   weekly-volume: uint,
   monthly-volume: uint,
   avg-transaction-size: uint,
   last-updated: uint})

;; Index to track transactions by sender
(define-map sender-transactions
  {sender: principal, tx-id: uint}
  {exists: bool})

;; Index to track transactions by recipient
(define-map recipient-transactions
  {recipient: principal, tx-id: uint}
  {exists: bool})

(define-data-var next-tx-id uint u1)

;; Record a new transaction
(define-public (record-transaction
                (sender principal)
                (recipient principal)
                (amount uint)
                (tx-type (string-ascii 20))
                (metadata (string-utf8 500)))
  (let ((tx-id (var-get next-tx-id))
        (current-time block-height))
    (map-set transactions
             {tx-id: tx-id}
             {sender: sender,
              recipient: recipient,
              amount: amount,
              timestamp: current-time,
              tx-type: tx-type,
              metadata: metadata})

    ;; Update indexes
    (map-set sender-transactions
             {sender: sender, tx-id: tx-id}
             {exists: true})

    (map-set recipient-transactions
             {recipient: recipient, tx-id: tx-id}
             {exists: true})

    (var-set next-tx-id (+ tx-id u1))
    (ok tx-id)))

;; Update transaction patterns for an institution
(define-public (update-transaction-patterns
                (institution-id uint)
                (daily-volume uint)
                (weekly-volume uint)
                (monthly-volume uint)
                (avg-transaction-size uint))
  (let ((current-time block-height))
    (map-set transaction-patterns
             {institution-id: institution-id}
             {daily-volume: daily-volume,
              weekly-volume: weekly-volume,
              monthly-volume: monthly-volume,
              avg-transaction-size: avg-transaction-size,
              last-updated: current-time})
    (ok true)))

;; Get transaction details
(define-read-only (get-transaction (tx-id uint))
  (map-get? transactions {tx-id: tx-id}))

;; Get transaction patterns for an institution
(define-read-only (get-transaction-patterns (institution-id uint))
  (map-get? transaction-patterns {institution-id: institution-id}))

;; Check for unusual transaction volume
(define-read-only (is-unusual-volume
                   (institution-id uint)
                   (current-volume uint)
                   (threshold-percentage uint))
  (match (map-get? transaction-patterns {institution-id: institution-id})
    pattern (let ((normal-volume (get daily-volume pattern))
                  (threshold (* normal-volume (/ threshold-percentage u100))))
              (> current-volume (+ normal-volume threshold)))
    false))

;; Check for unusual transaction size
(define-read-only (is-unusual-transaction-size
                   (institution-id uint)
                   (tx-size uint)
                   (threshold-percentage uint))
  (match (map-get? transaction-patterns {institution-id: institution-id})
    pattern (let ((avg-size (get avg-transaction-size pattern))
                  (threshold (* avg-size (/ threshold-percentage u100))))
              (> tx-size (+ avg-size threshold)))
    false))
