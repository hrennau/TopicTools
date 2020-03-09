(: resourceAccess.xqm - functions for accessing resources
 :
 : @version 20141205-1 first version 
 : ===================================================================================
 :)

module namespace m="http://www.ttools.org/xquery-functions";

declare base-uri "..";

(:#file#:)
declare variable $m:BASE_URI := file:current-dir() ! file:path-to-uri(.);
(:##:)

(:
 : ============================================================================
 :
 :     p u b l i c    f u n c t i o n s
 :
 : ============================================================================
 :)

declare function m:resolve-uri($uri as xs:string?) 
        as xs:anyURI? {
(:#file#:)
    let $uri := file:resolve-path($uri, $m:BASE_URI) ! file:path-to-uri(.) return
(:##:)
    resolve-uri($uri)
};

declare function m:static-base-uri() 
        as xs:anyURI? {
    (: add a trailing /, if missing, to patch BaseX bug :)
    let $value := static-base-uri()
    return xs:anyURI(replace($value, '[^/]$', '$0/')) 
};

declare function m:doc($uri as xs:string?)
        as document-node()? {
(:#file#:)
    let $uri := file:resolve-path($uri, $m:BASE_URI) ! file:path-to-uri(.) return
(:##:)
    doc($uri)
};

declare function m:doc-available($uri as xs:string?)
        as xs:boolean {
(:#file#:)
    let $uri := file:resolve-path($uri, $m:BASE_URI) ! file:path-to-uri(.) return
(:##:)        
    try {        
        doc-available($uri)
    } catch * {
        let $encoded := encode-for-uri($uri)
        return
            doc-available($encoded)
    }
};

declare function m:unparsed-text($href as xs:string?)
        as xs:string? {
(:#file#:)
    let $href := file:resolve-path($href, $m:BASE_URI) ! file:path-to-uri(.) return
(:##:)
    unparsed-text($href)
};

declare function m:unparsed-text($href as xs:string?, $encoding as xs:string)
        as xs:string? {
(:#file#:)
    let $href := file:resolve-path($href, $m:BASE_URI) ! file:path-to-uri(.) return
(:##:)
    unparsed-text($href, $encoding)
};

declare function m:unparsed-text-lines($href as xs:string?)
        as xs:string* {
(:#file#:)
    let $href := file:resolve-path($href, $m:BASE_URI) ! file:path-to-uri(.) return
(:##:)
    unparsed-text-lines($href)
};

declare function m:unparsed-text-lines($href as xs:string?, $encoding as xs:string)
        as xs:string* {
(:#file#:)
    let $href := file:resolve-path($href, $m:BASE_URI) ! file:path-to-uri(.) return
(:##:)
    unparsed-text-lines($href, $encoding)
};

declare function m:unparsed-text-available($href as xs:string?)
        as xs:boolean {
(:#file#:)
    let $href := file:resolve-path($href, $m:BASE_URI) ! file:path-to-uri(.) return
(:##:)
    unparsed-text-available($href)
};

declare function m:unparsed-text-available($href as xs:string?, $encoding as xs:string)
        as xs:boolean {
(:#file#:)
    let $href := file:resolve-path($href, $m:BASE_URI) ! file:path-to-uri(.) return
(:##:)
    unparsed-text-available($href, $encoding)
};

declare function m:uri-collection($uri as xs:string?)
        as xs:anyURI* {
(:#file#:)
    let $uri := file:resolve-path($uri, $m:BASE_URI) ! file:path-to-uri(.) return
(:##:)
    uri-collection($uri)
};
