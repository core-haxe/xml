package cases.tools;

class MemoryUsage {
    // Runtime-managed memory. Meaning varies slightly by target.
    public var managedBytes(default, null):Null<Float> = null;

    // Node ArrayBuffer storage, separate from its JavaScript heap.
    public var bufferBytes(default, null):Null<Float> = null;

    // Current and lifetime peak resident process memory.
    public var residentBytes(default, null):Null<Float> = null;
    public var peakResidentBytes(default, null):Null<Float> = null;

    // Cumulative allocation bytes, currently available for HashLink.
    public var totalAllocatedBytes(default, null):Null<Float> = null;

    private function new() {}

    public static function snapshot():MemoryUsage {
        var result = new MemoryUsage();

        #if (js && nodejs)
        // Direct access supports newer fields missing from older hxnodejs externs.
        var memory:Dynamic = js.Syntax.code("process.memoryUsage()");

        result.managedBytes = memory.heapUsed;
        result.residentBytes = memory.rss;

        if (memory.arrayBuffers != null) {
            result.bufferBytes = memory.arrayBuffers;
        }

        if (js.Syntax.code("typeof process.resourceUsage === 'function'")) {
            var peakKiB:Float =
                js.Syntax.code("process.resourceUsage().maxRSS");

            if (peakKiB > 0) {
                result.peakResidentBytes = peakKiB * 1024.0;
            }
        }

        #elseif hl
        var stats = hl.Gc.stats();
        result.managedBytes = stats.currentMemory;
        result.totalAllocatedBytes = stats.totalAllocated;

        #elseif cpp
        result.managedBytes =
            cpp.vm.Gc.memInfo64(cpp.vm.Gc.MEM_INFO_CURRENT);

        #elseif neko
        var stats = neko.vm.Gc.stats();
        result.managedBytes = stats.heap * 1.0 - stats.free;
        #end

        return result;
    }

    // Returns false when explicit GC is unavailable.
    // Taking a snapshot never triggers GC automatically.
    public static function collect():Bool {
        #if (js && nodejs)
        if (js.Syntax.code("typeof global.gc !== 'function'")) {
            return false;
        }

        js.Syntax.code("global.gc()");
        return true;

        #elseif hl
        hl.Gc.major();
        return true;

        #elseif cpp
        cpp.vm.Gc.run(true);
        return true;

        #elseif neko
        neko.vm.Gc.run(true);
        return true;

        #else
        return false;
        #end
    }

    public static function delta(before:MemoryUsage, after:MemoryUsage):String {
        return "managed=" + formatDelta(before.managedBytes, after.managedBytes)
            + ", buffers=" + formatDelta(before.bufferBytes, after.bufferBytes)
            + ", resident=" + formatDelta(before.residentBytes, after.residentBytes)
            + ", peakResidentIncrease="
                + formatDelta(before.peakResidentBytes, after.peakResidentBytes)
            + ", allocated="
                + formatDelta(before.totalAllocatedBytes, after.totalAllocatedBytes);
    }

    private static function formatDelta(before:Null<Float>, after:Null<Float>):String {
        if (before == null || after == null) {
            return "n/a";
        }

        var difference = after - before;
        var prefix = difference > 0 ? "+" : "";
        return prefix + formatBytes(difference);
    }

    public static function formatBytes(bytes:Null<Float>):String {
        if (bytes == null) {
            return "n/a";
        }

        return (Math.round(bytes / 1048576.0 * 100) / 100) + " MiB";
    }

    public function toString():String {
        return "managed=" + formatBytes(managedBytes)
            + ", buffers=" + formatBytes(bufferBytes)
            + ", resident=" + formatBytes(residentBytes)
            + ", peakResident=" + formatBytes(peakResidentBytes)
            + ", totalAllocated=" + formatBytes(totalAllocatedBytes);
    }
}