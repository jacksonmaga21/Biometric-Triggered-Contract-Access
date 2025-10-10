(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_NOT_FOUND (err u404))
(define-constant ERR_INVALID_THRESHOLD (err u400))
(define-constant ERR_ALREADY_VOTED (err u409))
(define-constant ERR_VOTING_CLOSED (err u408))
(define-constant ERR_INSUFFICIENT_VOTES (err u402))

(define-data-var voting-window uint u72)
(define-data-var minimum-oracles uint u2)
(define-data-var consensus-threshold uint u67)

(define-map verification-requests
  { user: principal, request-id: uint }
  {
    requested-at: uint,
    expires-at: uint,
    total-weight: uint,
    approval-weight: uint,
    rejection-weight: uint,
    finalized: bool,
    result: (optional bool)
  }
)

(define-map oracle-votes
  { user: principal, request-id: uint, oracle: principal }
  {
    vote: bool,
    weight: uint,
    voted-at: uint
  }
)

(define-map user-request-count principal uint)

(define-public (initiate-consensus-verification (threshold-percentage uint))
  (let
    (
      (caller tx-sender)
      (current-block stacks-block-height)
      (request-id (default-to u0 (map-get? user-request-count caller)))
      (expires-at (+ current-block (var-get voting-window)))
    )
    (asserts! (and (>= threshold-percentage u50) (<= threshold-percentage u100)) ERR_INVALID_THRESHOLD)
    (map-set verification-requests
      { user: caller, request-id: request-id }
      {
        requested-at: current-block,
        expires-at: expires-at,
        total-weight: u0,
        approval-weight: u0,
        rejection-weight: u0,
        finalized: false,
        result: none
      }
    )
    (map-set user-request-count caller (+ request-id u1))
    (ok request-id)
  )
)

(define-public (submit-consensus-vote (user principal) (request-id uint) (vote bool) (oracle-weight uint))
  (let
    (
      (caller tx-sender)
      (current-block stacks-block-height)
      (request (unwrap! (map-get? verification-requests { user: user, request-id: request-id }) ERR_NOT_FOUND))
    )
    (asserts! (< current-block (get expires-at request)) ERR_VOTING_CLOSED)
    (asserts! (not (get finalized request)) ERR_VOTING_CLOSED)
    (asserts! (is-none (map-get? oracle-votes { user: user, request-id: request-id, oracle: caller })) ERR_ALREADY_VOTED)
    (map-set oracle-votes
      { user: user, request-id: request-id, oracle: caller }
      { vote: vote, weight: oracle-weight, voted-at: current-block }
    )
    (let
      (
        (new-total (+ (get total-weight request) oracle-weight))
        (new-approval (if vote (+ (get approval-weight request) oracle-weight) (get approval-weight request)))
        (new-rejection (if vote (get rejection-weight request) (+ (get rejection-weight request) oracle-weight)))
      )
      (map-set verification-requests
        { user: user, request-id: request-id }
        (merge request {
          total-weight: new-total,
          approval-weight: new-approval,
          rejection-weight: new-rejection
        })
      )
      (ok true)
    )
  )
)

(define-public (finalize-consensus (user principal) (request-id uint))
  (let
    (
      (current-block stacks-block-height)
      (request (unwrap! (map-get? verification-requests { user: user, request-id: request-id }) ERR_NOT_FOUND))
      (approval-percentage (if (> (get total-weight request) u0) 
        (/ (* (get approval-weight request) u100) (get total-weight request)) u0))
      (consensus-reached (>= approval-percentage (var-get consensus-threshold)))
    )
    (asserts! (not (get finalized request)) ERR_VOTING_CLOSED)
    (map-set verification-requests
      { user: user, request-id: request-id }
      (merge request { finalized: true, result: (some consensus-reached) })
    )
    (ok consensus-reached)
  )
)

(define-read-only (get-verification-request (user principal) (request-id uint))
  (map-get? verification-requests { user: user, request-id: request-id })
)

(define-read-only (get-oracle-vote (user principal) (request-id uint) (oracle principal))
  (map-get? oracle-votes { user: user, request-id: request-id, oracle: oracle })
)

(define-read-only (check-consensus-status (user principal) (request-id uint))
  (match (map-get? verification-requests { user: user, request-id: request-id })
    request (ok {
      finalized: (get finalized request),
      result: (get result request),
      approval-rate: (if (> (get total-weight request) u0)
        (/ (* (get approval-weight request) u100) (get total-weight request)) u0)
    })
    ERR_NOT_FOUND
  )
)

(define-read-only (get-consensus-config)
  {
    voting-window: (var-get voting-window),
    minimum-oracles: (var-get minimum-oracles),
    consensus-threshold: (var-get consensus-threshold)
  }
)
