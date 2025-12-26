package cases;

import xml.XmlNode;
import utest.Test;
import utest.Assert;
import utest.Async;
import cases.AssertTools.*;

class TestComments extends Test {

    function testSingleComment(async:Async) {
        var xmlString = "
            <root>
                <child1>text1</child1>
                <!--
                <child2>text1</child2>
                -->
                <child3>text1</child3>
            </root>
        ";
        var node = XmlNode.fromString(xmlString);
        assertXmlEquals(xmlString, node);

        async.done();
    }

    function testMultipleComments(async:Async) {
        var xmlString = "
            <root>
                <child1>text1</child1>
                <!--
                <child2>text1</child2>
                -->
                <child3>text1</child3>
                <!--
                <child4>text1</child4>
                -->
                <child5>text1</child5>
            </root>
        ";
        var node = XmlNode.fromString(xmlString);
        assertXmlEquals(xmlString, node);

        async.done();
    }

    function testSingleInlineComment(async:Async) {
        var xmlString = "
            <root>
                <child1>text1</child1>
                <!--<child2>text1</child2>-->
                <child3>text1</child3>
            </root>
        ";
        var node = XmlNode.fromString(xmlString);
        assertXmlEquals(xmlString, node);

        async.done();
    }

    function testMultipleInlineComments(async:Async) {
        var xmlString = "
            <root>
                <child1>text1</child1>
                <!--<child2>text1</child2>-->
                <child3>text1</child3>
                <!--<child4>text1</child4>-->
                <child5>text1</child5>
            </root>
        ";
        var node = XmlNode.fromString(xmlString);
        assertXmlEquals(xmlString, node);

        async.done();
    }

}