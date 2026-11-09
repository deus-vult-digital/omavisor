import QtQuick
import QtTest
import "../lib/System.js" as System

TestCase {
  name: "System"

  function test_updateLabel() {
    compare(System.updateLabel("omarchy 4.0.6-1 -> 4.0.7-1\n"), "4.0.7-1")
    compare(System.updateLabel("omarchy-dev-checkout 3 new commits on origin/dev\n"), "3 commits")
    compare(System.updateLabel("omarchy-dev-checkout 1 new commit on origin/dev"), "1 commit")
    // The package version wins over a commit count.
    compare(System.updateLabel("omarchy-dev-checkout 2 new commits on o/d\nomarchy-dev 1 -> 2"), "2")
    compare(System.updateLabel(""), "Available")
  }

  function test_flags() {
    compare(System.jsonFlag('{"enabled":true,"temperature":4000}', "enabled"), true)
    compare(System.jsonFlag('{"enabled":false,"class":"disabled"}\n', "enabled"), false)
    compare(System.jsonFlag('{"enabled":"yes"}', "enabled"), null)
    compare(System.jsonFlag("garbage", "enabled"), null)
    compare(System.dndFlag("on\n"), true)
    compare(System.dndFlag("off"), false)
    compare(System.dndFlag(""), null)
  }

  function test_pathLine() {
    compare(System.pathLine("/home/u/Videos/screenrecording-1.mp4\n"), "/home/u/Videos/screenrecording-1.mp4")
    compare(System.pathLine("relative.mp4"), "")
    compare(System.pathLine(""), "")
  }
}
