package xml;

// Ordered direct content of an element. Child elements also remain in XmlNode.children.
enum XmlContent {
    Text(value:String);
    Element(node:XmlNode);
}
