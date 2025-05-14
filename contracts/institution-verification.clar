;; Institution Verification Contract
;; Validates and stores information about financial entities

(define-map institutions
  {institution-id: uint}
  {name: (string-ascii 100),
   license-number: (string-ascii 50),
   jurisdiction: (string-ascii 50),
   verified: bool,
   verification-date: uint,
   verification-expiry: uint})

(define-data-var next-institution-id uint u1)

;; Register a new institution
(define-public (register-institution
                (name (string-ascii 100))
                (license-number (string-ascii 50))
                (jurisdiction (string-ascii 50)))
  (let ((institution-id (var-get next-institution-id)))
    (map-set institutions
             {institution-id: institution-id}
             {name: name,
              license-number: license-number,
              jurisdiction: jurisdiction,
              verified: false,
              verification-date: u0,
              verification-expiry: u0})
    (var-set next-institution-id (+ institution-id u1))
    (ok institution-id)))

;; Verify an institution (restricted to authorized verifiers)
(define-public (verify-institution
                (institution-id uint)
                (expiry-blocks uint))
  (let ((current-block-height block-height))
    (if (is-authorized-verifier tx-sender)
        (match (map-get? institutions {institution-id: institution-id})
          institution (begin
            (map-set institutions
                     {institution-id: institution-id}
                     (merge institution
                            {verified: true,
                             verification-date: current-block-height,
                             verification-expiry: (+ current-block-height expiry-blocks)}))
            (ok true))
          (err u1)) ;; Institution not found
        (err u2)))) ;; Not authorized

;; Check if an institution is verified
(define-read-only (is-institution-verified (institution-id uint))
  (match (map-get? institutions {institution-id: institution-id})
    institution (and (get verified institution)
                     (< block-height (get verification-expiry institution)))
    false))

;; Get institution details
(define-read-only (get-institution (institution-id uint))
  (map-get? institutions {institution-id: institution-id}))

;; Helper function to check if caller is authorized to verify institutions
;; In a real implementation, this would check against a list of authorized verifiers
(define-read-only (is-authorized-verifier (address principal))
  (is-eq address (contract-owner)))

;; Helper function to get contract owner
(define-read-only (contract-owner)
  (as-contract tx-sender))
