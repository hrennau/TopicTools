(: builder_main.mod.xq - generates a topic tool main module 
 :
 : @version 20140628-1 
 : ===================================================================================
 :)

module namespace f="http://www.ttools.org/ttools/xquery-functions";

import module namespace tt="http://www.ttools.org/xquery-functions" at
    "tt/_constants.mod.xq",
    "tt/_request.mod.xq",
    "tt/_request_setters.mod.xq",    
    "tt/_reportAssistent.mod.xq",
    "tt/_nameFilter.mod.xq";
    
import module namespace i="http://www.ttools.org/ttools/xquery-functions" at
    "builder_extensions.mod.xq",
    "ttoolsConstants.mod.xq",
    "util.mod.xq";
    
declare namespace z="http://www.ttools.org/ttools/structure";

(:~
 : Generates the source code of the topic tool main module.
 :)
declare function f:makeMainModule($toolScheme as element(),
                            $explain as xs:string?,
                            $namespace as element(namespace))
        as xs:string {
    let $ttname := $toolScheme/@name/string(.)
    let $toolSchemeText := replace(string-join(serialize($toolScheme), ''), '&#xD;', '')
    let $toolSchemeText := replace($toolSchemeText, '\{', '{{')    
    let $toolSchemeText := replace($toolSchemeText, '\}', '}}')    
    let $ops := $toolScheme//operation
    let $op1 := $ops[1]
    let $ttPrefix := string-join(($i:cfg/ttSubDir, '_'), '/')
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
     
    let $toolText := <TEXT>
(:
 : {$ttname} - {$explain}
 :
 : @version {current-dateTime()} 
 :)

import module namespace tt="http://www.ttools.org/xquery-functions" at
    {$modulesBuiltin}
    "tt/_request.mod.xq";     
{
if (not($modules)) then () else
<NESTED-TEXT>
import module namespace i="{$namespace/@func/string()}" at
    {$modules}
</NESTED-TEXT>/concat(string(), '&#xA;')
}
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
    {('tt'[$op/@mod/starts-with(., $ttPrefix)], 'i')[1]}:{$func}($request{if ($func eq '_help') then ', $toolScheme' else ()})        
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
