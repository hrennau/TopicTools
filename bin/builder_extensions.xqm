(: builder_extensions.xqm - builds a topic tool
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
    "util.xqm";
    
declare namespace z="http://www.ttools.org/ttools/structure";
declare namespace soap="http://schemas.xmlsoap.org/soap/envelope/";

(:~
 : Generates the source code of the types module.
 :)
 declare function f:makeExtensionsModule($toolScheme as element(), $toolNamespace as element())
        as xs:string {
    let $ttname := $toolScheme/@name/string(.)
    let $mods := distinct-values($toolScheme//(type, facet)/@mod[not(starts-with(., '_'))])
    let $modules :=
        if (empty($mods)) then '&#xA;' else    
        concat(
            string-join(
                for $m in $mods
                order by $m return concat('"../', $m, '"')
             , ',&#xA;    '),
            ';&#xA;')
            
    let $types := 
        for $t in distinct-values($toolScheme//type/@name) 
        order by lower-case($t) return $t   
    let $facets := 
        for $f in distinct-values($toolScheme//facet/@name) 
        order by lower-case($f) return $f   
    
    let $itemTypeMappings :=
        for $t in $toolScheme//type/@itemType return <itemTypeMapping from="{$t/../@name}" to="{$t}"/>
    let $text := <TEXT>
(:~ 
 : _extensions.xqm - generated functions invoking application specific extensions.
 :
 : @version 20140402-1 first version 
 : ===================================================================================
 :)

module namespace m="http://www.ttools.org/xquery-functions";

{if (not(normalize-space($modules))) then () else
<NESTED-TEXT>import module namespace app="{$toolNamespace/@func/string()}" at
   {$modules}
</NESTED-TEXT>/string()}
declare namespace z="http://www.ttools.org/structure";

declare variable $m:NON_STANDARD_TYPES := '{$types}';

(:~
 : Parses a request string into a data type item. The function delegates the
 : parsing to the appropriate function identified by pseudo annotations.
 : 
 : @param paramName the parameter name
 : @param itemType the item type
 : @param itemText a string providing a single parameter item
 : @return the parsed item, or an z:errors element
 :)
declare function m:parseNonStandardItemType($paramName as xs:string, $itemType as xs:string, $itemText as xs:string)       
        as item()+ {{       
{        
    if (empty($toolScheme//type)) then <NESTED-TEXT><![CDATA[
    <z:error type="UNKNOWN_ITEMTYPE" paramName="{$paramName}" itemType="{$itemType}" 
        itemValue="{$itemText}"                       
        msg="{concat('Parameter ''', $paramName, ''' has unknown item type: ', $itemType)}"/>
};]]></NESTED-TEXT>/string()               
    else <NESTED-TEXT>   
    let $result :=    
    {for $type at $pos in $toolScheme//type
    let $name := $type/@name/string()   
    let $func := $type/@func/string()
    let $if := concat('else '[$pos ne 1], 'if')
    return <NESTED-TEXT2>
{'    '}{$if} ($itemType eq '{$name}') then       
            let $value := app:{$func}($itemText) return
                if ($value instance of xs:anyAtomicType+) then $value
                else if (not($value/descendant-or-self::z:error)) then $value
                else
                    let $parserMsg := string-join($value/descendant-or-self::z:error/@msg, '; ')
                    let $msg := concat("Parameter '", $paramName, "': ", lower-case(substring($parserMsg, 1, 1)), substring($parserMsg, 2))
                    return                
                        &lt;z:error type="PARAMETER_TYPE_ERROR" paramName="{{$paramName}}" 
                                 itemType="{{$itemType}}" itemValue="{{$itemText}}" msg="{{$msg}}"/>                         
    </NESTED-TEXT2>                    
    }                    
            else
                &lt;z:error type="SYSTEM_ERROR_UNKNOWN_ITEMTYPE" paramName="{{$paramName}}" itemType="{{$itemType}}" 
                itemValue="{{$itemText}}"                       
                msg="{{concat('Parameter ''', $paramName, ''' has unknown item type: ', $itemType,
                   '; this error would not occur if the tool scheme validation worked correctly')}}"/>                    
    return
        if ($result instance of element(z:error)) then &lt;z:errors>{{$result}}&lt;/z:errors>
        else $result      
}};
</NESTED-TEXT>
}

(:~
 : Non-standard types resulting in atomic item types require a mapping of the
 : non-standard item type name to the atomic item type name in order to enable
 : correct delivery from the param element. The atomic item type name is
 : retrieved from the @itemType attribute on the type annotations' 
 : &lt;type&gt; element.
 :
 : @param itemType the item type name as communicated to the user
 : @return the item type of delivered value items
 :)
declare function m:adaptItemTypeOfNonStandardItemType($itemType as xs:string)
        as xs:string {{
{if (not($itemTypeMappings)) then '    $itemType' else
        string-join((    
        for $mapping at $pos in $itemTypeMappings
        let $else := if ($pos eq 1) then () else 'else '
        return
            concat('    ', $else, 'if ($itemType eq "', $mapping/@from, '") then "', $mapping/@to, '"')
        ,
        '    else $itemType'),
        '&#xA;')
}        
}};

declare function m:checkNonStandardFacets($itemText as xs:string, $typedItem as item()+, $paramConfig as element()?)
        as element()* {{
    let $itemType := $paramConfig/@itemType
    let $name := $paramConfig/@name
    let $errors := (
{string-join(
    for $facet at $pos in $toolScheme//facet
    let $name := $facet/@name/string()   
    let $func := $facet/@func/string()
    return <NESTED-TEXT>
        (: *** check @{$name} :)
        if (not($paramConfig/@fct_{$name})) then () else
        let $facetValue := $paramConfig/@fct_{$name}/string()            
        let $check := app:{$func}($typedItem, $facetValue)
        return 
            if ($check) then () else         
                &lt;z:error type="PARAMETER_FACET_ERROR" paramName="{{$name}}" itemType="{{$itemType}}" 
                    itemValue="{{$itemText}}" facet="maxTodayPlus" facetValue="{{$facetValue}}"
                    msg="{{concat('Parameter ''', $name, ''': item value (', $typedItem, ') not facet-valid; ',
                    'facet={$name}, facetValue=', $paramConfig/@fct_{$name})}}"/>
        ,
</NESTED-TEXT>/replace(., '^&#xA;', '')
, '')}    
        ()
    )
    return
        $errors           
}};
</TEXT>
return replace($text, '^\s+', '')
};