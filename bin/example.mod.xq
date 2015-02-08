(: logOperations.mod.xq - reports the service operations observed in a JMeter log
 :
 : @version 20140124-1 
 : ===================================================================================
 :)

(:~@interface
<interface>
    <operations>
        <operation name="counts" func="getCounts">
            <paramConstraints>
                <exactlyOneOf>doc docs</exactlyOneOf>
            </paramConstraints>
            <param name="doc" type="docURI*"/>        
            <param name="docs" type="docDFD*"/>           
        </operation>
        <operation name="paths" func="getPaths">
            <paramConstraints>
                <exactlyOneOf>doc docs</exactlyOneOf>
            </paramConstraints>
            <param name="doc" type="docURI*"/>        
            <param name="docs" type="docDFD*"/>       
            <param name="skipRoot" type="xs:boolean" default="false"/>
            <param name="scope" type="xs:string*" values="all, atts, elems, leaves" default="all"/>            
        </operation>
        <operation name="items" func="getItemReport">
            <paramConstraints>
                <exactlyOneOf>doc dcat</exactlyOneOf>
            </paramConstraints>
            <param name="count" type="xs:boolean" default="false"/>        
            <param name="doc" type="docURI*"/>           
            <param name="dcat" type="dcat?"/>            
            <param name="names" type="nameFilter" default="*"/>  
            <param name="path" type="xs:boolean" default="false"/>            
            <param name="scope" type="xs:string" default="all" values="atts, elems, all"/>
            <param name="simple" type="xs:boolean" default="false"/>            
            <param name="values" type="xs:boolean" default="false"/>            
            <param name="nval" type="xs:integer" default="10"/>            
            <param name="nvalues" type="nameFilterMap?"/>            
            <param name="npvalues" type="nameFilterMap?"/>            
        </operation>
    </operations>
</interface>    
:)

module namespace f="http://www.ttools.org/ttools/xquery-functions";
import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "tt/_request.mod.xq",
    "tt/_reportAssistent.mod.xq",
    "tt/_nameFilter.mod.xq";
    
declare namespace z="http://www.ttools.org/ttools/structure";
declare namespace soap="http://schemas.xmlsoap.org/soap/envelope/";

(:~
 : Demo operation 'count'. Note how the code relies on the
 : binding of a document node to the parameter 'doc'. This is
 : possible because the parameter is configured to have
 : type 'docUri' and to be required.
 :
 : @param request the operation request
 : @return a report yielding various counts
 :)
 
