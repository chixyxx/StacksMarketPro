;; ========================================
;; Basic NFT Marketplace Contract
;; Comprehensive marketplace functionality
;; ========================================

;; Define the NFT
(define-non-fungible-token marketplace-nft uint)

;; Data variables
(define-data-var last-token-id uint u0)
(define-data-var contract-owner principal tx-sender)
(define-data-var marketplace-fee uint u250) ;; 2.5% fee (250 basis points)
(define-data-var is-marketplace-active bool true)

;; Token metadata storage
(define-map token-metadata
  { token-id: uint }
  {
    name: (string-ascii 64),
    description: (string-ascii 256),
    image-url: (string-ascii 256),
    creator: principal,
    created-at: uint,
    category: (string-ascii 32)
  }
)

;; Marketplace listings
(define-map token-listings
  { token-id: uint }
  { 
    seller: principal,
    price: uint,
    active: bool,
    listed-at: uint,
    expires-at: (optional uint)
  }
)

;; Offer system
(define-map token-offers
  { token-id: uint, buyer: principal }
  {
    amount: uint,
    expires-at: uint,
    is-active: bool
  }
)

;; Sales history
(define-map sales-history
  { token-id: uint, sale-id: uint }
  {
    seller: principal,
    buyer: principal,
    price: uint,
    sold-at: uint
  }
)

(define-data-var sale-counter uint u0)

;; Creator royalties
(define-map creator-royalties
  { token-id: uint }
  { royalty-percent: uint } ;; Basis points (100 = 1%)
)

;; User statistics
(define-map user-stats
  { user: principal }
  {
    nfts-created: uint,
    nfts-sold: uint,
    nfts-bought: uint,
    total-volume-sold: uint,
    total-volume-bought: uint
  }
)

;; Constants
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-NOT-FOUND (err u404))
(define-constant ERR-ALREADY-EXISTS (err u409))
(define-constant ERR-INVALID-PRICE (err u400))
(define-constant ERR-MARKETPLACE-INACTIVE (err u403))
(define-constant ERR-LISTING-EXPIRED (err u410))
(define-constant ERR-INSUFFICIENT-FUNDS (err u402))

;; Administrative functions
(define-public (set-marketplace-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (asserts! (<= new-fee u1000) ERR-INVALID-PRICE) ;; Max 10% fee
    (var-set marketplace-fee new-fee)
    (ok true)
  )
)

(define-public (toggle-marketplace)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (var-set is-marketplace-active (not (var-get is-marketplace-active)))
    (ok (var-get is-marketplace-active))
  )
)

;; NFT minting with metadata
(define-public (mint-nft (recipient principal) (name (string-ascii 64)) (description (string-ascii 256)) (image-url (string-ascii 256)) (category (string-ascii 32)) (royalty-percent uint))
  (let ((token-id (+ (var-get last-token-id) u1)))
    (asserts! (var-get is-marketplace-active) ERR-MARKETPLACE-INACTIVE)
    (asserts! (<= royalty-percent u1000) ERR-INVALID-PRICE) ;; Max 10% royalty
    
    (try! (nft-mint? marketplace-nft token-id recipient))
    
    ;; Store metadata
    (map-set token-metadata
      { token-id: token-id }
      {
        name: name,
        description: description,
        image-url: image-url,
        creator: tx-sender,
        created-at: block-height,
        category: category
      }
    )
    
    ;; Set royalty
    (map-set creator-royalties
      { token-id: token-id }
      { royalty-percent: royalty-percent }
    )
    
    ;; Update user stats
    (update-user-stats tx-sender u1 u0 u0 u0 u0)
    
    (var-set last-token-id token-id)
    (ok token-id)
  )
)

