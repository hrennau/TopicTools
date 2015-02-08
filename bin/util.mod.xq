(:
 : ===================================================================================
 : util.mod.xq - various utility functions of the ttools application
 :
 : @version 20150126-1 
 : ===================================================================================
 :)

module namespace f="http://www.ttools.org/ttools/xquery-functions";

import module namespace i="http://www.ttools.org/ttools/xquery-functions" at
    "ttoolsConstants.mod.xq";
    
import module namespace tt="http://www.ttools.org/xquery-functions" at
    "tt/_constants.mod.xq",
    "tt/_reportAssistent.mod.xq",
    "tt/_resourceAccess.mod.xq"    
    ;    
    
declare namespace z="http://www.ttools.org/ttools/structure";
declare namespace soap="http://schemas.xmlsoap.org/soap/envelope/";

(:~
 : Determines the name of the topic tool currently managed. 
 : Throws an error if no valid tool name can be determined
 :
 : @param directory the tool directory
 : @param name the tool name, as specified via 'name' parameter  
 : @return the actual tool name
 :) 
declare function f:getToolName($directory as xs:string, $name as xs:NCName?)
        as xs:NCName {
    if ($name) then $name else
        
    let $derived := replace(replace($directory, '[/\\]$', ''), '^.*[/\\]', '')
    return
        if (not($derived castable as xs:NCName)) then
            error(QName((), 'INVALID_ARG'), concat('Tool name must be an NCName, but the implicit tool name ',
                     '(= application directory) is not an NCName: ', $derived, ' ; use a different directory, ',
                    'or specify the tool name explicitly using parameter "name".'))                
        else xs:NCName($derived)
};

(:~
 : Retrieves the tool settings of the topic tool currently managed.
 :
 : @param directory the tool directory
 : @param name the tool name
 : @return the current tool settings
 :)