declare function f:getCounts($request as element())
        as element() {
    let $doc1 as document-node()* := tt:getParam($request, 'doc')
    let $doc2 as document-node()* := tt:getParam($request, 'docs')
    let $docs := ($doc1, $doc2)

    let $countElems := count($docs//*)
    let $countAtts := count($docs//@*)    
    let $countNodes := count($docs//(node(), @*))    
    return
        <z:counts uri="{$docs/document-uri(.)}">{
            <countElems>{$countElems}</countElems>,
            <countElems>{$countAtts}</countElems>,            
            <countNodes>{$countNodes}</countNodes>            
        }</z:counts>
};

(:~
 : Demo operation 'count'. Note how the code relies on the
 : binding of a document node to the parameter 'doc'. This is
 : possible because the parameter is configured to have
 : type 'docUri' and to be required.
 :
 : @param request the operation request
 : @return a report yielding various counts
 :)
 
declare function f:getPaths($request as element())
        as element() {
    let $scope as xs:string := tt:getParam($request, 'scope')        
    let $skipRoot as xs:boolean := tt:getParam($request, 'skipRoot')    
    
    let $doc1 as document-node()* := tt:getParam($request, 'doc')
    let $doc2 as document-node()* := tt:getParam($request, 'docs')
    let $docs := ($doc1, $doc2)

    let $attPaths :=
        if (not($scope = ('all', 'atts'))) then () else 
        for $p in distinct-values($docs//@*/f:getPath(., $skipRoot))
        order by lower-case($p) return <z:a p="{$p}"/>
    let $elemPaths :=
        let $elems :=
            if ($scope = ('all', 'elems')) then $docs//*
            else if ($scope = 'leaves') then $docs//*[not(*)]
            else ()                    
        for $p in distinct-values($elems/f:getPath(., $skipRoot))
        order by lower-case($p) return <z:e p="{$p}"/>
    return
        <z:paths scope="{$scope}" uri="{$docs/document-uri(.)}">{
            $attPaths,
            $elemPaths
        }</z:paths>
};

declare function f:getPath($n as node(), $skipRoot as xs:boolean)
        as xs:string {
    let $root := $n/ancestor-or-self::*[last()] return        
    string-join($n/ancestor-or-self::node()[not($skipRoot) or . >> $root]/
        concat(self::attribute()/'@', local-name()), '/')        
};

(:~
 : Demo operation 'getItemReport'. Note the name filter retrieved
 : from the request.
 :
 : @param request the operation request
 : @return a report yielding various counts
 :) 
declare function f:getItemReport($request as element())
        as item() {
    let $doc as document-node()* := (
        tt:getParam($request, 'doc'),
        tt:getParam($request, 'dcat')
    )        
    let $nameFilter as element(nameFilter) := tt:getParam($request, 'names')    
    let $count as xs:boolean := tt:getParam($request, 'count')
    let $scope as xs:string := tt:getParam($request, 'scope')  
    let $path as xs:boolean := tt:getParam($request, 'path')    
    let $simple as xs:boolean := tt:getParam($request, 'simple')   
    let $nval as xs:integer := tt:getParam($request, 'nval')   
    let $nvalues as element(nameFilterMap)? := tt:getParam($request, 'nvalues')
    let $npvalues as element(nameFilterMap)? := tt:getParam($request, 'npvalues')    
    let $path := if ($npvalues) then true() else $path
    
    let $elemNameInfos := if ($scope eq 'atts') then () else
        let $elems := $doc//*[not($simple) or not(*)]
        let $elemNames := tt:filterNames(distinct-values($elems/local-name(.)), $nameFilter)        
        for $n in $elemNames
        let $myItems := $elems[local-name(.) eq $n]
        let $countInfo := if (not($count)) then () else attribute count {count($myItems)}
        let $pathInfo := if (not($path)) then () else
            let $paths := distinct-values($myItems/f:_getPath(.))
            return
                if (count($paths) eq 1) then (
                    attribute path {$paths},
                    if (not($npvalues)) then () else
                        f:_getValues($n, $npvalues, $myItems)
                ) else 
                    <z:paths>{
                        for $p in $paths order by lower-case($p) return 
                        <z:path p="{$p}">{
                            if (not($npvalues)) then () else
                                let $pathItems := $myItems[f:_getPath(.) eq $p] return 
                                    f:_getValues($n, $npvalues, $pathItems)                        
                        }</z:path>
                    }</z:paths>                        
        let $valueInfo := 
            if (not($nvalues)) then () 
            else if (empty($myItems[not(*)])) then () 
            else f:_getValues($n, $nvalues, $myItems)
        return 
            <e name="{$n}">{
                ($countInfo, $pathInfo, $valueInfo)/self::attribute(),
                ($countInfo, $pathInfo, $valueInfo)/self::element()                
            }</e>
                
    let $attNameInfos := if ($scope eq 'elems') then () else
        let $atts := $doc//@*  
        let $attNames := tt:filterNames(distinct-values($atts/local-name()), $nameFilter)
        for $n in $attNames
        let $myItems := $atts[local-name(.) eq $n]
        let $countInfo := if (not($count)) then () else attribute count {count($myItems)}
        let $pathInfo := if (not($path)) then () else
            let $paths := distinct-values($myItems/f:_getPath(.))
            return
                if (count($paths) eq 1) then (
                    attribute path {$paths},
                    if (not($npvalues)) then () else
                        f:_getValues($n, $npvalues, $myItems)
                ) else 
                    <z:paths>{
                        for $p in $paths order by lower-case($p) return 
                        <z:path p="{$p}">{
                            if (not($npvalues)) then () else
                                let $pathItems := $myItems[f:_getPath(.) eq $p] return 
                                    f:_getValues($n, $npvalues, $pathItems)                        
                        }</z:path>
                    }</z:paths>
(:                    
                if (count($paths) eq 1) then attribute path {$paths}
                else 
                    <z:paths>{
                        for $p in $paths order by lower-case($p) return <z:path p="{$p}"/>
                    }</z:paths>
:)                    
        let $valueInfo := 
            if (not($nvalues)) then ()
            else f:_getValues($n, $nvalues, $myItems)
        return 
            <a name="{$n}">{
                ($countInfo, $pathInfo, $valueInfo)/self::attribute(),
                ($countInfo, $pathInfo, $valueInfo)/self::element()                
            }</a>
    return
        <z:items uri="{$doc/document-uri(.)}" filter="{$nameFilter/@sourceValue}" rootElem="{$doc/*/local-name(.)}">{
            for $item in ($elemNameInfos, $attNameInfos)
            order by lower-case($item/@name)
            return $item
        }</z:items>        
};

declare function f:_getPath($n as node())
        as xs:string {
    string-join($n/ancestor-or-self::node()
       [not(self::document-node())][not(parent::document-node())]/concat(self::attribute()/'@', local-name(.)), '/')        
};        

declare function f:_getValueCount($name as xs:string, $nvalues as element(nameFilterMap)?)
        as xs:integer? {
    let $value := tt:nameFilterMapValue($name, $nvalues, "10")
    return
        if ($value eq '*') then -1 else xs:integer($value)
};    

(:~
 : Returns a sample of text values found in a set of items.
 :
 : @param name the name of the items
 : @param nvalues a name filter map specifying the number of items
 :    dependent on the name
 : @param items the items
 : @return an element containing the values
 :)
declare function f:_getValues($name as xs:string, 
                              $nvalues as element(nameFilterMap), 
                              $items as node()*)
        as element(z:values)? {
    if ($items[1]/self::element() and empty($items[not(*)])) then () else
    
    let $values := distinct-values($items[not(*)])
    let $valueCount := f:_getValueCount($name, $nvalues)
    return
        if (not($valueCount)) then () else
            <z:values countAll="{count($values)}">{
                for $v in $values[$valueCount lt 0 or position() le $valueCount] 
                order by $v return <z:value v="{$v}"/>
            }</z:values>       
};        