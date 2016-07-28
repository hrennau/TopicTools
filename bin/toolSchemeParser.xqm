(:~
 : toolSchemeParser.xqm - parses a directory and constructs a tool scheme
 :
 : @version 20150211-1
 : 
 : ############################################################################
 :)

module namespace f="http://www.ttools.org/ttools/xquery-functions";

import module namespace tt="http://www.ttools.org/xquery-functions" at
    "tt/_constants.xqm",
    "tt/_reportAssistent.xqm",
    "tt/_nameFilter.xqm";
    
import module namespace i="http://www.ttools.org/ttools/xquery-functions" at
    "builder_main.xqm",
    "builder_extensions.xqm",
    "ttoolsConstants.xqm",    
    "toolSchemeValidator.xqm",    
    "util.xqm";
    
declare namespace z="http://www.ttools.org/ttools/structure";
declare namespace ztt="http://www.ttools.org/structure";

(:~
 : Parses a tool directory and generates the tool scheme, assembling and augmenting 
 : the contents of module annotations.
 :
 : @param dir the directory in which to build/install the topic tool
 : @param ttname the topic tool name 
 : @param features the features of the current tool flavor 
 : @return the extensions model
 :)
declare function f:getToolScheme($dir as xs:string, $ttname as xs:string, $features as xs:string*)
      as item()* {
    let $helpOperation :=
        <operation name="_help" func="_help" mod="{string-join(($f:cfg/ttSubDir, '_help.xqm'), '/')}">
            <param name="default" type="xs:boolean" default="false"/>
            <param name="type" type="xs:boolean" default="false"/>            
            <param name="mode" type="xs:string" default="overview" fct_values="overview, scheme"/>            
            <param name="ops" type="nameFilter?"/>            
        </operation>            
      
    let $fileNames := '^.*.xqm?$'
    let $useDir :=
        let $staticBaseUri := tt:static-base-uri()
        let $value := resolve-uri($dir, $staticBaseUri)
        let $value := replace($value, '/$', '')
        return replace($value, '\\', '/')
    let $useDirTt := string-join(($useDir, $i:cfg/ttSubDir), '/')
    let $files :=
        file:list($useDir, true(), '*')[matches(., $fileNames)] ! replace(., '\\', '/')
    let $annotations :=
        for $file in $files
        let $uri := string-join(($useDir, $file), '/')
        let $text := tt:unparsed-text($uri)
        let $ns := f:getModuleNamespace($text)
        
        (: collect annotations :)
        let $operationsElems := f:getAnnotations($text, 'operations')        
        let $operationElems := f:getAnnotations($text, 'operation')        
        let $typesElems := f:getAnnotations($text, 'types')
        let $typeElems := f:getAnnotations($text, 'type')        
        let $facetsElems := f:getAnnotations($text, 'facets')    
        let $facetElems := f:getAnnotations($text, 'facet')        
        return (
            <operations mod="{$file}" namespace="{$ns}">{$operationsElems}</operations>,        
            <operation mod="{$file}" namespace="{$ns}">{$operationElems}</operation>,            
            <types mod="{$file}" namespace="{$ns}">{$typesElems}</types>,
            <type mod="{$file}" namespace="{$ns}">{$typeElems}</type>,            
            <facets mod="{$file}" namespace="{$ns}">{$facetsElems}</facets>,               
            <facet mod="{$file}" namespace="{$ns}">{$facetElems}</facet>            
        )
    let $annotationItems := 
        for $ai in $annotations/*
        let $mod := $ai/root()/@mod/string() 
        let $ns := $ai/root()/@namespace/string()
        let $kind := $ai/parent::*/local-name()
        let $childElems :=
            if ($kind eq 'operations') then 'operation'
            else if ($kind eq 'types') then 'type'
            else if ($kind eq 'facets') then 'facet'
            else ()
        return
            if ($ai/self::_unparsed) then
                tt:createError('ANNOTATION_ERROR', 'Invalid annotation - not well-formed XML',
                    <_ module="{$mod}"/>)
            else if (not(local-name($ai) eq $kind)) then
                tt:createError('ANNOTATION_ERROR', concat('@', $kind, ' annotation must be ''', 
                    $kind, ''' element, but found ''', local-name($ai), ''''), 
                    <_ module="{$mod}"/>)
            else if ($childElems and empty($ai/*)) then  
                tt:createError('ANNOTATION_ERROR', concat('@', $kind, ' annotation must be ''', 
                    $kind, ''' element with ''', $childElems, ''' child elements, ',
                    'but the element is empty'), 
                    <_ module="{$mod}"/>)                    
            else if ($childElems and exists($ai/*[local-name(.) ne $childElems])) then  
                let $invalidChildren := $ai/*[local-name(.) ne $childElems]
                return
                    tt:createError('ANNOTATION_ERROR', concat('@', $kind, ' annotation must be ''', 
                    $kind, ''' element with ''', $childElems, ''' child elements, but the element ',
                    'contains non-', $childElems, ' children (', string-join(
                    $invalidChildren/local-name(.), ', '), ')'),
                    <_ module="{$mod}"/>)
            else if ($childElems) then
                for $child in $ai/* return
                    element {node-name($child)} {
                        $child/@*,
                        attribute mod {$mod},
                        attribute namespace {$ns},                        
                        $child/node()
                    }
            else
                element {node-name($ai)} {
                    $ai/@*,
                    attribute mod {$mod},
                    attribute namespace {$ns},
                    $ai/node()
                }
    let $errors := $annotationItems/self::ztt:error     
    return
        if ($errors) then tt:wrapErrors($errors)
        else
            let $scheme := 
                <topicTool name="{$ttname}">{
                    <operations>{
                        $annotationItems/self::operation,
                        $helpOperation
                    }</operations>,
                    <types>{
                        $annotationItems/self::type                                
                    }</types>,
                    <facets>{
                        $annotationItems/self::facet                                
                    }</facets>
                }</topicTool>
            let $errors := i:validateToolScheme($scheme, $features)                
            return
                if ($errors) then tt:wrapErrors($errors)
                else
                    f:pretty($scheme)
};

(:~
 : Extracts the annotations from a module
 :
 : @param text the module text
 : @param annoName the name of the annotations to be extracted
 : @return the extracted annotation contents (XML elements)
 :)
declare function f:getAnnotations($text as xs:string, $annoName as xs:string)
      as element()* {
    let $annoText :=
        replace($text, concat('^(.*?&#xA;\s*)\(:~@', $annoName, '\s(.*?):\).*'), '$2', 's')
            [. ne $text]
    return
        if (not($annoText)) then () else 
        let $tail := replace($text, concat('^(.*?&#xA;\s*)\(:~@', $annoName, '\s(.*?):\)(.*)'), '$3', 's')        
        (: let $annoTextCore := replace(replace($annoText, '\{', '{{'), '\}', '}}') :)
        return (
            try {parse-xml($annoText)/*} catch * {<_unparsed>{$annoText}</_unparsed>}
            ,
            f:getAnnotations($tail, $annoName)
        )
};

(:~
 : Extracts from the text of a library module the module namespace.
 :
 : @param text the module text
 : @return the module namespace
 :) 
declare function f:getModuleNamespace($text as xs:string)
        as xs:string {
    let $noctext := f:removeModuleComments($text)
    let $ns := replace($noctext, '.*?module\s+namespace\s+\S+\s*=\s*(''|")(.*?)\1.*', '$2', 's')
    return $ns
};

(:~
 : Removes comments from an XQuery code text.
 :
 : @param text XQuery code
 : @return the code with all comments removed
 :)
declare function f:removeModuleComments($text as xs:string)
        as xs:string {
    $text        
};        

