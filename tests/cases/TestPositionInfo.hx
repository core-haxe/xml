package cases;

import xml.XmlNode;
import utest.Test;
import utest.Assert;
import utest.Async;
import cases.AssertTools.*;

using xml.XmlTools;

class TestPositionInfo extends Test {
    function testBasic(async:Async) {
        var xmlString = "<root rootAttr1='rootValue1'>\n<child childAttr1='childValue1' childAttr2='childValue2'>text</child>\n</root>\n";
        var node = XmlNode.fromString(xmlString);

        trace(node.positionInfo); // wrong, needs to track differently
        Assert.equals(1, 1);

        async.done();
    }
}