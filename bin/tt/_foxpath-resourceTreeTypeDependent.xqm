module namespace f="http://www.ttools.org/xquery-functions";
import module namespace i="http://www.ttools.org/xquery-functions" at 
    "_foxpath-processorDependent.xqm",
    "_foxpath-util.xqm";
    
declare variable $f:UNAME external := 'hrennau';    
declare variable $f:TOKEN external := try {unparsed-text('/git/token')} catch * {()};

declare function f:getResponse($path as xs:string, $uname as xs:string?, $token as xs:string)
        as node()+ {
    let $rq := 
        <http:request method="get" href="{$path}">{
            $uname ! <http:header name="User-Agent" value="{.}"/>,
            <http:header name="Authorization" value="{concat('Token ', $token)}"/>
        }</http:request>
    let $rs := http:send-request($rq)
    let $rsHeader := $rs[1]
    let $body := $rs[position() gt 1]
    return
        ($body, $rsHeader)[1]
};        

declare function f:fox-unparsed-text($uri as xs:string, $options as map(*)?)
        as xs:string? {
    let $text := f:redirectedRetrieval($uri, $options)
    return
        try {if ($text) then $text else unparsed-text($uri)} 
        catch * {()}
};

declare function f:fox-unparsed-text-lines($uri as xs:string, $options as map(*)?)
        as xs:string* {
    let $text := f:redirectedRetrieval($uri, $options)
    return
        try {if ($text) then tokenize($text, '&#xA;&#xD;?') else unparsed-text-lines($uri)} 
        catch * {()}
};

declare function f:fox-doc($uri as xs:string, $options as map(*)?)
        as document-node()? {
    let $text := f:redirectedRetrieval($uri, $options)
    return
        try {if ($text) then parse-xml($text) else doc($uri)} 
        catch * {()}
};

declare function f:fox-doc-available($uri as xs:string, $options as map(*)?)
        as xs:boolean {
    let $text := f:redirectedRetrieval($uri, $options)
    return
        try {if ($text) then exists(parse-xml($text)) else doc-available($uri)} 
        catch * {false()}
};

declare function f:fox-file-lines($uri as xs:string, $options as map(*)?)
        as xs:string* {
    let $text := f:redirectedRetrieval($uri, $options)
    return
        try {if ($text) then tokenize($text, '&#xA;') else unparsed-text-lines($uri)} 
        catch * {()}
};

declare function f:redirectedRetrieval($uri as xs:string, $options as map(*)?)
        as xs:string? {
    let $rtrees := 
        if (empty($options)) then ()
        else map:get($options, 'URI_TREES')
    let $redirect := $rtrees//file[$uri eq concat(ancestor::tree/@baseURI, @path)]/@uri
    return
        try {
            if ($redirect) then 
                let $doc := f:getResponse($redirect, $f:UNAME, $f:TOKEN)
                return $doc//content/convert:binary-to-string(xs:base64Binary(.))  
            else ()
        } catch * {()}            
};

declare function f:childUriCollection($uri as xs:string, 
                                      $name as xs:string?,
                                      $stepDescriptor as element()?,
                                      $options as map(*)?) {
    (: let $DUMMY := trace($uri, 'CHILD_URI_COLLECTION; URI: ') return :)
    if (matches($uri, '^https://')) then
        f:childUriCollection_uriTree($uri, $name, $stepDescriptor, $options) else
        
    let $kindFilter := $stepDescriptor/@kindFilter
    let $ignKindTest :=        
        try {file:list($uri, false(), $name)           
            ! replace(., '\\', '/')
            ! replace(., '/$', '')
        } catch * {()}
    return
        if (not($kindFilter)) then $ignKindTest
        else 
            let $useUri := replace($uri, '/$', '')
            return
                if ($kindFilter eq 'file') then
                    $ignKindTest[file:is-file(concat($useUri, '/', .))]
                else if ($kindFilter eq 'dir') then
                    $ignKindTest[file:is-dir(concat($useUri, '/', .))]
                else
                    error(QName((), 'PROGRAM_ERROR'), concat('Unexpected kind filter: ', $kindFilter))
};

(:~
 : Returns the descendants of an input URI. If the $stopDescriptor specifies
 : a kind test (is-dir or is-file), this test is evaluted.
 :)
declare function f:descendantUriCollection($uri as xs:string, 
                                           $name as xs:string?, 
                                           $stepDescriptor as element()?,
                                           $options as map(*)?) {                                           
    if (matches($uri, '^https://')) then
        f:descendantUriCollection_uriTree($uri, $name, $stepDescriptor, $options) else
        
    let $kindFilter := $stepDescriptor/@kindFilter
    let $ignKindTest :=
        try {
            file:list($uri, true(), $name)           
            ! replace(., '\\', '/')
            ! replace(., '/$', '')
        } catch * {()}
    return
        if (not($kindFilter)) then $ignKindTest
        else 
            let $useUri := replace($uri, '/$', '')
            return
                if ($kindFilter eq 'file') then
                    $ignKindTest[file:is-file(concat($useUri, '/', .))]
                else if ($kindFilter eq 'dir') then
                    $ignKindTest[file:is-dir(concat($useUri, '/', .))]
                else
                    error(QName((), 'PROGRAM_ERROR'), concat('Unexpected kind filter: ', $kindFilter))
};

