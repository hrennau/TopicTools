xquery version "3.0";
(:
 :***************************************************************************
 :
 : _pcollection.utils.mod.xq - utility functions supporting the processing of pcollections
 :
 :***************************************************************************
 :)

module namespace f="http://www.ttools.org/xquery-functions";
import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "_errorAssistent.mod.xq",
    "_log.mod.xq",
    "_nameFilter.mod.xq",
    "_resourceAccess.mod.xq";    

declare namespace z="http://www.ttools.org/structure";
declare namespace pc="http://www.infospace.org/pcollection";

(:
 : ============================================================================
 :
 :     p u b l i c    f u n c t i o n s
 :
 : ============================================================================
 :)
 
(:
 : ============================================================================
 :
 :     p r i v a t e    f u n c t i o n s
 :
 : ============================================================================
 :)

(:~
 : Transforms a NODL document into a comprehensive collection model,
 : adding explicit information implied by the NODL contents.
 :
 : @param nodl a nodl
 : @return the nodl model
 :)
declare function f:_extendedNodl($nodl as element(pc:nodl))
        as element(pc:enodl) {
    let $pmodel := 
        let $pm := $nodl//pc:pmodel
        return
            element {node-name($pm)} {                
                $pm/@*,
                $pm/pc:property/f:_propertyModel(.),
                $pm/pc:anyProperty
            }                
    return
        f:_extendedNodlRC($nodl, $pmodel)        
};

(:~
 : Recursive helper function of function 'extendedNodl'.
 :
 : @param n the node to be processed
 : @param pmodel element defining the pmodel
 : @return a fragment of the extended NODL
 :)
