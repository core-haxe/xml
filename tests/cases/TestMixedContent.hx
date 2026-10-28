package cases;

import haxe.io.Bytes;
import haxe.io.BytesInput;
import utest.Assert;
import utest.Test;
import xml.XmlContent;
import xml.XmlNode;
import xml.XmlParser;
import xml.XmlParser.XmlParseException;

class TestMixedContent extends Test {
    function testTextBeforeAndAfterChild() {
        var node = XmlNode.fromString("<root>before<child>inside</child>after</root>", false);
        Assert.equals("beforeafter", node.nodeValue);
        Assert.equals("inside", node.children[0].nodeValue);
        Assert.equals(node, node.children[0].parent);
        Assert.same(["text:before", "element:child", "text:after"], describe(node));
        for (pretty in [false, true]) {
            var items = [for (item in Xml.parse(node.toString(pretty)).firstElement()) item];
            Assert.equals(3, items.length);
            Assert.equals("before", items[0].nodeValue);
            Assert.equals("child", items[1].nodeName);
            Assert.equals("after", items[2].nodeValue);
        }
    }

    function testObjectMovedResponse() {
        var node = XmlNode.fromString("<html><head><title>Object moved</title></head><body>\r\n<h2>Object moved to <a href='/target'>here</a>.</h2>\r\n</body></html>", false);
        var heading = node.children[1].children[0];
        Assert.equals("Object moved to .", heading.nodeValue);
        Assert.equals("here", heading.children[0].nodeValue);
        Assert.equals("/target", heading.children[0].attributes.get("href"));
        Assert.same(["text:Object moved to ", "element:a", "text:."], describe(heading));
    }

    function testSpacesAndSelfClosingChildren() {
        var node = XmlNode.fromString("<root> Before <child/> after <last value='x'/> tail </root>", false);
        Assert.equals(" Before  after  tail ", node.nodeValue);
        Assert.same(["text: Before ", "element:child", "text: after ", "element:last", "text: tail "], describe(node));
        Assert.equals("x", node.children[1].attributes.get("value"));

        var between = XmlNode.fromString("<root><a/> <b/></root>", false);
        Assert.equals(" ", between.nodeValue);
        Assert.same(["element:a", "text: ", "element:b"], describe(between));
    }

    function testTextAfterCommentsAndInstructions() {
        var node = XmlNode.fromString("<root> before <!--ignored--> after <?note?> tail </root>", false);
        Assert.equals("before  after  tail", node.nodeValue);
        Assert.isNull(node.content);
    }

    function testLeafTrimmingStillApplies() {
        var node = XmlNode.fromString("<root> prefix <child> \tvalue&#x0D;\n </child> suffix </root>", false);
        Assert.equals(" prefix  suffix ", node.nodeValue);
        Assert.equals("value", node.children[0].nodeValue);
        Assert.isNull(node.children[0].content);
    }

    function testSerializationEscapesDecodedValues() {
        var node = XmlNode.fromString("<root label='&quot;&amp;&lt;'>A &amp; <child/> &lt;B&gt;</root>", false);
        Assert.equals("A &  <B>", node.nodeValue);
        for (pretty in [false, true]) {
            var serialized = Xml.parse(node.toString(pretty)).firstElement();
            Assert.equals("\"&<", serialized.get("label"));
            var items = [for (item in serialized) item];
            Assert.equals("A & ", items[0].nodeValue);
            Assert.equals("child", items[1].nodeName);
            Assert.equals(" <B>", items[2].nodeValue);
        }
    }

    function testShortReads() {
        var body = "<root>Pré <a/> après <b k='v'>été</b> fin<!--x--> !<?note?> ?</root>";
        for (chunkSize in [1, 2, 3, 5, 4096]) {
            var node = XmlNode.parse(new MixedChunkedInput(Bytes.ofString(body), chunkSize), false);
            Assert.equals("Pré  après  fin ! ?", node.nodeValue);
            Assert.equals(2, node.children.length);
            Assert.equals("été", node.children[1].nodeValue);
        }
    }

    function testTextAcrossParserBufferBoundary() {
        var prefix = "<root><child/>";
        var padding = StringTools.rpad("", "x", 4095 - prefix.length);
        var expected = padding + "é tail";
        var node = XmlNode.fromString(prefix + expected + "</root>", false);
        Assert.equals(expected, node.nodeValue);
        Assert.equals(1, node.children.length);
        Assert.equals(2, node.content.length);
    }

    function testCompactNodesAndExplicitValueAssignment() {
        var leaf = XmlNode.fromString("<root> value </root>", false);
        Assert.equals("value", leaf.nodeValue);
        Assert.isNull(leaf.content);
        Assert.isNull(XmlNode.fromString("<root><a/><b/></root>", false).content);

        var mixed = XmlNode.fromString("<root>a<child/>b</root>", false);
        mixed.nodeValue = "replacement";
        Assert.isNull(mixed.content);
        Assert.equals("replacement", mixed.nodeValue);
        Assert.equals(1, mixed.children.length);
    }

    function testSelfClosingTerminatorRequired() {
        for (body in ["<root/", "<root/ >", "<root><child/x></root>"]) {
            var rejected = false;
            try XmlNode.fromString(body, false) catch (_:XmlParseException) rejected = true;
            Assert.isTrue(rejected);
        }
    }

    function testRawTextPositionsAfterChild() {
        var textEvents = 0;
        XmlParser.parse(new MixedChunkedInput(Bytes.ofString("<r><a/> tail</r>"), 1), event -> {
            switch (event) {
                case TextNode(text, parent, depth, position):
                    textEvents++;
                    Assert.equals(" tail", text);
                    Assert.equals("r", parent);
                    Assert.equals(0, depth);
                    Assert.equals(7, position.startOffset);
                    Assert.equals(12, position.endOffset);
                case _:
            }
        }, true, true);
        Assert.equals(1, textEvents);
    }

    static function describe(node:XmlNode):Array<String> {
        var values:Array<String> = [];
        for (part in node.content) switch (part) {
            case Text(text): values.push("text:" + text);
            case Element(child): values.push("element:" + child.nodeName);
        }
        return values;
    }
}

private class MixedChunkedInput extends BytesInput {
    var chunkSize:Int;

    public function new(bytes:Bytes, chunkSize:Int) {
        super(bytes);
        this.chunkSize = chunkSize;
    }

    public override function readBytes(buffer:Bytes, position:Int, length:Int):Int {
        return super.readBytes(buffer, position, length < chunkSize ? length : chunkSize);
    }
}