declare function f:getToolSettings($directory as xs:string, $toolName as xs:NCName)
        as element()? {    
    let $settingsURI := f:getToolSettingsURI($directory, $toolName)     
    return 
        if (tt:doc-available($settingsURI)) then tt:doc($settingsURI)/* 
        else ()
            
};

(:~
 : Returns the directory containing the tt framework modules of the
 : topic tool currently managed.
 :
 : @param directory the tool directory
 : @return the directory containing the tool's tt framework modules
 :)
declare function f:getTtModulesDir($directory as xs:string)
        as xs:string {
    let $ttSubDir := $i:cfg/ttSubDir[string(.)]
    let $ttDir := string-join(($directory, $ttSubDir), '/')
    return
        resolve-uri($ttDir, tt:static-base-uri())      
};

(:~
 : Returns the URI of the settings file of the topic tool currently
 : managed.
 :
 : @param directory the tool directory
 : @param toolName the tool name
 : @return the URI of the tool's tool settings file
 :)
declare function f:getToolSettingsURI($directory as xs:string, $toolName as xs:NCName)
        as xs:string {
    let $useDir :=        
        let $ttSubDir := $i:cfg/ttSubDir
        let $ttDir := string-join(($directory, $ttSubDir), '/')
        return
            resolve-uri($ttDir, tt:static-base-uri())   
    return
        concat($useDir, '/', $toolName, '-settings.xml')
};

(:~
 : Returns the URI of the main module of the topic tool currently managed.
 :
 : @param directory the tool directory
 : @param toolName the tool name
 : @return the URI of the tools's main module
 :)
declare function f:getTopicToolURI($directory as xs:string, $toolName as xs:NCName)
        as xs:string {
    let $useDir := resolve-uri($directory, tt:static-base-uri())         
    return
        string-join(($useDir, concat($toolName, '.xq')), '/')        
};

(:~
 : Returns the URI of the extensions module of the topic tool currently managed.
 :
 : @param directory the tool directory
 : @param toolName the tool name
 : @return the URI of the tool's extensions module
 :)
declare function f:getExtensionsModuleURI($directory as xs:string, $toolName as xs:NCName)
        as xs:string {
    let $useDir :=        
        let $ttSubDir := $i:cfg/ttSubDir
        let $ttDir := string-join(($directory, $ttSubDir), '/')
        return
            resolve-uri($ttDir, tt:static-base-uri())   
    return
        string-join(($useDir, '_extensions.mod.xq'), '/')        
};

(:~
 : Returns the tool flavor. If request parameter 'flavor' is set,
 : the value is used; otherwise, it is attempted to retrieve the
 : value from the tool settings; if this is not possible, the
 : builtin dafault is used ('xq30f').
 :
 : @param request the operation request
 : @param settings the tool settings
 : @return the flavor
 :)
declare function f:getToolFlavor($request as element(), $toolSettings as element()?)
        as xs:string {
    let $explicit := tt:getParam($request, 'flavor')
    return
        if ($explicit) then $explicit
        else 
            let $read := $toolSettings/flavor/string()
            return
                if ($read) then $read else 'xq30f'        
};        

(:~
 : Returns the tool namespace. If request parameter 'namespace' is set,
 : the value is used; otherwise, it is attempted to retrieve the
 : value from the tool settings; if this is not possible, the
 : builtin dafault is used ('http://www.ttools.org/TOOLNAME/xquery-functions').
 :
 : @param request the operation request
 : @param settings the tool settings
 : @return the flavor
 :)
declare function f:getToolNamespace($request as element(), $toolName as xs:string, $toolSettings as element()?)
        as element(namespace) {
    let $explicitRoot := tt:getParam($request, 'namespace')
    let $explicitFunc := tt:getParam($request, 'namespaceFunc')    
    let $explicitError := tt:getParam($request, 'namespaceError')    
    let $explicitStruct := tt:getParam($request, 'namespaceStruct')   
    return
        if ($explicitRoot) then
            <namespace 
                func="{if ($explicitFunc) then $explicitFunc else concat($explicitRoot, '/ns/xquery-functions')}"
                error="{if ($explicitError) then $explicitError else concat($explicitRoot, '/ns/error')}"
                struct="{if ($explicitStruct) then $explicitStruct else concat($explicitRoot, '/ns/structure')}"                
            />
        else if ($toolSettings) then
            let $settingFunc := $toolSettings/namespace/@func    
            let $settingError := $toolSettings/namespace/@error    
            let $settingStruct := $toolSettings/namespace/@struct   
            return
                <namespace 
                    func="{if ($explicitFunc) then $explicitFunc else $settingFunc}"
                    error="{if ($explicitError) then $explicitError else $settingError}"
                    struct="{if ($explicitStruct) then $explicitStruct else $settingStruct}"                
                />
        else
            let $defaultRoot := concat('http://www.ttools.org/', $toolName)
            return
                <namespace 
                    func="{if ($explicitFunc) then $explicitFunc else concat($defaultRoot, '/ns/xquery-functions')}"
                    error="{if ($explicitError) then $explicitError else concat($defaultRoot, '/ns/error')}"
                    struct="{if ($explicitStruct) then $explicitStruct else concat($defaultRoot, '/ns/structure')}"                
                />        
};        

(:~
 : Prettifies XML by removing pretty print text nodes.
 :)
declare function f:pretty($n as node())
        as node()? {
    typeswitch($n)
    case document-node() return 
        for $c in $n/node() return document {f:pretty($c)}
    case element() return
        element {node-name($n)} {
            for $a in $n/@* return f:pretty($a),
            for $c in $n/node() return f:pretty($c)
        }
    case text() return
        if ($n/.. and not(matches($n, '\S'))) then () else $n
    default return $n
};

(:~
 : Determines the features implied by the tool flavor.
 : The available features are:
 : xq10ge - supports XQuery 1.0 (at least)
 : xq10 - supports XQuery 1.0 (not more)
 : xq30ge - supports XQuery 3.0 (at least)
 : xq30 - supports XQuery 3.0 (not more)
 : file - supports the EXPath file module
 : file- - does not support the EXPath file module 
 :
 : @param flavor - the tool flavor
 : @return the features implied
 :)
 declare function f:featuresFromFlavor($flavor as xs:string)
        as xs:string* {
    if (matches($flavor, '^basex(\d\d)', 'i')) then (
        let $version := xs:integer(replace($flavor, '^basex', '', 'i'))
        return (
            'basex',
            lower-case(normalize-space($flavor)),
            if ($version lt 78) then ('xq10', 'xq10ge') else ('xq30', 'xq30ge'),
            if ($version lt 78) then 'file-' else 'file',
            if ($version lt 78) then 'eval-' else 'eval',
            if ($version lt 78) then 'sql-' else 'sql' 
        )
    ) else if (matches($flavor, '^saxonhe\d\d')) then (
        let $version := xs:integer(replace($flavor, '^saxonhe', '', 'i'))
        return (
            'saxonhe',
            lower-case(normalize-space($flavor)),
            if ($version lt 96) then ('xq10', 'xq10ge') else ('xq30', 'xq30ge'),
            'file-',
            'sql-',
            'eval-'
        )
    ) else if (matches($flavor, '^saxonpe\d\d')) then (
        let $version := xs:integer(replace($flavor, '^saxonpe', '', 'i'))
        return (
            'saxonpe',
            lower-case(normalize-space($flavor)),            
            if ($version lt 96) then ('xq10', 'xq10ge') else ('xq30', 'xq30ge'),
            if ($version lt 95) then 'file-' else 'file',
            if ($version lt 95) then 'eval-' else 'eval',
            'sql-'
        )
    ) else if (matches($flavor, '^saxonee\d\d')) then (
        let $version := xs:integer(replace($flavor, '^saxonee', '', 'i'))
        return (
            'saxonee',
            lower-case(normalize-space($flavor)),            
            if ($version lt 96) then ('xq10', 'xq10ge') else ('xq30', 'xq30ge'),
            if ($version lt 95) then 'file-' else 'file',
            if ($version lt 95) then 'eval-' else 'eval',
            'sql-'
        )
    ) else
        let $qvers := replace($flavor, '^(xq\d+)(.*)', '$1')
        let $additional := replace($flavor, '^(xq\d+)(.*)', '$2')
        return (
            $qvers,
            concat($qvers, 'ge'),
            if (contains($additional, 'f')) then 'file' else 'file-',
            if (contains($additional, 's')) then 'sql' else 'sql-',
            if (contains($additional, 'e')) then 'eval' else 'eval-'        
        )
};

(:~
 : Filters a text by features. Any section requiring particular features
 : (to be discarded unless required features are present) is started by a
 : feature requirement declaration with the following syntax:
 : (:#feature?( feature)*#:) | (:#|feature feature*#:) 
 : where 'feature' is the name of a feature, which must be an NCName.
 : 
 : With the second variant (:#|...:), at least one of the features 
 : must be given; with the first variant (without |), all features 
 : must be given.
 : 
 : Examples:
 :
 : (:#xq10#:)
 : (:#xq30ge file:)
 : (:|#xq30ge file:) 
 : (:##:)
 :
 : @param text the text to be filtered
 : @features the features
 : @return the filtered text
 :)
declare function f:filterTextByFeatures($text as xs:string, $features as xs:string*)
        as xs:string {
    let $lineElems := 
        <lines>{
            for $line in tokenize($text, '&#xD;?&#xA;')
            return
                if (matches($line, '^\(:#\|?((~?\i\c*)(\s+~?\i\c*)*)?#:\)\s*$')) then
                    let $requiredFeatures := replace($line, '^\(:#\|?((~?\i\c*)(\s+~?\i\c*)*)?#:\)\s*$', '$1')
                    let $orAtt := if (not(starts-with($line, '(:#|'))) then () else 
                        attribute boolean {'or'}
                    return
                        <features>{
                            $orAtt,
                            for $f in tokenize(normalize-space($requiredFeatures), ' ')
                            let $sign := if (starts-with($f, '~')) then '-' else ()
                            let $value := if ($sign eq '-') then substring($f, 2) else $f
                            return 
                                <feature>{
                                    if (not($sign eq '-')) then () else attribute sign {'-'},
                                    $value
                                }</feature>
                        }</features> 
                else
                    <line>{$line}</line>
        }</lines>                    
    let $lines :=                
        for $lineElem in $lineElems/*
        return
            if ($lineElem/self::features) then () else
                let $reqFeatures := $lineElem/preceding-sibling::features[1]
                let $required := $reqFeatures/feature[string()]
                let $boolean := ($reqFeatures/@boolean, 'and')[1]
                return
                    if (empty($required) 
                        or 
                        $boolean eq 'and' and (
                            every $f in $required satisfies 
                                if ($f/@sign eq '-') then not($f = $features) 
                                else $f = $features
                        ) 
                        or
                        $boolean eq 'or' and (
                            some $f in $required satisfies 
                                if ($f/@sign eq '-') then not($f = $features)
                                else $f = $features
                        )
                    ) 
                        then string($lineElem)
                    else ()
    return
        string-join($lines, '&#xA;')
};

