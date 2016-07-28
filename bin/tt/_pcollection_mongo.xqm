(:
 :***************************************************************************
 :
 : pcollection_mongo.xqm - functions for managing and searching 
 :                               mongodb-based p-faced collections
 :
 :***************************************************************************
 :)
 
module namespace f="http://www.ttools.org/xquery-functions";

(: import module namespace mongodb="http://expath.org/ns/mongodb" at "/projects/infospace/mongodb/mongodb.xqm"; :)
import module namespace mongodb="http://expath.org/ns/mongodb" at "mongodb.xqm";

import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "_errorAssistent.xqm",   
    "_mongoExecutor.xqm",
    "_nameFilter.xqm",
    "_pcollection_utils.xqm",    
    "_pfilter.xqm",    
    "_pfilter_parser.xqm",
    "_request.xqm",
    "_reportAssistent.xqm",
    "_resourceAccess.xqm";

declare namespace z="http://www.ttools.org/structure";
declare namespace pc="http://www.infospace.org/pcollection";

(:
 : ============================================================================
 :
 :     p r i v a t e    f u n c t i o n s
 :
 : ============================================================================
 :)

(:~
 : Returns a filtered pcollection. If no query is specified, the complete collection
 : is returned, otherwise only those collection members whose external properties
 : match the query.
 :
 : @param enodl the extended NODL document describing the collection
 : @param query a pfilter against which the external properties of the collection 
 :    members are matched
 : @return all collection members whose external properties match the specified
 :    pfilter, or all collection members if no pfilter has been specified
 :) 
declare function f:_filteredCollection_mongo($enodl as element(pc:enodl), $pfilter as element(pc:pfilter)?)
        as node()* {
    let $pmodel := $enodl/pc:pmodel
    let $nodeConstructor := $enodl/pc:nodeConstructor/@kind/tokenize(., '\+')[1]        
    let $mongoQuery := f:pfilter2MongoQuery($pfilter, $pmodel)
    let $mongoField := 
        if ($nodeConstructor eq 'uri') then '_node_uri'
        else if ($nodeConstructor eq 'text') then '_node_text'
        else tt:createError('INVALID_NODL', 
            concat('Unexpected node constructor: ', $nodeConstructor), ())

    let $connInfo := $enodl//pc:mongoNcat/pc:connection
    let $conn := f:_mongoConnectForExtendedNodl($enodl)
    let $result :=
        mongodb:find($conn, $connInfo/@db, $connInfo/@collection, 
            $mongoQuery, map{'fields' : map{$mongoField : 1, '_id' : 0}})
    let $xresult := for $r in $result return f:map2Elem($r, 'z:doc')
    let $docs := 
        if ($nodeConstructor eq 'uri') then
            for $r in $result return doc(map:get($r, '_node_uri'))
        else if ($nodeConstructor eq 'text') then
            for $r in $result return parse-xml(map:get($r, '_node_text'))
        else
            tt:createError('UNKNOWN_NODE_CONSTRUCTOR', 
                concat('Unknown node constructor kind: ', $nodeConstructor), ())
    return
        $docs
        (: <z:searchResult count="{count($xresult)}">{$docs}</z:searchResult> :)
};

(:~
 : Returns the size of a filtered pcollection. If no query is specified, the 
 : collection size is returned, otherwise the number of collection members
 : matching the query.
 :
 : @param nodl the NODL document describing the collection
 : @param query a pfilter against which the external properties of the collection 
 :    members are matched
 : @return all collection members whose external properties match the specified
 :    pfilter, or all collection members if no pfilter has been specified
 :) 
declare function f:_filteredCollectionCount_mongo($enodl as element(pc:enodl), 
                                                  $pfilter as element(pc:pfilter)?)
        as xs:integer {
    let $pmodel := $enodl/pc:pmodel       
    let $mongoQuery := f:pfilter2MongoQuery($pfilter, $pmodel)
    let $connInfo := $enodl//pc:mongoNcat/pc:connection
    let $conn := f:_mongoConnectForExtendedNodl($enodl)
    let $count :=
        mongodb:count($conn, $connInfo/@db, $connInfo/@collection, $mongoQuery)
    return $count
};

