package cases;

import utest.Assert;
import xml.XmlNode;

using StringTools;

class AssertTools {
    public static function assertXmlEquals(expected:String, actual:XmlNode) {
        // we'll haxe std xml to verify the validity (recursively) of the xml
        var xml = Xml.parse(expected).firstElement();
        var same = assertXmlNodes(xml, actual);
        if (same) {
            // just to stop the "no assertions"
            Assert.equals(1, 1);
        }
    }

    private static function assertXmlNodes(xml:Xml, node:XmlNode):Bool {
        // validate name
        if (xml.nodeName != node.nodeName) {
            Assert.fail("node name mismatch");
            return false;
        }

        // validate value
        var nodeValue:String = null;
        if (xml.firstChild() != null && xml.firstChild().nodeType == PCData) {
            nodeValue = xml.firstChild().nodeValue;
        }
        if (nodeValue != null && nodeValue.trim().length == 0) {
            nodeValue = null;
        }
        if (nodeValue != node.nodeValue) {
            Assert.fail('node value mismatch on "${node.nodeName}" ("${nodeValue}" != "${node.nodeValue}")');
            return false;
        }

        // validate attributes
        var attributes:Map<String, String> = [];
        for (attr in xml.attributes()) {
            attributes.set(attr, xml.get(attr));
        }

        if (attributes != null && node.attributes != null)  {
            // first we make sure that everything in node is in attributes
            for (attr in node.attributes.keys()) {
                var value = node.attributes.get(attr);
                if (attributes.get(attr) != value) {
                    Assert.fail('attribute failure 1');
                    return false;
                }
            }

            // no we see if xml has anything that isnt in the node.attributes
            for (attr in attributes.keys()) {
                if (!node.attributes.exists(attr)) {
                    Assert.fail('attribute failure 2');
                    return false;
                }
            }
        } else {
            Assert.fail("attributes mismatch");
        }

        // validate children
        var elements:Array<Xml> = [];
        for (el in xml.elements()) {
            elements.push(el);
        }

        if (elements != null && node.children != null) {
            if (elements.length != node.children.length) {
                Assert.fail("children count mismatch");
            }

            for (i in 0...node.children.length) {
                var childXml = elements[i];
                var childNode = node.children[i];
                var childSame = assertXmlNodes(childXml, childNode);
                if (!childSame) {
                    return false;
                }
            }
        } else {
            Assert.fail("children mismatch");
        }

        return true;
    }
}