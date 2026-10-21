import BsvChain.Wire.Relay

/-!
# The relay machine's laws (#78), 2026-10-15 [D]

Views of the relay layer, never rules of validity. The three theorems the
issue names, each in the form that holds at the pin:

* announcement: a transaction the node accepts is queued by the next
  propagator's pass for every peer that relays transactions, passes its fee
  filter and loaded filter, and is not known to have it, through each of the
  three acceptances the machine has: a peer's `tx` (`accepted_queued_for_unseen`,
  every peer but the sender), the RPC's (`rpcAccepted_queued_for_unseen`) and
  an orphan's on retry (`retryOrphan_accepted_queued_for_unseen`); a queued id
  is in the `inv` of one of that peer's flushes, the flushes following one
  another (`pending_announced_within`: index `i` in the `(i / broadcastMax + 1)`-th),
  so under any load it is announced (`accepted_announced_within`,
  `rpcAccepted_announced_within`, `retryOrphan_announced_within`); on an idle
  node the next flush is exactly one `inv` naming it
  (`accepted_announced_when_idle`); it is never announced back to a peer known
  to have it (`known_never_queued`), the sender included. The qualifiers are
  the pin's (src/net/net.cpp:852-876), and "unseen" is the machine's `known`,
  the ideal set the rolling filter approximates;
* the ban (`ban_sound_run`): a ban for misbehavior is reached only through
  recorded increments, every such entry naming a peer whose recorded
  increments sum to the threshold or more. The sentence as the issue words it,
  "a ban is reached only through recorded misbehavior increments", is false
  of the ban list at the pin: a bad message start, an oversized or malformed
  header and a stream moved across addresses ban with no increment, as does
  the operator (`ban_without_increment`, a witness by evaluation);
* the framing round trip is `unframe_frame` (`lean/BsvChain/Properties/P2P.lean`).

Beside them: the initial block download requests nothing
(`ibd_inv_requests_nothing`); a peer that asked for no transactions is
offered none (`relay_off_offered_nothing`); a miner-info data transaction is
never queued (`dataref_never_queued`); no internal reject code reaches the
wire (`step_rejects_on_wire`); a local peer is never banned for misbehavior
(`local_never_banned_by_score`).
[SRC] bitcoin-sv v1.2.3 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b, as cited
in `lean/BsvChain/Wire/Relay.lean`.
-/

namespace BsvChain.Wire
open BsvScript.Numbers

/-! ## 1. Announcement -/

/-- [D] 2026-10-15: the offer never shrinks a peer's queue. -/
theorem addOne_pending_mono (p : Peer) (q : Queued) (x : Bytes) (h : x ∈ p.pending) :
    x ∈ (p.addOne q).pending := by
  unfold Peer.addOne; split <;> simp_all

/-- [D] 2026-10-15: offers never shrink a peer's queue. -/
theorem foldl_addOne_pending_mono (qs : List Queued) (p : Peer) (x : Bytes) (h : x ∈ p.pending) :
    x ∈ (qs.foldl Peer.addOne p).pending := by
  induction qs generalizing p with
  | nil => simpa
  | cons q qs ih => exact ih _ (addOne_pending_mono p q x h)

/-- [D] 2026-10-15: an offer leaves the filters it reads alone. -/
theorem addOne_filters (p : Peer) (q : Queued) :
    (p.addOne q).minFeeFilter = p.minFeeFilter ∧ (p.addOne q).filtered = p.filtered ∧
      (p.addOne q).id = p.id := by
  unfold Peer.addOne; split <;> simp

/-- [D] 2026-10-15: offers keep the peer's id. -/
theorem foldl_addOne_id (qs : List Queued) (p : Peer) : (qs.foldl Peer.addOne p).id = p.id := by
  induction qs generalizing p with
  | nil => rfl
  | cons r rs ih => simp only [List.foldl_cons]; rw [ih]; exact (addOne_filters p r).2.2

/-- [D] 2026-10-15: the fee filter reads the peer's rate only. -/
theorem feeOk_congr (p p' : Peer) (q : Queued) (h : p'.minFeeFilter = p.minFeeFilter) :
    p'.feeOk q = p.feeOk q := by
  simp [Peer.feeOk, h]

/-- [D] 2026-10-15: a queued transaction the peer's filters pass, and that is
not known to it or already queued for it, ends in its queue. -/
theorem foldl_addOne_mem (qs : List Queued) (p : Peer) (q : Queued) (hq : q ∈ qs)
    (hf : p.feeOk q = true) (hb : q.id ∉ p.filtered) (hk : q.id ∉ p.known ∨ q.id ∈ p.pending) :
    q.id ∈ (qs.foldl Peer.addOne p).pending := by
  induction qs generalizing p with
  | nil => simp at hq
  | cons r rs ih =>
    simp only [List.foldl_cons]
    obtain ⟨hm, hfl, _⟩ := addOne_filters p r
    rcases List.mem_cons.mp hq with rfl | hq'
    · apply foldl_addOne_pending_mono
      unfold Peer.addOne
      split
      · simp
      · rename_i hc
        rcases hk with hk | hk
        · exfalso; apply hc; simp [hf, hk, hb]
        · exact hk
    · apply ih _ hq'
      · rw [feeOk_congr _ _ _ hm]; exact hf
      · rw [hfl]; exact hb
      · unfold Peer.addOne
        split
        · by_cases he : q.id = r.id
          · right; simp [he]
          · rcases hk with hk | hk
            · left; simp [hk, he]
            · right; simp [hk]
        · exact hk

/-- [D] 2026-10-15: a transaction a peer is known to have, and that is not
already queued for it, is never queued for it. -/
theorem foldl_addOne_known (qs : List Queued) (p : Peer) (x : Bytes) (hk : x ∈ p.known)
    (hp : x ∉ p.pending) : x ∉ (qs.foldl Peer.addOne p).pending := by
  induction qs generalizing p with
  | nil => simpa
  | cons r rs ih =>
    simp only [List.foldl_cons]
    apply ih
    · unfold Peer.addOne; split <;> simp [hk]
    · unfold Peer.addOne
      split
      · rename_i hc
        have hne : r.id ≠ x := by
          intro he; subst he; simp_all
        simp [hp, Ne.symm hne]
      · exact hp

/-- [D] 2026-10-15: the propagator's pass queues a transaction of its queue
for every peer that relays transactions, passes its filters and is not known
to have it (src/txn_propagator.cpp:136-175; src/net/net.cpp:836-878). A view,
never a rule. -/
theorem propagate_queues (s : Node) (p : Peer) (hp : p ∈ s.peers) (q : Queued) (hq : q ∈ s.queue)
    (hr : p.relayTxes = true) (hf : p.feeOk q = true) (hb : q.id ∉ p.filtered)
    (hk : q.id ∉ p.known) :
    ∃ p' ∈ s.propagate.peers, p'.id = p.id ∧ q.id ∈ p'.pending := by
  refine ⟨p.addTxns s.queue, List.mem_map.mpr ⟨p, hp, rfl⟩, ?_, ?_⟩
  · unfold Peer.addTxns; simp only [hr, Bool.not_true, Bool.false_eq_true, ite_false]
    exact foldl_addOne_id _ _
  · unfold Peer.addTxns; simp only [hr, Bool.not_true, Bool.false_eq_true, ite_false]
    exact foldl_addOne_mem _ _ _ hq hf hb (Or.inl hk)

/-- [D] 2026-10-15: NEVER TO A PEER THAT HAS IT. A transaction a peer is known
to have, and that is not already queued for it, is not queued by the
propagator's pass (src/net/net.cpp:869-870). A view, never a rule. -/
theorem known_never_queued (p : Peer) (qs : List Queued) (x : Bytes) (hk : x ∈ p.known)
    (hp : x ∉ p.pending) : x ∉ (p.addTxns qs).pending := by
  unfold Peer.addTxns
  split
  · simp
  · exact foldl_addOne_known qs p x hk hp

/-- [D] 2026-10-15: NEVER RELAYED to a peer whose version message asked for
no transactions: its queue is cleared (src/net/net.cpp:852-856). A view,
never a rule. -/
theorem relay_off_offered_nothing (p : Peer) (qs : List Queued) (h : p.relayTxes = false) :
    (p.addTxns qs).pending = [] := by
  simp [Peer.addTxns, h]

