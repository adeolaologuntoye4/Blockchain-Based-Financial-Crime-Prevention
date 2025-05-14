;; Alert Management Contract
;; Handles notification of potential issues

(define-map alerts
  {alert-id: uint}
  {entity-id: principal,
   alert-type: (string-ascii 50),
   risk-score: uint,
   description: (string-utf8 500),
   timestamp: uint,
   status: (string-ascii 20),
   assigned-to: (optional principal)})

;; Index to track alerts by entity
(define-map entity-alerts
  {entity-id: principal, alert-id: uint}
  {exists: bool})

;; Index to track open alerts
(define-map open-alerts
  {alert-id: uint}
  {exists: bool})

(define-data-var next-alert-id uint u1)
(define-data-var open-alert-count uint u0)

;; Create a new alert
(define-public (create-alert
                (entity-id principal)
                (alert-type (string-ascii 50))
                (risk-score uint)
                (description (string-utf8 500)))
  (let ((alert-id (var-get next-alert-id))
        (current-time block-height))
    (map-set alerts
             {alert-id: alert-id}
             {entity-id: entity-id,
              alert-type: alert-type,
              risk-score: risk-score,
              description: description,
              timestamp: current-time,
              status: "open",
              assigned-to: none})

    ;; Update indexes
    (map-set entity-alerts
             {entity-id: entity-id, alert-id: alert-id}
             {exists: true})

    (map-set open-alerts
             {alert-id: alert-id}
             {exists: true})

    (var-set next-alert-id (+ alert-id u1))
    (var-set open-alert-count (+ (var-get open-alert-count) u1))
    (ok alert-id)))

;; Update alert status
(define-public (update-alert-status
                (alert-id uint)
                (new-status (string-ascii 20)))
  (match (map-get? alerts {alert-id: alert-id})
    alert (begin
            (map-set alerts
                     {alert-id: alert-id}
                     (merge alert {status: new-status}))

            ;; Update open alerts count if closing an alert
            (if (and (is-eq (get status alert) "open")
                     (not (is-eq new-status "open")))
                (begin
                  (map-delete open-alerts {alert-id: alert-id})
                  (var-set open-alert-count (- (var-get open-alert-count) u1)))
                (if (and (not (is-eq (get status alert) "open"))
                         (is-eq new-status "open"))
                    (begin
                      (map-set open-alerts {alert-id: alert-id} {exists: true})
                      (var-set open-alert-count (+ (var-get open-alert-count) u1)))
                    true))

            (ok true))
    (err u1))) ;; Alert not found

;; Assign alert to investigator
(define-public (assign-alert
                (alert-id uint)
                (investigator principal))
  (match (map-get? alerts {alert-id: alert-id})
    alert (begin
            (map-set alerts
                     {alert-id: alert-id}
                     (merge alert {assigned-to: (some investigator),
                                   status: "assigned"}))

            ;; Update open alerts count
            (if (is-eq (get status alert) "open")
                (begin
                  (map-delete open-alerts {alert-id: alert-id})
                  (var-set open-alert-count (- (var-get open-alert-count) u1)))
                true)

            (ok true))
    (err u1))) ;; Alert not found

;; Get alert details
(define-read-only (get-alert (alert-id uint))
  (map-get? alerts {alert-id: alert-id}))

;; Check if an entity has an alert with given ID
(define-read-only (has-entity-alert (entity-id principal) (alert-id uint))
  (default-to false (get exists (map-get? entity-alerts {entity-id: entity-id, alert-id: alert-id}))))

;; Get count of open alerts
(define-read-only (get-open-alert-count)
  (var-get open-alert-count))

;; Get next alert ID (for iterating through alerts)
(define-read-only (get-next-alert-id)
  (var-get next-alert-id))
