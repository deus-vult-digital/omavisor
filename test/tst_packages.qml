import QtQuick
import QtTest
import "../lib/Packages.js" as Packages
import "../lib/Units.js" as Units
import "../lib/Format.js" as Format

TestCase {
  name: "PackagesUnits"

  function test_repo() {
    compare(Packages.repoCount(0, "linux 6.1-1 -> 6.2-1\nmesa 1-1 -> 2-1\n"), 2)
    // checkupdates: exit 2 is "no updates", exit 1 a failed sync.
    compare(Packages.repoCount(2, ""), 0)
    compare(Packages.repoCount(1, "==> ERROR: Cannot fetch updates"), -1)
    compare(Packages.repoCount(-1, ""), -1)
  }

  function test_aur() {
    compare(Packages.aurCount(0, "foo-bin 1-1 -> 2-1\n"), 1)
    // yay -Qua exits 1 with no output when nothing is out of date.
    compare(Packages.aurCount(1, ""), 0)
    compare(Packages.aurCount(1, ":: Searching AUR for updates...\n"), 0)
    compare(Packages.count(":: Searching AUR for updates...\nwarning: x\n"), 0)
    compare(Packages.aurCount(-1, "foo 1 -> 2"), -1)
    compare(Packages.label(1, "package"), "1 package")
    compare(Packages.label(3, "package"), "3 packages")
  }

  function test_units() {
    var list = Units.parse("omavisor-fail.service loaded failed failed /usr/bin/false\nfoo.timer loaded failed failed Foo timer job\n")
    compare(list.length, 2)
    compare(list[0].unit, "omavisor-fail.service")
    compare(list[0].description, "/usr/bin/false")
    compare(list[1].description, "Foo timer job")
    compare(Units.parse("● bar.service loaded failed failed Bar")[0].unit, "bar.service")
    compare(Units.parse("").length, 0)
    compare(Units.parse("0 loaded units listed.").length, 0)
    compare(Units.journalCommand("a b.service", true, Format.shellQuote), "journalctl -b -e --user-unit 'a b.service'")
    compare(Units.journalCommand("x.service", false, Format.shellQuote), "journalctl -b -e -u 'x.service'")
    compare(Units.key([{ unit: "a" }], []), "a|")
  }
}
