module namespace f="http://www.foxpath.org/ns/fox-functions";
import module namespace i="http://www.ttools.org/xquery-functions" 
at "_foxpath-processorDependent.xqm",
   "_foxpath-uri-operations.xqm";

import module namespace util="http://www.ttools.org/xquery-functions/util" 
at  "_foxpath-util.xqm";

(:~
 : Returns for given items all descendants and their attributes. Atomic
 : items are ignored.
 :
 : @param a sequence of items
 : @return descendant nodes and their attributes
 :) 
declare function f:allDescendants($items as item()*)
        as node()* {
    $items[. instance of node()]//(@*, *)        
};        

(:~
 : Returns the attribute names of a node. If $separator is specified, the sorted
 : names are concatenated, using this separator, otherwise the names are returned
 : as a sequence. If $localNames is true, the local names are returned, otherwise 
 : the lexical names. 
 : 
 : When using $namePattern, only those child elements are considered which have
 : a local name matching the pattern.
 :
 : Example: .../foo/att-names(., ', ', false(), '*put')
 : Example: .../foo/att-names(., ', ', false(), 'input|output') 
 :
 : @param nodes a sequence of nodes (only element nodes contribute to the result)
 : @param separator if used, the names are concatenated, using this separator
 : @param localNames if true, the local names are returned, otherwise the lexical names 
 : @param namePattern an optional name pattern filtering the attributes to be considered 
 : @return the names as a sequence, or as a concatenated string
 :)
declare function f:attNamesOld($nodes as node()*, 
                            $concat as xs:boolean?, 
                            $nameKind as xs:string?,   (: name | lname | jname :)
                            $namePatterns as xs:string*,
                            $excludedNamePatterns as xs:string*)
        as xs:string* {
    let $nameRegexes := $namePatterns 
       ! replace(., '\*', '.*') ! replace(., '\?', '.') 
       ! concat('^', ., '$')        
    let $excludedNameRegexes := $excludedNamePatterns 
       ! replace(., '\*', '.*') ! replace(., '\?', '.') 
       ! concat('^', ., '$')    
       
    for $node in $nodes       
    let $items := $node/@*
       [empty($nameRegexes) or 
            (some $r in $nameRegexes satisfies matches(local-name(.), $r, 'i'))]
       [empty($excludedNameRegexes) or 
            not(some $r in $excludedNameRegexes satisfies matches(local-name(.), $r, 'i'))]
    let $separator := ', '[$concat]
    let $names := 
        if ($nameKind eq 'lname') then 
            ($items/local-name(.)) => distinct-values() => sort()
        else if ($nameKind eq 'jname') then 
            ($items/f:unescape-json-name(local-name(.))) => distinct-values() => sort()
        else ($items/name(.)) => distinct-values() => sort()
    return
        if (exists($separator)) then string-join($names, $separator)
        else $names
};        

declare function f:attNames($nodes as node()*, 
                            $concat as xs:boolean?, 
                            $nameKind as xs:string?,   (: name | lname | jname :)
                            $nameFilter as xs:string?,
                            $nameFilterExclude as xs:string?)
        as xs:string* {
    let $cnameFilter := util:compileNameFilter($nameFilter, true())        
    let $cnameFilterExclude := util:compileNameFilter($nameFilterExclude, true())
       
    for $node in $nodes       
    let $items := $node/@*
       [empty($cnameFilter) or util:matchesNameFilter(local-name(.), $cnameFilter)]
       [empty($cnameFilterExclude) or not(util:matchesNameFilter(local-name(.), $cnameFilterExclude))] 
    let $separator := ', '[$concat]
    let $names := 
        if ($nameKind eq 'lname') then 
            ($items/local-name(.)) => distinct-values() => sort()
        else if ($nameKind eq 'jname') then 
            ($items/f:unescape-json-name(local-name(.))) => distinct-values() => sort()
        else ($items/name(.)) => distinct-values() => sort()
    return
        if (exists($separator)) then string-join($names, $separator)
        else $names
};        

(:~
 : Writes a set of standard attributes. Can be useful when working
 : with `xelement`.
 :
 : @param context the current context
 : @param flags flags signaling which attributes are required
 : @return the attributes
 :)
declare function f:atts($context as item(), $flags as xs:string)
        as attribute()* {
    if (contains($flags, 'b')) then
        let $uri :=
            if ($context instance of xs:anyAtomicType) then $context
            else $context ! base-uri(.)
        return
            attribute xml:base {$uri},
    if (contains($flags, 'j')) then
        if (not($context instance of node())) then ()
        else
            let $jpath := f:namePath($context, 'jname', ())
            return attribute jpath {$jpath}
};


(:~
 : Returns the names of folders containing a resource identified by $item. Parameter
 : $distance specifies the number of containing folders ($distance ge 1). A value
 : of 1, 2, 3, ... selects the closest, the two closest, the three closest folders,
 : and so forth. The folder names are returned in the order of containing before 
 : contained.
 :
 : @param item a node or a URI
 : @param distance identifies the number of folders to be reported
 : @return folder names, with a containing folder preceding the folders contained
 :)
declare function f:baseUriDirectories($item as item(), $distance as xs:integer?)
        as xs:string* {
    if ($distance eq 1) then f:baseUriDirectory($item)
    else if ($distance gt 1) then    
        let $baseUri := 
            (if ($item instance of node()) then $item else i:fox-doc($item, ()))
            ! base-uri(.) ! replace(., '\\', '/')
        let $resources := tokenize($baseUri, '/')
        return subsequence($resources, count($resources) - $distance - 1, $distance)
    else ()            
};

declare function f:baseUriDirectory($item as item())
        as xs:string {
    (if ($item instance of node()) then $item else i:fox-doc($item, ()))
    ! base-uri(.) ! replace(., '.*[/\\](.*)[/\\][^/\\]*$', '$1')
};

declare function f:baseUriFileName($item as item())
        as xs:string {
    (if ($item instance of node()) then $item else i:fox-doc($item, ()))
    ! base-uri(.) ! file:name(.)
};

(:~
 : Edits a text, replacing forward slashes by back slashes.
 :
 : @param arg text to be edited
 : @return edited text
 :)
declare function f:bslash($arg as xs:string?)
        as xs:string? {
    replace($arg, '/', '\\')        
};      

(:~
 : Returns true if all items have deep-equal content. When comparing  the items,
 : only their content is considered, not their name. Thus elements with different
 : names can have deep-equal content.
 :
 : @param items the items to be checked
 : @return false if there is a pair of items which do not have deep-equal content, true otherwise
 :)
declare function f:content-deep-equal($items as item()*)
        as xs:boolean? {
    let $docs :=
        for $item in $items return
            if ($item instance of node()) then $item
            else i:fox-doc($item, ())
    let $count := count($docs)
    return if ($count le 1) then true() else
    
    every $i in 1 to $count - 1 satisfies
        let $item1 := $docs[$i]
        let $item2 := $docs[$i + 1]
        let $atts1 := for $a in $item1/@* order by local-name($a), namespace-uri($a), string($a) return $a
        let $atts2 := for $a in $item2/@* order by local-name($a), namespace-uri($a), string($a) return $a
        return
            deep-equal($atts1, $atts2) and deep-equal($item1/node(), $item2/node())
};      

(:~
 : Returns the number of occurrences of a character in a string
 :
 : @param s a string
 : @param char a character
 : @return the number of times the character occurs in the string
 :)
declare function f:countChars($s as xs:string?, $char as xs:string?)
        as xs:integer? {
    let $char := replace($char, '[\^\-(){}\[\]]', '\\$0')
    let $s2 := replace($s, $char, '')        
    return string-length($s) - string-length($s2)        
};

(:~
 : Returns the text content of a file resource.
 :
 : @param uri the file URI
 : @param encoding an encoding
 : @param options for future use
 : @return the text content
 :)
declare function f:file-content($uri as xs:string?, 
                                $encoding as xs:string?,
                                $options as map(*)?)
        as xs:string? {
    let $redirectedRetrieval := i:fox-unparsed-text_github($uri, $encoding, $options)
    return
        if ($redirectedRetrieval) then $redirectedRetrieval
        else i:fox-unparsed-text($uri, $encoding, $options)
};      

(:~
 : Returns for a set of URIs the child URIs with a file name (final step) 
 : matching a name or name pattern from $names, and not matching a name or 
 : name pattern from $namesExcluded. 
 :
 : If $fromSubstring and $toSubstring are supplied, the file name must match the 
 : regex obtained by replacing in $name substring $fromSubstring with $toSubstring.
 :
 : @param context the context URIs
 : @param names names or name paterns of URIs to be included, whitespace separated
 : @param namesExcluded names or name paterns of URIs to be excluded, whitespace separated
 : @return selected child URIs
 :)
declare function f:foxChild($context as xs:string*,
                            $names as xs:string*,
                            $namesExcluded as xs:string*)
        as xs:string* {
    let $cnameFilter := util:compileNameFilter($names, true())        
    let $cnameFilterExclude := util:compileNameFilter($namesExcluded, true())    
    return (
        for $c in $context return
            i:childUriCollection($c, (), (), ()) 
            [empty($names) or util:matchesNameFilter(., $cnameFilter)]
            [empty($namesExcluded) or not(util:matchesNameFilter(., $cnameFilterExclude))]
            ! concat($c, '/', .)
        ) => distinct-values()
};

(:~
 : Returns the child elements of input nodes with a JSON name equal to
 : one of a set of input names. The JSON name is the name obtained by
 : decoding the element name as a JSON key.
 :
 : @param context the context URI
 : @param names one or several name patterns
 : @return child elements with a matching JSON name
 :)
