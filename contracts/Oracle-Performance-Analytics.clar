(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_NOT_FOUND (err u404))
(define-constant ERR_INVALID_ORACLE (err u400))

(define-map oracle-performance
  principal
  {
    total-verifications: uint,
    successful-verifications: uint,
    failed-verifications: uint,
    average-response-time: uint,
    last-performance-update: uint,
    accuracy-score: uint
  }
)

(define-map verification-logs
  { oracle: principal, timestamp: uint }
  {
    verification-result: bool,
    response-time-blocks: uint,
    user-feedback: (optional bool)
  }
)

(define-map oracle-analytics
  principal
  {
    weekly-accuracy: uint,
    monthly-accuracy: uint,
    performance-trend: int,
    reliability-rank: uint
  }
)

(define-data-var total-oracles uint u0)

(define-public (record-verification-performance (oracle principal) (success bool) (response-time uint))
  (let
    (
      (current-block stacks-block-height)
      (current-performance (default-to 
        { total-verifications: u0, successful-verifications: u0, failed-verifications: u0, 
          average-response-time: u0, last-performance-update: current-block, accuracy-score: u100 }
        (map-get? oracle-performance oracle)))
      (new-total (+ (get total-verifications current-performance) u1))
      (new-successful (if success (+ (get successful-verifications current-performance) u1) 
                               (get successful-verifications current-performance)))
      (new-failed (if success (get failed-verifications current-performance) 
                            (+ (get failed-verifications current-performance) u1)))
      (new-avg-time (/ (+ (* (get average-response-time current-performance) 
                            (get total-verifications current-performance)) response-time) new-total))
      (new-accuracy (if (> new-total u0) (/ (* new-successful u100) new-total) u100))
    )
    (map-set verification-logs
      { oracle: oracle, timestamp: current-block }
      { verification-result: success, response-time-blocks: response-time, user-feedback: none }
    )
    (map-set oracle-performance oracle {
      total-verifications: new-total,
      successful-verifications: new-successful,
      failed-verifications: new-failed,
      average-response-time: new-avg-time,
      last-performance-update: current-block,
      accuracy-score: new-accuracy
    })
    (try! (update-oracle-analytics oracle))
    (ok true)
  )
)

(define-public (submit-user-feedback (oracle principal) (timestamp uint) (feedback bool))
  (let
    (
      (log-entry (unwrap! (map-get? verification-logs { oracle: oracle, timestamp: timestamp }) ERR_NOT_FOUND))
    )
    (map-set verification-logs
      { oracle: oracle, timestamp: timestamp }
      (merge log-entry { user-feedback: (some feedback) })
    )
    (ok true)
  )
)

(define-private (update-oracle-analytics (oracle principal))
  (let
    (
      (current-block stacks-block-height)
      (week-blocks u1008)
      (month-blocks u4320)
      (week-start (- current-block week-blocks))
      (month-start (- current-block month-blocks))
      (performance (unwrap! (map-get? oracle-performance oracle) ERR_NOT_FOUND))
      (weekly-acc (calculate-period-accuracy oracle week-start current-block))
      (monthly-acc (calculate-period-accuracy oracle month-start current-block))
      (trend (calculate-performance-trend oracle))
    )
    (map-set oracle-analytics oracle {
      weekly-accuracy: weekly-acc,
      monthly-accuracy: monthly-acc,
      performance-trend: trend,
      reliability-rank: (calculate-reliability-rank oracle)
    })
    (ok true)
  )
)

(define-private (calculate-period-accuracy (oracle principal) (start-block uint) (end-block uint))
  (let
    (
      (performance (default-to 
        { total-verifications: u0, successful-verifications: u0, failed-verifications: u0, 
          average-response-time: u0, last-performance-update: u0, accuracy-score: u100 }
        (map-get? oracle-performance oracle)))
    )
    (get accuracy-score performance)
  )
)

(define-private (calculate-performance-trend (oracle principal))
  (let
    (
      (analytics (map-get? oracle-analytics oracle))
    )
    (match analytics
      some-analytics (- (to-int (get weekly-accuracy some-analytics)) (to-int (get monthly-accuracy some-analytics)))
      0
    )
  )
)

(define-private (calculate-reliability-rank (oracle principal))
  (let
    (
      (performance (default-to 
        { total-verifications: u0, successful-verifications: u0, failed-verifications: u0, 
          average-response-time: u0, last-performance-update: u0, accuracy-score: u100 }
        (map-get? oracle-performance oracle)))
      (accuracy (get accuracy-score performance))
      (total-verifs (get total-verifications performance))
    )
    (if (and (>= accuracy u95) (>= total-verifs u50)) u1
      (if (and (>= accuracy u90) (>= total-verifs u25)) u2
        (if (and (>= accuracy u80) (>= total-verifs u10)) u3
          (if (>= accuracy u70) u4 u5))))
  )
)

(define-read-only (get-oracle-performance (oracle principal))
  (map-get? oracle-performance oracle)
)

(define-read-only (get-oracle-analytics (oracle principal))
  (map-get? oracle-analytics oracle)
)

(define-read-only (get-verification-log (oracle principal) (timestamp uint))
  (map-get? verification-logs { oracle: oracle, timestamp: timestamp })
)

(define-read-only (get-top-performing-oracles)
  (ok "Query requires off-chain indexing for full implementation")
)
