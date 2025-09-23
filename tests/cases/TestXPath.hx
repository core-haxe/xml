package cases;

import xml.XmlNode;
import utest.Test;
import utest.Assert;
import utest.Async;
import cases.AssertTools.*;

using xml.XPath;

class TestXPath extends Test {
    function testBasic(async:Async) {
        var xmlString = "<foo><bar id='tim' id2='tom'><baz id='123'><tim>text1</tim></baz><baz id='456'><tim>text2</tim></baz></bar></foo>";
        var node = XmlNode.fromString(xmlString);
        var result = node.xpath("/foo/bar[@id='tim' && @id2='tom']/baz[@id=456]/tim");
        Assert.equals("text2", result[0].nodeValue);

        async.done();
    }

    function testBasic_no_result(async:Async) {
        var xmlString = "<foo><bar id='tim' id2='tom'><baz id='123'><tim>text1</tim></baz><baz id='456'><tim>text2</tim></baz></bar></foo>";
        var node = XmlNode.fromString(xmlString);
        var result = node.xpath("/foo/bar[@id='tim' && @id2='nope']/baz[@id=456]/tim");
        Assert.equals(null, result[0]);

        async.done();
    }
}