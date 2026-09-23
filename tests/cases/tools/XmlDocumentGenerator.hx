package cases.tools;

typedef XmlGeneratorOptions = {
    @:optional var seed:Int;
    @:optional var nodeCount:Int;

    // Root is depth 1.
    @:optional var maxDepth:Int;

    @:optional var maxAttributes:Int;
    @:optional var maxAttributeLength:Int;
    @:optional var maxTextLength:Int;
}

class XmlDocumentGenerator {
    // Each token represents one character after XML entity decoding.
    private static var TEXT_TOKENS:Array<String> =
        "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789     "
            .split("")
            .concat([
                "é", "·", "€", "漢", "😀",
                "&amp;", "&lt;", "&gt;", "&quot;", "&apos;"
            ]);

    private var state:Int;

    private function new(seed:Int) {
        // Xorshift requires a nonzero state.
        state = seed == 0 ? 1 : seed;
    }

    public static function generate(?options:XmlGeneratorOptions):String {
        if (options == null) {
            options = {};
        }

        var seed = options.seed == null ? 12345 : options.seed;
        var nodeCount = options.nodeCount == null ? 10000 : options.nodeCount;
        var maxDepth = options.maxDepth == null ? 6 : options.maxDepth;
        var maxAttributes = options.maxAttributes == null ? 3 : options.maxAttributes;
        var maxAttributeLength = options.maxAttributeLength == null ? 24 : options.maxAttributeLength;
        var maxTextLength = options.maxTextLength == null ? 128 : options.maxTextLength;

        if (nodeCount < 1 || maxDepth < 1) {
            throw "nodeCount and maxDepth must be at least 1";
        }

        if (nodeCount > 1 && maxDepth < 2) {
            throw "Multiple nodes require maxDepth of at least 2";
        }

        if (maxAttributes < 0 || maxAttributeLength < 0 || maxTextLength < 0) {
            throw "Attribute and text limits cannot be negative";
        }

        var random = new XmlDocumentGenerator(seed);
        var output = new StringBuf();
        var openElements:Array<String> = [];

        for (index in 0...nodeCount) {
            // Starts with a letter, so it is always a valid XML name.
            var name = "n_" + random.nextInt(1000000);

            output.add("<");
            output.add(name);

            var attributeCount = random.nextInt(maxAttributes + 1);

            for (attributeIndex in 0...attributeCount) {
                // The index guarantees unique attributes within this element.
                output.add(" a_");
                output.add(attributeIndex);
                output.add("_");
                output.add(random.nextInt(1000000));
                output.add("=\"");

                random.writeText(output, random.nextInt(maxAttributeLength + 1));

                output.add("\"");
            }

            var depth = openElements.length + 1;
            var canHaveChildren = index < nodeCount - 1 && depth < maxDepth;

            // Root must contain all subsequent nodes.
            var hasChildren = canHaveChildren && (index == 0 || random.nextInt(100) < 35);

            if (hasChildren) {
                output.add(">");
                openElements.push(name);
            } else {
                var textLength = random.nextInt(maxTextLength + 1);

                if (textLength == 0) {
                    output.add("/>");
                } else {
                    output.add(">");
                    random.writeText(output, textLength);
                    closeTag(output, name);
                }

                // Sometimes move back up to generate siblings at shallower depths.
                // Keep the root open until all nodes have been generated.
                while (openElements.length > 1 && random.nextInt(100) < 35) {
                    closeTag(output, openElements.pop());
                }
            }
        }

        while (openElements.length > 0) {
            closeTag(output, openElements.pop());
        }

        return output.toString();
    }

    private function writeText(output:StringBuf, length:Int):Void {
        for (_ in 0...length) {
            output.add(TEXT_TOKENS[nextInt(TEXT_TOKENS.length)]);
        }
    }

    private static function closeTag(output:StringBuf, name:String):Void {
        output.add("</");
        output.add(name);
        output.add(">");
    }

    // Deterministic random numbers using 32-bit integer operations.
    private function nextInt(exclusiveMax:Int):Int {
        state ^= state << 13;
        state ^= state >>> 17;
        state ^= state << 5;

        return (state >>> 1) % exclusiveMax;
    }
}
