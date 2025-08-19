# 🖼️ NFT Marketplace Smart Contract

A fully on-chain **ERC-721-style NFT Marketplace** built in **Clarity** for the Stacks blockchain.
This contract allows users to mint NFTs, list them for sale, make and accept offers, track royalties, and monitor user statistics.

---

## 🚀 Features

* **NFT Minting**

  * Mint NFTs with metadata: `name`, `description`, `image-url`, `category`
  * Creator royalties (up to 10%)

* **Marketplace Functionality**

  * List NFTs for sale with optional expiration
  * Buy NFTs securely with automatic fee & royalty handling
  * Make and accept offers on NFTs
  * Marketplace toggle and configurable fee (max 10%)

* **Payments & Fees**

  * Marketplace fee: default 2.5% (250 basis points)
  * Creator royalties on each secondary sale
  * Secure STX transfers with Clarity's `stx-transfer?`

* **User & Token Tracking**

  * Per-token metadata & history
  * Sales history for each token
  * Per-user statistics: NFTs created, bought, sold, and trading volumes

---

## 📂 Contract Structure

### Data Storage

* **`marketplace-nft`** → Non-fungible token
* **`token-metadata`** → Stores NFT metadata
* **`token-listings`** → Active marketplace listings
* **`token-offers`** → Buyer offers on NFTs
* **`sales-history`** → Past sales per token
* **`creator-royalties`** → Royalty info for creators
* **`user-stats`** → Statistics per user

### Key Variables

* `last-token-id` → Tracks latest minted token
* `contract-owner` → Marketplace admin
* `marketplace-fee` → Fee in basis points (default 250 = 2.5%)
* `is-marketplace-active` → Toggle marketplace activity

---

## ⚙️ Functions

### 🔑 Administrative

* `set-marketplace-fee (uint)` → Update fee (max 10%)
* `toggle-marketplace` → Enable/disable marketplace

### 🎨 NFT Management

* `mint-nft (recipient principal name description image-url category royalty-percent)`
  → Mint new NFT with metadata and royalty

### 🛒 Marketplace

* `list-for-sale (token-id price duration-blocks?)` → List NFT for sale
* `delist-nft (token-id)` → Remove listing
* `buy-nft (token-id)` → Purchase a listed NFT

### 💰 Offers

* `make-offer (token-id amount duration-blocks)` → Submit purchase offer
* `accept-offer (token-id buyer)` → Seller accepts buyer’s offer

### 📊 Read-only Queries

* `get-token-metadata (token-id)` → View NFT metadata
* `get-listing (token-id)` → View active listing
* `get-offer (token-id buyer)` → View a buyer’s offer
* `get-user-stats (user)` → View user stats
* `get-marketplace-info` → Marketplace status & config

---

## 🔒 Error Codes

| Code   | Meaning                 |
| ------ | ----------------------- |
| `u401` | Not authorized          |
| `u402` | Insufficient funds      |
| `u403` | Marketplace inactive    |
| `u404` | Not found               |
| `u409` | Already exists          |
| `u400` | Invalid price/parameter |
| `u410` | Listing expired         |

---

## 📜 Example Workflow

1. **Mint NFT**

   ```clarity
   (contract-call? .nft-marketplace mint-nft tx-sender "My NFT" "Unique digital art" "https://example.com/art.png" "art" u500)
   ```

   → Creates a new NFT with 5% royalty

2. **List NFT for Sale**

   ```clarity
   (contract-call? .nft-marketplace list-for-sale u1 u100000000 (some u144)) ;; 100 STX for ~1 day
   ```

3. **Buy NFT**

   ```clarity
   (contract-call? .nft-marketplace buy-nft u1)
   ```

4. **Make an Offer**

   ```clarity
   (contract-call? .nft-marketplace make-offer u1 u80000000 u100) ;; Offer 80 STX, valid 100 blocks
   ```

5. **Accept Offer**

   ```clarity
   (contract-call? .nft-marketplace accept-offer u1 'SP123...456)
   ```

---

## 🏗️ Deployment

1. Copy contract into `contracts/marketplace.clar`
2. Deploy using [Clarinet](https://github.com/hirosystems/clarinet):

   ```bash
   clarinet contract deploy marketplace
   ```
3. Interact via Clarinet console or frontend integration

---

## 📈 Future Improvements

* Auction support (timed bidding)
* Multi-token batch listings
* Enhanced royalty distribution (multi-creators)
* Metadata pinning with IPFS/Arweave
