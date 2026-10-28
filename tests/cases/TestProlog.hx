package cases;

import haxe.io.Bytes;
import haxe.io.BytesInput;
import utest.Assert;
import utest.Test;
import xml.XmlNode;
import xml.XmlParser;
import xml.XmlParser.XmlParseException;
import xml.XmlPositionInfo;

class TestProlog extends Test {
    function testBomAndXmlDeclarations() {
        var bodies = [
            "<registers />",
            "\uFEFF<registers />",
            "<?xml version=\"1.0\" encoding=\"utf-8\"?><registers />",
            "\uFEFF<?xml version=\"1.0\" encoding=\"utf-8\"?><registers />",
            "<?xml version = '1.0' encoding = 'UTF-8' standalone = 'yes' ?>\n<registers />",
            "<?xml\nversion='1.0'\nstandalone='no'?>\n<registers />"
        ];
        for (body in bodies) {
            for (trackPositions in [false, true]) {
                var node = XmlNode.fromString(body, trackPositions);
                Assert.equals("registers", node.nodeName);
                Assert.equals(0, node.children.length);
                Assert.equals(trackPositions, node.positionInfo != null);
            }
        }
    }

    function testLiteralBomInTextAndAttributes() {
        for (value in ["\uFEFFHello", "He\uFEFFllo", "Hello\uFEFF", "\uFEFF\uFEFFHello\uFEFF", "\uFEFF"]) {
            var body = '<root first="' + value + '" second="' + value + '"><a>' + value + '</a><b>' + value + '</b></root>';
            var node = XmlNode.fromString(body, false);
            Assert.equals(value, node.attributes.get("first"));
            Assert.equals(value, node.attributes.get("second"));
            Assert.equals(value, node.children[0].nodeValue);
            Assert.equals(value, node.children[1].nodeValue);
        }
    }

    function testNumericBomInTextAndAttributes() {
        var samples = [
            {encoded: "&#xFEFF;", expected: "\uFEFF"},
            {encoded: "&#65279;", expected: "\uFEFF"},
            {encoded: "&#xFEFF;Hello&#65279;", expected: "\uFEFFHello\uFEFF"},
            {encoded: "A&#xFEFF;B&#65279;C", expected: "A\uFEFFB\uFEFFC"},
            {encoded: "&#xFEFF;&#x1F600;&#65279;", expected: "\uFEFF😀\uFEFF"}
        ];
        for (sample in samples) {
            var node = XmlNode.fromString('<root value="' + sample.encoded + '">' + sample.encoded + '</root>', false);
            Assert.equals(sample.expected, node.attributes.get("value"));
            Assert.equals(sample.expected, node.nodeValue);
        }
    }

    function testDocumentBomWithEmbeddedBomAcrossShortReads() {
        var body = "\uFEFF<?xml version='1.0'?><root value='\uFEFF&#xFEFF;'>\uFEFFleft<child/>&#65279;right\uFEFF</root>";
        for (chunkSize in [1, 2, 3, 5, 4096]) {
            var node = XmlNode.parse(new ChunkedBytesInput(Bytes.ofString(body), chunkSize), false);
            Assert.equals("root", node.nodeName);
            Assert.equals("\uFEFF\uFEFF", node.attributes.get("value"));
            Assert.equals("\uFEFFleft\uFEFFright\uFEFF", node.nodeValue);
            Assert.equals(1, node.children.length);

            for (preserveText in [false, true]) {
                var texts:Array<String> = [];
                var attributes = 0;
                XmlParser.parse(new ChunkedBytesInput(Bytes.ofString(body), chunkSize), event -> {
                    switch (event) {
                        case Attribute(name, value, _, _, _):
                            attributes++;
                            Assert.equals("value", name);
                            Assert.equals("\uFEFF\uFEFF", value);
                        case TextNode(text, _, _, _):
                            texts.push(text);
                        case _:
                    }
                }, false, preserveText);
                Assert.equals(1, attributes);
                Assert.same(["\uFEFFleft", "\uFEFFright\uFEFF"], texts);
            }
        }
    }

    function testBomAndInstructionsAcrossShortReads() {
        var body = "\uFEFF<?xml version='1.0' encoding='utf-8'?><?before Grüße?><root><?inside?>tail</root><?after?>";
        for (chunkSize in [1, 2, 3, 5]) {
            var node = XmlNode.parse(new ChunkedBytesInput(Bytes.ofString(body), chunkSize), false);
            Assert.equals("root", node.nodeName);
            Assert.equals("tail", node.nodeValue);

            var instructions = readInstructions(body, chunkSize, false);
            Assert.equals(3, instructions.length);
            Assert.equals("before", instructions[0].target);
            Assert.equals("Grüße", instructions[0].data);
            Assert.equals("inside", instructions[1].target);
            Assert.equals("root", instructions[1].parent);
            Assert.equals(1, instructions[1].depth);
            Assert.equals("after", instructions[2].target);
            Assert.isNull(instructions[2].parent);
            Assert.isNull(instructions[1].position);
        }
    }

