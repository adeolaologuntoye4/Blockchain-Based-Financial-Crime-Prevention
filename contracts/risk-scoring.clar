;; Risk Scoring Contract
;; Identifies suspicious activity based on risk factors

(define-map entity-risk-scores
  {entity-id: principal}
  {base-score: uint,
   transaction-factor: uint,
   geographic-factor: uint,
   behavioral-factor: uint,
   total-score: uint,
   last-updated: uint})

(define-map risk-thresholds
  {threshold-id: (string-ascii 20)}
  {value: uint})

;; Initialize default risk thresholds
(begin
  (map-set risk-thresholds {threshold-id: "low"} {value: u30})
  (map-set risk-thresholds {threshold-id: "medium"} {value: u60})
  (map-set risk-thresholds {threshold-id: "high"} {value: u90}))

;; Calculate and update risk score for an entity
(define-public (calculate-risk-score
                (entity-id principal)
                (base-score uint)
                (transaction-factor uint)
                (geographic-factor uint)
                (behavioral-factor uint))
  (let ((total-score (+ base-score transaction-factor geographic-factor behavioral-factor))
        (capped-score (if (> total-score u100) u100 total-score))
        (current-time block-height))
    (map-set entity-risk-scores
             {entity-id: entity-id}
             {base-score: base-score,
              transaction-factor: transaction-factor,
              geographic-factor: geographic-factor,
              behavioral-factor: behavioral-factor,
              total-score: capped-score,
              last-updated: current-time})
    (ok capped-score)))

;; Get risk score for an entity
(define-read-only (get-risk-score (entity-id principal))
  (match (map-get? entity-risk-scores {entity-id: entity-id})
    score (get total-score score)
    u0))

;; Determine risk level based on score
(define-read-only (get-risk-level (score uint))
  (let ((low-threshold (unwrap-panic (get value (map-get? risk-thresholds {threshold-id: "low"}))))
        (medium-threshold (unwrap-panic (get value (map-get? risk-thresholds {threshold-id: "medium"}))))
        (high-threshold (unwrap-panic (get value (map-get? risk-thresholds {threshold-id: "high"})))))
    (if (< score low-threshold)
        "minimal"
        (if (< score medium-threshold)
            "low"
            (if (< score high-threshold)
                "medium"
                "high")))))

;; Update risk thresholds
(define-public (update-risk-threshold
                (threshold-id (string-ascii 20))
                (new-value uint))
  (if (and (>= new-value u0) (<= new-value u100))
      (begin
        (map-set risk-thresholds
                 {threshold-id: threshold-id}
                 {value: new-value})
        (ok true))
      (err u1))) ;; Invalid threshold value

;; Check if entity is high risk
(define-read-only (is-high-risk (entity-id principal))
  (let ((score (get-risk-score entity-id))
        (high-threshold (unwrap-panic (get value (map-get? risk-thresholds {threshold-id: "high"})))))
    (>= score high-threshold)))
