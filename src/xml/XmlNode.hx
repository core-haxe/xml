package xml;

import haxe.io.StringInput;
import haxe.io.Input;

class XmlNode {
    public var parent:XmlNode = null;
    public var children:Array<XmlNode> = [];
    public var attributes:Map<String, String> = [];
    public var attributePositions:Map<String, XmlPositionInfo> = null;

    public var nodeName:String;
    // Direct text only; text inside child elements belongs to those elements.
    public var nodeValue(get, set):String;
    private var textValue:String = null;

    // Allocated only when a node needs to retain multiple text/element segments.
    // Plain leaves and element-only nodes without whitespace keep the compact representation.
    public var content(default, null):Array<XmlContent> = null;

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
        var root:XmlNode = null;

        XmlParser.parse(input, (e) -> {
            switch (e) {
                case StartElement(name, parent, depth, position):
                    var element = new XmlNode(name, positionsEnabled);
                    element.positionInfo = position;
                    element.parent = currentElement;
                    if (element.parent != null) {
                        element.parent.appendChild(element);
                    } else if (root == null) root = element;
                    currentElement = element;
                case EndElement(name, parent, depth, position):    
                    currentElement.finishText();
                    currentElement = currentElement.parent;
                case Attribute(name, value, parent, depth, position):    
                    if (currentElement.attributes == null) {
                        currentElement.attributes = [];
                    }
                    currentElement.attributes.set(name, value);
                    if (currentElement.attributePositions != null && position != null) {
                        currentElement.attributePositions.set(name, position);
                    }                    
                case TextNode(text, parent, depth, position):    
                    currentElement.appendText(text);
                case StartComment(parent, depth, position):
                case EndComment(parent, depth, position):
                case ProcessingInstruction(target, data, parent, depth, position):    
            }
        }, positionsEnabled, true);

        return root;
    }

    private function get_nodeValue():String {
        if (content == null) return textValue;
        var first:String = null;
        var parts:StringBuf = null;
        for (part in content) switch (part) {
            case Text(text):
                if (first == null) first = text;
                else {
                    if (parts == null) { parts = new StringBuf(); parts.add(first); }
                    parts.add(text);
                }
            case Element(_):
        }
        return parts == null ? first : parts.toString();
    }

    // Explicit assignment restores the legacy "text followed by children" representation.
    private function set_nodeValue(value:String):String {
        content = null;
        textValue = value;
        return value;
    }

    private function ensureContent():Void {
        if (content != null) return;
        content = [];
        if (textValue != null) content.push(XmlContent.Text(textValue));
        for (child in children) content.push(XmlContent.Element(child));
        textValue = null;
    }

    private function appendChild(child:XmlNode):Void {
        if (textValue != null) ensureContent();
        if (content != null) content.push(XmlContent.Element(child));
        children.push(child);
    }

    private function appendText(text:String):Void {
        if (content == null && textValue == null && children.length == 0) textValue = text;
        else {
            ensureContent();
            content.push(XmlContent.Text(text));
        }
    }

    private function finishText():Void {
        if (children.length != 0) return;
        var text = get_nodeValue();
        if (text != null) text = StringTools.trim(text);
        textValue = text == "" ? null : text;
        content = null;
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
                sb.add(StringTools.htmlEscape(value, true));
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
            if (content != null) {
                // Formatting mixed content would insert significant whitespace.
                for (part in content) switch (part) {
                    case Text(text): sb.add(StringTools.htmlEscape(text));
                    case Element(child): child.stringifyNodes(sb, false, "");
                }
            } else {
                if (prettyPrint) {
                    sb.add("\n");
                }
                if (nodeValue != null) {
                    sb.add(StringTools.htmlEscape(nodeValue));
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
            }
            sb.add("</");
            sb.add(nodeName);
            sb.add(">");
        }
    }
}
