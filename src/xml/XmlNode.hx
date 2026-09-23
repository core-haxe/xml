package xml;

import haxe.io.StringInput;
import haxe.io.Input;

class XmlNode {
    public var parent:XmlNode = null;
    public var children:Array<XmlNode> = [];
    public var attributes:Map<String, String> = [];
    public var attributePositions:Map<String, XmlPositionInfo> = null;

    public var nodeName:String;
    public var nodeValue:String;

    public var positionInfo:XmlPositionInfo = null;

    public function new(nodeName:String, trackPositions:Null<Bool> = null) {
        this.nodeName = nodeName;
        if (XmlParser.resolveTrackPositions(trackPositions)) {
            this.attributePositions = [];
        }
    }

    public static function fromString(s:String, trackPositions:Null<Bool> = null):XmlNode {
        #if js
        if (js.Syntax.code("typeof TextEncoder !== 'undefined'")) {
            var encoded = new js.html.TextEncoder().encode(s);
            var bytes = haxe.io.Bytes.ofData(encoded.buffer);
            return parse(new haxe.io.BytesInput(bytes), trackPositions);
        }
        #end

        return parse(new StringInput(s), trackPositions);
    }

    public static function parse(input:Input, trackPositions:Null<Bool> = null):XmlNode {
        var positionsEnabled:Bool = XmlParser.resolveTrackPositions(trackPositions);
        var currentElement:XmlNode = null;

        XmlParser.parse(input, (e) -> {
            switch (e) {
                case StartElement(name, parent, depth, position):
                    var element = new XmlNode(name, positionsEnabled);
                    element.positionInfo = position;
                    element.parent = currentElement;
                    if (element.parent != null) {
                        if (element.parent.children == null) {
                            element.parent.children = [];
                        }
                        element.parent.children.push(element);
                    }
                    currentElement = element;
                case EndElement(name, parent, depth, position):    
                    if (currentElement.parent != null) {
                        currentElement = currentElement.parent;
                    }
                case Attribute(name, value, parent, depth, position):    
                    if (currentElement.attributes == null) {
                        currentElement.attributes = [];
                    }
                    currentElement.attributes.set(name, value);
                    if (currentElement.attributePositions != null && position != null) {
                        currentElement.attributePositions.set(name, position);
                    }                    
                case TextNode(text, parent, depth, position):    
                    currentElement.nodeValue = text;
                case StartComment(parent, depth, position):
                case EndComment(parent, depth, position):
                case ProcessingInstruction(target, data, parent, depth, position):    
            }
        }, positionsEnabled);

        return currentElement;
    }

    public function toString(prettyPrint:Bool = false):String {
        var sb = new StringBuf();
        stringifyNodes(sb, prettyPrint, "");
        return sb.toString();
    }

    private function stringifyNodes(sb:StringBuf, prettyPrint:Bool, indent:String) {
        if (prettyPrint) {
            sb.add(indent);
        }
        sb.add("<");
        sb.add(nodeName);
        if (attributes != null) {
            sb.add(" ");
            var count = 0;
            for (key in attributes.keys()) {
                count++;
            }
            var n = 0;
            for (key in attributes.keys()) {
                var value = attributes.get(key);
                sb.add(key);
                sb.add("=\"");
                sb.add(value);
                sb.add("\"");
                if (n != count - 1) {
                    sb.add(" ");
                }
                n++;
            }
        }
        if ((children == null || children.length == 0) && nodeValue == null) {
            sb.add("/>");
        } else {
            sb.add(">");
            if (prettyPrint) {
                sb.add("\n");
            }
            if (nodeValue != null) {
                sb.add(nodeValue);
            }
            if (children != null) {
                var n = 0;
                for (child in children) {
                    var newIndent = indent;
                    if (prettyPrint) {
                        newIndent += "    ";
                    }
                    child.stringifyNodes(sb, prettyPrint, newIndent);
                    if (prettyPrint && n != children.length - 1) {
                        sb.add("\n");
                    }
                    n++;
                }
            }
            if (prettyPrint) {
                sb.add("\n");
                sb.add(indent);
            }
            sb.add("</");
            sb.add(nodeName);
            sb.add(">");
        }
    }
}