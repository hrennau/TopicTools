(: resourceAccess.mod.xq - functions for accessing resources
 :
 : @version 20141205-1 first version 
 : ===================================================================================
 :)

module namespace m="http://www.ttools.org/xquery-functions";

declare base-uri "..";

(:
 : ============================================================================
 :
 :     p u b l i c    f u n c t i o n s
 :
 : ============================================================================
 :)

declare function m:static-base-uri() 
        as xs:anyURI? {
    (: add a trailing /, if missing, to patch BaseX bug :)
    let $value := static-base-uri()
    return xs:anyURI(replace($value, '[^/]$', '$0/')) 
};

declare function m:doc($uri as xs:string?)
        as document-node()? {
    doc($uri)
};

declare function m:doc-available($uri as xs:string?)
        as xs:boolean {
    doc-available($uri)
};

declare function m:unparsed-text($href as xs:string?)
        as xs:string? {
    unparsed-text($href)
};

declare function m:unparsed-text($href as xs:string?, $encoding as xs:string)
        as xs:string? {
    unparsed-text($href, $encoding)
};

declare function m:unparsed-text-lines($href as xs:string?)
        as xs:string* {
    unparsed-text-lines($href)
};

declare function m:unparsed-text-lines($href as xs:string?, $encoding as xs:string)
        as xs:string* {
    unparsed-text-lines($href, $encoding)
};

declare function m:unparsed-text-available($href as xs:string?)
        as xs:boolean {
    unparsed-text-available($href)
};

declare function m:unparsed-text-available($href as xs:string?, $encoding as xs:string)
        as xs:boolean {
    unparsed-text-available($href, $encoding)
};

declare function m:uri-collection($uri as xs:string?)
        as xs:anyURI* {
    uri-collection($uri)
};