declare function f:jchild($context as node()*,
                          $names as xs:string+)
        as item()* {
    let $flags := '' return
    
    if (every $name in $names satisfies not(matches($name, '[*?]'))) then        
        $context/*[convert:decode-key(local-name()) = $names]
    else
        let $namesRX := 
            $names 
            ! replace(., '\*', '.*') 
            ! replace(., '\?', '.') 
            ! concat('^', ., '$')
        return
            $context/*[
                let $jname := convert:decode-key(local-name())
                return some $rx in $namesRX satisfies matches($jname, $rx, $flags)
            ]                
};

(:~
 : Returns the child elements of input nodes with a JSON name equal to
 : one of a set of input names. The JSON name is the name obtained by
 : decoding the element name as a JSON key.
 :
 : @param context the context URI
 : @param names one or several name patterns
 : @return child elements with a matching JSON name
 :)
declare function f:jchildren($context as node()*,
                             $nameFilter as xs:string?,
                             $ignoreCase as xs:boolean?)
        as item()* {
    let $cnameFilter := util:compileNameFilter($nameFilter, $ignoreCase)        
    return $context/*[convert:decode-key(local-name()) ! util:matchesNameFilter(., $cnameFilter)]
};

(:~
 : Returns for a set of URIs the parent URIs with a file name (final step) 
 : matching a name or name pattern from $names, and not matching a name or 
 : name pattern from $namesExcluded. 
 :
 : @param context the context URIs
 : @param names names or name paterns of URIs to be included, whitespace separated
 : @param namesExcluded names or name paterns of URIs to be excluded, whitespace separated
 : @return selected parent URIs
:)
declare function f:foxParent($context as xs:string*,
                             $names as xs:string*,
                             $namesExcluded as xs:string*)
        as xs:string? {
    let $cnameFilter := util:compileNameFilter($names, true())        
    let $cnameFilterExclude := util:compileNameFilter($namesExcluded, true())    
    return (
        for $c in $context return
            i:parentUri($c, ()) 
            [empty($names) or util:matchesNameFilter(., $cnameFilter)]
            [empty($namesExcluded) or not(util:matchesNameFilter(., $cnameFilterExclude))]
        ) => distinct-values()
};

(:~
 : Filters a set of URIs, returning those URIs with a file name (final step) matching a 
 : name or name pattern from $names, and not matching a name or name pattern from 
 : $namesExcluded. 
 :
 : @param context the context URIs
 : @param names names or name paterns of URIs to be included, whitespace separated
 : @param namesExcluded names or name paterns of URIs to be excluded, whitespace separated
 : @return selected descendant or self URIs
 :)
declare function f:foxSelf($context as xs:string*,
                           $names as xs:string*,
                           $namesExcluded as xs:string*)
        as xs:string* {
    let $cnameFilter := util:compileNameFilter($names, true())        
    let $cnameFilterExclude := util:compileNameFilter($namesExcluded, true())
    return (    
        for $c in $context return
        $c
        [empty($names) or file:name(.) ! util:matchesNameFilter(., $cnameFilter)]
        [empty($namesExcluded) or file:name(.) ! not(util:matchesNameFilter(., $cnameFilterExclude))]
    ) => distinct-values()        
};

(:~
 : Returns for a set of URIs the descendant URIs with a file name (final step) 
 : matching a name or name pattern from $names, and not matching a name or name 
 : pattern from $namesExcluded. 
 :
 : @param context the context URIs
 : @param names names or name paterns of URIs to be included, whitespace separated
 : @param namesExcluded names or name paterns of URIs to be excluded, whitespace separated
 : @return selected child URIs
 :)
declare function f:foxDescendant(
                         $context as xs:string*,
                         $names as xs:string*,
                         $namesExcluded as xs:string*)
        as xs:string* {
    let $cnameFilter := util:compileNameFilter($names, true())        
    let $cnameFilterExclude := util:compileNameFilter($namesExcluded, true())
    return (
        for $c in $context 
            return i:descendantUriCollection($c, (), (), ()) 
                   [empty($names) or file:name(.) ! util:matchesNameFilter(., $cnameFilter)]
                   [empty($namesExcluded) or file:name(.) ! not(util:matchesNameFilter(., $cnameFilterExclude))]
                   ! concat($c, '/', .)
    ) => distinct-values()
};

(:~
 : Returns for a set of URIs the descendant or self URIs with a file name 
 : (final step) matching a name or name pattern from $names, and not matching 
 : a name or name pattern from $namesExcluded. 
 :
 : @param context the context URIs
 : @param names names or name paterns of URIs to be included, whitespace separated
 : @param namesExcluded names or name paterns of URIs to be excluded, whitespace separated
 : @return selected descendant or self URIs
 :)
declare function f:foxDescendantOrSelf(
                             $context as xs:string*,
                             $names as xs:string*,
                             $namesExcluded as xs:string*)
        as xs:string* {
    (
        for $c in $context return (
        f:foxDescendant($context, $names, $namesExcluded),
        f:foxSelf($context, $names, $namesExcluded)
    )) => distinct-values() => sort()
};

(:~
 : Returns the sibling URIs of a given URI, provided their name matches a given 
 : name, or a regex derived from it. If $fromSubstring and $toSubstring are 
 : supplied, the URI names must match the regex obtained obtained by replacing 
 : in $name substring $fromSubstring with $toSubstring.
 :
 : @param context the context URI
 : @param names one or several name patterns
 : @param fromSubstring used to map $name to a regex
 : @param toSubstring used to map $name to a regex
 : @return sibling URIs matching the name or the derived regex
 :)
declare function f:foxSibling($context as xs:string*,
                              $names as xs:string*,
                              $namesExcluded as xs:string*,
                              $fromSubstring as xs:string?,
                              $toSubstring as xs:string?)
        as xs:string* {
    (
    for $c in $context
    let $names := 
        let $raw :=if (exists($names)) then $names else file:name($c)
        return
            if (empty($fromSubstring) or empty($toSubstring)) then $raw
            else $raw ! replace(., $fromSubstring, $toSubstring, 'i')
    for $name in $names
    let $parent := i:parentUri($c, ())
    let $raw := f:foxChild($parent, $name, $namesExcluded)
    return $raw[not(. eq $c)]
    ) => distinct-values()
};

(:~
 : Returns the sibling URIs of the parent URI of a given URI, provided their 
 ; name matches a given name, or a regex derived from it. If $fromSubstring 
 : and $toSubstring are supplied, the URI names must match the regex obtained 
 : obtained by replacing in $name substring $fromSubstring with $toSubstring.
 :
 : @param context the context URI
 : @param names one or several name patterns
 : @param fromSubstring used to map $name to a regex
 : @param toSubstring used to map $name to a regex
 : @return sibling URIs matching the name or the derived regex
 :)
declare function f:foxParentSibling($context as xs:string*,
                                    $names as xs:string*,
                                    $namesExcluded as xs:string*,                                      
                                    $fromSubstring as xs:string?,
                                    $toSubstring as xs:string?)
        as xs:string* {
    (
    for $c in $context return
        i:parentUri($c, ()) 
        ! f:foxSibling(., $names, $namesExcluded, $fromSubstring, $toSubstring)
    ) => distinct-values()        
};

(:~
 : Returns for a set of URIs the ancestor URIs with a file name (final step) 
 : matching a name or name pattern from $names, and not matching a name or name 
 : pattern from $namesExcluded. 
 :
 : @param context the context URIs
 : @param names names or name paterns of URIs to be included, whitespace separated
 : @param namesExcluded names or name paterns of URIs to be excluded, whitespace separated
 : @return selected child URIs
 :)
declare function f:foxAncestor($context as xs:string*,                                        
                               $names as xs:string*,
                               $namesExcluded as xs:string*)
        as xs:string* {

    let $cnameFilter := util:compileNameFilter($names, true())        
    let $cnameFilterExclude := util:compileNameFilter($namesExcluded, true())
    return (
        for $c in $context 
            return i:ancestorUriCollection($c, (), ()) 
                   [empty($names) or file:name(.) ! util:matchesNameFilter(., $cnameFilter)]
                   [empty($namesExcluded) or file:name(.) ! not(util:matchesNameFilter(., $cnameFilterExclude))]
    ) => distinct-values()
};

(:~
 : Returns the ancestor-or-self URIs of a given URI, provided their name matches a 
 : given name, or a regex derived from it. If $fromSubstring and $toSubstring are 
 : supplied, the URI names must match the regex obtained obtained by replacing in 
 : $name substring $fromSubstring with $toSubstring.
 :
 : @param context the context URI
 : @param names one or several name patterns
 : @param fromSubstring used to map $name to a regex
 : @param toSubstring used to map $name to a regex
 : @return sibling URIs matching the name or the derived regex
 :)
declare function f:foxAncestorOrSelf($context as xs:string*,                                        
                                     $names as xs:string+,
                                     $namesExcluded as xs:string*)
        as xs:string* {
    (
    for $c in $context return (
    f:foxAncestor($context, $names, $namesExcluded),
    f:foxSelf($context, $names, $namesExcluded)
    )) => distinct-values()
};

(:~
 : Returns a frequency distribution.
 :
 : @param values a sequence of terms
 : @param min if specified - return only terms with a frequency >= $min
 : @param max if specified - return only terms with a frequency >= $max
 : @param kind the kind of frequency value - count, relfreq (relative frequency), 
 :   percent (percent frequency)
 : @param orderBy sort order - "a" (order by frequency ascending, 
 -   "d" (order by frequency descending); default: alphabetically
 : @param format  the output format, one of xml|json|csv|text|text*, default = text;
 :   "text* denotes "text" followed by a number (e.g. text40) specifying the width 
 :   of the term column - shorter terms are padded to this width
 : @return the frequency distribution
 :)
declare function f:frequencies($values as item()*, 
                               $min as xs:integer?, 
                               $max as xs:integer?, 
                               $kind as xs:string?, (: count | relfreq | percent :)
                               $orderBy as xs:string?,
                               $format as xs:string?)
        as item() {
        
    let $width := 
        if (not($format) or $format eq 'text*') then 1 + ($values ! string(.) ! string-length(.)) => max()
        else if (matches($format, '^text\d')) then replace($format, '^text', '')[string()] ! xs:integer(.)
        else ()
    let $format := 
        if (not($format)) then 'text'
        else if (matches($format, '^text.')) then 'text'
        else $format    
 
    let $freqAttName := ($kind, 'count')[1]
    
    (: Function return the frequency representation :)
    let $fn_count2freq :=
        switch($kind)
        case 'freq' return function($c, $nvalues) {($c div $nvalues) ! round(., 1) ! string(.) ! replace(., '^[^.]+$', '$0.0')}
        case 'percent' return function($c, $nvalues) {($c div $nvalues * 100) ! round(., 1) ! string(.) ! replace(., '^[^.]+$', '$0.0')}
        default return function($c, $nvalues) {$c}

    (: Function item returning a term representation :)
    let $fn_itemText :=
        switch($format) 
        case 'text' return function($s, $c) {
            if (empty($width)) then concat($s, ' (', $c, ')')
            else 
                concat($s, ' ', 
                       string-join(for $i in 1 to $width - string-length($s) - 1 return '.', ''), 
                       ' (', $c, ')')}
        case 'json' return function($s, $c) {'"'||$s||'": '||$c}
        case 'csv' return function($s, $c) {'"'||$s||'",'||$c}
        case 'xml' return ()
        default return error(QName((), 'INVALID_ARG'), 
            concat('Unknown frequencies format, should be text|xml|json|csv; found: ', $format))

    let $nvalues := count($values)     
    let $itemsUnordered :=        
        for $value in $values
        group by $s := string($value)
        let $c := count($value)        
        let $f := $fn_count2freq($c, $nvalues)
        where (empty($min) or not($c) or $c ge $min) and (empty($max) or not($max) or $c le $max)
        return <term text="{$s}" f="{$f}"/>

    let $items :=
        switch($orderBy)
        case 'a' return 
            for $item in $itemsUnordered 
            order by $item/@f/number(.), $item/@text/lower-case(.) 
            return $item
        case 'd' return 
            for $item in $itemsUnordered 
            order by $item/@f/number(.) descending, $item/@text/lower-case(.) 
            return $item
        default return 
            for $item in $itemsUnordered 
            order by $item/@text/lower-case(.) 
            return $item
            
    return  
        switch($format)
        case 'xml' return 
            let $min := $items/@f/number(.) => min()
            let $max := $items/@f/number(.) => max()
            return
                <terms>{
                    if ($kind eq 'percent') then (
                        attribute minPercent {$min},
                        attribute maxPercent {$max}
                    ) else if ($kind eq 'freq') then (
                        attribute minFreq {$min},
                        attribute maxFreq {$max}
                    ) else (
                        attribute minCount {$min},
                        attribute maxCount {$max}
                    ),
                    $items/<item text="{@text}">{attribute {$freqAttName} {@f}}</item>
            }</terms>
        case 'json' return ('{', $items/$fn_itemText(@text, @f) ! concat('  ', .), '}') => string-join('&#xA;')
        case 'csv' return $items/$fn_itemText(@text, @f) => string-join('&#xA;')
        case 'text' return $items/$fn_itemText(@text, @f) => string-join('&#xA;')
        default return $items => string-join('&#xA;')
};      

(:~
 : Returns selected child elements of a given sequence of nodes. Selected elements 
 : have a name matching a given name filter and not matching an optional name filter 
 : defining exclusions. 
 :
 : Depending on $nameKind, the local name ('lname'), the JSON name ('jname') or
 : the lexical name 'name') is considered when matching.
 :
 : When $ignoreCase is true, matching is performed ignoring character case.
 :
 : A name filter is a whitespace separated list of names or name patterns. Name
 : patterns can use wildcards * and ?. Example: "foo bar* *foobar"
 :
 : @param context the context node
 : @param names a name filter
 : @param namesExcluded a name filter defining exclusions
 : @return child nodes matching the name filter and not matching the name filter defining exclusions
 :)
declare function f:nodeChild(
                       $contextNodes as node()*,
                       $nameKind as xs:string?,   (: name | lname | jname :)
                       $names as xs:string?,
                       $namesExcluded as xs:string?,
                       $ignoreCase as xs:boolean?)
        as node()* {
    let $ignoreCase := ($ignoreCase, true())[1]        
    let $cnameFilter := $names ! util:compileNameFilter(., $ignoreCase)        
    let $cnameFilterExclude := $namesExcluded ! util:compileNameFilter(., $ignoreCase)
    let $fn_name := 
        switch($nameKind)
        case 'lname' return function($node) {$node/local-name(.)}
        case 'jname' return function($node) {$node/local-name(.) ! convert:decode-key(.)}
        case 'name' return function($node) {$node/name(.)}
        default return error()
    return
        $contextNodes/*[$fn_name(.) ! 
            util:matchesNameFilter(., $cnameFilter) and (
                not($namesExcluded) or util:matchesNameFilter(., $cnameFilterExclude))]
};

(:~
 : Returns selected descendant elements of a given sequence of nodes. Selected elements
 : have a name matching a given name filter and not matching an optional name filter 
 : defining exclusions. 
 :
 : Depending on $nameKind, the local name ('lname'), the JSON name ('jname') or
 : the lexical name 'name') is considered when matching.
 :
 : When $ignoreCase is true, matching is performed ignoring character case.
 :
 : A name filter is a whitespace separated list of names or name patterns. Name
 : patterns can use wildcards * and ?. Example: "foo bar* *foobar"
 :
 : @param context the context node
 : @param names a name filter
 : @param namesExcluded a name filter defining exclusions
 : @return child nodes matching the name filter and not matching the name filter defining exclusions
 :)
declare function f:nodeDescendant(
                       $contextNodes as node()*,
                       $nameKind as xs:string?,   (: name | lname | jname :)
                       $names as xs:string?,
                       $namesExcluded as xs:string?,
                       $ignoreCase as xs:boolean?
)
        as node()* {
    let $ignoreCase := ($ignoreCase, true())[1]        
    let $cnameFilter := $names ! util:compileNameFilter(., $ignoreCase)        
    let $cnameFilterExclude := $namesExcluded ! util:compileNameFilter(., $ignoreCase)
    let $fn_name := 
        switch($nameKind)
        case 'lname' return function($node) {$node/local-name(.)}
        case 'jname' return function($node) {$node/local-name(.) ! convert:decode-key(.)}
        case 'name' return function($node) {$node/name(.)}
        default return error()
    return
        $contextNodes//*[$fn_name(.) ! 
            util:matchesNameFilter(., $cnameFilter) and (
                not($namesExcluded) or util:matchesNameFilter(., $cnameFilterExclude))]
};

(:~
 : Creates an Item Location Report for a sequence of given nodes.
 :
 : @param nodes a sequence of JSON nodes
 : @param withFolders the location report should include the folder containing the documents
 : @return a location report
 :)
declare function f:nodesLocationReport($nodes as node()*,
                                       $nameKind as xs:string?,   (: name | lname | jname :)
                                       $withFolders as xs:integer?)
        as xs:string {        
    let $fn_name := 
        switch($nameKind)
        case 'name' return name#1
        case 'lname' return local-name#1
        case 'jname' return f:jname#1
        default return error(QName((), 'INVALID_ARG'), concat('Invalid "nameKind": ', $nameKind))
    return
    
    $nodes/f:hlistEntry((
        if ($withFolders) then f:baseUriDirectories(., $withFolders) else (),
        f:baseUriFileName(.), 
        $fn_name(.), 
        f:namePath(., 'jname', ()),
        .[self::attribute(), text()]/concat('value: ', .)
        ))
        => f:hlist((for $i in 1 to $withFolders return 'Folder', 'File', 'Name', 'Path', 'Value'), ())
};

(:~
 : Returns the JSON names of given nodes.
 :
 : @param nodes a sequence of nodes
 : @return a sequence of JSON names
 :)
declare function f:jname($nodes as node()*)
        as xs:string* {
    $nodes ! local-name(.) ! convert:decode-key(.)        
};

(:~
 : Returns the JSON Schema keywords found at and under a set of nodes from a 
 : JSON Schema document.
 :
 : @param values JSON values (element or document nodes)
 : @param namePatterns a list of names or name patterns, whitespace separated
 : @return the resolved reference, if the value contains one, or the original value
 :)
declare function f:jschemaKeywords($nodes as node()*, 
                                   $names as xs:string?,
                                   $namesExcluded as xs:string?)
        as element()* {
    let $cnameFilter := util:compileNameFilter($names, true())
    let $cnameFilterExclude := util:compileNameFilter($namesExcluded, true())
    return
        $nodes/f:jschemaKeywordsRC(., $cnameFilter, $cnameFilterExclude)
};

(:~
 : Recursive helper function of jschemaKeywords().
 :
 : @param n a node to process
 : @param filter a filter consisting of names and regular expressions
 : @return the keyword nodes under the input node, including it
 :)
declare function f:jschemaKeywordsRC($n as node(),
                                     $nameFilter as map(xs:string, item()*)?,
                                     $nameFilterExclude as map(xs:string, item()*)?)
        as node()* {
    let $unfiltered :=        
        typeswitch($n)
        case element(default) return $n    
        case element(discriminator) return $n    
        case element(example) return $n
        case element(examples) return $n
        case element(enum) return $n    
        case element(json) return ($n[parent::*], $n/*/f:jschemaKeywordsRC(., $nameFilter, $nameFilterExclude))
        case element(patternProperties) return ($n, $n/*/*/f:jschemaKeywordsRC(., $nameFilter, $nameFilterExclude))    
        case element(properties) return ($n, $n/*/*/f:jschemaKeywordsRC(., $nameFilter, $nameFilterExclude))
        case element(_) return $n/*/f:jschemaKeywordsRC(., $nameFilter, $nameFilterExclude)
        case document-node() return $n/*/f:jschemaKeywordsRC(., $nameFilter, $nameFilterExclude)
        default return 
            if (starts-with($n/name(), 'x-')) then $n
            else ($n, $n/*/f:jschemaKeywordsRC(., $nameFilter, $nameFilterExclude))
    return
        if (empty($nameFilter)) then $unfiltered else
        for $node in $unfiltered
        let $jname := $node/local-name() ! convert:decode-key(.) ! lower-case(.)
        where util:matchesPlusMinusNameFilters($jname, $nameFilter, $nameFilterExclude)
        return $node
};        

(:~
 : Returns the items in $value which are not distinct, that is, which
 : occur in $value more than once.
 :
 : @param value the items to analyze
 : @param ignoreCase if true, distinctness check ignores case
 : @return the non-distinct values
 :)
declare function f:nonDistinctValues($value as item()*,
                                     $ignoreCase as xs:boolean?)
        as item()* {
    if (not($ignoreCase)) then
        for $item in $value
        group by $data := data($item)
        where count($item) gt 1
        return $data
    else
        for $item in $value
        group by $data := data($item) ! lower-case(.)
        where count($item) gt 1
        return distinct-values($item)
};

(:~
 : Returns the URIs in $uris which are contain a non-distinct file name, that is,
 : which contain a file name also contained by a different URI.
 :
 : @param uris the URIs to analyze
 : @param ignoreCase if true, distinctness check ignores case
 : @return the URIs with a non-distinct file name
 :)
declare function f:nonDistinctFileNames($uris as item()*,
                                        $ignoreCase as xs:boolean?)
        as item()* {
    if (not($ignoreCase)) then
        for $uri in $uris
        group by $fname := file:name($uri)
        where count($uri) gt 1
        return $uri
    else
        for $uri in $uris
        group by $fname := file:name($uri) ! lower-case(.)
        where count($uri) gt 1
        return distinct-values($uri)
};

(:~
 : Returns the JSON Schema keywords found at and under a set of nodes from a 
 : JSON Schema document.
 :
 : @param values JSON values
 : @param namePatterns a list of names or name patterns, whitespace separated
 : @return the resolved reference, if the value contains one, or the original value
 :)
declare function f:oasKeywords($values as node()*, 
                               $names as xs:string?,
                               $namesExcluded as xs:string?)
        as element()* {
    let $cnameFilter := util:compileNameFilter($names, true())
    let $cnameFilterExclude := util:compileNameFilter($namesExcluded, true())
        
    let $values := $values ! root()/descendant-or-self::*[1]        
    for $value in $values
    let $oasVersion := $value/ancestor-or-self::*[last()]/(
        openapi/substring(., 1, 1),
        swagger/substring(., 1, 1)
        )[1]
    return        
        $value/f:oasKeywordsRC(., $oasVersion, $cnameFilter, $cnameFilterExclude)
};

(:~
 : Recursive helper function of jschemaKeywords().
 :
 : @param n a node to process
 : @param filter a filter consisting of names and regular expressions
 : @return the keyword nodes under the input node, including it
 :)
declare function f:oasKeywordsRC($n as node(),
                                 $version as xs:string?,
                                 $nameFilter as map(xs:string, item()*)?,
                                 $nameFilterExclude as map(xs:string, item()*)?)
        as node()* {
    let $unfiltered :=        
        typeswitch($n)
        
        (: Array item - continue with children :)
        case element(_) return $n/*/f:oasKeywordsRC(., $version, $nameFilter, $nameFilterExclude)
        
        (: Keywords with version-dependent treatment :)
        
        (: Keyword 'examples' 
           - if version 2: do not continue recursion;
           - if version 3: treat as map and continue with children :)           
        case element(examples) return (
            $n,
            if ($version ! starts-with(., '2')) then ()
            else $n/*/*/f:oasKeywordsRC(., $version, $nameFilter, $nameFilterExclude))
            
        (: Schema-related keywords - do not continue recursion :)
        case element(schema) return $n
        case element(schemas) return $n
        case element(definitions) return $n (: V2 :)
        
        (: Maps with object-valued entries - use the map object and continue with the children of the map entries :)

        case element(callbacks) return ($n, $n/*/*/*/f:oasKeywordsRC(., $version, $nameFilter, $nameFilterExclude)) (: Callback has a single member = expr :)
        case element(content) return ($n, $n/*/*/f:oasKeywordsRC(., $version, $nameFilter, $nameFilterExclude))   
        case element(encoding) return ($n, $n/*/*/f:oasKeywordsRC(., $version, $nameFilter, $nameFilterExclude))        
        case element(examples) return ($n, $n/*/*/f:oasKeywordsRC(., $version, $nameFilter, $nameFilterExclude))        
        case element(headers) return ($n, $n/*/*/f:oasKeywordsRC(., $version, $nameFilter, $nameFilterExclude))
        case element(links) return ($n, $n/*/*/f:oasKeywordsRC(., $version, $nameFilter, $nameFilterExclude))
        case element(pathItems) return ($n, $n/*/*/f:oasKeywordsRC(., $version, $nameFilter, $nameFilterExclude))        
        case element(paths) return ($n, $n/*/*/f:oasKeywordsRC(., $version, $nameFilter, $nameFilterExclude))        
        case element(requestBodies) return ($n, $n/*/*/f:oasKeywordsRC(., $version, $nameFilter, $nameFilterExclude))
        case element(responses) return ($n, $n/*/*/f:oasKeywordsRC(., $version, $nameFilter, $nameFilterExclude))
        case element(securityDefinitions) return ($n, $n/*/*/f:oasKeywordsRC(., $version, $nameFilter, $nameFilterExclude))   (: V2 :)
        case element(securitySchemes) return ($n, $n/*/*/f:oasKeywordsRC(., $version, $nameFilter, $nameFilterExclude))        
        case element(variables) return ($n, $n/*/*/f:oasKeywordsRC(., $version, $nameFilter, $nameFilterExclude))
        case element(webhooks) return ($n, $n/*/*/f:oasKeywordsRC(., $version, $nameFilter, $nameFilterExclude))        
        
        (: Keywords which MAY be a map :)
        (: ... parameters - dependent on location an array or a map:
               - in Components Object or Link Object or Swagger Object (V2): a map
               - elsewhere (in PathItem Object, Operation Object): an array
         :)
        case element(parameters) return (
            $n, 
            if ($n/(parent::components, ../parent::links, parent::json)) then $n/*/*/f:oasKeywordsRC(., $version, $nameFilter, $nameFilterExclude)
            else $n/*/f:oasKeywordsRC(., $version, $nameFilter, $nameFilterExclude)
        )            
        
        (: Maps string-string - do not consider children :)        
        case element(mapping) return $n (: map: string -> string :)        
        case element(scopes) return $n (: map: string -> string :)
        
        (: Keywords with type Any - do not consider children :)
        case element(example) return $n
        case element(value) return $n
        
        (: Keyword 'security' :)
        case element(security) return $n   (: an array of objects with a single property '{name}' :)

        (: requestBody - if in Link Object, do not recurse deeper :)
        case element(requestBody) return (
            $n,
            if ($n/../parent::links) then () else
            $n/*/f:oasKeywordsRC(., $version, $nameFilter, $nameFilterExclude)
        )
        
        default return (
            $n, 
            if (starts-with(local-name($n), 'x-')) then () else
                $n/*/f:oasKeywordsRC(., $version, $nameFilter, $nameFilterExclude))
   
    return
        if (empty($nameFilter)) then $unfiltered else
        for $node in $unfiltered
        let $jname := $node/local-name() ! convert:decode-key(.) ! lower-case(.)
        where util:matchesPlusMinusNameFilters($jname, $nameFilter, $nameFilterExclude)
        return $node
};        


(:~
 : Returns the JSON Schema keywords found in OpenAPI document.
 :
 : @param oasNodes nodes from OpenAPI documents
 : @param names list of names or name patterns - return only matching keywords
 : @param namesExclude list of names or name patterns - do not return matching 
 :   keywords 
 : @return keyword elements contained by the OpenAPI documents
 :)
declare function f:oasJschemaKeywords($oasNodes as node()*,
                                      $names as xs:string?,
                                      $namesExcluded as xs:string?)
        as element()* {
    let $oasNodes := 
        $oasNodes ! (
          typeswitch(.) case document-node() return * 
          default return ancestor-or-self::*[last()])
    return
    
    $oasNodes/(
        definitions/*/*/f:jschemaKeywords(., $names, $namesExcluded),
        components/schemas/*/*/f:jschemaKeywords(., $names, $namesExcluded),
        f:oasMsgSchemas(.)/*/f:jschemaKeywords(., $names, $namesExcluded)
    )        
};

(:~
 : Returns the effective content of a JSON value: if it is an object containing
 : a reference, the reference is recursively resolved. Otherwise, the original
 : value is returned.
 :
 : This function can be used in order to integrate reference resolving into navigation.
 : Example: all payload schemas in an OpenAPI document may be collected like this:
 :
 :    $oas\paths\*\jeff()\(get, post, put, delete, options, head, patch, trace)
 :    \(
 :         (requestBody, responses\*)\jeff()\(content\schema, schema),
 :         parameters\_\jeff()[in eq 'body']\schema
 :    )
 :
 : @param value a JSON value
 : @return the resolved reference, if the value contains one, or the original value
 :)
declare function f:jsonEffectiveValue($value as element())
        as element()? {
    let $reference := $value/_0024ref return
    
    if (not($reference)) then $value else
        $reference ! f:resolveJsonRef(., ., 'single') ! f:jsonEffectiveValue(.)
};

(:~
 : Returns the schema objects describing the messages of an OpenAPI document.
 :
 : @param oas OpenAPI documents (root element or some other node)
 : @return the schema objects describing messages
 :)
declare function f:oasMsgSchemas($oas as node()*) {
    let $fn_soContent := function ($co) {$co/*/schema}
    let $fn_soParameters := function ($p) {$p/*[in eq 'body']/schema}
    let $fn_soRequestBody := function ($rb) {$rb/content/$fn_soContent(.)}
    let $fn_soResponseObject := function ($ro) {$ro/(schema, content/$fn_soContent(.))}
    let $fn_soPathItem := 
        function ($pi) {
            $pi/(get, post, put, delete, options, head, patch, trace)/(
                parameters/$fn_soParameters(.),
                requestBody/$fn_soRequestBody(.),
                responses/*/$fn_soResponseObject(.))}
    let $oas := $oas/root()/descendant-or-self::json[1]            
    return $oas/(
        paths/*/$fn_soPathItem(.),
        parameters/$fn_soParameters(.),
        responses/*/$fn_soResponseObject(.),
        components/(
            responses/*/$fn_soResponseObject(.),
            requestBodies/*/$fn_soRequestBody(.),
            pathItems/*/$fn_soPathItem(.)))    
};

(:~
 : Foxpath function `repeat#2'. Creates a string which is the concatenation of
 : a given number of instances of a given string.
 :
 : @param string the string to be repeated
 : @param count the number of repeats
 : @return the result of repeating the string
 :)
declare function f:repeat($string as xs:string?, $count as xs:integer?)
        as xs:string {
    string-join(for $i in 1 to $count return $string, '')
};      

(:~
 : Writes a collection of files into a folder.
 :
 : @param files the file URIs
 : @param dir the folder into which to write
 : @return 0 if no errors were observed, 1 otherwise
 :)
declare function f:write-files($files as item()*, 
                               $dir as xs:string?,
                               $encoding as xs:string?)
        as xs:integer {
    let $tocItems :=        
        for $file at $pos in $files
        let $file := 
            if ($file instance of attribute()) then string($file) else $file
        let $path :=
            if ($file instance of node()) then 
                let $raw := $file/root()/document-uri(.)
                return if ($raw) then $raw else concat('__file__', $pos)
            else $file        
        let $fname := replace($path, '^.+/', '')
        group by $fname
        return
            if (count($file) eq 1) then 
                <file name="{$fname}" path="{$path}"/>
            else
                <files originalName="{$fname}" count="{count($file)}">{
                    let $prePostfix := replace($fname, '(.+)(\.[^.]*$)', '$1~~~$2')
                    let $pre := substring-before($prePostfix, '~~~')
                    let $post := substring-after($prePostfix, '~~~')
                    for $f at $pos in $file
                    let $hereName := if ($pos eq 1) then $fname else concat($pre, '___', $pos, '___', $post)
                    return
                        <file originalName="{$fname}" name="{$hereName}" path="{$f}"/>
                }</files> 
    let $toc := <toc countFnames="{count($tocItems)}" countFiles="{count($files)}">{$tocItems}</toc>
    let $tocFname := concat($dir, '/', '___toc.write-files.xml')
    let $_ := file:write($tocFname, $toc)
    
    let $errors :=
        for $file at $pos in $files
        let $file := 
            if ($file instance of attribute()) then string($file) else $file
        let $path :=
            if ($file instance of node()) then 
                let $raw := $file/root()/document-uri(.)
                return if ($raw) then $raw else concat('__file__', $pos)
            else $file   
        let $fname := $toc//file[@path eq $path]/@name/string()
        let $fname_ := string-join(($dir, $fname), '/')        
        let $fileContent := 
            if ($file instance of node()) then serialize($file)
            else i:fox-unparsed-text($file, $encoding, ())        
        return
            try {
                trace(file:write-text($fname_, $fileContent) , concat('Write file: ', $fname_, ' '))
            } catch * {trace(1, concat('ERR:CODE: ', $err:code, ', ERR:DESCRIPTION: ', $err:description, ' - '))}
    return
        ($errors[1], 0)[1]
};

(:~
 : Writes a collection of json documents as json docs into a folder.
 :
 : @param files the file URIs
 : @param dir the folder into which to write
 : @return 0 if no errors were observed, 1 otherwise
 :)
declare function f:write-json-docs($files as xs:string*, 
                                   $dir as xs:string?,
                                   $encoding as xs:string?)
        as xs:integer {
    let $tocItems :=        
        for $file at $pos in $files
        let $file := 
            if ($file instance of attribute()) then string($file) else $file
        let $path :=
            if ($file instance of node()) then 
                let $raw := $file/root()/document-uri(.)
                return if ($raw) then $raw else concat('__file__', $pos)
            else $file        
        let $fnameOrig := replace($path, '^.+/', '')
        let $fname := 
            if ($file instance of node()) then $fnameOrig 
            else concat($fnameOrig, '.xml')
        group by $fnameOrig
        return
            if (count($file) eq 1) then 
                <file name="{$fname}" originalName="{$fnameOrig}" path="{$path}"/>
            else
                <files originalName="{$fnameOrig}" count="{count($file)}">{
                    let $prePostfix := replace($fnameOrig, '(.+)(\.[^.]*$)', '$1~~~$2')
                    let $pre := substring-before($prePostfix, '~~~')
                    let $post := substring-after($prePostfix, '~~~')
                    for $f at $pos in $file
                    let $name := 
                        let $raw :=
                            if ($pos eq 1) then $fnameOrig else 
                                concat($pre, '___', $pos, '___', $post)
                        return
                             if ($f instance of node()) then $raw else concat($raw, '.xml')
                    return
                        <file name="{$name}" originalName="{$fnameOrig[1]}" path="{$f}"/>
                }</files> 
    let $toc := <toc countFnames="{count($tocItems)}" countFiles="{count($files)}">{$tocItems}</toc>
    let $tocFname := concat($dir, '/', '___toc.write-json-docs.xml')
    let $_ := file:write($tocFname, $toc)
    
    let $errors :=
        for $file at $pos in $files
        let $file := 
            if ($file instance of attribute()) then string($file) else $file
        let $path :=
            if ($file instance of node()) then 
                let $raw := $file/root()/document-uri(.)
                return if ($raw) then $raw else concat('__file__', $pos)
            else $file   
        let $fname := $toc//file[@path eq $path]/@name/string()
        let $fname_ := string-join(($dir, $fname), '/')        
        let $fileContent := 
            if ($file instance of node()) then serialize($file)
            else 
                try {
                    let $fileContent := i:fox-unparsed-text($file, $encoding, ())
                    return
                        json:parse($fileContent) ! serialize(.)
                } catch * {trace((), 
                    concat('ERR:CODE: ', $err:code, ', ERR:DESCRIPTION: ', $err:description, ' - '))}
        where $fileContent                    
        return
            try {
                trace(file:write-text($fname_, $fileContent) , concat('Write file: ', $fname_, ' '))
            } catch * {trace(1, concat('ERR:CODE: ', $err:code, ', ERR:DESCRIPTION: ', $err:description, ' - '))}
    return
        ($errors[1], 0)[1]
(:        
    let $errors :=
        for $file in $files
        let $path := $file
        let $fname := replace($path, '^.+/', '')
        let $fname_ := trace(concat(string-join(($dir, $fname), '/'), '.xml') , 'PATH#: ')
        let $fileContent := f:fox-unparsed-text($file, $encoding, ())
        let $fileContentXml := json:parse($fileContent) ! serialize(.)
        return
            try {
                file:write-text($fname_, $fileContentXml)
            } catch * {1}
    return
        ($errors[1], 0)[1]
:)        
};

(:~
 : Constructs an element with content given by $content. Each pair of items in $atts
 : provides the name and value of an attribute to be added.
 :
 : @param content the element content
 : @param name the element name
 : @param atts attributes to be added
 : @return the constructed element
 :)
declare function f:xelement($name as xs:string, $content as item()*)
        as element() {
    let $atts := $content[. instance of attribute()]
    let $nonatts := $content[not(. instance of attribute())]
    return
        element {$name} {
            $atts,
            $nonatts
        }
};      

(:~
 : Constructs an element with content given by $content. Each pair of items in $atts
 : provides the name and value of an attribute to be added.
 :
 : @param content the element content
 : @param name the element name
 : @param atts attributes to be added
 : @return the constructed element
 :)
declare function f:xelement_old($content as item()*,
                            $name as xs:string,
                            $atts as item()*)
        as element() {
    element {$name} {
        for $attName at $pos in $atts[(position() + 1) mod 2 eq 0]
        let $attValue := $atts[$pos + 1]
        return
            attribute {$attName} {$attValue},
        $content            
    }
};      

(:~
 : Foxpath function `xwrap#3`. Collects the items of $items into an XML document.
 :
 : Sorting:
 : (1) if flag 's' is used: item representations are sorted by the string value of the item
 : (2) if flag 'S' is used: item representations are sorted by the string value of the item, case-insensitively
 : (3) otherwise no sorting is performed
 :
 : Before copying into the result document, every item from $items is processed as follows:
 : (A) if an item is a node:
 :   (1) if flag 'b' is set, a copy enhanced by an @xml:base attribute is created
 :   (2) if flag 'p' is set, a copy enhanced by a @fox:path attribute is created
 :   (3) if flag 'j' is set, a copy enhanced by a @fox:jpath attribute is created
 :   (4) if flag 'f' is set, the copy is "flattened" - child nodes are discarded  
 :   (4) if flag 'a' is set, the item is not modified if it is not an attribute;
 :       if it is an attribute, it is mapped to an element which has a name 
 :       equal to the name of the parent of the attribute, and which contains a 
 :       copy of the attribute 
 :   (5) if flag 'A' is set, treatment as with flag 'a', but the constructed element
 :       has no namespace URI 
 :   (6) otherwise, the item is not modified

 : (B) if an item is atomic: 
 :   (1) if flag 'd' is set, the item is interpreted as URI and it is attempted to be
 :       parsed into a document, with an @xml:base attribute added to the root element,
 :       if flag 'b' is set, and without @xml:base otherwise; if parsing fails, a 
 :       <PARSE-ERROR> element is created with the item value as content
 :   (2) if flag 'w' is set, the item is interpreted as URI and the text found at
 :       this URI is retrieved and wrapped in an element with an @xml:base attribute
 :       element name given by parameter $name2, default _text_
 :   (3) if flag 't' is set, the item is interpreted as URI and the text found at 
 :       this URI is retrieved (not wrapped in an element)
 :   (4) if flag 'c' is set, the item is treated as a text and wrapped in an element;
 :       element name given by parameter $name2, default _text_
 :   (5) if none of the flags 'd', 'w', 't', 'c' is set: the item is not modified 
 :
 : @param items the items from which to create the content of the result document
 : @param name the name of the root element of the result document
 : @param flags flags controlling the representation of the items and possible sorting
 : @param name2 the name of inner wrapper elements, wrapping an individual item (only in case of flags c and w)
 : @param options foxpath processing options
 : @return the result document
 :)
declare function f:xwrap($items as item()*, 
                         $name as xs:QName, 
                         $flags as xs:string?, 
                         $name2 as xs:QName?, $options as map(*)?) 
        as element()? {
    (: name2 is the name of inner wrapper elements, wrapping an individual item :)
    let $name2 := if (empty($name2)) then '_text_' else $name2   
    
    let $sortRule := if (contains($flags, 's')) then 's' else if (contains($flags, 'S')) then 'S' else ()        
    let $val :=
        for $item in $items 
        order by if ($sortRule eq 's') then $item else if ($sortRule eq 'S') then lower-case($item) else ()
        return 

        typeswitch($item)
        
        (: item a node => copy item :)        
        case element() | attribute() | document-node() return
            let $item := if ($item/self::document-node()) then $item/* else $item
            let $additionalAtts := (
                if (not(contains($flags, 'b'))) then () else
                    attribute xml:base {$item/base-uri(.)},
                if (not(contains($flags, 'p'))) then () else
                    attribute path {$item/f:namePath(., 'name', ())},
                if (not(contains($flags, 'j'))) then () else
                    attribute jpath {$item/f:namePath(., 'jname', ())}
            )
            let $atts :=
                if (empty($additionalAtts) or empty($item/@*)) then $item/@*
                else
                    let $additionalAttNames := $additionalAtts ! node-name(.)
                    return $item/@*[not(node-name() = $additionalAttNames)]
            let $namespaces :=
                if (not($item/self::element())) then () else
                    for $prefix in in-scope-prefixes($item)[string()] return
                        namespace {$prefix} {namespace-uri-for-prefix($prefix, $item)}
            return
                (: Flags aA - attribute item is turned into an element :)
                if (contains($flags, 'a') or contains($flags, 'A')) then    
                    if (not($item/self::attribute())) then $item
                    else 
                        let $elemName := $item/../(
                            if (contains($flags, 'A')) then local-name(.)
                            else QName(namespace-uri(.), local-name(.)))
                        return element {$elemName} {$namespaces, $additionalAtts, $item}
                        
                (: Flag f - discard child nodes :)
                else if (contains($flags, 'f')) then
                    element {node-name($item)} {$namespaces, $additionalAtts, $atts}
                    
                (: With additional attributes :)
                else if (not($additionalAtts)) then $item
                
                (: Plain copy :)
                else
                    $item/element {node-name(.)} {$namespaces, $additionalAtts, $atts, node()}
                
        (: item a URI, flag 'd' => parse document at that URI :)
        default return
            if (contains($flags, 'd')) then
                let $doc := try {i:fox-doc($item, $options)/*} catch * {()}
                return if (not($doc)) then <PARSE-ERROR uri="{$item}"/> else
 
                if (contains($flags, 'b')) then
                    let $xmlBase := if ($doc/@xml:base) then () else attribute xml:base {$item}
                    return
                        if (not($xmlBase)) then $doc else
                            element {node-name($doc)} {
                                $doc/@*, $xmlBase, $doc/node()
                                    }
                else $doc
                    
            (: item a URI, flag 'w' => read text at that URI, write it into a wrapper element :)                    
            else if (contains($flags, 'w')) then
                let $text := try {i:fox-unparsed-text($item, (), $options)} catch * {()}
                return
                    if ($text) then element {$name2} {attribute xml:base {$item}, $text}
                    else <READ-ERROR uri="{$item}"/>
                
            (: item a URI, flag 't' => read text at that URI, copy it into result :)                
            else if (contains($flags, 't')) then
                let $text := try {i:fox-unparsed-text($item, (), $options)} catch * {()}
                return
                    if ($text) then $text
                    else <READ-ERROR uri="{$item}"/>
                
            (: flag 'c' => wrap item in an element :)                
            else if (contains($flags, 'c')) then
                element {$name2} {$item}
            
            else $item
            
    (: Write wrapper :)            
    let $namespaces :=  
        for $nn in f:extractNamespaceNodes($val[. instance of element()])
        group by $prefix := name($nn)
        let $nn1:= $nn[1]
        where $prefix ne 'xml' and $nn1
        return $nn1
    return
        element {$name} {
            $namespaces,        
            attribute countItems {count($val)},
            $val
        }
};

(:~
 : Returns for a given element all namespace bindings as strings
 : prefix=uri. The bindings are ordered by lowercase prefixes,
 : then lowercase URIs.
 :
 : @param elem the element to be observed
 : @return strings representing namespace bindings
 :)
declare function f:in-scope-namespaces($item as item()) 
        as xs:string+ {        
    let $elem :=
        typeswitch($item)
        case $doc as document-node() return $doc/*
        case $elem as element() return $elem
        case $node as node() return $node/..
        case $uri as xs:anyAtomicType return doc($uri)/*
        default return error()
        
    for $prefix in in-scope-prefixes($elem)
    order by $prefix
    return concat($prefix, '=', namespace-uri-for-prefix($prefix, $elem))
};    

(:~
 : Returns for a given element all namespace bindings as strings
 : prefix=uri. The bindings are ordered by lowercase prefixes,
 : then lowercase URIs.
 :
 : @param elem the element to be observed
 : @return strings representing namespace bindings
 :)
declare function f:in-scope-namespaces-descriptor($item as item()) 
        as xs:string+ {        
    f:in-scope-namespaces($item) => string-join(', ')
};    

(:~
 : Transforms a string by reversing character replacements used by 
 : the BaseX JSON representation (conversion format 'direct') for 
 : representing the names of object members.
 :
 : @param item a string
 : @return the result of character replacements reversed
 :)
declare function f:unescape-json-name($item as item()) as xs:string { 
    string-join(
        analyze-string($item, '_[0-9a-f]{4}')/*/(typeswitch(.)
        case element(fn:match) return substring(., 2) ! concat('"\u', ., '"') ! parse-json(.)
        default return replace(., '__', '_')), '')
};

