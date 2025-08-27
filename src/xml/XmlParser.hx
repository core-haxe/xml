package xml;

import haxe.io.Bytes;
import haxe.io.Eof;
import haxe.Exception;
import haxe.io.Input;

enum XmlEvent {
    StartElement(name:String, parent:String, depth:Int, position:XmlPositionInfo);
    EndElement(name:String, parent:String, depth:Int, position:XmlPositionInfo);
    TextNode(text:String, parent:String, depth:Int, position:XmlPositionInfo);
    Comment(text:String, parent:String, depth:Int, position:XmlPositionInfo); // not fully wired yet, easy to extend
    ProcessingInstruction(target:String, data:String, parent:String, depth:Int, position:XmlPositionInfo);
    Attribute(name:String, value:String, parent:String, depth:Int, position:XmlPositionInfo);
}

private enum abstract Token(Int) from Int to Int {
    var LessThan:Int;
    var GreaterThan:Int;
    var Equals:Int;
    var Quote:Int;
    var NewLine:Int;
    var LineFeed:Int;
    var Tab:Int;
    var Space:Int;
    var ExclamationMark:Int;
    var QuestionMark:Int;
    var ForwardSlash:Int;
    var Character:Int;
}

private enum State {
    ParserStart;
    NodeStart;
    IgnoreWhitespace(next:State);
    ReadNodeName;
    NodeAttributes;
    AttrName;
    AttrValue(quote:Int);
    NodeText;
    EndNodeName;
}