;; List NFT for sale
(define-public (list-for-sale (token-id uint) (price uint) (duration-blocks (optional uint)))
  (let ((owner (unwrap! (nft-get-owner? marketplace-nft token-id) ERR-NOT-FOUND)))
    (asserts! (is-eq tx-sender owner) ERR-NOT-AUTHORIZED)
    (asserts! (> price u0) ERR-INVALID-PRICE)
    (asserts! (var-get is-marketplace-active) ERR-MARKETPLACE-INACTIVE)
    
    (map-set token-listings 
      { token-id: token-id }
      { 
        seller: tx-sender, 
        price: price, 
        active: true,
        listed-at: block-height,
        expires-at: (match duration-blocks
          blocks (some (+ block-height blocks))
          none
        )
      }
    )
    (ok true)
  )
)

;; Remove listing
(define-public (delist-nft (token-id uint))
  (let (
    (listing (unwrap! (map-get? token-listings { token-id: token-id }) ERR-NOT-FOUND))
    (owner (unwrap! (nft-get-owner? marketplace-nft token-id) ERR-NOT-FOUND))
  )
    (asserts! (is-eq tx-sender owner) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq tx-sender (get seller listing)) ERR-NOT-AUTHORIZED)
    
    (map-set token-listings 
      { token-id: token-id }
      { 
        seller: (get seller listing),
        price: (get price listing),
        active: false,
        listed-at: (get listed-at listing),
        expires-at: (get expires-at listing)
      }
    )
    (ok true)
  )
)

;; Buy NFT
(define-public (buy-nft (token-id uint))
  (let (
    (listing (unwrap! (map-get? token-listings { token-id: token-id }) ERR-NOT-FOUND))
    (seller (get seller listing))
    (price (get price listing))
    (metadata (unwrap! (map-get? token-metadata { token-id: token-id }) ERR-NOT-FOUND))
    (creator (get creator metadata))
    (royalty-info (map-get? creator-royalties { token-id: token-id }))
    (marketplace-fee-amount (/ (* price (var-get marketplace-fee)) u10000))
    (sale-id (+ (var-get sale-counter) u1))
  )
    (asserts! (get active listing) ERR-NOT-FOUND)
    (asserts! (var-get is-marketplace-active) ERR-MARKETPLACE-INACTIVE)
    
    ;; Check if listing has expired
    (match (get expires-at listing)
      expiry (asserts! (<= block-height expiry) ERR-LISTING-EXPIRED)
      true
    )
    
    ;; Calculate royalty payment
    (let (
      (royalty-amount (match royalty-info
        royalty (/ (* price (get royalty-percent royalty)) u10000)
        u0
      ))
      (seller-amount (- (- price marketplace-fee-amount) royalty-amount))
    )
      ;; Transfer payments
      (try! (stx-transfer? marketplace-fee-amount tx-sender (var-get contract-owner)))
      (if (> royalty-amount u0)
        (try! (stx-transfer? royalty-amount tx-sender creator))
        true
      )
      (try! (stx-transfer? seller-amount tx-sender seller))
      
      ;; Transfer NFT
      (try! (nft-transfer? marketplace-nft token-id seller tx-sender))
      
      ;; Record sale
      (map-set sales-history
        { token-id: token-id, sale-id: sale-id }
        {
          seller: seller,
          buyer: tx-sender,
          price: price,
          sold-at: block-height
        }
      )
      
      ;; Update listing status
      (map-set token-listings 
        { token-id: token-id }
        { 
          seller: seller,
          price: price,
          active: false,
          listed-at: (get listed-at listing),
          expires-at: (get expires-at listing)
        }
      )
      
      ;; Update user statistics
      (update-user-stats seller u0 u1 u0 price u0)
      (update-user-stats tx-sender u0 u0 u1 u0 price)
      
      (var-set sale-counter sale-id)
      (ok true)
    )
  )
)