declare function f:_extendedNodlRC($n as node(), $pmodel as element(pc:pmodel))
        as node()* {
    typeswitch ($n)
    case document-node() return
        document {for $c in $n/node() return f:_extendedNodlRC($c, $pmodel)}

    case element(pc:nodl) return
        <enodl xmlns="http://www.infospace.org/pcollection">{
            attribute nodlURI {$n/root()/document-uri(.)},
            for $a in $n/@* return f:_extendedNodlRC($a, $pmodel),
            for $c in $n/node() return f:_extendedNodlRC($c, $pmodel)            
        }</enodl>
(:#sql#:)        
    case element(pc:sqlNcat) return
        let $nodl := $n/ancestor::pc:nodl
        (: let $collName := $n/ancestor::pc:nodl/pc:collection/@name :)
        return
            <sqlNcat xmlns="http://www.infospace.org/pcollection">{
                (: for $a in $n/@* return f:_extendedNodlRC($a, $pmodel), :)        
                <rdbms name="{$n/@rdbms}"/>,
                <connection>{
                    $n/@host,
                    $n/@db,
                    $n/@user,
                    $n/@password
                }</connection>,
                
                for $c in $n/node() return f:_extendedNodlRC($c, $pmodel),
                f:_sqlTablesModel($nodl, $pmodel)
            }</sqlNcat>
(:##:)        
    case element(pc:pmodel) return $pmodel

    case element() return
        element {node-name($n)} {
            for $a in $n/@* return f:_extendedNodlRC($a, $pmodel),
            for $c in $n/node() return f:_extendedNodlRC($c, $pmodel)            
        }
        
    case attribute(documentURI) return
        attribute {node-name($n)} {$n/resolve-uri(., base-uri(..))}
        
    default return $n        
};

(:~
 : Creates a pnode model. The model represents each property by a `property` element.
 :
 : @param enodl an extended nodl
 : @return an 'xmlProcessingPlan' element describing the required processing
 :)
declare function f:_pnodeModel($enodl as element(pc:enodl))
        as element(pc:pnodeModel) {
    let $pmodel := $enodl/pc:pmodel
    let $asElemNames :=
        for $item in $enodl/pc:ncatModel/pc:xmlNcat/@asElement/tokenize(normalize-space(.), ' ') return
            concat('^', replace($item, '\*', '.*'), '$')
    let $nodeDescriptorKind := $enodl/pc:nodeDescriptor/@kind/replace(., '\s+', '')
    return 
        <pnodeModel xmlns="http://www.infospace.org/pcollection" nodeDescriptorKind="{$nodeDescriptorKind}">{
            for $p in $pmodel/pc:property
            let $name := $p/@name
            let $asElem := some $n in $asElemNames satisfies matches($name, $n)
            return
                <property>{
                    $p/@*, 
                    if (not($asElem)) then () else attribute asElement {'true'}
                }</property>
        }</pnodeModel>                
};

(:~
 : Transforms a node into a pnode.
 :
 : @param node the node to be transformed
 : @param nodeURI the node URI to be stored in the pnode
 : @param pnodeModel a model describing the pnode to be created
 : @param a pnode
 :)
declare function f:_pnode($node as node(),
                          $nodeURI as xs:string?,
                          $pnodeModel as element(pc:pnodeModel))
        as element(pc:pnode) {
    let $docRoot := $node/descendant-or-self::*[1]
    let $psetters := $pnodeModel/pc:property    
    let $nodeDescriptorKind := tokenize($pnodeModel/@nodeDescriptorKind, '\+')
    
    return
        <pnode xmlns="http://www.infospace.org/pcollection">{
            if (not($nodeDescriptorKind = 'uri')) then () else
                let $uri := ($nodeURI, $node/root()/document-uri(.))[1]
                return
                    attribute node_uri {$uri}
            ,  
            let $properties :=
                for $p in $psetters
                let $pname := $p/@name
                let $value := tt:evaluate($p/@expr, $docRoot)
                let $useValue := $value ! xs:string(.)  (: refinements pending :)
                where exists($useValue)
                return
                    if (count($useValue) eq 1) then
                        if ($p/@asElement eq 'true') then
                            element {$pname} {$useValue}
                        else
                            attribute {QName((), $pname)} {$useValue}
                    else
                        element {$pname} {
                            for $item in $useValue return <item>{$item}</item>
                        }
            return (
                $properties[self::attribute()],
                $properties[self::element()]
            )
            ,
            if (not($nodeDescriptorKind = 'text')) then () else
                <node>{$node}</node>                   
        }</pnode>                
};

(:~
 : Retrieves from a pnode a property value.
 :
 : @param node a node descriptor
 : @param pfn a pfilter node
 : @return true if the node descriptor matches the pfilter node, false otherwise
 :)
declare function f:_pnodeProperty($pnode as element(pc:pnode), $pname as xs:string)
        as xs:string* {
    $pnode/@*[local-name(.) eq $pname]/string(.), 
    $pnode/*[not(*)][local-name(.) eq $pname]/string(),
    $pnode/*[*][local-name(.) eq $pname]/pc:item/string()
};

(:~
 : Retrieves from a pnode the node which it describes.
 :
 : @param node a node descriptor
 : @param pfn a pfilter node
 : @return true if the node descriptor matches the pfilter node, false otherwise
 :)
declare function f:_pnodeNode($pnode as element(pc:pnode))
        as node()? {
    if ($pnode/pc:node) then $pnode/pc:node/*
    else if ($pnode/@node_uri) then 
        let $uri := $pnode/resolve-uri(@node_uri, base-uri(.))
        return
            if (not(doc-available($uri))) then () else tt:doc($uri)
    else ()    
};

(:~
 : Enhances the property definition as found in a NODL, adding further attributes representing
 : the result of analysis.
 :
 : @param p an 'property' element
 : @return an element with attrbutes capturing type features.
 :)
declare function f:_propertyModel($p as element())
        as element(pc:property) {
    let $type := $p/@type/replace(., '\s+', '')
    let $card := replace($type, '^\i\c+', '')
    let $minMax :=
        if (not($card)) then (1, 1)
        else if ($card = '?') then (0, 1)        
        else if ($card = '*') then (0, -1)
        else if ($card = '+') then (1, -1)        
        else
            let $limits := tokenize(replace($card, '[{}]', ''), ',')
            let $min := $limits[1] ! xs:integer(.)
            let $max := 
                if (empty($limits[2])) then $min
                else if ($limits[2] eq '*') then -1
                else xs:integer($limits[2])
            return ($min, $max)
    let $itemType := replace($type, '^(\i\c+).*', '$1')
    let $numeric := $itemType castable as xs:long
    return
        element {node-name($p)}{
            $p/@*,
            attribute itemType {$itemType},
            attribute minOccurs {$minMax[1]},
            attribute maxOccurs {$minMax[2]},
            attribute numeric {$numeric}
        }
};

