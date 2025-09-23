package cases;

import xml.XmlNode;
import utest.Test;
import utest.Assert;
import utest.Async;
import cases.AssertTools.*;

class TestPositionInfo extends Test {
    function testBasic(async:Async) {
        var xmlString = "<root rootAttr1='rootValue1'>\n<child childAttr1='childValue1' childAttr2='childValue2'>text</child>\n</root>\n";
        var node = XmlNode.fromString(xmlString);

        Assert.equals(1, node.positionInfo.startLine);
        Assert.equals(2, node.positionInfo.startColumn);
        Assert.equals(1, node.positionInfo.endLine);
        Assert.equals(5, node.positionInfo.endColumn);
        Assert.equals(1, node.positionInfo.startOffset);
        Assert.equals(5, node.positionInfo.endOffset);

        Assert.equals(2, node.children[0].positionInfo.startLine);
        Assert.equals(3, node.children[0].positionInfo.startColumn);
        Assert.equals(2, node.children[0].positionInfo.endLine);
        Assert.equals(7, node.children[0].positionInfo.endColumn);
        Assert.equals(31, node.children[0].positionInfo.startOffset);
        Assert.equals(36, node.children[0].positionInfo.endOffset);


        async.done();
    }
}