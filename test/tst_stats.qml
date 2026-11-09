import QtQuick
import QtTest
import "../lib/Stats.js" as Stats

TestCase {
  name: "Stats"

  function test_cpu() {
    var a = Stats.cpuSample("cpu  100 0 100 700 100 0 0 0 0 0\ncpu0 1 2 3 4\n")
    compare(a.total, 1000)
    compare(a.busy, 200)
    var b = Stats.cpuSample("cpu  150 0 150 750 150 0 0 0 0 0\n")
    // 100 busy of 200 jiffies.
    compare(Stats.cpuUsage(a, b), 0.5)
    compare(Stats.cpuUsage(null, b), -1)
    compare(Stats.cpuUsage(b, b), -1)
    compare(Stats.cpuSample("garbage"), null)
  }

  function test_memory() {
    var m = Stats.memory("MemTotal:       65493420 kB\nMemFree:        10504468 kB\nMemAvailable:   29662908 kB\n")
    compare(m.total, 65493420 * 1024)
    compare(m.used, (65493420 - 29662908) * 1024)
    // An old kernel without MemAvailable: free + buffers + cached.
    var old = Stats.memory("MemTotal: 1000 kB\nMemFree: 100 kB\nBuffers: 100 kB\nCached: 300 kB\n")
    compare(old.used, 500 * 1024)
    compare(Stats.memory(""), null)
  }

  function test_cpuTemp() {
    var intel = '{"iwlwifi_1-virtual-0":{"Adapter":"Virtual device","temp1":{"temp1_input":55.0}},'
      + '"acpitz-acpi-0":{"temp1":{"temp1_input":40.0}},'
      + '"coretemp-isa-0000":{"Adapter":"ISA adapter","Package id 0":{"temp1_input":62.0,"temp1_max":100.0},"Core 0":{"temp2_input":60.0}}}'
    compare(Stats.cpuTemp(intel), 62)
    compare(Stats.cpuTemp('{"k10temp-pci-00c3":{"Tctl":{"temp1_input":48.5}}}'), 48.5)
    compare(Stats.cpuTemp('{"acpitz-acpi-0":{"temp1":{"temp1_input":41.0}}}'), 41)
    verify(isNaN(Stats.cpuTemp('{"nvme-pci-e100":{"Composite":{"temp1_input":43.8}}}')))
    verify(isNaN(Stats.cpuTemp("not json")))
  }

  function test_gpu() {
    var g = Stats.nvidia("7, 48, 111, 6141\n")
    compare(g.busy, 0.07)
    compare(g.temp, 48)
    compare(g.memUsed, 111 * 1048576)
    compare(g.memTotal, 6141 * 1048576)
    var na = Stats.nvidia("[N/A], 40, 10, 100")
    verify(isNaN(na.busy))
    compare(Stats.nvidia(""), null)
    compare(Stats.nvidia("No devices were found"), null)
    compare(Stats.busyPercent("35\n"), 0.35)
    verify(isNaN(Stats.busyPercent("")))
  }

  function test_disk() {
    var btrfs = "Overall:\n    Device size:\t\t     1022042832896\n    Used:\t\t\t      180960047104\n"
      + "    Free (estimated):\t\t      833109315584\t(min: 528258912256)\n"
      + "Data,single: Size:397292863488, Used:173884354560 (43.77%)\n"
    var b = Stats.btrfsUsage(btrfs)
    compare(b.used, 180960047104)
    compare(b.total, 180960047104 + 833109315584)
    compare(Stats.btrfsUsage("ERROR: not a btrfs filesystem: /"), null)
    var d = Stats.dfUsage("Filesystem 1B-blocks Used Available Use% Mounted on\n/dev/mapper/root 1022042832896 181496918016 833108267008  18% /\n")
    compare(d.used, 181496918016)
    compare(d.total, 181496918016 + 833108267008)
    compare(Stats.dfUsage(""), null)
  }

  function test_format() {
    compare(Stats.bytes(512), "512 B")
    compare(Stats.bytes(1536), "1.5 KB")
    compare(Stats.bytes(18.2 * 1073741824), "18.2 GB")
    compare(Stats.bytes(181 * 1073741824), "181 GB")
    compare(Stats.bytePair(12.4 * 1073741824, 62.5 * 1073741824), "12.4 / 62.5 GB")
    compare(Stats.bytePair(169 * 1073741824, 952 * 1073741824), "169 / 952 GB")
    compare(Stats.bytePair(1, 0), "")
    compare(Stats.percent(0.123), "12%")
    compare(Stats.percent(-1), "")
  }
}