(:~
 : Creates a collection to be used as a MongoDB-based ncat.
 :
 : @param request the operation request
 : @return a report describing ...
 :) 
declare function f:_createMongoNcat($enodl as element(pc:enodl), $request as element())
        as element() {
     try {
         let $conn := f:_mongoConnectForExtendedNodl($enodl) 
         let $ret := f:_createMongoCollectionForExtendedNodl($conn, $enodl)   
         return
            if ($ret/@alreadyExists eq 'true') then
                let $mongo := $enodl//pc:mongoNcat
                let $db := $mongo/pc:connection/@db
                let $collection := concat('ncat_', $enodl/pc:collection/@name)
                return                
                    tt:createError('COLLECTION_EXISTS', 
                        concat('Collection already exists; db=', $db, '; collection=', $collection,
                        '; nodl-uri=', $enodl/@nodlURI), ())
            else                                     
                <z:ncatCreated>{$ret/(@db, @collection, @collectionSize)}</z:ncatCreated>
     } catch * {
         tt:createError('MONGO_ERROR', $err:description, ())        
     }
};        

(:~
 : Deletes the tables required by a pcollection. Note that the database is
 : not deleted, even if it does not contain any tables except for those now
 : deleted.
 :
 : @param enodl an extended NODL
 : @param request the operation request
 : @return a report describing the Ncat deletion
 :) 
declare function f:_deleteMongoNcat($enodl as element(pc:enodl), $request as element())
        as element() {       
    let $conn := f:_mongoConnectForExtendedNodl($enodl)
    let $connInfo := $enodl//pc:mongoNcat/pc:connection
    let $db := $connInfo/@db
    let $collection := $connInfo/@collection    
    let $r_dropCollection := mongodb:drop-collection($conn, $db, $collection)
    let $remaining := mongodb:list-collections($conn, $db)
    return
        <z:deleteMongoNcat collectionName="{$collection}">{
            <z:collectionsAfter count="{count($remaining)}">{
                for $c in $remaining
                let $count := mongodb:count($conn, $db, $c)
                order by lower-case($c)
                return <z:collection name="{$c}" count="{$count}"/>
            }</z:collectionsAfter>
        }</z:deleteMongoNcat>
};        

(:~
 : Feeds a MongoDB based ncat with pnodes created for a set of XML documents.
 :
 : @param enodl an enodl (extended nodl) element
 : @param request the operation request
 : @return a report describing completion
 :) 
declare function f:_feedMongoNcat($enodl as element(pc:enodl), $request as element())
        as element() {
    let $dcat := tt:getParams($request, 'docs dox')  
    let $doc := tt:getParams($request, 'doc')
    let $path := tt:getParams($request, 'path')
    
    (: create and add pnodes :)
    
    let $conn := f:_mongoConnectForExtendedNodl($enodl)   
    let $pmodel := $enodl/pc:pmodel
    let $nodeConstructor := $enodl/pc:nodeConstructor    
    let $mongoNcat := $enodl//pc:mongoNcat
    
    let $results := (   
        for $d in $doc
        let $uri := if ($path) then () else document-uri($d)
        let $nodes := if (not($path)) then $d else tt:evaluate($path, $d) 
        for $node in $nodes
        let $node := if ($node/self::document-node()) then $node else document {$node}
        let $pnode := tt:_pnode($node, $uri, $pmodel, $nodeConstructor)
        return
            f:_insertPnode_mongo($conn, (), $uri, $pnode, $node, $pmodel, $mongoNcat)
        ,       
        for $href in $dcat//@href
        let $uri := $href/resolve-uri(., base-uri(..))        
        return
            f:_createAndInsertPnode_mongo($uri, $path, $conn, 
                $nodeConstructor, $pmodel, $mongoNcat)
    )
    return
        <feedNcat name="{$enodl//pc:collection/@name}"/>
};

(:~
 : Creates a pnode and imports it into a MongoDB based ncat.
 :
 : @param uri the node URI
 : @param path a path expression leading from the document root to the node(s) to be imported
 : @param conn a connection handle
 : @param nodeConstructor the node constructor element of an enodl
 : @param pmodel the pmodel element of an enodl
 : @param mongoNcat the mongoNcat element of an enodl
 : @return the empty sequence
 :)
