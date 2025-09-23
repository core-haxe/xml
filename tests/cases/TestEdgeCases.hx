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
}
