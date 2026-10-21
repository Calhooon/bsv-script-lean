import Lean.Data.Json

/-! Provenance grammar for the independent node column. It never compares semantics. -/
namespace NodeMetadata

private def nonempty (s : String) : Bool := !s.trimAscii.toString.isEmpty
private def recordPath (s : String) : Bool :=
  s.startsWith "docs/records/" && s.endsWith ".md" &&
  s.length > "docs/records/.md".length &&
  s.toList.all (fun c => c.isAlphanum || c == '/' || c == '-' || c == '_' || c == '.') &&
  (s.splitOn "..").length == 1

private def precheck (s : String) : Bool := Id.run do
  let body := (s.drop "rpc-precheck: ".length).toString
  let code := (body.splitOn " ").head!
  if code.toInt?.isNone then return false
  let rest := (body.drop (code.length + 1)).toString
  match rest.splitOn " (" with
  | [message, location] =>
    if !nonempty message || !location.endsWith ")" then return false
    let source := (location.dropEnd 1).toString
    match source.splitOn ":" with
    | [file, span] =>
      if !file.startsWith "src/" || !file.toList.all (fun c => c.isAlphanum || c == '/' || c == '_' || c == '.') then return false
      match span.splitOn "-" with
      | [lo, hi] => return lo.toNat?.isSome && hi.toNat?.isSome
      | _ => return false
    | _ => return false
  | _ => return false

def valid (s : String) : Bool :=
  s == "pending #66" || match s.splitOn " [X] " with
  | [observation, record] => recordPath record &&
    (observation == "needs-peer #71" ||
      (observation.startsWith "measured " && nonempty (observation.drop "measured ".length).toString) ||
      (observation.startsWith "unrealizable: " && nonempty (observation.drop "unrealizable: ".length).toString) ||
      (observation.startsWith "rpc-precheck: " && precheck observation))
  | _ => false

-- Executed guard checks; these add no theorem or axiom to the semantics.
#eval do
  let cases : List (String × Bool) := [
    ("pending #66", true),
    ("measured agree [X] docs/records/run.md", true),
    ("unrealizable: compiled constant [X] docs/records/run.md", true),
    ("needs-peer #71 [X] docs/records/run.md", true),
    ("rpc-precheck: -22 message (src/rpc/mining.cpp:830-838) [X] docs/records/run.md", true),
    ("unrealizable: unlabelled", false),
    ("agree [X] docs/records/run.md", false),
    ("measured [X] docs/records/run.md", false),
    ("needs-peer #71 [X] docs/records/run.md (reason)", false),
    ("measured agree [X] docs/records/../run.md", false),
    ("rpc-precheck: bad message (src/rpc/mining.cpp:830-838) [X] docs/records/run.md", false)]
  for (token, expected) in cases do
    unless valid token == expected do
      throw (IO.userError s!"node metadata guard mismatch: {token}")
  IO.println s!"node metadata guards: GREEN [X] ([M] {cases.length} valid/malformed cases)"
end NodeMetadata