class XmlParser {
    public static function parse(input:Input, onEvent:XmlEvent->Void):Void {
        var eof = false;
        var state:State = ParserStart;
        var sb = new XmlStringBuf();

        var nodeName = "";
        var attrName = "";
        var attrValue = "";
        /*
        var buffer = input.readAll();
        var n = buffer.length;
        */

        var stack = new Array<String>(); // names of open nodes
        var buffer = Bytes.alloc(4096);

        var line:Int = 1;
        var column:Int = 0;

        var start = Date.now().getTime();
        while (!eof) {
            try {
                var n = input.readBytes(buffer, 0, 4096);

                for (i in 0...n) {
                    var c = Bytes.fastGet(buffer.getData(), i);
                    var t = toToken(c);

                    column++;
                    if (t == NewLine) {
                        line++;
                        column = 1;
                    }
                    
                    switch (state) {
                        case ParserStart:
                            if (t == Token.LessThan) state = NodeStart;

                        case NodeStart:
                            switch (t) {
                                case ForwardSlash: // </tag>
                                    sb.reset();
                                    state = EndNodeName;

                                case Character:
                                    sb.reset();
                                    sb.addChar(c);
                                    state = ReadNodeName;

                                case ExclamationMark:
                                    // TODO: hook up comment/PI support here
                                    state = IgnoreWhitespace(ParserStart);

                                case QuestionMark:
                                    // TODO: hook up comment/PI support here
                                    state = IgnoreWhitespace(ParserStart);

                                case _:
                            }

                        case IgnoreWhitespace(next):
                            switch (t) {
                                case NewLine | LineFeed | Tab | Space:
                                    // skip
                                default:
                                    sb.reset();
                                    sb.addChar(c);
                                    state = next;
                            }

                        case ReadNodeName:
                            switch (t) {
                                case Character:
                                    sb.addChar(c);

                                case Space | Tab | NewLine | LineFeed | GreaterThan:
                                    nodeName = sb.toString();
                                    sb.reset();

                                    var parent = stack.length > 0 ? stack[stack.length - 1] : null;
                                    var depth = stack.length;
                                    onEvent(StartElement(nodeName, parent, depth, {line: line, column: column}));
                                    stack.push(nodeName);

                                    if (t == GreaterThan) {
                                        state = NodeText;
                                    } else {
                                        state = NodeAttributes;
                                    }

                                case ForwardSlash:
                                    nodeName = sb.toString();

                                    var parent = stack.length > 0 ? stack[stack.length - 1] : null;
                                    var depth = stack.length;
                                    onEvent(StartElement(nodeName, parent, depth, {line: line, column: column}));
                                    onEvent(EndElement(nodeName, parent, depth, {line: line, column: column}));
                                    stack.pop();

                                    state = IgnoreWhitespace(ParserStart);

                                case _:
                            }

                        case NodeAttributes:
                            switch (t) {
                                case Character:
                                    sb.reset();
                                    sb.addChar(c);
                                    state = AttrName;

                                case GreaterThan:
                                    /*
                                    var parent = stack.length > 0 ? stack[stack.length - 1] : null;
                                    var depth = stack.length;
                                    onEvent(StartElement(nodeName, parent, depth));

                                    stack.push(nodeName);
                                    */
                                    state = NodeText;

                                case ForwardSlash:
                                    var parent = stack.length > 0 ? stack[stack.length - 1] : null;
                                    var depth = stack.length;
                                    //onEvent(StartElement(nodeName, parent, depth));
                                    onEvent(EndElement(nodeName, parent, depth, {line: line, column: column}));
                                    stack.pop();

                                    state = IgnoreWhitespace(ParserStart);

                                case _:
                            }

                        case AttrName:
                            switch (t) {
                                case Character:
                                    sb.addChar(c);

                                case Equals:
                                    attrName = sb.toString();
                                    sb.reset();
                                    state = AttrValue(0);

                                case Space | Tab | NewLine | LineFeed:
                                    // ignore

                                case _:
                            }

                        case AttrValue(q):
                            switch (t) {
                                case Quote:
                                    if (q == 0) {
                                        // opening quote
                                        state = AttrValue(c);
                                    } else if (q == c) {
                                        // closing quote
                                        attrValue = sb.toString();

                                        var parent = stack.length > 0 ? stack[stack.length - 1] : null;
                                        var depth = stack.length - 1;
                                        onEvent(Attribute(attrName, attrValue, parent, depth, {line: line, column: column}));

                                        sb.reset();
                                        state = NodeAttributes;
                                    } else {
                                        sb.addChar(c);
                                    }

                                case Character | Space | Tab | NewLine:
                                    sb.addChar(c);

                                case _:
                            }

                        case NodeText:
                            if (t == Token.LessThan) {
                                if (sb.length > 0) {
                                    var parent = stack.length > 0 ? stack[stack.length - 1] : null;
                                    var depth = stack.length - 1;
                                    var s = StringTools.trim(sb.toString());
                                    if (s.length > 0) {
                                        onEvent(TextNode(s, parent, depth, {line: line, column: column}));
                                    }

                                    sb.reset();
                                }
                                state = NodeStart;
                            } else {
                                sb.addChar(c);
                            }

                        case EndNodeName:
                            switch (t) {
                                case Character:
                                    sb.addChar(c);

                                case GreaterThan:
                                    var endName = sb.toString();

                                    var parent = stack.length > 0 ? stack[stack.length - 1] : null;
                                    var depth = stack.length - 1;
                                    onEvent(EndElement(endName, parent, depth, {line: line, column: column}));

                                    stack.pop();
                                    state = ParserStart;

                                case _:
                            }
                    }
                }
                //throw new Eof();
            } catch (_:Eof) {
                eof = true;
            }
        }
    }

    private static function toToken(c:Int):Token {
        if (tokenMap == null) {
            initTokenMap();
        }

        if (!tokenMap.exists(c)) {
            return Token.Character;
        }

        return tokenMap.get(c);
    }

    private static var tokenMap:Map<Int, Token>;
    private static function initTokenMap() {
        tokenMap = [];
        tokenMap.set('<'.code, Token.LessThan);
        tokenMap.set('>'.code, Token.GreaterThan);
        tokenMap.set('='.code, Token.Equals);
        tokenMap.set('\"'.code, Token.Quote);
        tokenMap.set('\''.code, Token.Quote);
        tokenMap.set('\n'.code, Token.NewLine);
        tokenMap.set('\r'.code, Token.LineFeed);
        tokenMap.set('\t'.code, Token.Tab);
        tokenMap.set(' '.code, Token.Space);
        tokenMap.set('!'.code, Token.ExclamationMark);
        tokenMap.set('?'.code, Token.QuestionMark);
        tokenMap.set('/'.code, Token.ForwardSlash);
    }
}