package xml;

import haxe.io.Bytes;
import haxe.io.Eof;
import haxe.Exception;
import haxe.io.Input;

// ------------------------
// Events
// ------------------------
enum XmlEvent {
    StartElement(name:String, parent:String, depth:Int, position:XmlPositionInfo);
    EndElement(name:String, parent:String, depth:Int, position:XmlPositionInfo);
    TextNode(text:String, parent:String, depth:Int, position:XmlPositionInfo);
    Comment(text:String, parent:String, depth:Int, position:XmlPositionInfo);
    ProcessingInstruction(target:String, data:String, parent:String, depth:Int, position:XmlPositionInfo);
    Attribute(name:String, value:String, parent:String, depth:Int, position:XmlPositionInfo);
}

// ------------------------
// Exception
// ------------------------
class XmlParseException extends Exception {
    public var line:Int;
    public var column:Int;

    public function new(message:String, line:Int, column:Int) {
        super(message);
        this.line = line;
        this.column = column;
    }

    public override function toString():String {
        return 'XmlParseException at $line:$column – $message';
    }
}

inline function error(msg:String, line:Int, column:Int):Void {
    throw new XmlParseException(msg, line, column);
}

// ------------------------
// Internal enums
// ------------------------
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

// ------------------------
// Parser
// ------------------------
class XmlParser {
    public static function parse(input:Input, onEvent:XmlEvent->Void):Void {
        var eof = false;
        var state:State = ParserStart;
        var sb = new XmlStringBuf();

        var nodeName = "";
        var attrName = "";
        var attrValue = "";
        var stack = new Array<String>(); // names of open nodes
        var buffer = Bytes.alloc(4096);

        var line:Int = 1;
        var column:Int = 0;

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
                            if (t == Token.LessThan) {
                                state = NodeStart;
                            } else if (t != Space && t != Tab && t != NewLine && t != LineFeed) {
                                error('Unexpected content outside root element', line, column);
                            }

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
                                    // TODO: comments/PI
                                    state = IgnoreWhitespace(ParserStart);

                                case QuestionMark:
                                    // TODO: PI
                                    state = IgnoreWhitespace(ParserStart);

                                case _:
                                    error('Unexpected token at start of node: ' + String.fromCharCode(c), line, column);
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
                                    if (nodeName == "") {
                                        error('Empty tag name', line, column);
                                    }
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
                                    if (nodeName == "") {
                                        error('Empty self-closing tag name', line, column);
                                    }

                                    var parent = stack.length > 0 ? stack[stack.length - 1] : null;
                                    var depth = stack.length;
                                    onEvent(StartElement(nodeName, parent, depth, {line: line, column: column}));
                                    onEvent(EndElement(nodeName, parent, depth, {line: line, column: column}));

                                    state = IgnoreWhitespace(ParserStart);

                                case _:
                                    error('Unexpected token in tag name: ' + String.fromCharCode(c), line, column);
                            }

                        case NodeAttributes:
                            switch (t) {
                                case Character:
                                    sb.reset();
                                    sb.addChar(c);
                                    state = AttrName;

                                case GreaterThan:
                                    state = NodeText;

                                case ForwardSlash:
                                    var parent = stack.length > 0 ? stack[stack.length - 1] : null;
                                    var depth = stack.length;
                                    onEvent(EndElement(nodeName, parent, depth, {line: line, column: column}));
                                    stack.pop();
                                    state = IgnoreWhitespace(ParserStart);

                                case _:
                                    // ignore whitespace already handled above
                            }

                        case AttrName:
                            switch (t) {
                                case Character:
                                    sb.addChar(c);

                                case Equals:
                                    attrName = sb.toString();
                                    if (attrName == "") {
                                        error('Empty attribute name', line, column);
                                    }
                                    sb.reset();
                                    state = AttrValue(0);

                                case Space | Tab | NewLine | LineFeed:
                                    // ignore

                                case GreaterThan:
                                    error('Attribute "' + sb.toString() + '" missing value', line, column);

                                case _:
                                    error('Unexpected token in attribute name', line, column);
                            }

                        case AttrValue(q):
                            switch (t) {
                                case Quote:
                                    if (q == 0) {
                                        state = AttrValue(c); // opening quote
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
                                    error('Unexpected token in attribute value', line, column);
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
                                    if (stack.length == 0) {
                                        error('Unexpected closing tag </$endName>', line, column);
                                    }
                                    var expected = stack[stack.length - 1];
                                    if (endName != expected) {
                                        error('Mismatched closing tag </$endName>, expected </$expected>', line, column);
                                    }

                                    var parent = stack.length > 1 ? stack[stack.length - 2] : null;
                                    var depth = stack.length - 1;
                                    onEvent(EndElement(endName, parent, depth, {line: line, column: column}));

                                    stack.pop();
                                    state = ParserStart;

                                case _:
                                    error('Unexpected token in closing tag', line, column);
                            }
                    }
                }
            } catch (_:Eof) {
                eof = true;
            }
        }

        // EOF checks
        switch (state) {
            case AttrValue(_):
                error('Unterminated attribute value', line, column);
            case _:
        }

        if (stack.length > 0) {
            error('Unclosed tag: ' + stack[stack.length - 1], line, column);
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
