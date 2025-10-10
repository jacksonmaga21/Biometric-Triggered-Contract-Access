(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_NOT_FOUND (err u404))
(define-constant ERR_INSUFFICIENT_STAKE (err u402))
(define-constant ERR_ALREADY_STAKED (err u409))
(define-constant ERR_COOLDOWN_ACTIVE (err u408))

(define-data-var minimum-stake uint u5000000)
(define-data-var slash-threshold uint u3)
(define-data-var unstake-cooldown uint u2016)
(define-data-var slash-pool uint u0)

(define-map oracle-stakes
  principal
  {
    staked-amount: uint,
    stake-block: uint,
    slash-count: uint,
    unstake-requested: (optional uint),
    rewards-earned: uint
  }
)

(define-map pending-slashes
  { oracle: principal, violation: uint }
  {
    amount: uint,
    reporter: principal,
    block-height: uint,
    executed: bool
  }
)

(define-public (stake-oracle (amount uint))
  (let
    (
      (caller tx-sender)
      (current-block stacks-block-height)
    )
    (asserts! (>= amount (var-get minimum-stake)) ERR_INSUFFICIENT_STAKE)
    (asserts! (is-none (map-get? oracle-stakes caller)) ERR_ALREADY_STAKED)
    (try! (stx-transfer? amount caller (as-contract tx-sender)))
    (map-set oracle-stakes caller {
      staked-amount: amount,
      stake-block: current-block,
      slash-count: u0,
      unstake-requested: none,
      rewards-earned: u0
    })
    (ok amount)
  )
)

(define-public (request-unstake)
  (let
    (
      (caller tx-sender)
      (stake-data (unwrap! (map-get? oracle-stakes caller) ERR_NOT_FOUND))
      (current-block stacks-block-height)
    )
    (asserts! (is-none (get unstake-requested stake-data)) ERR_ALREADY_STAKED)
    (map-set oracle-stakes caller 
      (merge stake-data { unstake-requested: (some current-block) }))
    (ok current-block)
  )
)

(define-public (execute-unstake)
  (let
    (
      (caller tx-sender)
      (stake-data (unwrap! (map-get? oracle-stakes caller) ERR_NOT_FOUND))
      (unstake-block (unwrap! (get unstake-requested stake-data) ERR_NOT_FOUND))
      (current-block stacks-block-height)
      (cooldown-end (+ unstake-block (var-get unstake-cooldown)))
    )
    (asserts! (>= current-block cooldown-end) ERR_COOLDOWN_ACTIVE)
    (try! (as-contract (stx-transfer? (get staked-amount stake-data) tx-sender caller)))
    (map-delete oracle-stakes caller)
    (ok (get staked-amount stake-data))
  )
)

(define-public (propose-slash (oracle principal) (violation-type uint) (slash-amount uint))
  (let
    (
      (caller tx-sender)
      (current-block stacks-block-height)
      (stake-data (unwrap! (map-get? oracle-stakes oracle) ERR_NOT_FOUND))
    )
    (asserts! (is-some (map-get? oracle-stakes caller)) ERR_UNAUTHORIZED)
    (asserts! (<= slash-amount (get staked-amount stake-data)) ERR_INSUFFICIENT_STAKE)
    (map-set pending-slashes
      { oracle: oracle, violation: violation-type }
      {
        amount: slash-amount,
        reporter: caller,
        block-height: current-block,
        executed: false
      }
    )
    (ok true)
  )
)

(define-public (execute-slash (oracle principal) (violation-type uint))
  (let
    (
      (slash-data (unwrap! (map-get? pending-slashes { oracle: oracle, violation: violation-type }) ERR_NOT_FOUND))
      (stake-data (unwrap! (map-get? oracle-stakes oracle) ERR_NOT_FOUND))
      (slash-amount (get amount slash-data))
      (new-stake (- (get staked-amount stake-data) slash-amount))
      (new-slash-count (+ (get slash-count stake-data) u1))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (not (get executed slash-data)) ERR_ALREADY_STAKED)
    (var-set slash-pool (+ (var-get slash-pool) slash-amount))
    (map-set oracle-stakes oracle
      (merge stake-data { 
        staked-amount: new-stake, 
        slash-count: new-slash-count 
      }))
    (map-set pending-slashes 
      { oracle: oracle, violation: violation-type }
      (merge slash-data { executed: true }))
    (ok slash-amount)
  )
)

(define-public (distribute-rewards)
  (let
    (
      (caller tx-sender)
      (stake-data (unwrap! (map-get? oracle-stakes caller) ERR_NOT_FOUND))
      (total-pool (var-get slash-pool))
      (reward-share (/ total-pool u10))
    )
    (asserts! (> total-pool u0) ERR_NOT_FOUND)
    (asserts! (< (get slash-count stake-data) (var-get slash-threshold)) ERR_UNAUTHORIZED)
    (var-set slash-pool (- total-pool reward-share))
    (map-set oracle-stakes caller
      (merge stake-data { 
        rewards-earned: (+ (get rewards-earned stake-data) reward-share)
      }))
    (try! (as-contract (stx-transfer? reward-share tx-sender caller)))
    (ok reward-share)
  )
)

(define-public (update-minimum-stake (new-amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set minimum-stake new-amount)
    (ok new-amount)
  )
)

(define-read-only (get-oracle-stake (oracle principal))
  (map-get? oracle-stakes oracle)
)

(define-read-only (is-oracle-staked (oracle principal))
  (is-some (map-get? oracle-stakes oracle))
)

(define-read-only (get-slash-proposal (oracle principal) (violation uint))
  (map-get? pending-slashes { oracle: oracle, violation: violation })
)

(define-read-only (get-staking-config)
  {
    minimum-stake: (var-get minimum-stake),
    slash-threshold: (var-get slash-threshold),
    unstake-cooldown: (var-get unstake-cooldown),
    slash-pool: (var-get slash-pool)
  }
)