declare function f:childUriCollection_uriTree($uri as xs:string, 
                                              $name as xs:string?,
                                              $stepDescriptor as element()?,
                                              $options as map(*)?) {
    (: let $DUMMY := trace($uri, 'CHILD_FROM_URI_TREE, URI: ') :)
    let $rtrees := 
        if (empty($options)) then ()
        else map:get($options, 'URI_TREES')
    return if (empty($rtrees)) then () else
    (: let $DUMMY := trace(count($rtrees), 'COUNT_RTREES: ') :)
    
    let $kindFilter := $stepDescriptor/@kindFilter    
    let $baseUris := $rtrees/tree/@baseURI
    
    let $ignNameTest := distinct-values(
        let $uri_ := 
            if (ends-with($uri, '/')) then $uri else concat($uri, '/')    
        let $precedingTreeBaseUris := $baseUris[starts-with($uri_, .)]
        return
            (: case 1: URI starts with base uris :)        
            if ($precedingTreeBaseUris) then
                for $bu in $precedingTreeBaseUris
                let $tree := $bu/..
                
                (: the matching elements :)
                let $matchElems :=
                    if ($bu eq $uri_) then 
                        if ($kindFilter eq 'file') then $tree/file
                        else if ($kindFilter eq 'dir') then $tree/dir
                        else $tree/*
                    else
                        let $match := $tree//*[concat($bu, @path) eq $uri]
                        return
                            if (not($match)) then () else
                                if ($kindFilter eq 'file') then $match/file
                                else if ($kindFilter eq 'dir') then $match/dir
                                else $match/*
                return                                
                    $matchElems/@name   
            (: case 2: URI is the prefix of base uris :)                    
            else
                let $continuingTreeBaseUris := $baseUris[starts-with(., $uri_)][not(. eq $uri_)]
                return
                    if (not($continuingTreeBaseUris)) then ()
                    else if ($kindFilter eq 'dir') then ()
                    else
                        $continuingTreeBaseUris 
                        ! substring-after(., $uri_) 
                        ! replace(., '/.*', '')
    )
    return
        if (not($name) or empty($ignNameTest)) then $ignNameTest
        else
            let $regex := concat('^', replace(replace($name, '\*', '.*', 's'), '\?', '.'), '$')
            return $ignNameTest[matches(., $regex, 'is')]
};

declare function f:descendantUriCollection_uriTree($uri as xs:string, 
                                                   $name as xs:string?,
                                                   $stepDescriptor as element()?,
                                                   $options as map(*)?) {
    (: let $DUMMY := trace($uri, 'DESCENDANT_FROM_URI_TREE, URI: ') :)

    let $rtrees := 
        if (empty($options)) then ()
        else map:get($options, 'URI_TREES')
    return if (empty($rtrees)) then () else

    let $kindFilter := $stepDescriptor/@kindFilter
    let $baseUris := $rtrees/tree/@baseURI
    
    let $ignNameTest := distinct-values(
        let $uri_ := if (ends-with($uri, '/')) then $uri else concat($uri, '/')    
        let $precedingTreeBaseUris := $baseUris[starts-with($uri_, .)]  
        return
            (: case 1: URI starts with base uris :)
            if ($precedingTreeBaseUris) then
                for $bu in $precedingTreeBaseUris
                let $tree := $bu/..
                
                (:  potentially matching elements :)
                let $candidates :=
                    if ($kindFilter eq 'file') then $tree/descendant::file
                    else if ($kindFilter eq 'dir') then $tree/descendant::dir
                    else $tree/descendant::*
                
                (: the matching elements :)
                let $matchElems :=
                    if ($bu eq $uri_) then $candidates
                    else
                        let $match := $tree//*[concat($bu, @path) eq $uri]
                        return
                            if (not($match)) then () else
                                $candidates[not(. << $match)]
                let $fullUris :=                                
                    $matchElems/concat($bu, @path)
   
                (: return the paths as postfix of input URI :)
                let $fromPos := string-length($uri) + 2                
                return
                    $fullUris ! substring(., $fromPos)                    

            (: case 2: URI is the prefix of base uris :)
            else
                let $continuingTreeBaseUris := $baseUris[starts-with(., $uri_)][not(. eq $uri_)]
                return
                    if (not($continuingTreeBaseUris)) then ()
                    else
                        for $bu in $continuingTreeBaseUris
                        let $tree := $bu/..
                        let $suffix := substring-after($bu, $uri_)
                        let $suffixSteps := tokenize($suffix, '/')[string()]
                        return (
                            if ($kindFilter eq 'file') then () else
                                for $i in 1 to count($suffixSteps)
                                return
                                    string-join($suffixSteps[position() le $i], '/'),
                            let $matchElems :=    
                                if ($kindFilter eq 'file') then $tree/descendant::file
                                else if ($kindFilter eq 'dir') then $tree/descendant-or-self::dir
                                else $tree/descendant-or-self::*
                            return
                                $matchElems/@path ! concat($suffix, .)
                                (: return the paths as postfix of input URI :)
                        )
    )
    (: process name test :)
    return
        if (not($name) or empty($ignNameTest)) then $ignNameTest
        else
            let $regex := concat('^', replace(replace($name, '\*', '.*', 's'), '\?', '.'), '$')
            return
                if ($regex eq '^.*$') then $ignNameTest
                else
                    $ignNameTest[matches(replace(., '^.*/', ''), $regex, 'is')]
};
