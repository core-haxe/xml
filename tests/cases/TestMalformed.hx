package cases;

import xml.XmlParser.XmlParseException;
import xml.XmlNode;
import utest.Test;
import utest.Assert;
import utest.Async;
import cases.AssertTools.*;

class TestMalformed extends Test {
    function test_unclosed_tag(async:Async) {
        var xmlString = "<root>";
        try {
            XmlNode.fromString(xmlString);
            Assert.fail();
        } catch (e:XmlParseException) {
            Assert.equals("Unclosed tag: root", e.message);
            Assert.equals(1, e.line);
            Assert.equals(6, e.column);
            async.done();
        }
    }

    function test_mismatched_tag(async:Async) {
        var xmlString = "<root><child></wrong></root>";
        try {
            XmlNode.fromString(xmlString);
            Assert.fail();
        } catch (e:XmlParseException) {
            Assert.equals("Mismatched closing tag </wrong>, expected </child>", e.message);
            async.done();
        }
    }

    function test_unexpected_closing_tag(async:Async) {
        var xmlString = "</orphan>";
        try {
            XmlNode.fromString(xmlString);
            Assert.fail();
        } catch (e:XmlParseException) {
            Assert.equals("Unexpected closing tag </orphan>", e.message);
            async.done();
        }
    }

    function test_empty_tag_name(async:Async) {
        var xmlString = "<>";
        try {
            XmlNode.fromString(xmlString);
            Assert.fail();
        } catch (e:XmlParseException) {
            Assert.equals("Unexpected token at start of node: >", e.message);
            async.done();
        }
    }

    function test_empty_selfclosing_tag(async:Async) {
        var xmlString = "</>";
        try {
            XmlNode.fromString(xmlString);
            Assert.fail();
        } catch (e:XmlParseException) {
            Assert.equals("Unexpected closing tag </>", e.message);
            async.done();
        }
    }

    function test_attribute_missing_value(async:Async) {
        var xmlString = "<root attr>";
        try {
            XmlNode.fromString(xmlString);
            Assert.fail();
        } catch (e:XmlParseException) {
            Assert.equals('Attribute "attr" missing value', e.message);
            async.done();
        }
    }

    function test_empty_attribute_name(async:Async) {
        var xmlString = "<root =\"value\"/>";
        try {
            XmlNode.fromString(xmlString);
            Assert.fail();
        } catch (e:XmlParseException) {
            Assert.equals("Unexpected token in attribute name", e.message);
            async.done();
        }
    }

    function test_unterminated_attribute_value(async:Async) {
        var xmlString = "<root attr=\"value>";
        try {
            XmlNode.fromString(xmlString);
            Assert.fail();
        } catch (e:XmlParseException) {
            Assert.equals("Unexpected token in attribute value", e.message);
            async.done();
        }
    }

    function test_content_outside_root(async:Async) {
        var xmlString = "hello<root></root>";
        try {
            XmlNode.fromString(xmlString);
            Assert.fail();
        } catch (e:XmlParseException) {
            Assert.equals("Unexpected content outside root element", e.message);
            async.done();
        }
    }

    function test_unexpected_token(async:Async) {
        var xmlString = "<root $>";
        try {
            XmlNode.fromString(xmlString);
            Assert.fail();
        } catch (e:XmlParseException) {
            Assert.equals("Attribute \"$\" missing value", e.message);
            async.done();
        }
    }
}