;; Make offer on NFT
(define-public (make-offer (token-id uint) (amount uint) (duration-blocks uint))
  (begin
    (asserts! (is-some (nft-get-owner? marketplace-nft token-id)) ERR-NOT-FOUND)
    (asserts! (> amount u0) ERR-INVALID-PRICE)
    (asserts! (> duration-blocks u0) ERR-INVALID-PRICE)
    
    (map-set token-offers
      { token-id: token-id, buyer: tx-sender }
      {
        amount: amount,
        expires-at: (+ block-height duration-blocks),
        is-active: true
      }
    )
    (ok true)
  )
)

;; Accept offer
(define-public (accept-offer (token-id uint) (buyer principal))
  (let (
    (owner (unwrap! (nft-get-owner? marketplace-nft token-id) ERR-NOT-FOUND))
    (offer (unwrap! (map-get? token-offers { token-id: token-id, buyer: buyer }) ERR-NOT-FOUND))
    (amount (get amount offer))
    (metadata (unwrap! (map-get? token-metadata { token-id: token-id }) ERR-NOT-FOUND))
    (creator (get creator metadata))
    (royalty-info (map-get? creator-royalties { token-id: token-id }))
    (marketplace-fee-amount (/ (* amount (var-get marketplace-fee)) u10000))
  )
    (asserts! (is-eq tx-sender owner) ERR-NOT-AUTHORIZED)
    (asserts! (get is-active offer) ERR-NOT-FOUND)
    (asserts! (<= block-height (get expires-at offer)) ERR-LISTING-EXPIRED)
    
    ;; Calculate payments
    (let (
      (royalty-amount (match royalty-info
        royalty (/ (* amount (get royalty-percent royalty)) u10000)
        u0
      ))
      (seller-amount (- (- amount marketplace-fee-amount) royalty-amount))
    )
      ;; Transfer payments
      (try! (stx-transfer? marketplace-fee-amount buyer (var-get contract-owner)))
      (if (> royalty-amount u0)
        (try! (stx-transfer? royalty-amount buyer creator))
        true
      )
      (try! (stx-transfer? seller-amount buyer tx-sender))
      
      ;; Transfer NFT
      (try! (nft-transfer? marketplace-nft token-id tx-sender buyer))
      
      ;; Deactivate offer
      (map-set token-offers
        { token-id: token-id, buyer: buyer }
        {
          amount: amount,
          expires-at: (get expires-at offer),
          is-active: false
        }
      )
      
      (ok true)
    )
  )
)

;; Helper function to update user statistics
(define-private (update-user-stats (user principal) (created uint) (sold uint) (bought uint) (volume-sold uint) (volume-bought uint))
  (let (
    (current-stats (default-to 
      { nfts-created: u0, nfts-sold: u0, nfts-bought: u0, total-volume-sold: u0, total-volume-bought: u0 }
      (map-get? user-stats { user: user })
    ))
  )
    (map-set user-stats
      { user: user }
      {
        nfts-created: (+ (get nfts-created current-stats) created),
        nfts-sold: (+ (get nfts-sold current-stats) sold),
        nfts-bought: (+ (get nfts-bought current-stats) bought),
        total-volume-sold: (+ (get total-volume-sold current-stats) volume-sold),
        total-volume-bought: (+ (get total-volume-bought current-stats) volume-bought)
      }
    )
  )
)

;; Read-only functions
(define-read-only (get-token-metadata (token-id uint))
  (map-get? token-metadata { token-id: token-id })
)

(define-read-only (get-listing (token-id uint))
  (map-get? token-listings { token-id: token-id })
)

(define-read-only (get-offer (token-id uint) (buyer principal))
  (map-get? token-offers { token-id: token-id, buyer: buyer })
)

(define-read-only (get-user-stats (user principal))
  (map-get? user-stats { user: user })
)

(define-read-only (get-marketplace-info)
  {
    fee: (var-get marketplace-fee),
    active: (var-get is-marketplace-active),
    total-tokens: (var-get last-token-id),
    owner: (var-get contract-owner)
  }
)