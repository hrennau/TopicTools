xquery version "3.0";
(:
 :***************************************************************************
 :
 : _pcollection_xml.mod.xq - functions for managing and searching XML based pollections
 :
 :***************************************************************************
 :)
 
module namespace f="http://www.ttools.org/xquery-functions";
import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "_errorAssistent.mod.xq",    
    "_nameFilter.mod.xq",
    "_pcollection_utils.mod.xq",    
    "_pfilter.mod.xq",    
    "_pfilter_parser.mod.xq",
    "_processorSpecific.mod.xq",    
    "_request.mod.xq",
    "_reportAssistent.mod.xq",    
    "_pfilter.mod.xq";

declare namespace z="http://www.ttools.org/structure";
declare namespace pc="http://www.infospace.org/pcollection";
declare namespace file="http://expath.org/ns/file";

(:
 : ============================================================================
 :
 :     p r i v a t e    f u n c t i o n s
 :
 : ============================================================================
 :)

(:~
 : Returns a filtered pcollection which is implemented by an XML based ncat. 
 : If no query is specified, the complete collection is returned, otherwise only 
 : those collection members whose external properties match the query.
 :
 : @param enodl the extended NODL document describing the collection
 : @param pfilter a pfilter against which the external properties of the collection 
 :    members are matched
 : @return all collection members whose external properties match the specified
 :    pfilter, or all collection members if no pfilter has been specified
 :) 