    function testProcessingInstructionData() {
        var instructions = readInstructions("<?before a > b &amp; ??><root><?inside raw? data  ?></root><?after?>", 1, false);
        Assert.equals(3, instructions.length);
        Assert.equals("a > b &amp; ?", instructions[0].data);
        Assert.equals("raw? data  ", instructions[1].data);
        Assert.equals("", instructions[2].data);
        Assert.equals(0, instructions[0].depth);
        Assert.equals(0, instructions[2].depth);

        var stylesheet = readInstructions("<?xml-stylesheet href='style.xsl'?><root/>", 1, false);
        Assert.equals("xml-stylesheet", stylesheet[0].target);
        Assert.equals("href='style.xsl'", stylesheet[0].data);
    }

    function testInstructionTerminatorAcrossParserBufferBoundary() {
        // The '?' is byte 4095, with its '>' arriving in the next 4096-byte read.
        var data = StringTools.rpad("", "x", 4090);
        var body = "<?pi " + data + "?><root/>";
        var instructions = readInstructions(body, 4096, true);
        Assert.equals(1, instructions.length);
        Assert.equals("pi", instructions[0].target);
        Assert.equals(data, instructions[0].data);
        Assert.equals(4097, instructions[0].position.endOffset);
    }

    function testDeclarationTerminatorAcrossParserBufferBoundary() {
        var declaration = "<?xml version='1.0'";
        var body = StringTools.rpad(declaration, " ", 4095) + "?><root/>";
        var node = XmlNode.parse(new ChunkedBytesInput(Bytes.ofString(body), 4096), false);
        Assert.equals("root", node.nodeName);
    }

    function testPositionsWithBomAndNestedInstruction() {
        var node = XmlNode.parse(new ChunkedBytesInput(Bytes.ofString("\uFEFF<root/>"), 1), true);
        Assert.equals(4, node.positionInfo.startOffset);
        Assert.equals(8, node.positionInfo.endOffset);
        Assert.equals(1, node.positionInfo.startLine);
        Assert.equals(2, node.positionInfo.startColumn);

        var body = "<root><?inside data?></root>";
        var instructions = readInstructions(body, 1, true);
        Assert.equals(1, instructions.length);
        Assert.equals(6, instructions[0].position.startOffset);
        Assert.equals(body.indexOf("</root>"), instructions[0].position.endOffset);
        Assert.equals(1, instructions[0].position.startLine);
        Assert.equals(7, instructions[0].position.startColumn);
        Assert.equals("root", instructions[0].parent);
        Assert.equals(1, instructions[0].depth);
    }

    function testMalformedDeclarationsAndInstructions() {
        var invalidDeclarations = [
            "<?xml?><root/>",
            "<?xml version=1.0?><root/>",
            "<?xml encoding='utf-8' version='1.0'?><root/>",
            "<?xml version='1.0' standalone='maybe'?><root/>",
            "<?XML version='1.0'?><root/>",
            " <?xml version='1.0'?><root/>",
            "<!--comment--><?xml version='1.0'?><root/>",
            "<?xml version='1.0'?><?xml version='1.0'?><root/>",
            "<root><?xml version='1.0'?></root>"
        ];
        for (body in invalidDeclarations) {
            assertRejected(Bytes.ofString(body), "Invalid XML declaration");
        }
        for (body in ["<? ?><root/>", "<?1target?><root/>", "<?target?x?><root/>"]) {
            assertRejected(Bytes.ofString(body), "Invalid processing instruction target");
        }
        for (body in ["<?target data>", "<?target data?", "<?xml version='1.0'"]) {
            assertRejected(Bytes.ofString(body), "Unterminated processing instruction or XML declaration");
        }
    }

    function testIncompleteInvalidAndMisplacedBom() {
        for (hex in ["ef", "efbb"]) {
            assertRejected(Bytes.ofHex(hex), "Incomplete UTF-8 byte order mark");
        }
        for (hex in ["ef00", "efbb00"]) {
            assertRejected(Bytes.ofHex(hex), "Invalid UTF-8 byte order mark");
        }
        assertRejected(Bytes.ofString(" \uFEFF<root/>"), "Unexpected content outside root element");
    }

    static function readInstructions(body:String, chunkSize:Int, trackPositions:Bool):Array<RecordedInstruction> {
        var instructions:Array<RecordedInstruction> = [];
        XmlParser.parse(new ChunkedBytesInput(Bytes.ofString(body), chunkSize), event -> {
            switch (event) {
                case ProcessingInstruction(target, data, parent, depth, position):
                    instructions.push({target: target, data: data, parent: parent, depth: depth, position: position});
                case _:
            }
        }, trackPositions);
        return instructions;
    }

    static function assertRejected(bytes:Bytes, message:String):Void {
        try {
            XmlNode.parse(new ChunkedBytesInput(bytes, 1), false);
            Assert.fail("Expected rejection: " + message);
        } catch (error:XmlParseException) {
            Assert.equals(message, error.message);
        }
    }
}

private typedef RecordedInstruction = {
    var target:String;
    var data:String;
    var parent:String;
    var depth:Int;
    var position:XmlPositionInfo;
}

private class ChunkedBytesInput extends BytesInput {
    var chunkSize:Int;

    public function new(bytes:Bytes, chunkSize:Int) {
        super(bytes);
        this.chunkSize = chunkSize;
    }

    override public function readBytes(buffer:Bytes, position:Int, length:Int):Int {
        return super.readBytes(buffer, position, length < chunkSize ? length : chunkSize);
    }
}
