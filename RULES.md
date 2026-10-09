# Blackjack — Rules

Authoritative rules for this game's implementation. If the code conflicts
with this document, the code is wrong — fix the code.

## 1. Objective
Beat the dealer. Get a hand value closer to 21 than the dealer's hand without
going over 21. Blackjack (an ace + a 10-value card on the first two cards)
beats every other 21.

## 2. Setup
- Each seat places a bet (minimum 10 virtual chips) from its bankroll.
- The engine builds a shoe: 1 deck (Friendly table), 4 decks (Classic), or
  6 decks (High Roller). The shoe reshuffles below ~25% penetration.
- Cards deal one at a time, visibly: each seat gets one card, the dealer
  gets one upcard, each seat gets a second card, the dealer gets a hole
  card (face down).

## 3. Turn order
1. Betting (all seats).
2. Animated deal.
3. Insurance / even-money decisions (only when the dealer shows an Ace on
   Classic/High Roller tables — Friendly offers no insurance).
4. Each seat plays in turn: Hit / Stand / Double / Surrender (Friendly only).
5. Dealer reveals the hole card and plays.
6. Settle bets, show results.

## 4. Legal moves
- **Hit**: take one more card. May hit any number of times.
- **Stand**: lock the total.
- **Double down**: on the first two cards only, and only if the bankroll
  covers the extra bet — double the bet, take exactly one more card, then
  stand automatically.
- **Surrender** (Friendly table only, first action only): forfeit the hand,
  get half the bet back.
- **Insurance** (Classic/High Roller, dealer shows Ace): side bet of half
  the main bet. Pays 2:1 if the dealer has Blackjack; lost otherwise.
- **Even money** (dealer shows Ace, seat holds Blackjack): take a guaranteed
  1:1 win immediately instead of risking a push.

## 5. Illegal moves
- Betting more than the bankroll, or below the 10-chip minimum.
- Hitting, doubling, or surrendering after standing, busting, doubling,
  surrendering, or receiving Blackjack.
- Doubling with only two cards dealt but insufficient bankroll.
- Any input while the dealer is dealing, playing, or settling
  (input is locked; the engine owns those phases).

## 6. Captures
N/A — no captures in Blackjack.

## 7. Special rules
- **Blackjack pays 3:2** (bet 100 → win 150, stake returned).
- **Dealer Blackjack**: if the dealer has Blackjack, all non-Blackjack
  hands lose immediately; player Blackjacks push; insurance pays 2:1.
- **Insurance skipped on Friendly**: no insurance is ever offered.
- **Aces** count as 11 or 1 (whichever avoids busting).
- Dealer never draws when every seat has already busted or surrendered.

## 8. Scoring
Hand value = sum of card values (J/Q/K = 10, Ace = 1 or 11). A "soft" hand
contains an ace counted as 11.

## 9. Winning conditions
- Player Blackjack vs no dealer Blackjack: win 3:2.
- Hand value over dealer's without busting: win 1:1.
- Dealer busts: all standing hands win 1:1.
- Insurance bet wins 2:1 when the dealer has Blackjack.
- Even money: guaranteed 1:1 on player Blackjack vs dealer Ace.

## 10. Draw conditions
Equal hand values (without Blackjack involved) = **push**: the bet is
returned. Player Blackjack vs dealer Blackjack = push. Insurance and even
money are never pushes.

## 11. AI strategy (dealer)
Dealer play is fully visible — the hole card flips, each hit is dealt with
narration, then the dealer stands:
- **Friendly Flo (easy)**: stands on ALL 17s (including soft 17).
- **Classic Vegas (medium)**: hits soft 17, stands on hard 17+.
- **High Roller (hard)**: hits soft 17, stands on hard 17+, deeper shoe.

## 12. Edge cases
- Three or more cards totaling 21 is NOT Blackjack (no 3:2 bonus).
- Doubling then busting loses the doubled bet.
- Surrender returns exactly half the bet (rounded down).
- A broke seat (bank < 10) is spotted 1000 chips by the house on the next
  hand — the game never dead-ends.
- Pausing freezes engine timers; the watchdog recovers any engine-driven
  phase found without a live timer (dealing, dealer play, settling).
  Human-gated phases (betting, insurance, player turn) are never touched.

## 13. Test cases
1. Hand [A, K] = 21, Blackjack; [A, 9, A] = 21 soft, not Blackjack.
2. [10, 6, 7] = 23 → bust.
3. Dealer on Friendly with [A, 6] stands; on Classic hits.
4. Insurance: dealer Ace + hole 10 → insurance pays 2:1, main bet lost.
5. Even money: player BJ vs dealer Ace, take → +1× bet immediately.
6. Push: player 18 vs dealer 18 → bet returned.
7. Surrender: bet 100 → 50 returned, hand over.
8. Broke seat (< 10 chips) starts the next hand at 1000.
