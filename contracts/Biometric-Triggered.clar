(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_NOT_FOUND (err u404))
(define-constant ERR_INVALID_ORACLE (err u400))
(define-constant ERR_VERIFICATION_FAILED (err u403))
(define-constant ERR_ORACLE_EXISTS (err u409))
(define-constant ERR_INSUFFICIENT_FUNDS (err u402))

(define-data-var contract-enabled bool true)
(define-data-var oracle-count uint u0)
(define-data-var verification-timeout uint u144)

(define-map oracles 
  principal
  {
    active: bool,
    reputation: uint,
    verifications: uint,
    registered-at: uint
  }
)

(define-map biometric-verifications
  { user: principal, nonce: uint }
  {
    oracle: principal,
    verified: bool,
    timestamp: uint,
    expires-at: uint
  }
)

(define-map user-nonces principal uint)

(define-map protected-functions
  uint
  {
    name: (string-ascii 50),
    required-reputation: uint,
    fee: uint,
    enabled: bool
  }
)

(define-map user-balances principal uint)

(define-public (register-oracle)
  (let
    (
      (caller tx-sender)
      (current-block stacks-block-height)
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-none (map-get? oracles caller)) ERR_ORACLE_EXISTS)
    (map-set oracles caller {
      active: true,
      reputation: u100,
      verifications: u0,
      registered-at: current-block
    })
    (var-set oracle-count (+ (var-get oracle-count) u1))
    (ok true)
  )
)

(define-public (submit-verification (user principal) (verified bool) (nonce uint))
  (let
    (
      (caller tx-sender)
      (oracle-data (unwrap! (map-get? oracles caller) ERR_INVALID_ORACLE))
      (current-block stacks-block-height)
      (expires-at (+ current-block (var-get verification-timeout)))
    )
    (asserts! (get active oracle-data) ERR_UNAUTHORIZED)
    (asserts! (> (get reputation oracle-data) u50) ERR_UNAUTHORIZED)
    (map-set biometric-verifications
      { user: user, nonce: nonce }
      {
        oracle: caller,
        verified: verified,
        timestamp: current-block,
        expires-at: expires-at
      }
    )
    (map-set oracles caller
      (merge oracle-data { verifications: (+ (get verifications oracle-data) u1) })
    )
    (ok true)
  )
)

(define-public (verify-and-execute (function-id uint))
  (let
    (
      (caller tx-sender)
      (current-nonce (default-to u0 (map-get? user-nonces caller)))
      (verification (map-get? biometric-verifications { user: caller, nonce: current-nonce }))
      (function-data (unwrap! (map-get? protected-functions function-id) ERR_NOT_FOUND))
      (current-block stacks-block-height)
    )
    (asserts! (var-get contract-enabled) ERR_UNAUTHORIZED)
    (asserts! (get enabled function-data) ERR_UNAUTHORIZED)
    (match verification
      some-verification
        (begin
          (asserts! (get verified some-verification) ERR_VERIFICATION_FAILED)
          (asserts! (< current-block (get expires-at some-verification)) ERR_VERIFICATION_FAILED)
          (let
            (
              (oracle (get oracle some-verification))
              (oracle-data (unwrap! (map-get? oracles oracle) ERR_INVALID_ORACLE))
              (required-rep (get required-reputation function-data))
              (fee (get fee function-data))
              (user-balance (default-to u0 (map-get? user-balances caller)))
            )
            (asserts! (>= (get reputation oracle-data) required-rep) ERR_UNAUTHORIZED)
            (asserts! (>= user-balance fee) ERR_INSUFFICIENT_FUNDS)
            (map-set user-balances caller (- user-balance fee))
            (map-set user-nonces caller (+ current-nonce u1))
            (ok function-id)
          )
        )
      ERR_VERIFICATION_FAILED
    )
  )
)

(define-public (deposit-funds (amount uint))
  (let
    (
      (caller tx-sender)
      (current-balance (default-to u0 (map-get? user-balances caller)))
    )
    (try! (stx-transfer? amount caller (as-contract tx-sender)))
    (map-set user-balances caller (+ current-balance amount))
    (ok amount)
  )
)

(define-public (withdraw-funds (amount uint))
  (let
    (
      (caller tx-sender)
      (current-balance (default-to u0 (map-get? user-balances caller)))
    )
    (asserts! (>= current-balance amount) ERR_INSUFFICIENT_FUNDS)
    (map-set user-balances caller (- current-balance amount))
    (try! (as-contract (stx-transfer? amount tx-sender caller)))
    (ok amount)
  )
)

(define-public (add-protected-function (id uint) (name (string-ascii 50)) (reputation uint) (fee uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set protected-functions id {
      name: name,
      required-reputation: reputation,
      fee: fee,
      enabled: true
    })
    (ok true)
  )
)

(define-public (update-oracle-reputation (oracle principal) (new-reputation uint))
  (let
    (
      (oracle-data (unwrap! (map-get? oracles oracle) ERR_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set oracles oracle (merge oracle-data { reputation: new-reputation }))
    (ok true)
  )
)

(define-public (toggle-contract (enabled bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set contract-enabled enabled)
    (ok enabled)
  )
)

(define-public (set-verification-timeout (blocks uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set verification-timeout blocks)
    (ok blocks)
  )
)

(define-read-only (get-oracle-info (oracle principal))
  (map-get? oracles oracle)
)

(define-read-only (get-verification (user principal) (nonce uint))
  (map-get? biometric-verifications { user: user, nonce: nonce })
)

(define-read-only (get-user-balance (user principal))
  (default-to u0 (map-get? user-balances user))
)

(define-read-only (get-user-nonce (user principal))
  (default-to u0 (map-get? user-nonces user))
)

(define-read-only (get-function-info (id uint))
  (map-get? protected-functions id)
)

(define-read-only (get-contract-stats)
  {
    enabled: (var-get contract-enabled),
    oracle-count: (var-get oracle-count),
    verification-timeout: (var-get verification-timeout)
  }
)