(:~
 : Resolves a link to a resource. If $mediatype is specified, the
 : XML or JSON document is returned, otherwise the document text.
 :
 : @param node node containing the link
 : @param mediatype mediatype expected
 : @return the resource, either as XDM root node, or as text
 :)
declare function f:resolve-link($node as node(), $mediatype as xs:string?)
        as item()? {
    let $base := $node/ancestor-or-self::*[1]        
    let $uri := 
        if ($base) then resolve-uri($node, $base/base-uri(.))
        else resolve-uri($node)
    return
        if ($mediatype eq 'xml') then
            if (doc-available($uri)) then doc($uri)
            else ()
        else if (not(unparsed-text-available($uri))) then ()
        else
            let $text := unparsed-text($uri)
            return
                if ($mediatype eq 'json') then try {json:parse($text)} catch * {()}
                else $text
};        

(:~
 : Returns the child element names of a node. If $concat is true, the sorted names are 
 : concatenated, using ', ' as separator. Otherwise the names are returned
 : as a sequence. Dependent on $nameKind, the local names (lname), the JSON
 : names (jname) or the lexical names (name) are returned. Names are sorted.
 :
 : When using $namePattern, only those child elements are considered which have
 : a local name matching the pattern.
 :
 : Example: .../foo/child-names(., ', ', false(), '*put')
 : Example: .../foo/child-names(., ', ', false(), 'input|output') 
 :
 : @param nodes nodes (only elements contribute to the result)
 : @param concat if true, the names are concatenated
 : @param nameKind one of "name", "lname" or "jname" 
 : @param namePatterns optional name patterns selecting child names to be considered
 : @param excludedNamePattern optional name patterns selecting child elements to be ignored
 : @return the names as a sequence, or as a concatenated string
 :)