/-- [D] 2026-10-15: NEVER RELAYED: a miner-info data transaction is never
queued (src/net/net.cpp:3576-3578). A view, never a rule. -/
theorem dataref_never_queued (s : Node) (q : Queued) (h : q.id ∈ s.datarefs) :
    (s.enqueue q).queue = s.queue := by
  simp [Node.enqueue, h]

/-- [D] 2026-10-15: the inventory test reads the pools, never the peers. -/
theorem knows_updPeer (s : Node) (pid : PeerId) (f : Peer → Peer) :
    (s.updPeer pid f).knows = s.knows := rfl

/-- [D] 2026-10-15: a peer other than the changed one is untouched. -/
theorem mem_updPeer_other (s : Node) (pid : PeerId) (f : Peer → Peer) (p : Peer)
    (hp : p ∈ s.peers) (hne : p.id ≠ pid) : p ∈ (s.updPeer pid f).peers := by
  simp only [Node.updPeer, List.mem_map]
  exact ⟨p, hp, by simp [hne]⟩

/-- [D] 2026-10-15: THE ANNOUNCEMENT. A transaction the node accepts from a
peer (`tx`, its verdict `accepted`, the node not knowing it before, not in
blocks-only mode for the sender, not a miner-info data transaction) is queued
by the next propagator's pass for every other peer that relays transactions,
passes its fee filter and loaded filter and is not known to have it
(src/net/net_processing.cpp:3351-3393; src/validation.cpp:2097-2116,
:975-997; src/net/net.cpp:3574-3582,836-878). A view, never a rule. -/
theorem accepted_queued_for_unseen (s : Node) (src : PeerId) (ps : Peer)
    (hsrc : s.peer? src = some ps) (hign : s.ignoresTxFrom ps = false) (q : Queued)
    (hnew : s.knows q.id = false) (hdr : q.id ∉ s.datarefs)
    (p : Peer) (hp : p ∈ s.peers) (hne : p.id ≠ src) (hr : p.relayTxes = true)
    (hf : p.feeOk q = true) (hb : q.id ∉ p.filtered) (hk : q.id ∉ p.known) :
    ∃ p' ∈ (s.recvTx src q .accepted).1.propagate.peers, p'.id = p.id ∧ q.id ∈ p'.pending := by
  apply propagate_queues _ p
  · simp only [Node.recvTx, hsrc, hign, Bool.false_eq_true, ite_false]
    rw [show ((s.addKnown src q.id).updPeer src _).knows q.id = s.knows q.id from rfl, hnew]
    simp only [Bool.false_eq_true, ite_false, Node.enqueue, List.contains_iff_mem]
    split <;>
      exact mem_updPeer_other _ _ _ _ (mem_updPeer_other _ _ _ _ hp hne) hne
  · simp only [Node.recvTx, hsrc, hign, Bool.false_eq_true, ite_false]
    rw [show ((s.addKnown src q.id).updPeer src _).knows q.id = s.knows q.id from rfl, hnew]
    simp only [Bool.false_eq_true, ite_false, Node.enqueue]
    have : ((s.addKnown src q.id).updPeer src (fun p =>
        { p with requested := p.requested.filter (· != q.id),
                 inFlight := p.inFlight.filter (· != q.id) })).datarefs = s.datarefs := rfl
    rw [this]
    simp [hdr]
  all_goals assumption

/-- [D] 2026-10-15: NEVER BACK TO THE SENDER. After the `tx` message the
sender is known to have the transaction (src/net/net_processing.cpp:3370-3371),
so the propagator's pass does not queue it back to the sender, unless it was
already queued for it before. A view, never a rule. -/
theorem accepted_never_back_to_sender (s : Node) (src : PeerId) (ps : Peer)
    (hsrc : s.peer? src = some ps) (hign : s.ignoresTxFrom ps = false) (q : Queued)
    (hpend : ∀ p ∈ s.peers, p.id = src → q.id ∉ p.pending) :
    ∀ p' ∈ (s.recvTx src q .accepted).1.propagate.peers, p'.id = src → q.id ∉ p'.pending := by
  intro p' hp' hid
  simp only [Node.recvTx, hsrc, hign, Bool.false_eq_true, ite_false] at hp'
  have key : ∀ t : Node, t.peers = ((s.addKnown src q.id).updPeer src (fun p =>
      { p with requested := p.requested.filter (· != q.id),
               inFlight := p.inFlight.filter (· != q.id) })).peers →
      p' ∈ t.propagate.peers → q.id ∉ p'.pending := by
    intro t ht hm
    simp only [Node.propagate, List.mem_map, ht, Node.updPeer, Node.addKnown] at hm
    obtain ⟨p1, ⟨p0, ⟨p00, h00, rfl⟩, rfl⟩, rfl⟩ := hm
    have hidx : ∀ (r : Peer) (qs : List Queued), (r.addTxns qs).id = r.id := by
      intro r qs; unfold Peer.addTxns; split
      · rfl
      · exact foldl_addOne_id _ _
    rw [hidx] at hid
    by_cases h : p00.id = src
    · simp only [h, ite_true] at hid ⊢
      have hp0 := hpend p00 h00 h
      apply known_never_queued
      all_goals (try split) <;> simp_all
    · simp only [h, ite_false] at hid
  split at hp'
  · split at hp' <;> exact key _ (by simp only [Node.enqueue]; try (split <;> rfl)) hp'
  · exact key _ (by simp only [Node.enqueue]; try (split <;> rfl)) hp'

/-! ## 2. The ban -/

/-- [D] 2026-10-15: the ban invariant: a peer marked for a ban has a recorded
score at the threshold or above, and every ban entry for misbehavior names
such a peer. -/
def BanSound (s : Node) : Prop :=
  (∀ p ∈ s.peers, p.shouldBan = true → s.cfg.banScore ≤ s.score p.id) ∧
  (∀ b ∈ s.banned, b.cause = .misbehavior → ∃ pid, b.peer = some pid ∧ s.cfg.banScore ≤ s.score pid)

