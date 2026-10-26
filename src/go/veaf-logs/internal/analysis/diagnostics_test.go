package analysis

import (
	"os"
	"strings"
	"testing"
	"time"
)

// Every field of the contract is answered, by a value or by Unknown, and the
// block holds them in order. VEAF_LOGS_PRINT_DOCTOR=1 prints it, to compare
// with `veaf-tools doctor` on the same machine.
func TestCollectDoctorAnswersEveryField(t *testing.T) {
	if os.Getenv("VEAF_LOGS_PRINT_DOCTOR") == "" {
		t.Setenv("VEAF_HOME", t.TempDir()) // off the user's own VEAF home unless asked to compare
	}
	d := CollectDoctor(MachineRedactor(), time.Now())
	for _, name := range fieldOrder {
		if d.Fields[name] == "" {
			t.Errorf("%s: empty", name)
		}
	}
	block := d.Block()
	last := -1
	for _, name := range fieldOrder {
		at := strings.Index(block, "\n"+name+": ")
		if at < last {
			t.Errorf("%s out of order", name)
		}
		last = at
	}
	if os.Getenv("VEAF_LOGS_PRINT_DOCTOR") != "" {
		t.Log("\n" + block)
	}
}

// From inside a checkout, the Lua modules of src/scripts/veaf are counted, as
// the Python's live scan does; a shipped executable finds none.
func TestLuaModulesAreCountedFromACheckout(t *testing.T) {
	n := luaModuleCount(".")
	t.Logf("%d modules", n)
	if n == 0 {
		t.Fatal("no Lua module found above the package, inside the repository")
	}
	if n := luaModuleCount(t.TempDir()); n != 0 {
		t.Fatalf("%d modules found outside any checkout", n)
	}
}