declare function f:child-names($nodes as node()*, 
                               $concat as xs:boolean?, 
                               $nameKind as xs:string?,   (: name | lname | jname :)
                               $namePatterns as xs:string?,
                               $excludedNamePatterns as xs:string?,
                               $nosort as xs:boolean?)
        as xs:string* {
    let $nameRegexes := $namePatterns 
                      ! tokenize(.)
                      ! replace(., '\*', '.*') ! replace(., '\?', '.') 
                      ! concat('^', ., '$')        
    let $excludedNameRegexes := 
                      $excludedNamePatterns
                      ! tokenize(.)
                      ! replace(., '\*', '.*') ! replace(., '\?', '.') 
                      ! concat('^', ., '$')
    let $separator := ', '[$concat]

    for $node in $nodes
    let $items := $node/*
       [empty($nameRegexes) or (some $nameRegex in $nameRegexes satisfies 
         matches(local-name(.), $nameRegex, 'i'))]
       [empty($excludedNameRegexes) or not(
         some $excludedNameRegex in $excludedNameRegexes satisfies 
            matches(local-name(.), $excludedNameRegex, 'i'))]
    let $names := 
        if ($nameKind eq 'lname') then 
            ($items/local-name(.)) => distinct-values()
        else if ($nameKind eq 'jname') then 
            ($items/convert:decode-key(local-name(.))) => distinct-values()
        else ($items/name(.)) => distinct-values()
    let $names := if ($nosort) then $names else $names => sort()        
    let $path :=        
        if (exists($separator)) then string-join($names, $separator)
        else $names
    order by $path        
    return
        $path
};        

(:~
 : Returns the descendant element names of a node. If $separator is specified, the sorted
 : names are concatenated, using this separator, otherwise the names are returned
 : as a sequence. If $localNames is true, the local names are returned, otherwise the 
 : lexical names. 
 :
 : When using $namePattern, only those descendant elements are considered which have
 : a local name matching the pattern.
 :
 : Example: .../foo/descendant-names(., ', ', false(), '*put')
 : Example: .../foo/descendant-names(., ', ', false(), 'input|output') 
 :
 : @param node a node (unless it is an element, the function returns the empty sequence)
 : @param separator if used, the names are concatenated, using this separator
 : @param localNames if true, the local names are returned, otherwise the lexical names 
 : @param namePattern an optional name pattern filtering the descendant elements to be considered
 : @return the names as a sequence, or as a concatenated string
 :)
declare function f:descendant-names(
                             $node as node(), 
                             $concat as xs:boolean?, 
                             $nameKind as xs:string?,   (: name | lname | jname :)
                             $namePattern as xs:string?,
                             $excludedNamePattern as xs:string?)
        as xs:string* {
    let $nameRegex := $namePattern ! replace(., '\*', '.*') ! replace(., '\?', '.') 
                      ! concat('^', ., '$')        
    let $excludedNameRegex := $excludedNamePattern ! replace(., '\*', '.*') ! replace(., '\?', '.') 
                      ! concat('^', ., '$')        
    let $items := $node//*
       [not($nameRegex) or matches(local-name(.), $nameRegex, 'i')]
       [not($excludedNameRegex) or not(matches(local-name(.), $excludedNameRegex, 'i'))]
    let $separator := ', '[$concat]
    let $names := 
        if ($nameKind eq 'lname') then 
            ($items/local-name(.)) => distinct-values() => sort()
        else if ($nameKind eq 'jname') then 
            ($items/f:unescape-json-name(local-name(.))) => distinct-values() => sort()
        else ($items/name(.)) => distinct-values() => sort()
    return
        if (exists($separator)) then string-join($names, $separator)
        else $names
};        

(:~
 : Copies a file to a target URI. The target URI may be a folder URI or a file URI.
 :
 : Options:
 : overwrite ( or o) - copy overwrites existing file
 : create (or c)     - if target folder does not exist, it is created 
 :
 : @param node a node
 : @param localName if true, the local name is returned, otherwise the lexical name
 : @return the parent name
 :)
declare function f:fileCopy($fileUri as xs:string,
                            $targetUri as xs:string,
                            $options as map(xs:string, item()*)?)
        as empty-sequence() {
    let $fileUriDomain := i:uriDomain($fileUri, ())
    return
        if (not($fileUriDomain eq 'FILE_SYSTEM')) then 
            error(QName((), 'INVALID_CALL'),
                concat('Function file-copy() expects a source file from the ',
                  'file system; file URI: ', $fileUri))
            else

    let $targetUriDomain := i:uriDomain($targetUri, ())
    return
        if (not($targetUriDomain eq 'FILE_SYSTEM')) then 
            error(QName((), 'INVALID_CALL'),
                concat('Function file-copy() expects a target folder in the ',
                  'file system; target dir URI: ', $targetUri))
            else
            
    if (i:fox-file-exists($targetUri, ())) then
        if (i:fox-is-file($targetUri, ()) and not($options?overwrite)) then
             error(QName((), 'INVALID_CALL'), concat('Target file exists; use option "overwrite" ',
                 'if you want to overwrite existing files; file URI: ', $targetUri))
        else file:copy($fileUri, $targetUri)
    else
        let $targetParentUri := trace(file:parent($targetUri) , '___TARGET_PARENT_URI: ')
        let $_CRETE := 
            if (i:fox-file-exists($targetParentUri, ())) then ()
            else if (not($options?create)) then
                error(QName((), 'INVALID_CALL'), concat('Target directory does not ',
                    'exists; use option "create" if you want automatic creation of ',
                    'a non-existent target dir; target dir URI: ', $targetParentUri))
            else file:create-dir($targetParentUri)
        return
            file:copy($fileUri, $targetUri)
                
(:                
                if (not(i:fox-file-exists(file:parent($targetUri))) then file:copy($
    let $targetFileExists :=
        $targetResourceExists and (
            i:fox-is-file($targetUri, ()) or
            i:fox-file-exists($targetUri||'/'||file:name($fileUri), ()))
    let $_CHECK := (
        if (not($targetFileExists) or $options?overwrite) then () 
        else
            error(QName((), 'INVALID_CALL'), concat('Target file exists; use option "overwrite" ',
                'if you want to overwrite existing files; file URI: ', $targetUri))
        ,                
        
    if (i:fox-file-exists($targetUri, ())) then
        let $_CHECK :=
            if (i:fox-is-dir($targetDirUri)) then
                let $targetFileUri := $targetUri || '/' || file:name($fileUri)
                return
                    if (i:fox-file-exists($targetFileUri, .)) then
                if ($options?overwrite) then ()
                else
                    error(QName((), 'INVALID_CALL'), concat('Target file exists; use option "overwrite" ',
                        'if you want to overwrite existing files; file URI: ', $targetUri))
                        
        return
            file:copy($fileUri, $targetUri)
                
    else            
    let $_CREATE_DIR :=
        let $targetDirExists := i:fox-file-exists($targetDirUri, ())    
        return
            if ($targetDirExists) then ()
            else if ($options?create) then file:create-dir($targetDirUri)
            else
                error(QName((), 'INVALID_CALL'), concat('Target directory does not ',
                    'exists; use option "create" if you want automatic creation of ',
                    'a non-existent target dir; target dir URI: ', $targetDirUri))
    let $_CHECK_OVERWRITE :=
        if ($options?overwrite) then ()
        else if (not(i:fox-file-exists($targetDirUri || '/' || file:name($fileUri), ()))) then ()
        else
            error(QName((), 'INVALID_CALL'), concat('Target file exists; use option "overwrite" ',
                'if you want to overwrite existing files; file URI: ', $fileUri))
    return
        file:copy($fileUri, $targetDirUri)
:)        
};        

(:~
 : Returns the parent name of a node. If $localNames is true, the local name is returned, 
 : otherwise the lexical names. 
 :
 : @param node a node
 : @param localName if true, the local name is returned, otherwise the lexical name
 : @return the parent name
 :)
declare function f:parent-name($node as node(),
                               $nameKind as xs:string?)   (: name | lname | jname :)
        as xs:string* {
    let $item := $node/..
    let $name := if ($nameKind eq 'lname') then $item/local-name(.)
                 else if ($nameKind eq 'jname') then $item/f:unescape-json-name(local-name(.))
                 else $item/name(.)
    return
        $name
};        

(:~
 : Returns the median value of a set of numeric values
 :
 : @param values the values
 : @return the median value
 :)
declare function f:median($values as xs:anyAtomicType*)
        as xs:anyAtomicType {
    let $count := count($values)
    return
        if ($count eq 1) then $values else
        
        let $sorted := $values => sort()
        let $half := $count div 2
        return
            if ($half eq ceiling($half)) then 
                0.5 * ($sorted[$half] + $sorted[$half + 1])
            else $sorted[ceiling($half)]            
};

(:~
 : Returns those atomic items which are in the left value, but not in the right one. 
 :
 : @param leftValue a value
 : @param rightValue another value 
 : @return the items in the left value, but not the right one
 :)
declare function f:leftValueOnly($leftValue as item()*,
                                 $rightValue as item()*)
    as item()* {
    $leftValue[not(. = $rightValue)] => distinct-values()
};

(:~
 : Returns for a sequence of documents for each document those data paths which are not contained
 : in all other documents.
 :
 : @param docs a sequence of documents or document URIs
 : @param counts a whitespace separated list of options;
 :   count - do not display paths, only counts
 : @return a structured representation of data paths not used by all documents
 :)
declare function f:pathCompare($items as item()*,
                               $nameKind as xs:string?,
                               $options as xs:string?)
        as item()? {
    let $options := $options ! tokenize(.) ! lower-case(.)
    
    let $nameKind := ($nameKind, 'lname')[1]
    let $docs :=
        for $item in $items return
            if ($item instance of node()) then $item
            else i:fox-doc($item, ())
    let $count := count($docs)
    return
        if ($count lt 2) then () else
    
    let $pathArrays := 
        for $doc at $pos in $docs
        let $paths := $doc/f:allDescendants(.)/f:namePath(., $nameKind, ()) => distinct-values() => sort()
        return array{$paths}
        
    let $commonPaths := util:atomIntersection($pathArrays)
    let $pathsMap := map:merge(
        for $doc at $pos in $docs
        let $paths := $doc/f:allDescendants(.)/f:namePath(., $nameKind, ()) => distinct-values() => sort()
        return map:entry($pos, $paths)
    )
    let $deviations :=    
        for $i in 1 to $count
        let $paths := $pathArrays[$i] ! array:flatten(.)
        let $pathsNotCommon := $paths[not(. = $commonPaths)]
        return
            if (empty($pathsNotCommon)) then () else
            <document nr="{$i}">{
                $docs[$i]/base-uri(.) ! attribute uri {.},
                <pathsNotInAll count="{count($pathsNotCommon)}">{
                    if ($options = 'counts') then () else
                    ($pathsNotCommon => sort()) ! <path p="{.}"/>
                }</pathsNotInAll>            
            }</document>
    return
        if (empty($deviations)) then ()
        else
            <deviations>{
                $deviations
            }</deviations>
};

(:~
 : Returns the paths leading from a context node to all descendants. This may be
 : regarded as a representation of the node's content, hence the function name.
 :
 : @param context a node
 : @param nameKind the kind of name used as path steps: 
 :   jname - JSON names; lname - local names; name - lexical names
 : @param includedNames name patterns of nodes which must be present in the path 
 : @param excludedNames name patterns of nodes excluded from the content 
 : @param excludedNodes nodes excluded from the content 
 : @return the parent name
 :)
declare function f:pathContent($context as node()*, 
                               $nameKind as xs:string?,
                               $alsoInnerNodes as xs:boolean?,
                               $includedNames as xs:string?,
                               $excludedNames as xs:string?,
                               $excludedNodes as node()*)
        as xs:string* {
            
    let $descendants := (
        if ($nameKind eq 'jname') then $context/descendant::*
        else $context/(@*, descendant::*/(., @*))
    )[$alsoInnerNodes or not(*)]
    
    let $includedNamesRegex :=
        $includedNames ! tokenize(.)
        ! replace(., '\*', '.*')
        ! replace(., '\?', '.')
        ! concat('^', ., '$')

    let $excludedNamesRegex :=
        $excludedNames ! tokenize(.)
        ! replace(., '\*', '.*')
        ! replace(., '\?', '.')
        ! concat('^', ., '$')

    let $includedNodes :=
        if (empty($includedNamesRegex)) then ()
        else if ($nameKind eq 'jname') then
            $descendants[name() ! convert:decode-key(.) ! (some $r in $includedNamesRegex satisfies matches(., $r, 'i'))]
        else
            $descendants[local-name(.) ! (some $r in $includedNamesRegex satisfies matches(., $r, 'i'))]
    
    let $excludedNodes := (
        $excludedNodes,
        
        if (empty($excludedNamesRegex)) then ()
        else if ($nameKind eq 'jname') then
            $descendants[name() ! convert:decode-key(.) ! (some $r in $excludedNamesRegex satisfies matches(., $r, 'i'))]
        else
            $descendants[local-name(.) ! (some $r in $excludedNamesRegex satisfies matches(., $r, 'i'))]
    )
    let $descendants2 :=
        if (empty($includedNamesRegex)) then $descendants
        else $descendants[ancestor-or-self::* intersect $includedNodes]
        
    let $descendants3 := 
        if (empty($excludedNodes)) then $descendants2
        else $descendants2[not(ancestor-or-self::* intersect $excludedNodes)]
    
    for $d in $descendants3 return
    let $ancos := $d/ancestor-or-self::node()[. >> $context]
    let $steps :=        
        if ($nameKind eq 'lname') then 
            $ancos/concat(self::attribute()/'@', local-name(.))
        else if ($nameKind eq 'jname') then 
            $ancos/concat(self::attribute()/'@', 
                let $raw := f:unescape-json-name(local-name(.))
                return if (not(contains($raw, '/'))) then $raw else concat('"', $raw, '"')
            )
        else $ancos/concat(self::attribute()/'@', name(.))
    return string-join($steps, '/')
};        

