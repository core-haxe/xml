package xml;

class XPath {
    /**
     * Poor Mans XPath: supports absolute/relative paths, attribute filter [@k='v'] (quotes optional)
     * and 1-based positional filters like [1].
     * (mostly generated)
     */
    public static function xpath(node:XmlNode, path:String):Array<XmlNode> {
        if (path == null) return [];
        var absolute = path.length > 0 && path.charAt(0) == '/';
        var parts = path.split("/");
        if (parts.length > 0 && parts[0] == "") parts.shift();

        var start:Array<XmlNode>;
        if (absolute) {
            // find topmost ancestor
            var root = node;
            while (root.parent != null) root = root.parent;
            // virtual document node whose child is the real root
            var doc = new XmlNode("__document__");
            doc.children = [root];
            start = [doc];
        } else {
            start = [node];
        }

        return xpathRecursive(parts, 0, start);
    }

    private static function xpathRecursive(parts:Array<String>, index:Int, current:Array<XmlNode>):Array<XmlNode> {
        if (index >= parts.length) return current;
        var step = parts[index];
        if (step == "") return xpathRecursive(parts, index + 1, current);

        // parse: name + optional predicates
        var reStep = ~/^([^\[]+)(.*)$/;
        var name = step;
        var rawPredicates = "";
        if (reStep.match(step)) {
            name = reStep.matched(1);
            rawPredicates = reStep.matched(2); // includes all [ ... ] blocks
        }

        // parse all [ ... ] blocks
        var predicates:Array<String> = [];
        var rePred = ~/\[([^\]]+)\]/;
        var pos = 0;
        while (pos < rawPredicates.length && rePred.matchSub(rawPredicates, pos, rawPredicates.length - pos)) {
            predicates.push(rePred.matched(1));
            var mpos = rePred.matchedPos();
            pos = mpos.pos + mpos.len;
        }

        var pos:Int = -1;
        var filters:Array<String> = [];

        // separate numeric positional filter vs attribute filters
        for (p in predicates) {
            if (~/^\d+$/.match(p)) {
                pos = Std.parseInt(p);
            } else {
                filters.push(p);
            }
        }

        var next:Array<XmlNode> = [];
        for (node in current) {
            var matches = [];
            for (c in node.children) {
                if (name == "*" || c.nodeName == name) {
                    var ok = true;
                    for (f in filters) {
                        if (!evalFilter(f, c)) {
                            ok = false;
                            break;
                        }
                    }
                    if (ok) matches.push(c);
                }
            }
            if (pos > 0) {
                var idx = pos - 1;
                if (idx >= 0 && idx < matches.length) next.push(matches[idx]);
            } else {
                next = next.concat(matches);
            }
        }
        return xpathRecursive(parts, index + 1, next);
    }

    // Evaluate a boolean filter like "@id='bob' && @class='big'"
    private static function evalFilter(expr:String, node:XmlNode):Bool {
        var tokens = tokenize(expr);
        return evalTokens(tokens, node);
    }

    private static function tokenize(expr:String):Array<String> {
        var result = new Array<String>();
        var re = ~/@[a-zA-Z0-9_-]+|&&|\|\||!=|=|['"][^'"]*['"]|[^\s]+/g;

        var pos = 0;
        while (pos < expr.length && re.matchSub(expr, pos, expr.length - pos)) {
            var mpos = re.matchedPos();
            result.push(expr.substr(mpos.pos, mpos.len));
            pos = mpos.pos + mpos.len;
            // skip whitespace
            while (pos < expr.length && StringTools.isSpace(expr.charAt(pos), 0)) pos++;
        }
        return result;
    }

    private static function evalTokens(tokens:Array<String>, node:XmlNode):Bool {
        // recursive descent would be cleaner, but here’s a simple 2-stage parser
        // 1. evaluate all && groups
        var orGroups:Array<Bool> = [];
        var i = 0;
        while (i < tokens.length) {
            var andValue = evalAtom(tokens[i], tokens[i+1], tokens[i+2], node);
            i += 3;
            while (i < tokens.length && tokens[i] == "&&") {
                var nextVal = evalAtom(tokens[i+1], tokens[i+2], tokens[i+3], node);
                andValue = andValue && nextVal;
                i += 4;
            }
            orGroups.push(andValue);
            if (i < tokens.length && tokens[i] == "||") i++;
        }
        // 2. join with ||
        var result = false;
        for (g in orGroups) result = result || g;
        return result;
    }

    private static function evalAtom(left:String, op:String, right:String, node:XmlNode):Bool {
        if (left == null || op == null || right == null) return false;
        if (!StringTools.startsWith(left, "@")) return false;

        var key = left.substr(1);
        var val = node.attributes.get(key);
        var cmpVal = right;
        if ((StringTools.startsWith(cmpVal, "'") && StringTools.endsWith(cmpVal, "'"))
        || (StringTools.startsWith(cmpVal, "\"") && StringTools.endsWith(cmpVal, "\""))) {
            cmpVal = cmpVal.substr(1, cmpVal.length - 2);
        }

        return switch (op) {
            case "=": val == cmpVal;
            case "!=": val != cmpVal;
            default: false;
        }
    }
}