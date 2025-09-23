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
    public var start:Int;
    public var end:Int;

    public function new(message:String, line:Int, column:Int, start:Int, end:Int) {
        super(message);
        this.line = line;
        this.column = column;
        this.start = start;
        this.end = end;
    }

    public override function toString():String {
        if (start != -1 && end != -1) {
            return 'XmlParseException at $line:$column ($start:$end) – $message'; 
        }
        return 'XmlParseException at $line:$column – $message';
    }
}

inline function error(msg:String, line:Int, column:Int, start:Int = -1, end:Int = -1):Void {
    throw new XmlParseException(msg, line, column, start, end);
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

        // line/column as before
        var line:Int = 1;
        var column:Int = 0;

        // absolute offset across chunks (0-based)
        var absPos:Int = 0;

        // "last char" line/column (used to compute endLine/Column when current char is a terminator)
        var lastLine:Int = line;
        var lastColumn:Int = column;

        // positions for the different token types (initialized to -1)
        var tokenStartPos:Int = -1;
        var tokenStartLine:Int = 1;
        var tokenStartColumn:Int = 0;

        var nameStartPos:Int = -1;
        var nameStartLine:Int = 1;
        var nameStartColumn:Int = 0;

        var attrNameStartPos:Int = -1;
        var attrNameStartLine:Int = 1;
        var attrNameStartColumn:Int = 0;

        var attrValueStartPos:Int = -1;
        var attrValueStartLine:Int = 1;
        var attrValueStartColumn:Int = 0;

        var textStartPos:Int = -1;
        var textStartLine:Int = 1;
        var textStartColumn:Int = 0;

        while (!eof) {
            try {
                var n = input.readBytes(buffer, 0, 4096);

                for (i in 0...n) {
                    var currentPos = absPos + i; // 0-based index of this character in the whole stream
                    var c = Bytes.fastGet(buffer.getData(), i);
                    var t = toToken(c);

                    // save last char's line/column
                    lastLine = line;
                    lastColumn = column;

                    // update current char line/column
                    column++;
                    if (t == Token.NewLine) {
                        line++;
                        column = 1;
                    }

                    switch (state) {
                        case ParserStart:
                            if (t == Token.LessThan) {
                                // record start of this token (the '<')
                                tokenStartPos = currentPos;
                                tokenStartLine = line;
                                tokenStartColumn = column;
                                state = NodeStart;
                            } else if (t != Token.Space && t != Token.Tab && t != Token.NewLine && t != Token.LineFeed) {
                                error('Unexpected content outside root element', line, column);
                            }

                        case NodeStart:
                            switch (t) {
                                case Token.ForwardSlash: // </tag>
                                    sb.reset();
                                    // name will start at next character (we'll record when we see the first character)
                                    state = EndNodeName;

                                case Token.Character:
                                    sb.reset();
                                    // first char of the node name
                                    nameStartPos = currentPos;
                                    nameStartLine = line;
                                    nameStartColumn = column;
                                    sb.addChar(c);
                                    state = ReadNodeName;

                                case Token.ExclamationMark:
                                    // TODO: comments/PI
                                    // set token start at the '!' (tokenStartPos already set when we saw '<')
                                    state = IgnoreWhitespace(ParserStart);

                                case Token.QuestionMark:
                                    // TODO: PI
                                    state = IgnoreWhitespace(ParserStart);

                                case _:
                                    error('Unexpected token at start of node: ' + String.fromCharCode(c), line, column);
                            }

                        case IgnoreWhitespace(next):
                            switch (t) {
                                case Token.NewLine | Token.LineFeed | Token.Tab | Token.Space:
                                    // skip
                                default:
                                    sb.reset();
                                    // we re-enter with this char as first char of next state:
                                    // record a sensible start for that next state in its handler
                                    sb.addChar(c);
                                    state = next;
                            }

                        case ReadNodeName:
                            switch (t) {
                                case Token.Character:
                                    if (sb.length == 0) {
                                        // record start if not already (covers cases where name started here)
                                        nameStartPos = currentPos;
                                        nameStartLine = line;
                                        nameStartColumn = column;
                                    }
                                    sb.addChar(c);

                                case Token.Space | Token.Tab | Token.NewLine | Token.LineFeed | Token.GreaterThan:
                                    // name ended just before this current char (so use currentPos as exclusive end)
                                    nodeName = sb.toString();
                                    if (nodeName == "") {
                                        error('Empty tag name', line, column);
                                    }
                                    sb.reset();

                                    var parent = stack.length > 0 ? stack[stack.length - 1] : null;
                                    var depth = stack.length;
                                    onEvent(StartElement(nodeName, parent, depth, {
                                        startLine: nameStartLine,
                                        startColumn: nameStartColumn,
                                        endLine: lastLine,
                                        endColumn: lastColumn,
                                        startOffset: nameStartPos,
                                        endOffset: currentPos // exclusive: currentPos is the terminator (space or '>')
                                    }));
                                    stack.push(nodeName);

                                    if (t == Token.GreaterThan) {
                                        state = NodeText;
                                    } else {
                                        state = NodeAttributes;
                                    }

                                case Token.ForwardSlash:
                                    // self-closing name: it ended before this char
                                    nodeName = sb.toString();
                                    if (nodeName == "") {
                                        error('Empty self-closing tag name', line, column);
                                    }

                                    var parent = stack.length > 0 ? stack[stack.length - 1] : null;
                                    var depth = stack.length;
                                    onEvent(StartElement(nodeName, parent, depth, {
                                        startLine: nameStartLine,
                                        startColumn: nameStartColumn,
                                        endLine: lastLine,
                                        endColumn: lastColumn,
                                        startOffset: nameStartPos,
                                        endOffset: currentPos
                                    }));
                                    // for a self-closing tag we also emit EndElement right away;
                                    // make EndElement range be the small self-closing marker (from '<' up to '/'?),
                                    // but here we'll use the whole tag start (name) to the current char (exclusive)
                                    onEvent(EndElement(nodeName, parent, depth, {
                                        startLine: nameStartLine,
                                        startColumn: nameStartColumn,
                                        endLine: lastLine,
                                        endColumn: lastColumn,
                                        startOffset: nameStartPos,
                                        endOffset: currentPos
                                    }));

                                    state = IgnoreWhitespace(ParserStart);

                                case _:
                                    error('Unexpected token in tag name: ' + String.fromCharCode(c), line, column);
                            }

                        case NodeAttributes:
                            switch (t) {
                                case Token.Character:
                                    sb.reset();
                                    // start of attribute name
                                    attrNameStartPos = currentPos;
                                    attrNameStartLine = line;
                                    attrNameStartColumn = column;
                                    sb.addChar(c);
                                    state = AttrName;

                                case Token.GreaterThan:
                                    state = NodeText;

                                case Token.ForwardSlash:
                                    // self-closing shorthand: emit EndElement for the node (range from last recorded token start to current char)
                                    var parent = stack.length > 0 ? stack[stack.length - 1] : null;
                                    var depth = stack.length;
                                    onEvent(EndElement(nodeName, parent, depth, {
                                        startLine: tokenStartLine,
                                        startColumn: tokenStartColumn,
                                        endLine: line,
                                        endColumn: column,
                                        startOffset: tokenStartPos,
                                        endOffset: currentPos + 1 // include '/' char
                                    }));
                                    stack.pop();
                                    state = IgnoreWhitespace(ParserStart);

                                case _:
                                    // ignore whitespace already handled above
                            }

                        case AttrName:
                            switch (t) {
                                case Token.Character:
                                    if (sb.length == 0) {
                                        attrNameStartPos = currentPos;
                                        attrNameStartLine = line;
                                        attrNameStartColumn = column;
                                    }
                                    sb.addChar(c);

                                case Token.Equals:
                                    attrName = sb.toString();
                                    if (attrName == "") {
                                        error('Empty attribute name', line, column);
                                    }
                                    sb.reset();
                                    // prepare to read value; when we see the opening quote we'll start attrValue collection
                                    attrValueStartPos = -1;
                                    attrValueStartLine = 1;
                                    attrValueStartColumn = 0;
                                    state = AttrValue(0);

                                case Token.Space | Token.Tab | Token.NewLine | Token.LineFeed:
                                    // ignore

                                case Token.GreaterThan:
                                    error('Attribute "' + sb.toString() + '" missing value', line, column);

                                case _:
                                    error('Unexpected token in attribute name', line, column);
                            }

                        case AttrValue(q):
                            switch (t) {
                                case Token.Quote:
                                    if (q == 0) {
                                        // opening quote; the actual value content will start at the next character we append
                                        state = AttrValue(c); // remember which quote char was used
                                    } else if (q == c) {
                                        // closing quote -> attribute finished.
                                        attrValue = sb.toString();
                                        var parent = stack.length > 0 ? stack[stack.length - 1] : null;
                                        var depth = stack.length - 1;

                                        // compute attr-range: from attrName start to the closing quote (inclusive)
                                        var attrRangeStart = attrNameStartPos;
                                        var attrRangeEndExclusive = currentPos + 1; // include closing quote

                                        onEvent(Attribute(attrName, attrValue, parent, depth, {
                                            startLine: attrNameStartLine,
                                            startColumn: attrNameStartColumn,
                                            endLine: lastLine,
                                            endColumn: lastColumn,
                                            startOffset: attrRangeStart,
                                            endOffset: attrRangeEndExclusive
                                        }));
                                        sb.reset();
                                        state = NodeAttributes;
                                    } else {
                                        // a quote-like char inside an open quoted value: add it to the value
                                        if (sb.length == 0) {
                                            // first character inside value
                                            attrValueStartPos = currentPos;
                                            attrValueStartLine = line;
                                            attrValueStartColumn = column;
                                        }
                                        sb.addChar(c);
                                    }

                                case Token.Character | Token.Space | Token.Tab | Token.NewLine | Token.ForwardSlash:
                                    if (sb.length == 0) {
                                        // mark the start of the attribute value content (first real char inside quotes)
                                        attrValueStartPos = currentPos;
                                        attrValueStartLine = line;
                                        attrValueStartColumn = column;
                                    }
                                    sb.addChar(c);

                                case _:
                                    error('Unexpected token in attribute value', line, column);
                            }

                        case NodeText:
                            if (t == Token.LessThan) {
                                // text node ended before this '<' (so use currentPos as exclusive end)
                                if (sb.length > 0) {
                                    var parent = stack.length > 0 ? stack[stack.length - 1] : null;
                                    var depth = stack.length - 1;
                                    var s = StringTools.trim(sb.toString());
                                    if (s.length > 0) {
                                        // text start was recorded when first char appended; if not recorded (unlikely), fallback to currentPos - sb.length
                                        var startOff = textStartPos >= 0 ? textStartPos : (currentPos - sb.length);
                                        onEvent(TextNode(s, parent, depth, {
                                            startLine: textStartLine,
                                            startColumn: textStartColumn,
                                            endLine: lastLine,
                                            endColumn: lastColumn,
                                            startOffset: startOff,
                                            endOffset: currentPos // exclusive: position of '<'
                                        }));
                                    }
                                    sb.reset();
                                }
                                state = NodeStart;
                            } else {
                                if (sb.length == 0) {
                                    // first char of text node content
                                    textStartPos = currentPos;
                                    textStartLine = line;
                                    textStartColumn = column;
                                }
                                sb.addChar(c);
                            }

                        case EndNodeName:
                            switch (t) {
                                case Token.Character:
                                    if (sb.length == 0) {
                                        // first char of end tag name
                                        nameStartPos = currentPos;
                                        nameStartLine = line;
                                        nameStartColumn = column;
                                    }
                                    sb.addChar(c);

                                case Token.GreaterThan:
                                    var endName = sb.toString();
                                    if (stack.length == 0) {
                                        error('Unexpected closing tag </$endName>', line, column);
                                    }
                                    var expected = stack[stack.length - 1];
                                    if (endName != expected) {
                                        error('Mismatched closing tag </$endName>, expected </$expected>', line, column, tokenStartPos, currentPos + 1);
                                    }

                                    var parent = stack.length > 1 ? stack[stack.length - 2] : null;
                                    var depth = stack.length - 1;

                                    // closing tag range: from the '<' that started the NodeStart (tokenStartPos) up to the '>' inclusive
                                    onEvent(EndElement(endName, parent, depth, {
                                        startLine: tokenStartLine,
                                        startColumn: tokenStartColumn,
                                        endLine: line,
                                        endColumn: column,
                                        startOffset: tokenStartPos,
                                        endOffset: currentPos + 1 // include '>' char
                                    }));

                                    stack.pop();
                                    state = ParserStart;

                                case _:
                                    error('Unexpected token in closing tag', line, column, tokenStartPos, currentPos + 1);
                            }
                    }
                }

                // update absolute offset by number of bytes processed in this read
                absPos += n;
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
