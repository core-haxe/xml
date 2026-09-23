package cases;

import xml.XmlNode;
import utest.Test;
import utest.Assert;
import utest.Async;
import cases.AssertTools.*;

class TestEdgeCases extends Test {
    function testForwardSlashInAttribute(async:Async) {
        var xmlString = "<root rootAttr1='rootValue1'><child childAttr1='this/is/a/path'/></root>";
        var node = XmlNode.fromString(xmlString);
        assertXmlEquals(xmlString, node);
        Assert.equals("this/is/a/path", node.children[0].attributes.get("childAttr1"));

        async.done();
    }

    function testAllowedPunctuationInSingleQuotedAttribute(async:Async) {
        var xmlString = "<root attr='a \"quoted\" value > != ? / - : ; , . [](){} #$%^*+|~`@'/>";
        var node = XmlNode.fromString(xmlString);
        assertXmlEquals(xmlString, node);
        Assert.equals("a \"quoted\" value > != ? / - : ; , . [](){} #$%^*+|~`@", node.attributes.get("attr"));

        async.done();
    }

    function testAllowedPunctuationInDoubleQuotedAttribute(async:Async) {
        var xmlString = "<root attr=\"Bob's value > != ? / - : ; , . [](){} #$%^*+|~`@\"/>";
        var node = XmlNode.fromString(xmlString);
        assertXmlEquals(xmlString, node);
        Assert.equals("Bob's value > != ? / - : ; , . [](){} #$%^*+|~`@", node.attributes.get("attr"));

        async.done();
    }

    function testDecodesStandardEntitiesInAttribute(async:Async) {
        var xmlString = "<root attr=\"a &lt; b &amp;&amp; b &gt; c &quot;quoted&quot; &apos;apostrophe&apos;\"/>";
        var node = XmlNode.fromString(xmlString);
        assertXmlEquals(xmlString, node);
        Assert.equals("a < b && b > c \"quoted\" 'apostrophe'", node.attributes.get("attr"));

        async.done();
    }

    function testDecodesNumericEntitiesInAttribute(async:Async) {
        var xmlString = "<root attr=\"&#60;&#x3C;&#62;&#x3E;\"/>";
        var node = XmlNode.fromString(xmlString);
        assertXmlEquals(xmlString, node);
        Assert.equals("<<>>", node.attributes.get("attr"));

        async.done();
    }

    function testDecodesEntitiesInText(async:Async) {
        var xmlString = "<root>Tom &amp; Jerry &lt;tag&gt;</root>";
        var node = XmlNode.fromString(xmlString);
        assertXmlEquals(xmlString, node);
        Assert.equals("Tom & Jerry <tag>", node.nodeValue);

        async.done();
    }

    function testAllowsRawLessThanInQuotedAttribute(async:Async) {
        var xmlString = "<root attr=\"if (item.age < 99) item.age += 5\"/>";
        var node = XmlNode.fromString(xmlString);
        Assert.equals("if (item.age < 99) item.age += 5", node.attributes.get("attr"));

        async.done();
    }

    function testLiteralUnicodeInAttributesAndText(async:Async) {
        var expected = "météo · € 漢 😀";
        var node = XmlNode.fromString('<root value="météo · € 漢 😀">météo · € 漢 😀</root>');
        Assert.equals(expected, node.attributes.get("value"));
        Assert.equals(expected, node.nodeValue);

        async.done();
    }

    function testDecimalUnicodeEntitiesInAttributesAndText(async:Async) {
        var expected = "météo · € 漢 😀";
        var encoded = "m&#233;t&#233;o &#183; &#8364; &#28450; &#128512;";
        var node = XmlNode.fromString('<root value="' + encoded + '">' + encoded + '</root>');
        Assert.equals(expected, node.attributes.get("value"));
        Assert.equals(expected, node.nodeValue);

        async.done();
    }

    function testHexUnicodeEntitiesInAttributesAndText(async:Async) {
        var expected = "météo · € 漢 😀";
        var encoded = "m&#xE9;t&#xE9;o &#xB7; &#x20AC; &#x6F22; &#x1F600;";
        var node = XmlNode.fromString('<root value="' + encoded + '">' + encoded + '</root>');
        Assert.equals(expected, node.attributes.get("value"));
        Assert.equals(expected, node.nodeValue);

        async.done();
    }

    function testUtf8TextAcrossReadBoundary(async:Async) {
        var prefix = "<root>";
        var padding = StringTools.lpad("", "a", 4095 - prefix.length);
        var expected = padding + "é";
        var node = XmlNode.fromString(prefix + expected + "</root>");
        Assert.equals(expected, node.nodeValue);

        async.done();
    }

    function testUtf8AttributeAcrossReadBoundary(async:Async) {
        var prefix = '<root value="';
        var padding = StringTools.lpad("", "a", 4095 - prefix.length);
        var expected = padding + "é";
        var node = XmlNode.fromString(prefix + expected + '"/>');
        Assert.equals(expected, node.attributes.get("value"));

        async.done();
    }
}
