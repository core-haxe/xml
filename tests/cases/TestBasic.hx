package cases;

import xml.XmlNode;
import utest.Test;
import utest.Assert;
import utest.Async;
import cases.AssertTools.*;

class TestBasic extends Test {
    function testBasic(async:Async) {
        var xmlString = "<root rootAttr1='rootValue1'><child childAttr1='childValue1' childAttr2='childValue2'>text</child></root>";
        var node = XmlNode.fromString(xmlString);
        assertXmlEquals(xmlString, node);

        async.done();
    }

    function testWhitespace(async:Async) {
        var xmlString = "
            <root rootAttr1='rootValue1'>
                <child childAttr1='childValue1' childAttr2='childValue2'>text</child>
            </root>
        ";
        var node = XmlNode.fromString(xmlString);
        assertXmlEquals(xmlString, node);

        async.done();
    }
}