declare function f:_filteredCollection_xml($enodl as element(pc:enodl), $pfilter as element(pc:pfilter)?)
        as node()* {
    let $ncatUri := $enodl//pc:xmlNcat/@documentURI
    let $ncat :=
        if (tt:doc-available($ncatUri)) then tt:doc($ncatUri)/* else ()
    return if (not($ncat)) then
        let $msg :=
            if (not($ncatUri)) then 'The xml NCAT model does not specify a node URI.'
            else
                concat('The specified NCAT document cannot be opened; URI: ''', $ncatUri, '''.')
        return tt:createError('INVALID_NODL', $msg, ())
    else

    for $pnode in $ncat//pc:pnode        
    where not($pfilter) or tt:matchesPfilter($pnode, $pfilter)
    return
        let $uri := $pnode/@node_uri/resolve-uri(., base-uri(..))
        return
            if (not(tt:doc-available($uri))) then () else tt:doc($uri)       
};

(:#file eval#:)
(:~
 : Creates a new xml based ncat.
 :
 : @param request the operation request
 : @return a report describing ...
 :) 
declare function f:_createXmlNcat($enodl as element(pc:enodl), $request as element())
        as element()? {
    let $xmlNcat := $enodl//pc:ncatModel/pc:xmlNcat
    let $docUri := $xmlNcat/@documentURI/resolve-uri(., base-uri(..))
    
    return
        if (file:exists($docUri)) then
            tt:createError('INVALID_ARG', concat('Cannot create NCAT ',
            'at this URI: ', $docUri, ' - file exists'), ())
        else            
            let $ncat :=
                <pnodes xmlns="http://www.infospace.org/pcollection">{
                    $enodl//pc:collection/@*,
                    attribute nodeProviderKind {$enodl//pc:nodeProvider/@kind},
                    attribute countNodes {'0'}
                }</pnodes>
            return (
                file:write($docUri, $ncat),
                <z:createNcat msg="XML NCAT written" documentURI="{$docUri}"/>
            )                
};
(:##:)

(:#file#:)
(:~
 : Deletes an XML based ncat.
 :
 : @param request the operation request
 : @return a report describing ...
 :) 
declare function f:_deleteXmlNcat($enodl as element(pc:enodl), $request as element())
        as element()? {
    let $xmlNcat := $enodl//pc:ncatModel/pc:xmlNcat
    let $docUri := $xmlNcat/@documentURI/resolve-uri(., base-uri(..))
    
    return
        if (not(file:exists($docUri))) then
            tt:createError('INVALID_ARG', concat('No NCAT found at this URI: ', $docUri), ())
        else  (       
            file:delete($docUri),
            <z:deleteNcat nodl="{$enodl/@nodlURI}" ncatURI="{$docUri}"/>
        )            
};
(:##:)

(:#file eval#:)
(:~
 : Feeds an ncat with pnodes created for a set of XML documents.
 :
 : @param an extended NODL element
 : @request the operation request
 : @return an element providing some counts concerning the feed operation
 :) 
declare function f:_feedXmlNcat($enodl as element(pc:enodl), $request as element())
        as element() {
    let $ncatUri := $enodl//pc:xmlNcat/@documentURI
    let $ncat :=
        if (tt:doc-available($ncatUri)) then tt:doc($ncatUri)/*
        else f:_createXmlNcat($enodl, $request)
     
    let $dcat := tt:getParams($request, 'dirs')
    let $pnodeModel := tt:_pnodeModel($enodl)
    let $pnodes :=    
        for $href in $dcat//@href
        let $uri := $href/resolve-uri(., base-uri(..))
        let $doc := tt:doc($uri)
        return
            tt:_pnode($doc, $uri, $pnodeModel)
    let $uris := $pnodes/@node_uri            
    let $newNcat :=
        let $newPnodes := (
            $ncat/pc:pnode[not(@node_uri = $uris)],
            $pnodes
        )
        return
            element {node-name($ncat)} {
                $ncat/(@* except @countNodes),
                attribute countNodes {count($newPnodes)},
                $ncat/(* except pc:pnode),
                $newPnodes
            }   
    let $oldNcatSize := count($ncat//pc:pnode)
    let $newNcatSize := count($newNcat//pc:pnode)    
    return (
        file:write($ncatUri, $newNcat),
        <feedNcat name="{$enodl//pc:collection/@name}" 
                  countNewPnodes="{count($pnodes)}"
                  oldNcatSize="{$oldNcatSize}"
                  newNcatSize="{$newNcatSize}"/>        
    )
};

(:##:)
(:~
 : Retrieves pnodes from an XML based ncat.
 :
 : @param enodl the extended NODL document describing the ncat
 : @param query only pnodes matching this pfilter are exported
 : @return a sequence of pnodes
 :) 
declare function f:_getPnodes_xml($enodl as element(pc:enodl), $pfilter as element(pc:pfilter)?)
        as node()* {
    let $ncatUri := f:_getNcatURI_xml($enodl)
    let $ncat := f:_getNcat_xml($enodl)
    return if (not($ncat)) then
        let $msg :=
            if (not($ncatUri)) then 'The xml NCAT model does not specify a document URI.'
            else
                concat('The specified NCAT document cannot be opened; URI: ''', $ncatUri, '''.')
        return tt:createError('INVALID_NODL', $msg, ())
    else

    if (not($pfilter)) then $ncat//pc:pnode
    else
        for $pnode in $ncat//pc:pnode        
        where tt:matchesPfilter($pnode, $pfilter)
        return
            $pnode    
};

(:#file#:)
(:~
 : Inserts pnodes into an XML based ncat. Any existing pnodes with
 : a node URI found among the new pnodes is replaced.
 :
 : @param request the operation request
 : @return a report describing ...
 :) 
declare function f:_insertPnodes_xml($enodl as element(pc:enodl), 
                                     $pnodes as element()*)
        as element()? {
    let $ncat := f:_getNcat_xml($enodl)
    return if (not($ncat)) then () else
    
    let $asElemNames :=
        for $item in $enodl/pc:ncatModel/pc:xmlNcat/@asElement/tokenize(normalize-space(.), ' ') return
            concat('^', replace($item, '\*', '.*'), '$')

    (: the inserted pnodes are edited so as to conform to the @asElement configuration :)
    let $pnodesInserted :=
        if (empty($asElemNames)) then $pnodes
        else
            for $pnode in $pnodes
            let $atts :=
                for $a in $pnode/@*
                let $name := local-name($a)
                return
                    if ($name = ('node_uri', 'node_text')) then $a
                    else if (some $n in $asElemNames satisfies matches($name, $n)) then
                        element {$name} {string($a)}
                    else $a
            return
                element {node-name($pnode)} {
                    $atts[self::attribute()],
                    $atts[self::*],
                    $pnode/node()
                }
    let $ncatUri := f:_getNcatURI_xml($enodl)
    let $nodeUris := distinct-values($pnodes/@node_uri)
    let $newNcat :=
        element {node-name($ncat)} {
            $ncat/@*,
            $ncat/pc:pnode[not(@node_uri = $nodeUris)],
            $pnodesInserted
        }
    let $ncatSizeBefore := count($ncat/pc:pnode)
    let $ncatSizeNew := count($newNcat/pc:pnode)
    return (
        file:write($ncatUri, $newNcat),
        <copyNcat targetName="{$enodl//pc:collection/@name}" 
                  countCopied="{count($pnodes)}"
                  targetSizeBefore="{$ncatSizeBefore}"
                  targetSizeAfter="{$ncatSizeNew}"/>
    )
};

(:##:)
(:~
 : Returns the URI of an xml ncat described by a NODL document.
 :
 : @param enodl extended NODL document
 : @return the ncat
 :)
declare function f:_getNcatURI_xml($enodl as element(pc:enodl))
        as xs:string? {
    $enodl//pc:xmlNcat/@documentURI
};

(:~
 : Returns the xml ncat described by a NODL document.
 :
 : @param enodl extended NODL document
 : @return the ncat
 :)
declare function f:_getNcat_xml($enodl as element(pc:enodl))
        as element()? {
    let $ncatUri := f:_getNcatURI_xml($enodl)
    return
        if (tt:doc-available($ncatUri)) then tt:doc($ncatUri)/* else ()
};
