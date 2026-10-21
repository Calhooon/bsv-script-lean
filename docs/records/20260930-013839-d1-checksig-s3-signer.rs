// Public synthetic signing fixture. Scalar one is a non-secret test constant.
// DER serialization is derived from this repo's ecdsa_vectors.rs, at the pinned
// source restored for issue #31. No wallet key or credential is read.
use bsv_rs::primitives::ec::PrivateKey;

fn hex(data: &[u8]) -> String {
    data.iter().map(|byte| format!("{byte:02x}")).collect()
}

fn der(r: &[u8; 32], s: &[u8; 32]) -> Vec<u8> {
    fn integer(value: &[u8; 32]) -> Vec<u8> {
        let mut body: Vec<u8> = value.iter().copied().skip_while(|byte| *byte == 0).collect();
        if body.is_empty() { body.push(0); }
        if body[0] & 0x80 != 0 { body.insert(0, 0); }
        let mut out = vec![2, body.len() as u8];
        out.extend(body);
        out
    }
    let body = [integer(r), integer(s)].concat();
    let mut out = vec![0x30, body.len() as u8];
    out.extend(body);
    out
}

fn main() {
    let mut public_fixture_scalar = [0u8; 32];
    public_fixture_scalar[31] = 1;
    let key = PrivateKey::from_bytes(&public_fixture_scalar).expect("public fixture scalar");
    let args: Vec<String> = std::env::args().collect();
    if args.len() == 1 {
        println!("{}", hex(&key.public_key().to_compressed()));
        return;
    }
    assert_eq!(args.len(), 2);
    assert_eq!(args[1].len(), 64);
    let mut digest = [0u8; 32];
    for (index, byte) in digest.iter_mut().enumerate() {
        *byte = u8::from_str_radix(&args[1][index * 2..index * 2 + 2], 16).expect("digest hex");
    }
    let signature = key.sign(&digest).expect("synthetic digest signature");
    println!("{}", hex(&der(signature.r(), signature.s())));
}
