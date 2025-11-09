(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_NOT_FOUND (err u404))
(define-constant ERR_CIRCUIT_ACTIVE (err u503))
(define-constant ERR_COOLDOWN_ACTIVE (err u429))

(define-data-var circuit-breaker-active bool false)
(define-data-var global-threat-level uint u0)
(define-data-var auto-trigger-threshold uint u75)
(define-data-var circuit-cooldown-blocks uint u144)
(define-data-var last-reset-block uint u0)

(define-map threat-indicators
  principal
  {
    failed-attempts: uint,
    suspicious-patterns: uint,
    last-violation: uint,
    threat-score: uint,
    quarantined: bool
  }
)

(define-map circuit-events
  uint
  {
    triggered-at: uint,
    triggered-by: principal,
    reason: (string-ascii 100),
    threat-level: uint,
    auto-triggered: bool,
    resolved-at: (optional uint)
  }
)

(define-data-var event-counter uint u0)

(define-public (report-suspicious-activity (target principal) (violation-type uint))
  (let
    (
      (current-block stacks-block-height)
      (current-data (default-to 
        { failed-attempts: u0, suspicious-patterns: u0, last-violation: u0, threat-score: u0, quarantined: false }
        (map-get? threat-indicators target)))
      (new-failures (+ (get failed-attempts current-data) u1))
      (new-patterns (if (is-eq violation-type u1) (+ (get suspicious-patterns current-data) u1)
                       (get suspicious-patterns current-data)))
      (new-score (+ (get threat-score current-data) (* violation-type u10)))
    )
    (map-set threat-indicators target {
      failed-attempts: new-failures,
      suspicious-patterns: new-patterns,
      last-violation: current-block,
      threat-score: new-score,
      quarantined: (>= new-score u50)
    })
    (var-set global-threat-level (+ (var-get global-threat-level) u5))
    (if (>= (var-get global-threat-level) (var-get auto-trigger-threshold))
      (begin
        (try! (trigger-circuit-breaker "Automatic threat threshold exceeded" true))
        (ok true))
      (ok true))
  )
)

(define-public (trigger-circuit-breaker (reason (string-ascii 100)) (auto bool))
  (let
    (
      (current-block stacks-block-height)
      (caller tx-sender)
      (event-id (var-get event-counter))
    )
    (asserts! (or auto (is-eq caller CONTRACT_OWNER)) ERR_UNAUTHORIZED)
    (var-set circuit-breaker-active true)
    (var-set last-reset-block current-block)
    (map-set circuit-events event-id {
      triggered-at: current-block,
      triggered-by: caller,
      reason: reason,
      threat-level: (var-get global-threat-level),
      auto-triggered: auto,
      resolved-at: none
    })
    (var-set event-counter (+ event-id u1))
    (ok event-id)
  )
)

(define-public (reset-circuit-breaker)
  (let
    (
      (current-block stacks-block-height)
      (cooldown-end (+ (var-get last-reset-block) (var-get circuit-cooldown-blocks)))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (>= current-block cooldown-end) ERR_COOLDOWN_ACTIVE)
    (var-set circuit-breaker-active false)
    (var-set global-threat-level u0)
    (ok true)
  )
)

(define-public (quarantine-principal (target principal))
  (let
    (
      (current-data (default-to 
        { failed-attempts: u0, suspicious-patterns: u0, last-violation: u0, threat-score: u100, quarantined: false }
        (map-get? threat-indicators target)))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set threat-indicators target (merge current-data { quarantined: true }))
    (ok true)
  )
)

(define-read-only (is-circuit-active)
  (var-get circuit-breaker-active)
)

(define-read-only (get-threat-status (principal-id principal))
  (map-get? threat-indicators principal-id)
)

(define-read-only (get-circuit-event (event-id uint))
  (map-get? circuit-events event-id)
)

(define-read-only (get-system-status)
  {
    circuit-active: (var-get circuit-breaker-active),
    global-threat-level: (var-get global-threat-level),
    auto-trigger-threshold: (var-get auto-trigger-threshold),
    total-events: (var-get event-counter)
  }
)
