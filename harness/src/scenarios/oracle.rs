//! Family-owned realization recipes. Sources and observation boundaries are retained in receipts.
use super::core::*;

fn oracle_run(root: &Path, rows: &[Value]) -> Result<Vec<Value>> {
    let mut results = vec![];
    for (index, row) in rows.iter().enumerate() {
        let p = &row["effective"];
        let extra=format!("maxstackmemoryusageconsensus=0\nmaxstackmemoryusagepolicy={}\nmaxopsperscriptpolicy={}\nmaxpubkeyspermultisigpolicy={}\nmaxscriptnumlengthpolicy={}\nmaxscriptsizepolicy={}\nmaxstdtxvalidationduration=1000\nmaxnonstdtxvalidationduration=2000\n",p["maxStackMemoryUsage"],p["maxOpsPerScript"],p["maxPubKeysPerMultiSig"],p["maxScriptNumLength"],p["maxScriptSize"]);
        let mut n = start_retry(root, &format!("oracle-{index}"), &extra)?;
        let input = row["input"].as_u64().ok_or("oracle input")? as usize;
        let u = row["utxo"].get(input).ok_or("oracle prevout")?;
        // Explicit flags allow height omission at misc.cpp:769-775. This
        // preserves the wrapper's already-resolved era, including inverse calls.
        let request = json!({"tx":row["tx"],"n":input,"flags":p["flags"],"reportflags":true,"txo":{"lock":u["script"],"value":u["value"]}});
        let reply = n.call("verifyscript", json!([[request.clone()], true, 60000]))?;
        let r = &reply[0];
        if r["flags"] != p["flags"] {
            return Err(format!("oracle flag drift for {}: {reply}", row["id"]));
        }
        let observed = match text(&r["result"])? {
            "ok" => json!({"verdict":"valid"}),
            "error" => {
                let description = text(&r["description"])?;
                let code = bsv_script_harness::svnode_codes::code_of(description)
                    .ok_or_else(|| format!("unmapped oracle error: {description}"))?;
                json!({"verdict":"invalid","code":code.code})
            }
            _ => {
                return Err(format!(
                    "non-judging oracle reply for {}: {reply}",
                    row["id"]
                ))
            }
        };
        let expected = row["expect"][text(&row["column"])?].clone();
        n.stop()?;
        results.push(measured(row,observed,expected,"Owned empty-chain verifyscript instance, exact transaction/input/value/locking bytes, effective flag word echoed by reportflags, all five effective resource limits configured. Explicit flags permit txo.height omission, avoiding re-derivation of the wrapper's effective era, including modified-mandatory and inverse calls. This judges the recorded wrapper request, not admission or the wrapper's derivation algorithm.",std::mem::take(&mut n.calls),json!({"request":request,"effective":p,"conf":n.conf})));
    }
    Ok(results)
}

pub(super) fn run(root: &Path) -> Result<Vec<Value>> {
    oracle_run(root, &row_read("oracle")?)
}