(:~
 : Returns the percent value of a fraction
 :
 : The nominator is the first item of $values.
 : The denominator is $value2, if not empty, or the second item of $values, otherwise.
 :
 : @param values either one or several values
 : @param value2 the denominator
 : @param fractionDigits number of fraction digits
 : @return the quotient as percent value
 :)
declare function f:percent($values as xs:numeric*, $value2 as xs:numeric?, $fractionDigits as xs:integer?)
        as xs:numeric? {
    let $fd := ($fractionDigits, 1) [1]
    let $value1 := $values[1]
    let $value2 := ($value2, $values[2])[1]
    let $percent := ($value1 div $value2 * 100) => round($fd)
    return $percent
};

(:~
 : Returns the parent name of a node. If $localNames is true, the local name is returned, 
 : otherwise the lexical names. 
 :
 : @param node a node
 : @param localName if true, the local name is returned, otherwise the lexical name
 : @return the parent name
 :)
declare function f:namePath($nodes as node()*, 
                            $nameKind as xs:string?,   (: name | lname | jname :) 
                            $numSteps as xs:integer?)
        as xs:string* {
    for $node in $nodes return
    
    (: _TO_DO_ Remove hack when BaseX Bug is removed; return to: let $nodes := $node/ancestor-or-self::node() :)        
    let $ancos := 
        let $all := $node/ancestor-or-self::node()
        let $dnode := $all[. instance of document-node()]
        return ($dnode, $all except $dnode)
    let $steps := 
        
        if ($nameKind eq 'lname') then 
            $ancos/concat(self::attribute()/'@', local-name(.))
        else if ($nameKind eq 'jname') then 
            $ancos/concat(self::attribute()/'@', 
                let $raw := f:unescape-json-name(local-name(.))
                return if (not(contains($raw, '/'))) then $raw else concat('"', $raw, '"')
            )
        else 
            $ancos/concat(self::attribute()/'@', name(.))
    let $steps := if (empty($numSteps)) then $steps else subsequence($steps, count($steps) + 1 - $numSteps)
    return string-join($steps, '/')
};        

