//! The crate facts the runners rely on, pinned beside the crate's version (bsv-script-lean #40's post-close
//! ask from #20/#24, carried to #31): a later bsv-rs that models pre-Genesis coins or the coin's own era changes
//! what `engine.rs`'s `word_for` must do, so the facts are asserted here at 0.4.4 (`src/script/flags.rs` at
//! 0.4.4, the crates.io copy of `5c15528`, 872 lines; each range below the same code as at `v0.3.30` = `c7ff2c3` (866 lines),
//! moved by 0.3.31's doc comments: `ProtocolEra::at_height` 102–110, `mainnet` 113–119, `ScriptFlags::per_input`
//! 300–306, `block` 319–333, `standard` 348–350; since 0.3.28 the script-number length limit under a word,
//! `MAX_SCRIPT_NUM_LENGTH_AFTER_GENESIS` 52, `MAX_SCRIPT_NUM_LENGTH_AFTER_CHRONICLE` 55,
//! `DEFAULT_SCRIPT_NUM_LENGTH_POLICY` 58, `is_mempool_word` 367, `max_script_num_length` 381–392; at `v0.3.30` 100–108, 111–117,
//! 298–304, 317–331, 346–348, 365 and 379–390; at `v0.3.29` = `da186ce` and `v0.3.28` = `a97b9b6` the same code) and run by
//! `make check-pins` (`tools/check_pins.py`, the site "bsv-rs crate facts"). The ranges were 76–89, 91–97,
//! 297–311, 326–328 at `v0.3.27` (`82059b8`). A failure here is a pin drift, never a verdict.
use bsv_rs::script::{ProtocolEra, ScriptFlags};

#[test]
fn protocol_era_is_none_below_genesis_and_named_above() {
    // flags.rs:102–110 (at 0.4.4; the same code as 100–108 at v0.3.30 and 90–98 at v0.3.29 and v0.3.28): `None` below the Genesis height; PostGenesis to the Chronicle height; PostChronicle from it
    assert_eq!(
        ProtocolEra::mainnet(620_537),
        None,
        "a pre-Genesis block has no era in the crate"
    );
    assert_eq!(
        ProtocolEra::mainnet(620_538),
        Some(ProtocolEra::PostGenesis)
    );
    assert_eq!(
        ProtocolEra::mainnet(943_815),
        Some(ProtocolEra::PostGenesis)
    );
    assert_eq!(
        ProtocolEra::mainnet(943_816),
        Some(ProtocolEra::PostChronicle)
    );
    assert_eq!(ProtocolEra::mainnet(0), None);
    assert_eq!(ProtocolEra::at_height(5, 10, 20), None);
    assert_eq!(
        ProtocolEra::at_height(10, 10, 20),
        Some(ProtocolEra::PostGenesis)
    );
    assert_eq!(
        ProtocolEra::at_height(20, 10, 20),
        Some(ProtocolEra::PostChronicle)
    );
}

#[test]
fn block_and_standard_words_carry_both_utxo_markers_from_the_block_era() {
    // flags.rs:319–333 / 348–350 (at 0.4.4; the same code as 317–331 / 346–348 at v0.3.30 and 307–321 / 336–338 at v0.3.29 and v0.3.28): the word's UTXO markers come from the BLOCK's era (`per_input(era)`), never
    // from the coin's height: a post-Chronicle block word sets both markers, a post-Genesis one the Genesis
    // marker alone. The reference derives them per input from the coin's height (`policy.h:226–245`); the
    // runner therefore reports a pre-Genesis coin as not applicable (`engine.rs` `word_for`).
    let pc = ScriptFlags::block(ProtocolEra::PostChronicle);
    assert!(
        pc.contains(ScriptFlags::UTXO_AFTER_GENESIS)
            && pc.contains(ScriptFlags::UTXO_AFTER_CHRONICLE)
    );
    assert_eq!(
        pc.bits(),
        0x003D_462F,
        "the post-Chronicle block word of Params.derive at the default heights"
    );
    let pg = ScriptFlags::block(ProtocolEra::PostGenesis);
    assert!(
        pg.contains(ScriptFlags::UTXO_AFTER_GENESIS)
            && !pg.contains(ScriptFlags::UTXO_AFTER_CHRONICLE)
    );
    assert!(!pg.contains(ScriptFlags::CHRONICLE));
    let sc = ScriptFlags::standard(ProtocolEra::PostChronicle);
    assert!(
        sc.contains(ScriptFlags::UTXO_AFTER_GENESIS)
            && sc.contains(ScriptFlags::UTXO_AFTER_CHRONICLE)
    );
    assert_eq!(
        sc.bits(),
        0x003D_47FF,
        "the post-Chronicle relay word of Params.derive at the default heights"
    );
    let sg = ScriptFlags::standard(ProtocolEra::PostGenesis);
    assert!(
        sg.contains(ScriptFlags::UTXO_AFTER_GENESIS)
            && !sg.contains(ScriptFlags::UTXO_AFTER_CHRONICLE)
    );
}

#[test]
fn the_script_number_length_limit_is_the_reference_number_of_the_coin_era_and_the_path() {
    // flags.rs:52–58, 367–392 (at 0.4.4; the same code as 52–58, 365–390 at v0.3.30 and 52–58, 355–380 at v0.3.29 and v0.3.28; bsv-rs#17, the spec's #20 Finding, eras-00041): under a block word the
    // limit is the coin's era's consensus width (`consensus.h:64`, `:66`), the Chronicle marker deciding it (the
    // runner's `word_for` sets it from the COIN's era); under a mempool word (the four standard-only bits present,
    // `is_mempool_word`) the node's `-maxscriptnumlengthpolicy`, 10,000 by default (`policy.h:156`), 0 = the
    // consensus limit. The pre-Genesis width of 4 bytes has no word in the crate (`ScriptFlags::check`).
    let block_g = ScriptFlags::block(ProtocolEra::PostGenesis);
    let block_c = ScriptFlags::block(ProtocolEra::PostChronicle);
    let std_c = ScriptFlags::standard(ProtocolEra::PostChronicle);
    assert!(!block_g.is_mempool_word() && !block_c.is_mempool_word() && std_c.is_mempool_word());
    assert_eq!(
        block_g.max_script_num_length(false, 10_000),
        750_000,
        "a post-Genesis coin on the block path"
    );
    assert_eq!(
        block_c.max_script_num_length(true, 10_000),
        32_000_000,
        "a post-Chronicle coin on the block path"
    );
    assert_eq!(block_c.without(ScriptFlags::UTXO_AFTER_CHRONICLE).max_script_num_length(false, 10_000), 750_000,
               "the block word of a post-Chronicle spend of a post-Genesis coin: the coin's width (eras-00041)");
    assert_eq!(
        std_c.max_script_num_length(true, 10_000),
        10_000,
        "the mempool path: the policy default"
    );
    assert_eq!(std_c.max_script_num_length(false, 10_000), 10_000);
    assert_eq!(
        std_c.max_script_num_length(true, 0),
        32_000_000,
        "0 selects the consensus limit"
    );
    assert_eq!(
        bsv_rs::script::flags::DEFAULT_SCRIPT_NUM_LENGTH_POLICY,
        10_000
    );
}