declare function f:_createAndInsertPnode_mongo($uri as xs:string,
                                               $path as xs:string?,
                                               $conn as xs:string,
                                               $nodeConstructor as element(pc:nodeConstructor),
                                               $pmodel as element(pc:pmodel),
                                               $mongoNcat as element(pc:mongoNcat))
        as empty-sequence() {
    let $node := tt:doc($uri)
    let $node := 
        if (not($path)) then $node else tt:evaluate($path, $node)
    let $pnode := tt:_pnode($node, $uri, $pmodel, $nodeConstructor)
    return
        f:_insertPnode_mongo($conn, (), $uri, $pnode, $node, $pmodel, $mongoNcat)
};

(:~
 : Imports a pnode into a MongoDB based ncat.
 :
 : @param conn a connection handle
 : @param nkey if specified, the node key to be used when inserting node-related rows into the database
 : @param nodeUri the node URI of the node to be processed
 : @param pnode the pnode describing the node
 : @param node the node itself 
 : @param mongo a MongoDB processing plan
 : @return items received as result when inserting rows into the database
 :)
declare function f:_insertPnode_mongo($conn as xs:string,
                                      $nkey as xs:string?,
                                      $nodeUri as xs:string?,
                                      $pnode as element(pc:pnode),
                                      $node as node()?,
                                      $pmodel as element(pc:pmodel),
                                      $mongoNcat as element(pc:mongoNcat))
        as empty-sequence() {
    let $nodeUri := $pnode/@_node_uri/string()
    let $nodeText := 
        if (not($pnode/pc:_node)) then () 
        else
            let $serParams := $tt:NODE_SER_PARAMS
            return serialize($pnode/pc:_node/*, $serParams)
    let $document :=
        map:merge((
            if (not($nodeUri)) then () else
                map{"_node_uri" : $nodeUri},
            if (not($nodeText)) then () else
                map{"_node_text" : $nodeText},
            for $node in $pnode/((@* except @_node_uri), (* except pc:_node))
            let $name := local-name($node)
            let $propertyModel := $pmodel/pc:property[@name eq $name]
            let $category := $propertyModel/@itemTypeCategory/string()
            let $maxOccurs := $propertyModel/@maxOccurs/xs:integer(.)            
            let $valueItems := if (not($node/*)) then $node else $node/*
            let $values := 
                if ($category eq 'string') then $valueItems ! string(.)
                else if ($category eq 'number') then $valueItems ! number(.)
                else if ($category eq 'boolean') then $valueItems ! xs:boolean(.)
                else $valueItems ! string(.)
            let $mapValue :=
                if (count($values) le 1 and $maxOccurs le 1) then $values
                else array { $values }
            return map { $name : $mapValue }
        ))
    return
        mongodb:insert($conn, 
                       $mongoNcat/pc:connection/@db/string(), 
                       $mongoNcat/pc:connection/@collection/string(), 
                       $document)        
};

(:~
 : Retrieves pnodes from a MongoDB based ncat. 
 :
 : @param enodl the extended NODL document describing the ncat
 : @param query only pnodes matching this pfilter are exported
 : @return a sequence of pnodes
 :) 
declare function f:_getPnodes_mongo($enodl as element(pc:enodl), $pfilter as element(pc:pfilter)?)
        as node()* {
    error()        
};

(:~
 : Retrieves a pnode from a MongoDB based ncat.
 :
 : @param conn a connection handle
 : @param nkey the primary key of the node in the main table
 : @return a pnode capturing the node identity and the node properties
 :)
declare function f:_getPnode_mongo($conn as xs:string,
                                   $nkey as xs:string,
                                   $mongo as element(mongoProcessingPlan))
        as element(pc:pnode)? {
    error()        
};

(:~
 : Maps an property element to a MongoDB data type.
 :
 : @param rpType the property data type
 : @return the SQL data type
 :)
declare function f:_propertyMongoType($p as element())
        as xs:string {
    error()        
};        

(:~
 : Opens a connection to the data base specified by a nodl.
 :
 : @param enodl an extended nodl
 : @return the connection handle
 :)
declare function f:_mongoConnectForExtendedNodl($enodl as element())
        as xs:string {
    let $connData := $enodl//pc:mongoNcat/pc:connection
    let $conn := tt:mongoConnect($connData/@host) 
    return
        $conn
};        

(:~
 : Creates the collection specified by the nodl.
 :
 : @param enodel an extended nodl
 : @return the connection handle
 :)
declare function f:_createMongoCollectionForExtendedNodl($conn as xs:string, $enodl as element())
        as element(z:createCollection) {
    let $mongo := $enodl//pc:mongoNcat
    let $db := $mongo/pc:connection/@db
    let $collection := $enodl/pc:collection/@name/concat('ncat_', .)
    
    let $indexDocs :=    
        let $pmodel := $enodl/pc:pmodel
        let $nodeDescKinds := $enodl/pc:nodeConstructor/@kind/tokenize(., '\+')
        return
            for $p in $pmodel/(* except pc:anyProperty)
            return (
                map{$p/@name/string() : 1},
                if (not($nodeDescKinds)) then () else
                    map{'_node_uri' : 1}
            )
    
    let $ret1 := tt:createCollection($conn, $db, $collection)
    return $ret1
};        


(:~
 : Creates the data base specified by a nodl.
 :
 : @param enodel an extended nodl
 : @return the connection handle
 :)
declare function f:_createMongoDbForExtendedNodl($conn as xs:integer, $enodl as element())
        as xs:integer? {
    error()
};        


(:~
 : Opens a connection to the data base specified by a nodl.
 :
 : @param enodel an extended nodl
 : @return the connection handle
 :)
declare function f:_openMongoDbForExtendedNodl($conn as xs:string, $enodl as element())
        as xs:integer? {
    error()        
};        

(:~
 : Maps a property value item to the value which is actually stored
 : in the SQL data base.
 :
 : @param value the value item
 : @sqlType the SQL type
 : @return the string to be stored
 :)
declare function f:_value2mongoValue($value as item()?, $sqlType as xs:string)
        as xs:string {
    error()        
};

(:~
 : Transforms a document into document text to be stored
 : in a relational database.
 :
 : @param doc the document
 : @return the document text ready for storage
 :)
declare function f:_getDocTextForMongo($doc as node())
        as xs:string {
    error()        
};            

(:~
 : Transforms a pfilter into a MongoDB query.
 :
 : @param pfilter a pfilter
 : @param pmodel a pmodel 
 : @return the text of the where clause
 :)
declare function f:pfilter2MongoQuery($pfilter as element(pc:pfilter)?, 
                                      $pmodel as element(pc:pmodel))
        as item() {
    if (not($pfilter)) then () else
    
    let $xquery :=
        let $tree := f:_pfilter2MongoQueryRC($pfilter/*, $pmodel)
        return
            <mq>{
                if ($tree/self::mqAnd) then $tree/* else $tree
            }</mq>
     let $mquery := f:mongoQueryXml2MongoQuery($xquery, $pmodel)
     return
        $mquery
};

(:~
 : Transforms a pfilter into a where clause expressing it.
 :
 : @param pfn a pfilter node
 : @return the fragment of the where clause corresponding to the given pfilter node
 :)
declare function f:_pfilter2MongoQueryRC($pfn as element(), $pmodel as element(pc:pmodel))
        as element() {
    typeswitch ($pfn)
    case element(pc:and) return
        <mqAnd>{for $child in $pfn/* return f:_pfilter2MongoQueryRC($child, $pmodel)}</mqAnd>
    case element(pc:or) return
        <mqOr>{for $child in $pfn/* return f:_pfilter2MongoQueryRC($child, $pmodel)}</mqOr>    
    case element(pc:not) return
        <mqNot>{f:_pfilter2MongoQueryRC($pfn/*, $pmodel)}</mqNot>    
    case $p as element(pc:p) return
        let $pname := $p/@name
        let $op := $p/@op             
        let $tvalue := 
            if ($p/pc:value/pc:item) 
            then $p/pc:value/pc:item/string() 
            else $p/pc:value/string() 
        let $useTvalue :=
            let $edited :=
                if (not($op eq '~')) then $tvalue else 
                    let $tvs := for $v in $tvalue return replace($v, '\*', '.*')
                    let $tvs := for $v in $tvs return replace($v, '[\[\]{}+?^$]', '\\$0')
                    let $tvs := for $v in $tvs return concat('^', $v, '$')
                    return $tvs                    
            return $edited 
        return
            <mqCmp name="{$pname}">{
                if (count($useTvalue) gt 1) then
                    <mqIn>{
                        attribute mqOp {$op},
                        for $tv in $useTvalue return <mqItem>{$tv}</mqItem>
                    }</mqIn>
                else if ($op eq '=') then $tvalue
                else
                    let $elemName :=
                        <ops>
                            <op t="&lt;" mqt="_.lt"/>
                            <op t="&lt;=" mqt="_.lte"/>                        
                            <op t=">" mqt="_.gt"/>
                            <op t=">=" mqt="_.gte"/>                        
                            <op t="~" mqt="_.regex"/>
                        </ops>/*[@t eq $op]/@mqt/string()
                    return
                        element {$elemName} {$useTvalue}
            }</mqCmp>
    default return
        error(QName($tt:URI_ERROR, 'INVALID_PFILTER'), concat('Unexpected element, local name: ', local-name($pfn)))
};

(:~
 : Transforms the XML representation of a MongoDB query into a
 : map representation.
 :
 : Note. The MongoDB module requires queries to be supplied as
 : map representations.
 :
 : @param xquery an XML representation of the query
 : @param pmodel the p-model describing the external properties of the p-collection 
 : @return a map representation of the query
 :)
declare function f:mongoQueryXml2MongoQuery($xquery as element(mq), 
                                            $pmodel as element(pc:pmodel))
        as map(*) {
    f:mongoQueryXml2MongoQueryRC($xquery, $pmodel)            
};

(:~
 : Recursive helper function of `mongoQueryXml2MongoQuery
 :
 : @param n the node to be processed
 : @param pmodel the p-model describing the external properties of the p-collection
 : @return a map representation of the input node
 :)
declare function f:mongoQueryXml2MongoQueryRC($n as node(), 
                                              $pmodel as element(pc:pmodel))
        as item() {
    typeswitch($n)
    
    case element(mq) return
        map:merge(
            for $c in $n/* return f:mongoQueryXml2MongoQueryRC($c, $pmodel)
        )
    case element(mqAnd) return
        map{"$and" :
            array {
                for $c in $n/* return f:mongoQueryXml2MongoQueryRC($c, $pmodel)            
            }
        }
    case element(mqOr) return
        map{"$or" :
            array {
                for $c in $n/* return f:mongoQueryXml2MongoQueryRC($c, $pmodel)            
           }
        }
    case element(mqNot) return
        map{"$not" :
            f:mongoQueryXml2MongoQueryRC($n/*, $pmodel)            
        }
    case element(mqCmp) return    
        let $name := $n/@name
        return
            if (not($n/*)) then 
                let $value := f:_getTypedMongoItems($n, $name, $pmodel)
                return map{$name : $value}
            else
                map{$name : f:mongoQueryXml2MongoQueryRC($n/*, $pmodel)}         

    case element(mqIn) return
        map{'$in' :
            if ($n/@mqOp eq '~') then
                array {$n/*/concat('/', string(), '/i')}
            else
                let $name := $n/ancestor::*[@name][1]/@name
                let $values := f:_getTypedMongoItems($n/*, $name, $pmodel)
                return array {$values}
        }
        
    case element(_.regex) return
        map{'$regex' : string($n) }
        
    case element(_.lt) return
        let $name := ancestor::*[@name][1]/@name    
        let $value := f:_getTypedMongoItems($n, $name, $pmodel)    
        return map{'$lt' : $value}
        
    case element(_.lte) return
        let $name := ancestor::*[@name][1]/@name    
        let $value := f:_getTypedMongoItems($n, $name, $pmodel)    
        return map{'$lte' : $value}
        
    case element(_.gt) return
        let $name := $n/ancestor::*[@name][1]/@name    
        let $value := f:_getTypedMongoItems($n, $name, $pmodel)    
        return map{'$gt' : $value}
        
    case element(_.gte) return
        let $name := $n/ancestor::*[@name][1]/@name    
        let $value := f:_getTypedMongoItems($n, $name, $pmodel)    
        return map{'$gte' : $value}
        
    case element(_.eq) return
        let $name := $n/ancestor::*[@name][1]/@name    
        let $value := f:_getTypedMongoItems($n, $name, $pmodel)    
        return map{'$eq' : $value}
        
    case element(_.ne) return
        let $name := $n/ancestor::*[@name][1]/@name    
        let $value := f:_getTypedMongoItems($n, $name, $pmodel)    
        return map{'$ne' : $value}
        
    default return
        tt:createError('PROGRAM_ERROR', concat('Unexpected MongoDB query xml node: ', name($n)), ())        
        
};

(:~
 : Returns for a sequence of pnode items represented by nodes
 : typed values.
 :
 : Note. The typed values are determined in accordance to
 : the item type category (number, string, boolean, other).
 :
 : @param items nodes containing the item data
 : @param pname the name of the external property
 : @param pmodel a model of the external properties
 : @return the items represented by typed items
 :)
declare function f:_getTypedMongoItems($items as node()*, 
                                       $pname as xs:string, 
                                       $pmodel as element(pc:pmodel))
        as item()* {
    let $propertyModel := $pmodel/*[@name eq $pname]
    let $category := $propertyModel/@itemTypeCategory
    return
        if ($category eq 'number') then $items ! number(.)
        else if ($category eq 'boolean') then $items ! xs:boolean(.)
        else $items ! string(.)       
};

declare function f:map2Elem($map as map(*), $name as xs:string)
        as element() {
    element {$name} {
        for $key in map:keys($map)
        let $useKey := replace($key, '\$', '_.')
        let $value := $map($key)
        return
            typeswitch($value)
            case map(*) return f:map2Elem($value, $useKey)
            case array(*) return f:array2Elem($value, $useKey, 'item')
            default return element {$useKey} {$value}
    }
};

declare function f:array2Elem($arr as array(*), $name as xs:string, $itemName as xs:string)
        as element() {
    element {$name} {
        for $index in 1 to array:size($arr)
        let $value := array:get($arr, $index)
        return
            typeswitch($value)
            case map(*) return f:map2Elem($value, $itemName)
            case array(*) return f:array2Elem($value, $name, $itemName)
            default return element {$itemName} {$value}
    }
};

declare function f:_feedMongoNcat2($enodl as element(pc:enodl), $request as element())
        as element() {
    let $dcat := tt:getParams($request, 'docs dox')  
    let $doc := tt:getParams($request, 'doc')
    let $path := tt:getParams($request, 'path')
    
    (: add nodes from dcat :)
    let $conn := f:_mongoConnectForExtendedNodl($enodl)   
    let $pmodel := $enodl/pc:pmodel
    let $nodeConstructor := $enodl/pc:nodeConstructor    
    let $mongoNcat := $enodl//pc:mongoNcat
    let $results := (   
        for $d in $doc
        let $nodes :=  
            if (not($path)) then $d else 
                for $root in tt:evaluate($path, $d) return document {$root}
        let $uri := ()
        for $node in $nodes
        let $pnode := tt:_pnode($node, $uri, $pmodel, $nodeConstructor)
        return
            f:_insertPnode_mongo($conn, (), $uri, $pnode, $node, $pmodel, $mongoNcat) (: [last() ne 9999999] :)
        ,       
        for $href in $dcat//@href
        return
            f:_createAndInsertPnode_mongo($href, $path, $conn, $nodeConstructor, $pmodel, $mongoNcat)
    )
    return
        <feedNcat name="{$enodl//pc:collection/@name}" 
                  countProcessed="{count($dcat//@href)}"/>
};

(:~
 : Feeds an ncat with pnodes created for a set of XML documents.
 :
 : @param request the operation request
 : @return a report describing ...
 :) 
 (:~@operation
    <operation name="test01" type="empty-sequence()" func="test01">     
    </operation>   
:)
declare function f:test01($request as element())
        as element()? {
    let $doc := doc('otds-fti')
    for $node at $pos in tt:evaluate('/*/*:Accommodations/*:Accommodation', $doc)
    return        
        file:write(concat('/tmp/f', $pos), $node)
};        