(:~
 : Returns the local name of a lexical QName.
 :
 : @param name a lexical QName
 : @return the name with the prefix removed
 :)
declare function f:remove-prefix($name as xs:string?)
        as xs:string? {
    $name ! replace(., '^.+:', '')
};        

(:~
 : Returns those atomic items which are in the right value, but not in the left one. 
 :
 : @param leftValue a value
 : @param rightValue another value 
 : @return the items in the right value, but not the left one
 :)
declare function f:rightValueOnly($leftValue as item()*,
                                  $rightValue as item()*)
    as item()* {
    $rightValue[not(. = $leftValue)]  => distinct-values()
};

(:~
 : Truncates a string if longer than a maximum length, appending '...'.
 :
 : @param name a lexical QName
 : @return the name with the prefix removed
 :)
declare function f:truncate($string as xs:string?, $len as xs:integer, $flag as xs:string?)
        as xs:string? {
    $string ! substring($string, 1, $len) || ' ...'[string-length($string) gt $len]
};        

declare function f:hlistEntry($items as item()*)
        as xs:string {
    let $sep := codepoints-to-string(30000)
    return
        string-join($items, $sep)
};

(:~
 : Transforms a sequence of value into an indented list. Each value is a concatenated 
 : list of items from subsequent levels of hierarchy. Example:
 :
 : foo#bar
 : foo#bar2#bar3
 : foo#zoo#zoo2
 : boo#len
 : zoo
 : =>
 : foo
 : . bar2
 : . . bar3
 : . zoo
 . . . zoo2
 . boo
 . . len
 . zoo
 :)
