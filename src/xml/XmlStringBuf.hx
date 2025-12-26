package xml;

class XmlStringBuf {
    private var buffer:StringBuf;

    public function new():Void {
        buffer = new StringBuf();
    }

	public var length(get, never):Int;
    private function get_length() {
        return buffer.length;
    }

	public function add<T>(x:T):Void {
        buffer.add(x);
    }

	public function addChar(c:Int):Void {
        buffer.addChar(c);
    }

	public function addSub(s:String, pos:Int, ?len:Int):Void {
        buffer.addSub(s, pos, len);
    }

	public function toString():String {
        return buffer.toString();
    }

    public function reset() {
        #if js
        //@:privateAccess buffer.offset = 0;
        buffer = new StringBuf();
        #else
        buffer = new StringBuf();
        #end
    }
}