(: builder_main.xqm - generates a topic tool main module 
 :
 : @version 20140628-1 
 : ===================================================================================
 :)

module namespace f="http://www.ttools.org/ttools/xquery-functions";

import module namespace tt="http://www.ttools.org/xquery-functions" at
    "tt/_constants.xqm",
    "tt/_request.xqm",
    "tt/_request_setters.xqm",    
    "tt/_reportAssistent.xqm",
    "tt/_nameFilter.xqm";
    
import module namespace i="http://www.ttools.org/ttools/xquery-functions" at
    "builder_extensions.xqm",
    "ttoolsConstants.xqm",
    "util.xqm";
    
declare namespace z="http://www.ttools.org/ttools/structure";

(:~
 : Generates the source code of the topic tool main module.
 :)
declare function f:makeMainModule($toolScheme as element(),
                            $explain as xs:string?,
                            $namespace as element(namespace))
        as xs:string {
    (: file:write('/projects/tt-intro/toolScheme.xml', $toolScheme), :)
    let $tsReport := f:evalToolScheme4MainModule($toolScheme)
    
    let $ttname := $toolScheme/@name/string(.)
    let $toolSchemeText := replace(string-join(serialize($toolScheme), ''), '&#xD;', '')
    let $toolSchemeText := replace($toolSchemeText, '\{', '{{')    
    let $toolSchemeText := replace($toolSchemeText, '\}', '}}')    
    let $ops := $toolScheme//operation
    let $op1 := $ops[1]
    let $ttPrefix := string-join(($i:cfg/ttSubDir, '_'), '/')
    
    let $moduleImports :=
        for $ns in $tsReport//namespace[not(@builtin eq 'true')]
        let $mods := $ns/modules/module/@uri
        return
            concat(
                'import module namespace ', $ns/@prefix, '="', $ns/@uri, '" at',
                '&#xA;    ',
                string-join(
                    for $m in $mods
                    order by $m return concat('"', $m, '"')
                 , ',&#xA;    '),
                ';')                    

    let $moduleImportBuiltin :=
        let $ns := $tsReport//namespace[@builtin eq 'true']
        let $mods := $ns/modules/module/@uri
        return
            concat(
                'import module namespace ', $ns/@prefix, '="', $ns/@uri, '" at',
                '&#xA;    ',
                string-join(
                    for $m in $mods
                    order by $m return concat('"', $m, '"')
                 , ',&#xA;    '),
                ';',
                '&#xA;',
                '&#xA;')                    
(:
    let $modules :=
        let $mods := distinct-values($toolScheme//@mod[not(starts-with(., $ttPrefix))])
        return
            if (empty($mods)) then () else
            concat(
                string-join(
                    for $m in $mods
                    order by $m return concat('"', $m, '"')
                 , ',&#xA;    '),
                ';')                    
    let $modulesBuiltin :=
        concat(
            string-join(
                for $m in distinct-values($toolScheme//@mod[starts-with(., $ttPrefix)])
                order by $m return concat('"', $m, '"')
             , ',&#xA;    '),
            ',')                    
:)     
    let $toolText := <TEXT>
(:
 : {$ttname} - {$explain}
 :
 : @version {current-dateTime()} 
 :)

{string-join($moduleImportBuiltin, '&#xA;&#xA;')}

{string-join($moduleImports, '&#xA;&#xA;')}

declare namespace m="{$namespace/@func/string()}";
declare namespace z="{$namespace/@struct/string()}";
declare namespace zz="http://www.ttools.org/structure";

declare variable $request as xs:string external;

(: tool scheme 
   ===========
:)
declare variable $toolScheme :=
{$toolSchemeText};

declare variable $req as element() := tt:loadRequest($request, $toolScheme);

<![CDATA[
(:~
 : Executes pseudo operation '_storeq'. The request is stored in
 : simplified form, in which every parameter is represented by a 
 : parameter element whose name captures the parameter value
 : and whose text content captures the (unitemized) parameter 
 : value.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation__storeq($request as element())
        as node() {
    element {node-name($request)} {
        attribute crTime {current-dateTime()},
        
        for $c in $request/* return
        let $value := replace($c/@paramText, '^\s+|\s+$', '', 's')
        return
            element {node-name($c)} {$value}
    }       
};
]]>
{
    for $op in $ops
    let $func := ($op/@func, $op/@name)[1]/string()
    let $prefix := $tsReport//operations/operation[@name eq $op/@name]/ancestor::namespace/@prefix/string()
    let $resultType := ($op/@type/string(), 'node()')[1]
    return <NESTED-TEXT>    
(:~
 : Executes operation '{$op/@name/string()}'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation_{$op/@name/string()}($request as element())
        as {$resultType} {{
    {('tt'[$op/@mod/starts-with(., $ttPrefix)], $prefix)[1]}:{$func}($request{if ($func eq '_help') then ', $toolScheme' else ()})        
}};
</NESTED-TEXT>/string()
}
(:~
 : Executes an operation.
 :
 : @param req the operation request
 : @return the result of the operation
 :)
declare function m:execOperation($req as element())
      as item()* {{
    if ($req/self::zz:errors) then tt:_getErrorReport($req, 'Invalid call', 'code', ()) else
    if ($req/@storeq eq 'true') then m:execOperation__storeq($req) else
    
    let $opName := tt:getOperationName($req) 
    let $result :=    
{string-join((
    "        if ($opName eq '_help') then m:execOperation__help($req)",
    for $op at $pos in $ops 
    let $if := if ($pos eq 1) then 'else if' else 'else if'
    return 
        concat('        ', $if, ' ($opName eq ''', $op/@name/string(), ''') then m:execOperation_', $op/@name/string(), '($req)'),
    "        else",
    "        tt:createError('UNKNOWN_OPERATION', concat('No such operation: ', $opName), ",
    "            <error op='{$opName}'/>)"
 ), '&#xA;')}    
     let $errors := if ($result instance of node()+) then tt:extractErrors($result) else ()     
     return
         if ($errors) then tt:_getErrorReport($errors, 'System error', 'code', ())     
         else $result
}};

m:execOperation($req)
    </TEXT>/replace(., '^\s+', '')
    return
        $toolText    
};

(:~
 : Evaluates a toolScheme and creates a report supporting the
 : generation of the application main module.
 :
 : @param toolScheme the tool scheme
 : @return the namespaces etc. report
 :) 
declare function f:evalToolScheme4MainModule($toolScheme as element())
        as element() {
    let $ttNamespace := 'http://www.ttools.org/xquery-functions'
    let $namespaces := distinct-values($toolScheme//operation/@namespace)[not(. eq $ttNamespace)]
    let $operations := $toolScheme//operation
    let $ttOperations := $operations[@namespace eq $ttNamespace]/@name
    let $ttModules := distinct-values($ttOperations/../@mod)
    let $nsElem :=
        <namespaces>{
            <namespace prefix="tt" uri="{$ttNamespace}" builtin="true">{
                <modules>{
                    for $m in $ttModules return <module uri="{$m}"/>,
                    <module uri="tt/_request.xqm"/>,
                    <module uri="tt/_help.xqm"/>                    
                }</modules>, 
                <operations>{
                    for $o in $ttOperations return 
                        <operation name="{$o}"/>
                }</operations>
            }</namespace>,
            for $ns at $pos in $namespaces
            let $prefix := concat('a', $pos)
            let $myOperations := $operations[@namespace eq $ns]/@name
            let $myModules := distinct-values($myOperations/../@mod)
            order by $ns
            return
                <namespace prefix="{$prefix}" uri="{$ns}">{
                    <modules>{
                        for $m in $myModules order by $m return
                            <module uri="{$m}"/>
                    }</modules>,
                    <operations>{
                        for $o in $myOperations return 
                            <operation name="{$o}"/>
                    }</operations>
                }</namespace>
        }</namespaces>
    return
        $nsElem
};