declare function f:hlist($values as xs:string*, 
                         $headers as xs:string*,
                         $emptyLines as xs:string?)
        as xs:string {
    let $sep := codepoints-to-string(30000) (:  ($sep, '#')[1] :)        
    let $values := $values[string(.)] => sort()    
    let $emptyLineFns :=
        if (not($emptyLines)) then ()
        else
            map:merge(
                for $i in 1 to string-length($emptyLines)
                let $lineCount := substring($emptyLines, $i, 1) ! xs:integer(.)
                where $lineCount
                return
                    map:entry($i - 1, function() {for $j in 1 to $lineCount return ''})
            )                    
            
    return
        let $lines := f:hlistRC(0, $values, $sep, $emptyLineFns)
        return (
            if (empty($headers)) then () else 
                let $maxLen := min(( (($lines ! string-length(.) => max()), 80)[1], 100))
                let $sepline := string-join(for $i in 1 to $maxLen return '=', '')
                return (
                    $sepline,        
                    for $header at $pos in $headers
                    let $prefix := (for $i in 1 to $pos - 1 return '.  ') => string-join('')
                    return $prefix || $header,
                    $sepline,
                    ''                    
                ),
            $lines) => string-join('&#xA;')
};

declare function f:hlistRC($level as xs:integer, 
                           $values as xs:string*, 
                           $sep as xs:string,
                           $emptyLineFns as map(*)?)
        as xs:string* {
    let $prefix := (for $i in 1 to $level return '.  ') => string-join('')
    return
        if (not(some $value in $values satisfies contains($value, $sep))) then 
            for $value in $values
            group by $v := $value
            let $suffix := count($value)[. ne 1] ! concat(' (', ., ')')
            let $parts := tokenize($v, '~~~')
            return 
                if (count($parts) eq 1) then $prefix || $v || $suffix
                else
                    for $part in $parts
                    return $prefix || $part
        else
            for $value in $values
            (: group by $groupValue := (substring-before($value, $sep)[string()], $value)[1] :)
            group by $groupValue := replace($value, '(^.*?)' || $sep || '.*', '$1', 's')
            let $contentValue := $value ! substring-after(., $sep)[string()]           
            order by $groupValue
            let $parts := tokenize($groupValue, '~~~')
            return (
                if (count($parts) eq 1) then concat($prefix, $groupValue)
                else for $part in $parts return ($prefix || $part),
                f:hlistRC($level + 1, $contentValue, $sep, $emptyLineFns),
                $emptyLineFns ! map:get(., $level) ! .()
                (:''[$level eq 0] :)
            )
};


