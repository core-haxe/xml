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
}
