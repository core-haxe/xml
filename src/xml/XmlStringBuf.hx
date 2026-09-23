package xml;

import haxe.io.Bytes;

class XmlStringBuf {
    private var buffer:Bytes;
    private var byteLength:Int = 0;

    public function new():Void {
        buffer = Bytes.alloc(64);
    }

    public var length(get, never):Int;

    private function get_length():Int {
        return byteLength;
    }

    public function add<T>(x:T):Void {
        var bytes = Bytes.ofString(Std.string(x));
        ensureCapacity(byteLength + bytes.length);
        buffer.blit(byteLength, bytes, 0, bytes.length);
        byteLength += bytes.length;
    }

    // The parser passes an input byte here, not a Unicode code point.
    public function addChar(c:Int):Void {
        ensureCapacity(byteLength + 1);
        buffer.set(byteLength, c);
        byteLength++;
    }

    public function addSub(s:String, pos:Int, ?len:Int):Void {
        add(s.substr(pos, len));
    }

    public function toString():String {
        return buffer.getString(0, byteLength);
    }

    public function reset():Void {
        byteLength = 0;
    }

    private function ensureCapacity(required:Int):Void {
        if (required <= buffer.length) {
            return;
        }

        var capacity = buffer.length * 2;
        if (capacity < required) {
            capacity = required;
        }

        var expanded = Bytes.alloc(capacity);
        expanded.blit(0, buffer, 0, byteLength);
        buffer = expanded;
    }
}