import QtQuick
import QtTest
import "../lib/Theme.js" as Theme

TestCase {
  name: "Theme"

  function test_parseList() {
    compare(Theme.parseList("Catppuccin\nOsaka Jade\n\nOsaka Jade\n  Tokyo Night  \n"), ["Catppuccin", "Osaka Jade", "Tokyo Night"])
    compare(Theme.parseList(""), [])
  }

  function test_slug() {
    // The same mapping omarchy-theme-set applies to its argument.
    compare(Theme.slug("Osaka Jade"), "osaka-jade")
    compare(Theme.slug("Retro 82"), "retro-82")
    compare(Theme.slug("<b>Tokyo Night</b>"), "tokyo-night")
    compare(Theme.slug("osaka-jade"), "osaka-jade")
    verify(Theme.same("Osaka Jade", "osaka-jade"))
    verify(!Theme.same("Osaka Jade", "Nord"))
    verify(!Theme.same("", ""))
  }

  function test_parseColors() {
    var c = Theme.parseColors('mode = "dark"\n\naccent = "#509475"\nbackground = "#111c18" # ground\nforeground="#C1C497"\nbad = "red"\nshort = "#123"\n[section]\n')
    compare(c.mode, "dark")
    compare(c.colors.accent, "#509475")
    compare(c.colors.background, "#111c18")
    compare(c.colors.foreground, "#C1C497")
    compare(c.colors.bad, undefined)
    compare(c.colors.short, undefined)
    compare(Theme.swatches(c.colors), ["#111c18", "#C1C497", "#509475"])
  }

  function test_dump_and_cards() {
    var dump = Theme.parseDump(
      "@@omavisor-theme\tosaka-jade\t/t/osaka-jade\t/t/osaka-jade/preview.png\n" +
      'mode = "dark"\nbackground = "#111c18"\nred = "#FF5345"\n' +
      "@@omavisor-theme\tsynthwave\t/u/synthwave\t\n" +
      'mode = "light"\n')
    compare(dump["osaka-jade"].dir, "/t/osaka-jade")
    compare(dump["osaka-jade"].swatches, ["#111c18", "#FF5345"])
    compare(dump["synthwave"].preview, "")
    compare(dump["synthwave"].mode, "light")

    var cards = Theme.cards(["Osaka Jade", "Synthwave", "Nord"], dump, "Osaka Jade")
    compare(cards.length, 3)
    compare(cards[0].preview, "file:///t/osaka-jade/preview.png")
    verify(cards[0].current)
    verify(!cards[1].current)
    compare(cards[1].preview, "")
    // Listed but missing from the dump: still a card.
    compare(cards[2].slug, "nord")
    compare(cards[2].swatches, [])
  }
}
