package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// The lens's negative control: a rejected script is not evidence of the named error.
func TestWrongErrorCode(t *testing.T) {
	b, err := os.ReadFile("../../../../corpus/fixtures/go-sdk/script_tests.json")
	if err != nil {
		t.Fatal(err)
	}
	var rows [][]any
	if err := json.Unmarshal(b, &rows); err != nil {
		t.Fatal(err)
	}
	for _, row := range rows {
		if len(row) != 7 || !strings.HasPrefix(row[6].(string), "bsl:seed:seed-000002 ") {
			continue
		}
		path := filepath.Join(t.TempDir(), "script_tests.json")
		for _, expected := range []string{"EVAL_FALSE", "DIV_BY_ZERO", "NOT_AN_ERROR_CODE"} {
			row[5] = expected
			data, err := json.Marshal([][]any{row})
			if err != nil {
				t.Fatal(err)
			}
			if err := os.WriteFile(path, data, 0600); err != nil {
				t.Fatal(err)
			}
			got, err := scriptTests(path, classes{}, map[string]bool{})
			if expected == "NOT_AN_ERROR_CODE" {
				if err == nil {
					t.Fatal("unknown expected error accepted")
				}
			} else if err != nil {
				t.Fatal(err)
			} else if expected == "EVAL_FALSE" && (got.agree != 1 || got.red != 0) {
				t.Fatalf("correct expected error rejected: %+v", got)
			} else if expected == "DIV_BY_ZERO" && (got.agree != 0 || got.red != 1) {
				t.Fatalf("wrong expected error accepted: %+v", got)
			}
		}
		return
	}
	t.Fatal("negative-control fixture absent")
}