(:~
 :
 : ===    J S O N   r e l a t e d ===
 :
 :)

(:~
 : Resolves a JSON reference to a set of JSON objects. The reference is
 : a JSON Pointer (https://tools.ietf.org/html/rfc6901).
 :
 : Parameter 'mode' controls the mode of resolving:
 : mode=recursive - the reference is resolved recursively, 
 :                  only the final result is returned;
 : mode=recursive-collecting' - 
                    the reference is resolved recursively, 
 :                  all referenced values are returned;
 : mode=single -    the reference is resolved once, no recursive resolving 
 :
 : Default mode: recursive
 :
 : @param reference the reference string
 : @param doc a node from the document used as congtext
 : @param mode mode of resolve - one of 'recursive', 'recursive-collecting', 'single' 
 : @return the referenced schema object, or the empty string if no such object is found
 :)
declare function f:resolveJsonRef($reference as xs:string?, 
                                  $doc as element(),
                                  $mode as xs:string?)
        as element()* {
    if (not($reference)) then () else

    let $mode := ($mode, 'recursive')[1]
    return f:resolveJsonRefRC($reference, $doc, $mode, (), ())
};

declare function f:resolveJsonRefRC(
                          $reference as xs:string?, 
                          $doc as element(),
                          $mode as xs:string?,
                          $visited as element()*,
                          $referencing as element()?)
        as element()* {
    let $doc := $doc/ancestor-or-self::*[last()]
    let $withFragment := contains($reference, '#')
    let $resource := 
        if ($withFragment) then substring-before($reference, '#') else $reference
    let $path :=
        if ($withFragment) then replace($reference, '.*?#/', '') else ()
    let $context :=
        if (not($resource)) then $doc else
            try {
                resolve-uri($resource, $doc/base-uri(.)) 
                ! json:doc(.)/*
            } catch * {
                (: Second try - replace '-' with '/' in base URI;
                   motivation: maybe this document has been downloaded to a file
                   with a name obtained by replacing in an internet address
                   / with - :)
                let $baseUri2 := $doc/base-uri(.) ! replace(., '-', '/')
                return
                    try {
                        let $baseUri2 := $doc/base-uri(.) ! replace(., '-', '/')
                        let $dirPart := replace($baseUri2, '/[^/]+$', '')
                        let $uri := resolve-uri($resource, $baseUri2)
                        let $uriAdjusted := replace($uri, $dirPart||'/', $dirPart||'-')
                        return json:doc($uriAdjusted)/*
                    } catch * {
                        trace((), '___WARNING - CANNOT RESOLVE REFERENCE: ' || $reference ||
                              ' ; CONTEXT: ' || $doc/base-uri(.))
                    }                     
            }
    where $context            
    return   
        if (not($path)) then $context else
            let $steps := tokenize($path, '\s*/\s*')
            let $target := f:resolveJsonRefSteps($steps, $context)
            return 
                if ($mode eq 'single') then $target
                else if ($target intersect $visited) then 
                    (: 'recursive' mode - return referencing object :)
                    if ($mode eq 'recursive') then $referencing else ()                
                else
                    if ($target/_0024ref) then (
                        $target[$mode eq 'recursive-collecting'], 
                        $target/_0024ref/f:resolveJsonRefRC(., $doc, $mode, ($visited, $target), ..)
                        )/.   (: Remove duplicates :)
                    else $target
};

(:~
 : Recursive helper function of 'resolveJsonRef'.
 :
 : @param steps the steps of the path (JSON Pointer steps)
 : @param context the context in which to resolve the path
 : @return the targets addressed by the path
 :)
declare function f:resolveJsonRefSteps($steps as xs:string+, 
                                       $context as element()*)
        as element()* {
    let $head := head($steps)
    let $tail := tail($steps)
    let $refToken := $head 
                     ! web:decode-url(.)
                     ! replace(., '~1', '/') 
                     ! replace(., '~0', '~')
    let $elem :=
        if ($context/@type eq 'array') then
            if (matches($refToken, '^\d+$')) then $context/_[1 + xs:integer($refToken)]
            else () (: Invalid JSON Pointer syntax :)
        else 
            let $elemName := $refToken ! convert:encode-key(.)
            return $context/*[name() eq $elemName]
    return
        if (not($elem)) then ()
        else if (empty($tail)) then $elem
        else f:resolveJsonRefSteps($tail, $elem)
};

(:~
 : Resolves an XSD type reference to the referenced type definition.
 :)
declare function f:resolveXsdTypeRef($reference as attribute(type), 
                                     $schema as element(xs:schema)?)
        as element()? {
    if (not($reference)) then () else
    
    let $schema := ($schema, $reference/ancestor::xs:schema[1])[1]
    let $refQname := $reference/resolve-QName(., ..)
    let $refNs := string(namespace-uri-from-QName($refQname))
    let $refName := local-name-from-QName($refQname)
    let $result := f:resolveXsdTypeRefRC($refNs, $refName, $schema, (), (), ())
    return $result[self::xs:simpleType, xs:complexType][1]
};

declare function f:resolveXsdTypeRefRC($refNs as xs:string,
                                       $refName as xs:string,
                                       $schema as element(xs:schema),
                                       $schemasSameLevel as element(xs:schema)*,
                                       $chameleonNs as xs:string?,
                                       $visited as element(xs:schema)*)
        as element()? {
    if ($visited intersect $schema) then $visited else
    
    let $tns := ($schema/@targetNamespace, $chameleonNs, '')[1]
    let $typeDefHere :=
        if ($refNs ne $tns) then () else
            $schema/(xs:simpleType, xs:complexType)[@name eq $refName]            
    return
        if ($typeDefHere) then $typeDefHere else

            let $visitedNew := ($visited, $schema)
            let $resultSSL := 
                if (not($schemasSameLevel)) then () else
                    f:resolveXsdTypeRefRC($refNs, $refName, 
                        head($schemasSameLevel), tail($schemasSameLevel), $chameleonNs, $visitedNew)
            let $typeDefSSL := $resultSSL[self::xs:simpleType, self::xs:complexType]
            return
                if ($typeDefSSL) then $typeDefSSL
                else                
                    let $visitedNew := ($visitedNew, $resultSSL)
                    let $schemaLocationsNextLevel :=
                        if ($tns eq $refNs) then $schema/xs:include/@schemaLocation
                        else $schema/xs:import[@namespace eq $tns]/@schemaLocation
                    let $schemasNextLevel := 
                        $schemaLocationsNextLevel/resolve-uri(., ..)
                        ! (try {doc(.)} catch * {()})
                        [not(. intersect $visited)]
                    let $resultSNL := 
                        if (not($schemasNextLevel)) then () else
                            f:resolveXsdTypeRefRC($refNs, $refName, 
                                head($schemasNextLevel), tail($schemasNextLevel), $tns, $visitedNew)
                    return $resultSNL                                
};        

(:~
 : Resolves a JSON Schema allOf group. Returns all subschemas, with schema
 : references recursively resolved and allOf subschemas recursively replaced
 : by their subschemas.
 :
 : @param allOf a JSON Schema allOf keyword
 : @return the subschemas, recursively resolved
 :)
declare function f:resolveJsonAllOf($allOf as element())
        as element()* {
    for $subschema in $allOf/_        
    return
        if ($subschema[_0024ref]) then 
            let $effective := f:jsonEffectiveValue($subschema)
            return
                if ($effective/allOf) then $effective/allOf/f:resolveJsonAllOf(.)
                else $effective
        else if ($subschema/_allOf) then $subschema/allOf/f:resolveJsonAllOf(.)
        else $subschema
};

(:~
 : Resolves a JSON Schema anyOf group. Returns all subschemas, with schema
 : references recursively resolved and anyOf subschemas recursively replaced
 : by their subschemas.
 :
 : @param allOf a JSON Schema allOf keyword
 : @return the subschemas, recursively resolved
 :)
declare function f:resolveJsonAnyOf($anyOf as element())
        as element()* {
    for $subschema in $anyOf/_/f:jsonEffectiveValue(.)        
    return
        if ($subschema/_anyOf) then $subschema/anyOf/f:resolveJsonAnyOf(.)
        else $subschema
};

(:~
 : Resolves a JSON Schema oneOf group. Returns all subschemas, with schema
 : references recursively resolved and oneOf subschemas recursively replaced
 : by their subschemas.
 :
 : @param oneOf a JSON Schema oneOf keyword
 : @return the subschemas, recursively resolved
 :)
declare function f:resolveJsonOneOf($oneOf as element())
        as element()* {
    for $subschema in $oneOf/_/f:jsonEffectiveValue(.)
    return
        if ($subschema/_oneOf) then $subschema/oneOf/f:resolveJsonOneOf(.)
        else $subschema
};

(:~
 :
 : ===    U t i l i t i e s ===
 :
 :)

(:~
 : Returns namespace nodes which apply to all elements in the
 : input sequence of elements.
 :
 : @param elems a sequence of elements
 : @return a sequence of namespace nodes
 :)
declare function f:extractNamespaceNodes($elems as element()*)
        as namespace-node()* {
    let $nspairs := (
        for $elem in $elems
        let $prefixes := in-scope-prefixes($elem)
        let $nspair := $prefixes ! concat(., '#', namespace-uri-for-prefix(., $elem))
        return $nspair 
    ) => distinct-values()

    for $nspair in $nspairs
    group by $nsuri := substring-after($nspair, '#')
    where 1 eq ($nspair => distinct-values() => count())
    return
        let $prefix := $nspair[1] ! substring-before(., '#')
        return
            if ($prefix eq '' and 
                (some $elem in $elems satisfies not('' = in-scope-prefixes($elem)))) 
            then () else namespace {$prefix} {$nsuri}
               
};