/-- [D] 2026-10-15: a transition that sets no mark, records no misbehavior
ban, keeps the settings and only appends to the log. -/
def Ext (s t : Node) : Prop :=
  t.cfg = s.cfg ∧ (∃ l, t.log = s.log ++ l) ∧
  (∀ b ∈ t.banned, b ∈ s.banned ∨ b.cause ≠ .misbehavior) ∧
  (∀ p' ∈ t.peers, p'.shouldBan = true → ∃ p ∈ s.peers, p.id = p'.id ∧ p.shouldBan = true)

/-- [D] 2026-10-15: a node extends itself. -/
theorem Ext.refl (s : Node) : Ext s s :=
  ⟨rfl, ⟨[], by simp⟩, fun b hb => Or.inl hb, fun p hp h => ⟨p, hp, rfl, h⟩⟩

/-- [D] 2026-10-15: extensions compose: the log appends, no mark or misbehavior ban appears. -/
theorem Ext.trans {s t u : Node} (h1 : Ext s t) (h2 : Ext t u) : Ext s u := by
  obtain ⟨c1, ⟨l1, g1⟩, b1, p1⟩ := h1
  obtain ⟨c2, ⟨l2, g2⟩, b2, p2⟩ := h2
  refine ⟨c2.trans c1, ⟨l1 ++ l2, by simp [g2, g1]⟩, ?_, ?_⟩
  · intro b hb
    rcases b2 b hb with h | h
    · exact b1 b h
    · exact Or.inr h
  · intro p hp hs
    obtain ⟨p0, hp0, hid, hs0⟩ := p2 p hp hs
    obtain ⟨p00, hp00, hid0, hs00⟩ := p1 p0 hp0 hs0
    exact ⟨p00, hp00, hid0.trans hid, hs00⟩

/-- [D] 2026-10-15: the score never falls when the log grows. -/
theorem score_append (s : Node) (l : List (PeerId × Nat × Bytes)) (pid : PeerId) :
    s.score pid ≤ ({ s with log := s.log ++ l } : Node).score pid := by
  simp [Node.score, List.filter_append, List.map_append, List.sum_append]

/-- [D] 2026-10-15: a log that only grows never lowers a score. -/
theorem score_of_log {s t : Node} (h : ∃ l, t.log = s.log ++ l) (pid : PeerId) :
    s.score pid ≤ t.score pid := by
  obtain ⟨l, hl⟩ := h
  have := score_append s l pid
  simp [Node.score, hl] at this ⊢

/-- [D] 2026-10-15: an extension keeps the ban invariant (the scores only grow). -/
theorem BanSound.of_ext {s t : Node} (h : BanSound s) (e : Ext s t) : BanSound t := by
  obtain ⟨c, hl, hb, hp⟩ := e
  refine ⟨fun p' hp' hs => ?_, fun b hb' hc => ?_⟩
  · obtain ⟨p, hp0, hid, hs0⟩ := hp p' hp' hs
    rw [c, ← hid]; exact (h.1 p hp0 hs0).trans (score_of_log hl _)
  · rcases hb b hb' with hin | hne
    · obtain ⟨pid, hpid, hsc⟩ := h.2 b hin hc
      exact ⟨pid, hpid, by rw [c]; exact hsc.trans (score_of_log hl _)⟩
    · exact absurd hc hne

/-- [D] 2026-10-15: changing peers without touching their marks or ids. -/
theorem Ext.updPeer (s : Node) (pid : PeerId) (f : Peer → Peer)
    (hf : ∀ p, (f p).shouldBan = p.shouldBan ∧ (f p).id = p.id) : Ext s (s.updPeer pid f) := by
  refine ⟨rfl, ⟨[], by simp [Node.updPeer]⟩, fun b hb => Or.inl hb, ?_⟩
  intro p' hp' hs
  simp only [Node.updPeer, List.mem_map] at hp'
  obtain ⟨p, hp, rfl⟩ := hp'
  refine ⟨p, hp, ?_, ?_⟩
  · split <;> simp [(hf p).2]
  · split at hs <;> simp_all [(hf p).1]

/-- [D] 2026-10-15: mapping every peer by a change that keeps marks and ids is an extension. -/
theorem Ext.peers_map (s : Node) (g : Peer → Peer)
    (hf : ∀ p, (g p).shouldBan = p.shouldBan ∧ (g p).id = p.id) :
    Ext s { s with peers := s.peers.map g } := by
  refine ⟨rfl, ⟨[], by simp⟩, fun b hb => Or.inl hb, ?_⟩
  intro p' hp' hs
  simp only [List.mem_map] at hp'
  obtain ⟨p, hp, rfl⟩ := hp'
  exact ⟨p, hp, (hf p).2.symm, by rw [(hf p).1] at hs; exact hs⟩

/-- [D] 2026-10-15: a fold of extensions is an extension. -/
theorem Ext.foldl {α : Type} (f : Node → α → Node) (hf : ∀ s x, Ext s (f s x)) (l : List α) (s : Node) :
    Ext s (l.foldl f s) := by
  induction l generalizing s with
  | nil => exact Ext.refl s
  | cons x xs ih => exact (hf s x).trans (ih _)

/-- [D] 2026-10-15: marking an id known to a peer is an extension. -/
theorem Ext.addKnown (s : Node) (pid : PeerId) (id : Bytes) : Ext s (s.addKnown pid id) :=
  Ext.updPeer _ _ _ (fun _ => ⟨rfl, rfl⟩)

/-- [D] 2026-10-15: `AskFor` is an extension (src/net/net.cpp:3269-3318). -/
theorem Ext.askFor (s : Node) (pid : PeerId) (id : Bytes) : Ext s (s.askFor pid id) := by
  unfold Node.askFor
  split
  · exact Ext.refl s
  · split
    · exact Ext.refl s
    · have h := Ext.updPeer s pid (fun p => { p with requested := p.requested ++ [id] })
        (fun _ => ⟨rfl, rfl⟩)
      obtain ⟨c, l, b, p⟩ := h
      exact ⟨c, l, b, p⟩

/-- [D] 2026-10-15: `EnqueueTransaction` is an extension (src/net/net.cpp:3574-3582). -/
theorem Ext.enqueue (s : Node) (q : Queued) : Ext s (s.enqueue q) := by
  unfold Node.enqueue; split
  · exact Ext.refl s
  · exact ⟨rfl, ⟨[], by simp⟩, fun b hb => Or.inl hb, fun p hp h => ⟨p, hp, rfl, h⟩⟩

/-- [D] 2026-10-15: the queue's enqueue keeps the settings. -/
@[simp] theorem enqueue_cfg (s : Node) (q : Queued) : (s.enqueue q).cfg = s.cfg := by
  unfold Node.enqueue; split <;> rfl
/-- [D] 2026-10-15: the queue's enqueue keeps the log. -/
@[simp] theorem enqueue_log (s : Node) (q : Queued) : (s.enqueue q).log = s.log := by
  unfold Node.enqueue; split <;> rfl
/-- [D] 2026-10-15: the queue's enqueue keeps the ban list. -/
@[simp] theorem enqueue_banned (s : Node) (q : Queued) : (s.enqueue q).banned = s.banned := by
  unfold Node.enqueue; split <;> rfl
/-- [D] 2026-10-15: the queue's enqueue keeps the peers. -/
@[simp] theorem enqueue_peers (s : Node) (q : Queued) : (s.enqueue q).peers = s.peers := by
  unfold Node.enqueue; split <;> rfl

/-- [D] 2026-10-15: changing only the pools, queues and lists the ban does not read. -/
theorem Ext.fields (s t : Node) (hc : t.cfg = s.cfg) (hl : t.log = s.log) (hb : t.banned = s.banned)
    (hp : t.peers = s.peers) : Ext s t :=
  ⟨hc, ⟨[], by simp [hl]⟩, fun b h => Or.inl (hb ▸ h), fun p h hs => ⟨p, hp ▸ h, rfl, hs⟩⟩

/-- [D] 2026-10-15: `Misbehaving` keeps the invariant: it marks a peer only
when the recorded score crosses the threshold
(src/net/net_processing.cpp:620-628). -/
theorem BanSound.misbehaving {s : Node} (h : BanSound s) (pid : PeerId) (n : Nat) (r : Bytes) :
    BanSound (s.misbehaving pid n r) := by
  unfold Node.misbehaving
  dsimp only
  split
  · exact h
  · have hs' : BanSound { s with log := s.log ++ [(pid, n, r)] } :=
      h.of_ext ⟨rfl, ⟨[(pid, n, r)], rfl⟩, fun b hb => Or.inl hb, fun p hp hs => ⟨p, hp, rfl, hs⟩⟩
    split
    · rename_i hn hcross
      refine ⟨fun p' hp' hs => ?_, fun b hb hc => hs'.2 b hb hc⟩
      simp only [Node.updPeer, List.mem_map] at hp'
      obtain ⟨p, hp, rfl⟩ := hp'
      by_cases hid : p.id = pid
      · simp only [hid, ite_true]
        simp only [Node.score, Node.updPeer] at hcross ⊢
        simp [List.filter_append, List.map_append, List.sum_append] at hcross ⊢
        omega
      · simp only [hid, ite_false] at hs ⊢
        exact hs'.1 p hp hs
    · exact hs'

/-- [D] 2026-10-15: the send pass's ban step keeps the invariant: an entry for
misbehavior is written only for a marked peer (src/net/net_processing.cpp:4900-4917). -/
theorem BanSound.consumeBan {s : Node} (h : BanSound s) (pid : PeerId) :
    BanSound (s.consumeBan pid) := by
  unfold Node.consumeBan
  split
  · exact h
  · rename_i p hfind
    have hp : p ∈ s.peers := List.mem_of_find?_eq_some hfind
    have hpid : p.id = pid := by simpa using List.find?_some hfind
    split
    · exact h
    · rename_i hsb
      simp only [Bool.not_eq_true', Bool.not_eq_false] at hsb
      have hsc : s.cfg.banScore ≤ s.score pid := hpid ▸ h.1 p hp (by simpa using hsb)
      have h1 : BanSound (s.updPeer pid (fun p => { p with shouldBan := false })) := by
        refine ⟨fun p' hp' hs => ?_, fun b hb hc => ?_⟩
        · simp only [Node.updPeer, List.mem_map] at hp'
          obtain ⟨p0, hp0, rfl⟩ := hp'
          by_cases hid : p0.id = pid
          · simp [hid] at hs
          · simp only [hid, ite_false] at hs ⊢
            have := h.1 p0 hp0 hs
            simpa [Node.updPeer, Node.score] using this
        · obtain ⟨q, hq, hqs⟩ := h.2 b hb hc
          exact ⟨q, hq, by simpa [Node.updPeer, Node.score] using hqs⟩
      split
      · exact h1
      · have h2 := h1.of_ext (Ext.updPeer _ pid (fun p => { p with disconnect := true })
          (fun _ => ⟨rfl, rfl⟩))
        split
        · exact h2
        · refine ⟨fun p' hp' hs => ?_, fun b hb hc => ?_⟩
          · simp only [Node.ban, List.mem_map] at hp'
            obtain ⟨p0, hp0, rfl⟩ := hp'
            have := h2.1 p0 hp0
            split at hs <;> simp_all [Node.ban, Node.score]
          · simp only [Node.ban, List.mem_append, List.mem_singleton] at hb
            rcases hb with hb | rfl
            · obtain ⟨q, hq, hqs⟩ := h2.2 b hb hc
              exact ⟨q, hq, by simpa [Node.ban, Node.score] using hqs⟩
            · exact ⟨pid, rfl, by simpa [Node.ban, Node.score, Node.updPeer] using hsc⟩

/-- [D] 2026-10-15: a ban with a cause other than misbehavior is an extension (src/net/net.cpp:535-580). -/
theorem Ext.ban (s : Node) (a : AddrId) (c : BanCause) (hc : c ≠ .misbehavior) (pid : Option PeerId) :
    Ext s (s.ban a c pid) := by
  refine ⟨rfl, ⟨[], by simp [Node.ban]⟩, ?_, ?_⟩
  · intro b hb
    simp only [Node.ban, List.mem_append, List.mem_singleton] at hb
    rcases hb with hb | rfl
    · exact Or.inl hb
    · exact Or.inr hc
  · intro p' hp' hs
    simp only [Node.ban, List.mem_map] at hp'
    obtain ⟨p, hp, rfl⟩ := hp'
    exact ⟨p, hp, by split <;> rfl, by split at hs <;> simpa using hs⟩

/-- [D] 2026-10-15: a direct ban by a peer's address is an extension. -/
theorem Ext.directBan (s : Node) (pid : PeerId) (c : BanCause) (hc : c ≠ .misbehavior) :
    Ext s (s.directBan pid c) := by
  unfold Node.directBan; split
  · exact Ext.refl s
  · exact Ext.ban _ _ _ hc _

/-- [D] 2026-10-15: offers keep a peer's mark. -/
theorem foldl_addOne_shouldBan (qs : List Queued) (p : Peer) :
    (qs.foldl Peer.addOne p).shouldBan = p.shouldBan := by
  induction qs generalizing p with
  | nil => rfl
  | cons r rs ih => simp only [List.foldl_cons]; rw [ih]; unfold Peer.addOne; split <;> rfl

/-- [D] 2026-10-15: the inventory's gain keeps a peer's mark and id (src/net/net.cpp:836-878). -/
theorem Ext.addTxns_peer (p : Peer) (qs : List Queued) :
    (p.addTxns qs).shouldBan = p.shouldBan ∧ (p.addTxns qs).id = p.id := by
  unfold Peer.addTxns; split
  · exact ⟨rfl, rfl⟩
  · exact ⟨foldl_addOne_shouldBan _ _, foldl_addOne_id _ _⟩

/-- [D] 2026-10-15: the `tx` message keeps the ban invariant: its only score change is `Misbehaving` (src/validation.cpp:2091-2094). -/
theorem BanSound.recvTx {s : Node} (h : BanSound s) (pid : PeerId) (q : Queued) (v : Verdict) :
    BanSound (s.recvTx pid q v).1 := by
  unfold Node.recvTx
  dsimp only
  split
  · exact h
  · split
    · exact h
    · have e0 := (Ext.addKnown s pid q.id).trans (Ext.updPeer _ pid (fun p =>
        { p with requested := p.requested.filter (· != q.id),
                 inFlight := p.inFlight.filter (· != q.id) }) (fun _ => ⟨rfl, rfl⟩))
      have h0 := h.of_ext e0
      generalize ((s.addKnown pid q.id).updPeer pid (fun p =>
        { p with requested := p.requested.filter (· != q.id),
                 inFlight := p.inFlight.filter (· != q.id) })) = s0 at h0 ⊢
      split
      · split
        · exact h0.of_ext (Ext.enqueue _ _)
        · exact h0
      · cases v with
        | accepted =>
          apply h0.of_ext
          exact (Ext.enqueue s0 q).trans (Ext.fields _ _ rfl rfl rfl rfl)
        | missingInputs parents =>
          try dsimp only
          split
          · exact h0.of_ext (Ext.fields _ _ (by simp) (by simp) (by simp) (by simp))
          · apply h0.of_ext
            refine (Ext.foldl _ ?_ parents s0).trans (Ext.fields _ _ rfl rfl rfl rfl)
            intro t x
            try dsimp only
            split
            · exact Ext.addKnown _ _ _
            · exact (Ext.addKnown _ _ _).trans (Ext.askFor _ _ _)
        | invalid code reason dos corruption =>
          dsimp only
          apply BanSound.misbehaving
          have h1 : BanSound (if corruption = true then s0 else { s0 with rejects := s0.rejects ++ [q.id] }) := by
            split
            · exact h0
            · exact h0.of_ext (Ext.fields _ _ (by simp) (by simp) (by simp) (by simp))
          generalize (if corruption = true then s0 else { s0 with rejects := s0.rejects ++ [q.id] }) = s1 at h1 ⊢
          split
          · exact h1.of_ext (Ext.enqueue _ _)
          · exact h1

/-- [D] 2026-10-15: an orphan's retry keeps the ban invariant (src/validation.cpp:1971-1981). -/
theorem BanSound.retryOrphan {s : Node} (h : BanSound s) (q : Queued) (v : Verdict) :
    BanSound (s.retryOrphan q v).1 := by
  unfold Node.retryOrphan
  dsimp only
  split
  · exact h
  · cases v with
    | accepted => exact h.of_ext (Ext.fields s _ (by simp) (by simp) (by simp) (by simp))
    | missingInputs _ => exact h.of_ext (Ext.fields s _ (by simp) (by simp) (by simp) (by simp))
    | invalid code reason dos corruption =>
      dsimp only
      apply BanSound.misbehaving
      split
      · exact h.of_ext (Ext.fields s _ (by simp) (by simp) (by simp) (by simp))
      · exact h.of_ext (Ext.fields s _ (by simp) (by simp) (by simp) (by simp))

/-- [D] 2026-10-15: the `inv` message is an extension: it scores nothing (src/net/net_processing.cpp:2454-2532). -/
theorem Ext.recvInv (s : Node) (pid : PeerId) (items : List InvItem) : Ext s (s.recvInv pid items) := by
  unfold Node.recvInv
  split
  · exact Ext.refl s
  · apply Ext.foldl
    intro t i
    unfold Node.invItem
    dsimp only
    split
    · split
      · exact Ext.addKnown _ _ _
      · split
        · exact (Ext.addKnown _ _ _).trans (Ext.askFor _ _ _)
        · exact Ext.addKnown _ _ _
    · split
      · exact Ext.refl _
      · exact Ext.updPeer _ _ _ (fun _ => ⟨rfl, rfl⟩)

/-- [D] 2026-10-15: the inventory flush is an extension. -/
theorem Ext.flush (s : Node) (pid : PeerId) : Ext s (s.flush pid).1 := by
  unfold Node.flush
  dsimp only
  split
  · exact Ext.refl s
  · split
    · exact Ext.refl s
    · exact (Ext.updPeer s pid _ (fun _ => by exact ⟨rfl, rfl⟩)).trans (Ext.fields _ _ rfl rfl rfl rfl)

/-- [D] 2026-10-15: the request pass is an extension. -/
theorem Ext.request (s : Node) (pid : PeerId) : Ext s (s.request pid).1 := by
  unfold Node.request
  dsimp only
  split
  · exact Ext.refl s
  · exact Ext.updPeer s pid _ (fun _ => ⟨rfl, rfl⟩)

/-- [D] 2026-10-15: every transition keeps the ban invariant. -/
theorem BanSound.step {s : Node} (h : BanSound s) (e : Event) : BanSound (s.step e).1 := by
  cases e with
  | recvInv pid items => exact h.of_ext (Ext.recvInv _ _ _)
  | recvTx pid q v => exact h.recvTx pid q v
  | retryOrphan q v => exact h.retryOrphan q v
  | recvGetData pid items => exact h
  | rpcAccepted q =>
    apply h.of_ext
    exact (Ext.enqueue s q).trans (Ext.fields _ _ rfl rfl rfl rfl)
  | propagate =>
    apply h.of_ext
    exact (Ext.peers_map s (·.addTxns s.queue) (fun p => Ext.addTxns_peer p s.queue)).trans
      (Ext.fields _ _ rfl rfl rfl rfl)
  | flush pid => exact h.of_ext (Ext.flush _ _)
  | request pid => exact h.of_ext (Ext.request _ _)
  | misbehave pid n r => exact h.misbehaving pid n r
  | sendBan pid => exact h.consumeBan pid
  | badMagic pid => exact h.of_ext (Ext.directBan _ _ _ (by decide))
  | oversizedHeader pid => exact h.of_ext (Ext.directBan _ _ _ (by decide))
  | streamMismatch pid => exact h.of_ext (Ext.directBan _ _ _ (by decide))
  | setban a => exact h.of_ext (Ext.ban _ _ _ (by decide) _)
  | setIbd b =>
    apply h.of_ext
    exact Ext.fields _ _ rfl rfl rfl rfl

/-- [D] 2026-10-15: THE BAN. From a node with no peer marked and no ban for
misbehavior, along any run, every peer marked for a ban has recorded
increments summing to the threshold or more, and every ban entry for
misbehavior names such a peer: a ban for misbehavior is reached only through
recorded increments (src/net/net_processing.cpp:610-634,4900-4919). The
other causes are named in the entry (`BanCause`); `ban_without_increment`
shows the issue's unqualified sentence false of the ban list at the pin. A
view, never a rule. -/
theorem ban_sound_run (s : Node) (h0 : BanSound s) (es : List Event) : BanSound (s.run es).1 := by
  induction es generalizing s with
  | nil => exact h0
  | cons e es ih => exact ih _ (h0.step e)

/-- [D] 2026-10-15: a node with no marks and no bans is sound. -/
theorem BanSound.clean (s : Node) (hp : ∀ p ∈ s.peers, p.shouldBan = false) (hb : s.banned = []) :
    BanSound s :=
  ⟨fun p h hs => by simp_all, fun b h => by simp [hb] at h⟩

/-- [D] 2026-10-15: the witness. A peer whose header is over its cap is banned
with no increment recorded (src/net/net_message.cpp:22-26,
src/net/association.cpp:396-401): the ban list is reached outside the
misbehavior score. A view, never a rule. -/
theorem ban_without_increment :
    let s : Node := { peers := [{ id := 0, addr := 7 }] }
    (s.step (.oversizedHeader 0)).1.banned = [{ addr := 7, cause := .oversizedHeader, peer := some 0 }] ∧
      (s.step (.oversizedHeader 0)).1.log = [] := by
  decide

/-- [D] 2026-10-15: a local peer is disconnected, never banned, for its score;
a whitelisted or manual peer is neither (src/net/net_processing.cpp:4900-4917). -/
theorem local_never_banned_by_score (s : Node) (pid : PeerId) (p : Peer)
    (hp : s.peer? pid = some p) (hl : p.isLocal = true) :
    (s.consumeBan pid).banned = s.banned := by
  unfold Node.consumeBan
  simp only [hp]
  split
  · rfl
  · split
    · rfl
    · simp [Node.updPeer]

/-- [D] 2026-10-15: finding a peer in a list changed without moving ids. -/
theorem peer?_map (s : Node) (g : Peer → Peer) (hg : ∀ p, (g p).id = p.id) (pid : PeerId) :
    ({ s with peers := s.peers.map g } : Node).peer? pid = (s.peer? pid).map g := by
  simp [Node.peer?, List.find?_map, Function.comp_def, hg]

/-- [D] 2026-10-15: the lookup reads the peers only. -/
theorem peer?_of_peers (t u : Node) (pid : PeerId) (h : t.peers = u.peers) : t.peer? pid = u.peer? pid := by
  simp [Node.peer?, h]

/-- [D] 2026-10-15: changing another peer leaves a peer's lookup alone. -/
theorem peer?_updPeer_ne (s : Node) (pid pid' : PeerId) (f : Peer → Peer)
    (hf : ∀ p, (f p).id = p.id) (hne : pid' ≠ pid) : (s.updPeer pid f).peer? pid' = s.peer? pid' := by
  unfold Node.updPeer
  rw [peer?_map s _ (fun p => by split <;> simp [hf])]
  cases h : s.peer? pid' with
  | none => rfl
  | some r =>
    have hr : r.id = pid' := by simpa using List.find?_some h
    simp [hr, hne]

/-- [D] 2026-10-15: on a node whose queue holds one transaction, a peer with
nothing queued that relays transactions, passes the filters and is not known
to have it is sent exactly one `inv` naming it by the pass and its flush. -/
theorem propagate_flush_single (t : Node) (q : Queued) (hq : t.queue = [q])
    (hmax : 0 < t.cfg.broadcastMax) (p : Peer) (hp : t.peer? p.id = some p)
    (hr : p.relayTxes = true) (hf : p.feeOk q = true) (hb : q.id ∉ p.filtered)
    (hk : q.id ∉ p.known) (hpd : p.pending = []) :
    (t.propagate.flush p.id).2 = [(p.id, .inv [txItem q.id])] := by
  have e := peer?_map t (·.addTxns t.queue) (fun r => (Ext.addTxns_peer r t.queue).2) p.id
  have hpr : t.propagate.peer? p.id = some (p.addTxns t.queue) := by
    rw [show t.propagate.peer? p.id = ({ t with peers := t.peers.map (·.addTxns t.queue) } : Node).peer? p.id
      from rfl, e, hp]; rfl
  have hadd : (p.addTxns t.queue).pending = [q.id] := by
    rw [hq]; simp [Peer.addTxns, hr, Peer.addOne, hf, hk, hb, hpd]
  unfold Node.flush
  rw [hpr]
  dsimp only
  have hcfg : t.propagate.cfg = t.cfg := rfl
  rw [hadd, hcfg]
  have : [q.id].take t.cfg.broadcastMax = [q.id] := by
    cases h : t.cfg.broadcastMax with
    | zero => omega
    | succ n => simp
  rw [this]
  simp

/-- [D] 2026-10-15: THE ANNOUNCEMENT, ON AN IDLE NODE. A transaction the node
accepts from a peer, with nothing else queued, is announced to each other
peer that relays transactions, passes its filters, has nothing queued and is
not known to have it, by exactly one `inv` naming it on that peer's next
flush after the propagator's pass (src/net/net_processing.cpp:3351-3393,
5536-5674; src/validation.cpp:2097-2116; src/net/net.cpp:836-878). A view,
never a rule. -/
theorem accepted_announced_when_idle (s : Node) (src : PeerId) (ps : Peer)
    (hsrc : s.peer? src = some ps) (hign : s.ignoresTxFrom ps = false) (q : Queued)
    (hnew : s.knows q.id = false) (hdr : q.id ∉ s.datarefs) (hq : s.queue = [])
    (hmax : 0 < s.cfg.broadcastMax) (p : Peer) (hp : s.peer? p.id = some p) (hne : p.id ≠ src)
    (hr : p.relayTxes = true) (hf : p.feeOk q = true) (hb : q.id ∉ p.filtered)
    (hk : q.id ∉ p.known) (hpd : p.pending = []) :
    ((s.recvTx src q .accepted).1.propagate.flush p.id).2 = [(p.id, .inv [txItem q.id])] := by
  apply propagate_flush_single _ q _ _ p _ hr hf hb hk hpd
  · simp only [Node.recvTx, hsrc, hign, Bool.false_eq_true, ite_false]
    rw [show ((s.addKnown src q.id).updPeer src _).knows q.id = s.knows q.id from rfl, hnew]
    simp [Node.enqueue, Node.updPeer, Node.addKnown, hdr, hq]
  · simp only [Node.recvTx, hsrc, hign, Bool.false_eq_true, ite_false]
    rw [show ((s.addKnown src q.id).updPeer src _).knows q.id = s.knows q.id from rfl, hnew]
    simp only [Bool.false_eq_true, ite_false]
    rw [enqueue_cfg]
    exact hmax
  · simp only [Node.recvTx, hsrc, hign, Bool.false_eq_true, ite_false]
    rw [show ((s.addKnown src q.id).updPeer src _).knows q.id = s.knows q.id from rfl, hnew]
    simp only [Bool.false_eq_true, ite_false]
    have e1 : (s.addKnown src q.id).peer? p.id = s.peer? p.id :=
      peer?_updPeer_ne _ _ _ _ (fun _ => rfl) hne
    have e2 : ((s.addKnown src q.id).updPeer src (fun p =>
        { p with requested := p.requested.filter (· != q.id),
                 inFlight := p.inFlight.filter (· != q.id) })).peer? p.id =
        (s.addKnown src q.id).peer? p.id :=
      peer?_updPeer_ne _ _ _ _ (fun _ => rfl) hne
    rw [peer?_of_peers _ ((s.addKnown src q.id).updPeer src (fun p =>
        { p with requested := p.requested.filter (· != q.id),
                 inFlight := p.inFlight.filter (· != q.id) })) _ (by simp), e2, e1, hp]

/-- [D] 2026-10-15: THE ANNOUNCEMENT, THE RPC'S ACCEPTANCE. A transaction
`sendrawtransaction` accepts (not a miner-info data transaction) is queued by
the next propagator's pass for every peer that relays transactions, passes its
fee filter and loaded filter and is not known to have it
(src/rpc/rawtransaction.cpp:1682; src/net/net.cpp:3574-3582,836-878). A view,
never a rule. -/
theorem rpcAccepted_queued_for_unseen (s : Node) (q : Queued) (hdr : q.id ∉ s.datarefs)
    (p : Peer) (hp : p ∈ s.peers) (hr : p.relayTxes = true) (hf : p.feeOk q = true)
    (hb : q.id ∉ p.filtered) (hk : q.id ∉ p.known) :
    ∃ p' ∈ (s.rpcAccepted q).propagate.peers, p'.id = p.id ∧ q.id ∈ p'.pending := by
  apply propagate_queues _ p _ q _ hr hf hb hk
  · simpa [Node.rpcAccepted] using hp
  · simp [Node.rpcAccepted, Node.enqueue, hdr]

/-- [D] 2026-10-15: THE ANNOUNCEMENT, AN ORPHAN ACCEPTED ON RETRY. An orphan
retried after its parents arrived and accepted (not a miner-info data
transaction) is queued by the next propagator's pass for every peer that
relays transactions, passes its fee filter and loaded filter and is not known
to have it (src/txn_validator.cpp:695-720; src/validation.cpp:1859-1865,2109-2116;
src/net/net_processing.cpp:975-997; src/net/net.cpp:3574-3582,836-878). A view, never a rule. -/
theorem retryOrphan_accepted_queued_for_unseen (s : Node) (q : Queued)
    (o : Bytes × PeerId × List Bytes) (ho : s.orphans.find? (·.1 = q.id) = some o)
    (hdr : q.id ∉ s.datarefs)
    (p : Peer) (hp : p ∈ s.peers) (hr : p.relayTxes = true) (hf : p.feeOk q = true)
    (hb : q.id ∉ p.filtered) (hk : q.id ∉ p.known) :
    ∃ p' ∈ (s.retryOrphan q .accepted).1.propagate.peers, p'.id = p.id ∧ q.id ∈ p'.pending := by
  obtain ⟨oid, opid, ops⟩ := o
  apply propagate_queues _ p _ q _ hr hf hb hk
  · simpa [Node.retryOrphan, ho] using hp
  · simp [Node.retryOrphan, ho, Node.enqueue, hdr]

/-- [D] 2026-10-15: a flush keeps the settings. -/
theorem flush_cfg (s : Node) (pid : PeerId) : (s.flush pid).1.cfg = s.cfg := by
  unfold Node.flush
  split
  · rfl
  · dsimp only; split <;> rfl

/-- [D] 2026-10-15: a peer's flush leaves it in place with its queue less the
items one flush takes (`SendTxnInventory`, src/net/net_processing.cpp:5539-5570, the fetch at :5543;
`FetchNInventory`, src/net/net.cpp:907-928). -/
theorem flush_peer? (s : Node) (p : Peer) (hp : s.peer? p.id = some p) :
    (s.flush p.id).1.peer? p.id = some { p with pending := p.pending.drop s.cfg.broadcastMax } := by
  unfold Node.flush
  rw [hp]
  dsimp only
  split
  · rename_i h
    dsimp only
    rw [hp]
    congr 1
    rcases List.take_eq_nil_iff.mp h with h0 | h0
    · rw [h0, List.drop_zero]
    · cases p; simp_all
  · dsimp only
    show (s.updPeer p.id (fun p => { p with pending := p.pending.drop s.cfg.broadcastMax })).peer? p.id = _
    unfold Node.updPeer
    rw [peer?_map _ _ (fun r => by split <;> rfl), hp]
    simp

/-- [D] 2026-10-15: `k` flushes of one peer, nothing else between them, take
`k` times the items one flush takes off its queue and keep the settings. -/
theorem flushes_peer? (pid : PeerId) (k : Nat) : ∀ (s : Node) (p : Peer), p.id = pid →
    s.peer? pid = some p →
    ((fun t : Node => (t.flush pid).1)^[k] s).peer? pid =
        some { p with pending := p.pending.drop (k * s.cfg.broadcastMax) } ∧
      ((fun t : Node => (t.flush pid).1)^[k] s).cfg = s.cfg := by
  induction k with
  | zero => intro s p _ hp; refine ⟨?_, rfl⟩; rw [Function.iterate_zero_apply, hp]; cases p; simp
  | succ k ih =>
    intro s p hid hp
    subst hid
    rw [Function.iterate_succ_apply]
    obtain ⟨e1, e2⟩ := ih _ { p with pending := p.pending.drop s.cfg.broadcastMax } rfl
      (flush_peer? s p hp)
    rw [flush_cfg] at e1 e2
    refine ⟨?_, e2⟩
    rw [e1, List.drop_drop]
    congr 3
    rw [Nat.succ_mul]
    omega

/-- [D] 2026-10-15: THE ANNOUNCEMENT UNDER LOAD. An id at index `i` of a peer's
queue is in the `inv` of that peer's `(i / broadcastMax + 1)`-th flush, the
flushes of that peer following one another with no other transition between
them, for `broadcastMax` above 0 (`SendTxnInventory` takes at most
`broadcastMax` items a flush from the queue's front,
src/net/net_processing.cpp:5539-5570, the fetch at :5543, called from
`SendInventory` at :5667-5669; src/net/net.cpp:907-928). A view, never
a rule. -/
theorem pending_announced_within (s : Node) (p : Peer) (hp : s.peer? p.id = some p)
    (hmax : 0 < s.cfg.broadcastMax) (i : Nat) (hi : i < p.pending.length) :
    ∃ items, (((fun t : Node => (t.flush p.id).1)^[i / s.cfg.broadcastMax] s).flush p.id).2 =
      [(p.id, .inv items)] ∧ txItem p.pending[i] ∈ items := by
  obtain ⟨e1, e2⟩ := flushes_peer? p.id (i / s.cfg.broadcastMax) s p rfl hp
  generalize ((fun t : Node => (t.flush p.id).1)^[i / s.cfg.broadcastMax] s) = t at e1 e2
  have hkm : i / s.cfg.broadcastMax * s.cfg.broadcastMax ≤ i := Nat.div_mul_le_self _ _
  have hlt : i - i / s.cfg.broadcastMax * s.cfg.broadcastMax < s.cfg.broadcastMax := by
    have := Nat.mod_lt i hmax
    have := Nat.div_add_mod i s.cfg.broadcastMax
    rw [Nat.mul_comm] at this
    omega
  have hj : i - i / s.cfg.broadcastMax * s.cfg.broadcastMax <
      ((p.pending.drop (i / s.cfg.broadcastMax * s.cfg.broadcastMax)).take s.cfg.broadcastMax).length := by
    simp only [List.length_take, List.length_drop]
    omega
  have hmem : p.pending[i] ∈
      (p.pending.drop (i / s.cfg.broadcastMax * s.cfg.broadcastMax)).take s.cfg.broadcastMax := by
    have h := List.getElem_mem hj
    rw [List.getElem_take, List.getElem_drop] at h
    have hi' : i / s.cfg.broadcastMax * s.cfg.broadcastMax +
        (i - i / s.cfg.broadcastMax * s.cfg.broadcastMax) = i := by omega
    simp only [hi'] at h
    exact h
  unfold Node.flush
  rw [e1]
  dsimp only
  rw [e2]
  split
  · rename_i h; rw [h] at hmem; simp at hmem
  · exact ⟨_, rfl, List.mem_map_of_mem hmem⟩

/-- [D] 2026-10-15: every id in a peer's queue is announced by one of that
peer's flushes, the flushes following one another with no other transition
between them (`pending_announced_within`). A view, never a rule. -/
theorem queued_announced_within (s : Node) (p : Peer) (hp : s.peer? p.id = some p)
    (hmax : 0 < s.cfg.broadcastMax) (x : Bytes) (hx : x ∈ p.pending) :
    ∃ k items, (((fun t : Node => (t.flush p.id).1)^[k] s).flush p.id).2 =
      [(p.id, .inv items)] ∧ txItem x ∈ items := by
  obtain ⟨i, hi, rfl⟩ := List.mem_iff_getElem.mp hx
  obtain ⟨items, h1, h2⟩ := pending_announced_within s p hp hmax i hi
  exact ⟨_, items, h1, h2⟩

/-- [D] 2026-10-15: a queued transaction reaches every peer that relays
transactions, passes its filters and is not known to have it: the
propagator's pass queues it (`propagate_queues`) and one of that peer's
flushes after it announces it (`queued_announced_within`). A view, never a
rule. -/
theorem propagate_announced_within (t : Node) (q : Queued) (hq : q ∈ t.queue)
    (hmax : 0 < t.cfg.broadcastMax) (p : Peer) (hp : t.peer? p.id = some p)
    (hr : p.relayTxes = true) (hf : p.feeOk q = true) (hb : q.id ∉ p.filtered)
    (hk : q.id ∉ p.known) :
    ∃ k items, (((fun u : Node => (u.flush p.id).1)^[k] t.propagate).flush p.id).2 =
      [(p.id, .inv items)] ∧ txItem q.id ∈ items := by
  have e := peer?_map t (·.addTxns t.queue) (fun r => (Ext.addTxns_peer r t.queue).2) p.id
  have hpr : t.propagate.peer? (p.addTxns t.queue).id = some (p.addTxns t.queue) := by
    rw [(Ext.addTxns_peer p t.queue).2]
    rw [show t.propagate.peer? p.id = ({ t with peers := t.peers.map (·.addTxns t.queue) } : Node).peer? p.id
      from rfl, e, hp]; rfl
  have hin : q.id ∈ (p.addTxns t.queue).pending := by
    unfold Peer.addTxns
    simp only [hr, Bool.not_true, Bool.false_eq_true, ite_false]
    exact foldl_addOne_mem _ _ _ hq hf hb (Or.inl hk)
  have := queued_announced_within t.propagate (p.addTxns t.queue) hpr hmax q.id hin
  rw [(Ext.addTxns_peer p t.queue).2] at this
  exact this

/-- [D] 2026-10-15: THE ANNOUNCEMENT, A PEER'S `tx`, UNDER ANY LOAD. A
transaction the node accepts from a peer (not known before, not in
blocks-only mode for the sender, not a miner-info data transaction) is
announced to each other peer that relays transactions, passes its filters and
is not known to have it, in the `inv` of one of that peer's flushes after the
propagator's pass, whatever was queued before
(src/net/net_processing.cpp:3351-3393,5536-5674; src/validation.cpp:2097-2116;
src/net/net.cpp:836-878). A view, never a rule. -/
theorem accepted_announced_within (s : Node) (src : PeerId) (ps : Peer)
    (hsrc : s.peer? src = some ps) (hign : s.ignoresTxFrom ps = false) (q : Queued)
    (hnew : s.knows q.id = false) (hdr : q.id ∉ s.datarefs)
    (hmax : 0 < s.cfg.broadcastMax) (p : Peer) (hp : s.peer? p.id = some p) (hne : p.id ≠ src)
    (hr : p.relayTxes = true) (hf : p.feeOk q = true) (hb : q.id ∉ p.filtered)
    (hk : q.id ∉ p.known) :
    ∃ k items, (((fun u : Node => (u.flush p.id).1)^[k] (s.recvTx src q .accepted).1.propagate).flush
      p.id).2 = [(p.id, .inv items)] ∧ txItem q.id ∈ items := by
  apply propagate_announced_within _ q _ _ p _ hr hf hb hk
  · simp only [Node.recvTx, hsrc, hign, Bool.false_eq_true, ite_false]
    rw [show ((s.addKnown src q.id).updPeer src _).knows q.id = s.knows q.id from rfl, hnew]
    simp [Node.enqueue, Node.updPeer, Node.addKnown, hdr]
  · simp only [Node.recvTx, hsrc, hign, Bool.false_eq_true, ite_false]
    rw [show ((s.addKnown src q.id).updPeer src _).knows q.id = s.knows q.id from rfl, hnew]
    simp only [Bool.false_eq_true, ite_false]
    rw [enqueue_cfg]
    exact hmax
  · simp only [Node.recvTx, hsrc, hign, Bool.false_eq_true, ite_false]
    rw [show ((s.addKnown src q.id).updPeer src _).knows q.id = s.knows q.id from rfl, hnew]
    simp only [Bool.false_eq_true, ite_false]
    have e1 : (s.addKnown src q.id).peer? p.id = s.peer? p.id :=
      peer?_updPeer_ne _ _ _ _ (fun _ => rfl) hne
    have e2 : ((s.addKnown src q.id).updPeer src (fun p =>
        { p with requested := p.requested.filter (· != q.id),
                 inFlight := p.inFlight.filter (· != q.id) })).peer? p.id =
        (s.addKnown src q.id).peer? p.id :=
      peer?_updPeer_ne _ _ _ _ (fun _ => rfl) hne
    rw [peer?_of_peers _ ((s.addKnown src q.id).updPeer src (fun p =>
        { p with requested := p.requested.filter (· != q.id),
                 inFlight := p.inFlight.filter (· != q.id) })) _ (by simp), e2, e1, hp]

/-- [D] 2026-10-15: THE ANNOUNCEMENT, THE RPC'S ACCEPTANCE, UNDER ANY LOAD.
A transaction `sendrawtransaction` accepts (not a miner-info data
transaction) is announced to each peer that relays transactions, passes its
filters and is not known to have it, in the `inv` of one of that peer's
flushes after the propagator's pass (src/rpc/rawtransaction.cpp:1682;
src/net/net.cpp:3574-3582,836-878; src/net/net_processing.cpp:5536-5674). A
view, never a rule. -/
theorem rpcAccepted_announced_within (s : Node) (q : Queued) (hdr : q.id ∉ s.datarefs)
    (hmax : 0 < s.cfg.broadcastMax) (p : Peer) (hp : s.peer? p.id = some p)
    (hr : p.relayTxes = true) (hf : p.feeOk q = true) (hb : q.id ∉ p.filtered)
    (hk : q.id ∉ p.known) :
    ∃ k items, (((fun u : Node => (u.flush p.id).1)^[k] (s.rpcAccepted q).propagate).flush
      p.id).2 = [(p.id, .inv items)] ∧ txItem q.id ∈ items := by
  apply propagate_announced_within _ q _ _ p _ hr hf hb hk
  · simp [Node.rpcAccepted, Node.enqueue, hdr]
  · simpa [Node.rpcAccepted] using hmax
  · rw [peer?_of_peers _ s _ (by simp [Node.rpcAccepted]), hp]

/-- [D] 2026-10-15: THE ANNOUNCEMENT, AN ORPHAN ACCEPTED ON RETRY, UNDER ANY
LOAD. An orphan retried after its parents arrived and accepted (not a
miner-info data transaction) is announced to each peer that relays
transactions, passes its filters and is not known to have it, in the `inv` of
one of that peer's flushes after the propagator's pass
(src/txn_validator.cpp:695-720; src/validation.cpp:1859-1865,2109-2116;
src/net/net_processing.cpp:975-997; src/net/net.cpp:3574-3582,836-878;
src/net/net_processing.cpp:5536-5674). A
view, never a rule. -/
theorem retryOrphan_announced_within (s : Node) (q : Queued)
    (o : Bytes × PeerId × List Bytes) (ho : s.orphans.find? (·.1 = q.id) = some o)
    (hdr : q.id ∉ s.datarefs) (hmax : 0 < s.cfg.broadcastMax)
    (p : Peer) (hp : s.peer? p.id = some p) (hr : p.relayTxes = true) (hf : p.feeOk q = true)
    (hb : q.id ∉ p.filtered) (hk : q.id ∉ p.known) :
    ∃ k items, (((fun u : Node => (u.flush p.id).1)^[k] (s.retryOrphan q .accepted).1.propagate).flush
      p.id).2 = [(p.id, .inv items)] ∧ txItem q.id ∈ items := by
  obtain ⟨oid, opid, ops⟩ := o
  apply propagate_announced_within _ q _ _ p _ hr hf hb hk
  · simp [Node.retryOrphan, ho, Node.enqueue, hdr]
  · simpa [Node.retryOrphan, ho] using hmax
  · rw [peer?_of_peers _ s _ (by simp [Node.retryOrphan, ho]), hp]

/-! ## 3. The initial block download and the wire's reject codes -/

/-- [D] 2026-10-15: a peer change that keeps the request queues keeps them. -/
theorem updPeer_requested (s : Node) (pid : PeerId) (f : Peer → Peer)
    (hf : ∀ p, (f p).requested = p.requested) :
    (s.updPeer pid f).peers.map (·.requested) = s.peers.map (·.requested) := by
  simp only [Node.updPeer, List.map_map]
  apply List.map_congr_left
  intro p _
  simp only [Function.comp_apply]
  split <;> simp [hf]

/-- [D] 2026-10-15: one `inv` item during the initial block download asks for
nothing and leaves the latch set. -/
theorem invItem_ibd (p : Peer) (pid : PeerId) (t : Node) (i : InvItem) (ht : t.ibd = true) :
    (t.invItem p pid i).peers.map (·.requested) = t.peers.map (·.requested) ∧
      (t.invItem p pid i).askedFor = t.askedFor ∧ (t.invItem p pid i).ibd = true := by
  have hk : (t.addKnown pid i.hash).peers.map (·.requested) = t.peers.map (·.requested) :=
    updPeer_requested _ _ _ (fun _ => rfl)
  unfold Node.invItem
  dsimp only
  split
  · have hib : (t.addKnown pid i.hash).ibd = true := ht
    split
    · exact ⟨hk, rfl, ht⟩
    · split
      · rename_i hc; simp [hib] at hc
      · exact ⟨hk, rfl, ht⟩
  · split
    · exact ⟨rfl, rfl, ht⟩
    · exact ⟨updPeer_requested _ _ _ (fun _ => rfl), rfl, ht⟩

/-- [D] 2026-10-15: THE IBD GATE. During the initial block download an `inv`
draws no request: no peer's request queue changes and nothing is asked for
(src/net/net_processing.cpp:2518-2520). A view, never a rule. -/
theorem ibd_inv_requests_nothing (s : Node) (h : s.ibd = true) (pid : PeerId) (items : List InvItem) :
    (s.recvInv pid items).peers.map (·.requested) = s.peers.map (·.requested) ∧
      (s.recvInv pid items).askedFor = s.askedFor := by
  unfold Node.recvInv
  split
  · exact ⟨rfl, rfl⟩
  · rename_i p _
    suffices ∀ t : Node, t.ibd = true →
        (items.foldl (Node.invItem p pid) t).peers.map (·.requested) = t.peers.map (·.requested) ∧
        (items.foldl (Node.invItem p pid) t).askedFor = t.askedFor ∧
        (items.foldl (Node.invItem p pid) t).ibd = true from
      ⟨(this s h).1, (this s h).2.1⟩
    intro t ht
    induction items generalizing t with
    | nil => exact ⟨rfl, rfl, ht⟩
    | cons i is ih =>
      simp only [List.foldl_cons]
      obtain ⟨e1, e2, e3⟩ := invItem_ibd p pid t i ht
      obtain ⟨a, b, c⟩ := ih _ e3
      exact ⟨a.trans e1, b.trans e2, c⟩

/-- [D] 2026-10-15: the reject message carries only wire codes, above 0 and
below `REJECT_INTERNAL`, with a reason of at most 111 bytes
(src/validation.cpp:1940-1950). -/
theorem rejectFor_on_wire (pid : PeerId) (id : Bytes) (code : Nat) (reason : Bytes) :
    ∀ o ∈ rejectFor pid id code reason, ∀ r, o.2 = .reject r →
      0 < r.code ∧ r.code < rejectInternal ∧ r.reason.length ≤ maxRejectReason := by
  intro o ho r hr
  unfold rejectFor at ho
  split at ho
  · rename_i hc
    simp only [List.mem_singleton] at ho
    subst ho
    simp only [Msg.reject.injEq] at hr
    subst hr
    exact ⟨hc.1, hc.2, by simp⟩
  · simp at ho

/-- [D] 2026-10-15: every message the `tx` transition sends is its reject message. -/
theorem recvTx_out (s : Node) (pid : PeerId) (q : Queued) (v : Verdict) :
    ∀ o ∈ (s.recvTx pid q v).2, ∃ c r, o ∈ rejectFor pid q.id c r := by
  intro o ho
  unfold Node.recvTx at ho
  dsimp only at ho
  repeat' split at ho
  all_goals (try (simp at ho; done))
  all_goals exact ⟨_, _, ho⟩

/-- [D] 2026-10-15: every message an orphan's retry sends is its reject message. -/
theorem retryOrphan_out (s : Node) (q : Queued) (v : Verdict) :
    ∀ o ∈ (s.retryOrphan q v).2, ∃ pid c r, o ∈ rejectFor pid q.id c r := by
  intro o ho
  unfold Node.retryOrphan at ho
  dsimp only at ho
  repeat' split at ho
  all_goals (try (simp at ho; done))
  all_goals exact ⟨_, _, _, ho⟩

/-- [D] 2026-10-15: NEVER ON THE WIRE: no transition sends an internal reject
code (0x100 and above: high fee, already known, conflict, mempool full,
src/validation.h:1150-1163) or a reason over 111 bytes. A view, never a rule. -/
theorem step_rejects_on_wire (s : Node) (e : Event) :
    ∀ o ∈ (s.step e).2, ∀ r, o.2 = .reject r →
      0 < r.code ∧ r.code < rejectInternal ∧ r.reason.length ≤ maxRejectReason := by
  intro o ho r hr
  cases e with
  | recvTx pid q v =>
    obtain ⟨c, rs, hm⟩ := recvTx_out s pid q v o ho
    exact rejectFor_on_wire _ _ _ _ o hm r hr
  | retryOrphan q v =>
    obtain ⟨pid, c, rs, hm⟩ := retryOrphan_out s q v o ho
    exact rejectFor_on_wire _ _ _ _ o hm r hr
  | recvGetData pid items =>
    simp only [Node.step, Node.recvGetData, List.mem_append, List.mem_map] at ho
    rcases ho with ⟨i, _, rfl⟩ | ho
    · simp at hr
    · split at ho <;> simp_all
  | flush pid =>
    simp only [Node.step, Node.flush] at ho
    repeat' split at ho
    all_goals simp_all
  | request pid =>
    simp only [Node.step, Node.request] at ho
    repeat' split at ho
    all_goals simp_all
  | _ => simp [Node.step] at ho

end BsvChain.Wire
