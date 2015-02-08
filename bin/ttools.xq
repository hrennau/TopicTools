(:
 : ttools - A tool for creating topic tools
 :
 : @version 2014-04-07T23:24:01.156+02:00 
 :)

import module namespace tt="http://www.ttools.org/xquery-functions" at
    "tt/_rcat.mod.xq",
    "tt/_request.mod.xq",
    "tt/_help.mod.xq";
    

import module namespace i="http://www.ttools.org/ttools/xquery-functions" at
    "example.mod.xq",
    "prototypeWriter.mod.xq",
    "builder.mod.xq",
    "util.mod.xq";    
   
declare namespace m="http://www.ttools.org/ttools/xquery-functions";
declare namespace z="http://www.ttools.org/ttools/structure";
declare namespace ztt="http://www.ttools.org/structure";

declare variable $request as xs:string external;

(: Service configuration. 
   ======================
:)
declare variable $toolScheme :=
<service name="ttools">
  <operation name="counts" func="getCounts" provider="example.mod.xq">
    <param name="doc" type="docUri" required="true"/>
  </operation>
  <operation name="items" func="getItemReport" provider="example.mod.xq">
    <paramConstraints>
      <exactlyOneOf>doc dcat</exactlyOneOf>
    </paramConstraints>
    <param name="count" type="xs:boolean" default="true"/>
    <param name="doc" type="doc"/>
    <param name="dcat" type="dcat"/>
    <param name="names" type="nameFilter" default="*"/>
    <param name="path" type="xs:boolean" default="false"/>
    <param name="scope" type="xs:string" default="all" values="atts, elems, att"/>
    <param name="simple" type="xs:boolean" default="false"/>
    <param name="values" type="xs:boolean" default="false"/>
    <param name="nval" type="xs:integer" default="10"/>
    <param name="nvalues" type="nameFilterMap"/>
    <param name="npvalues" type="nameFilterMap"/>
  </operation>
  <operation name="add" func="addModule" type="empty-sequence()" provider="prototypeWriter.mod.xq">
    <param name="dir" type="directory"/>
    <param name="name" type="xs:NCName?"/>
    <param name="mod" type="xs:NCName"/>
    <param name="ops" type="xs:NCName+"/>
    <param name="flavor" type="xs:string*" default="basex79"
        fct_pattern="basex\d\d|saxon(he|pe|ee)\d\d|xq(10|30)[fse]*"/>
  </operation>
  <operation name="new" func="new" type="node()">
    <param name="dir" type="directory" fct_dirExists="false"/>
    <param name="name" type="xs:NCName?"/>
    <param name="explain" type="xs:string?"/>     
    <param name="mod" type="xs:NCName?"/>
    <param name="ops" type="xs:NCName*"/>  
    <param name="flavor" type="xs:string*" default="basex79"
        fct_pattern="basex\d\d|saxon(he|pe|ee)\d\d|xq(10|30)[fse]*"/>           
    <param name="namespace" type="xs:string?"/>    
    <param name="namespaceFunc" type="xs:string?"/>    
    <param name="namespaceError" type="xs:string?"/>    
    <param name="namespaceStruct" type="xs:string?"/>    
  </operation>  
  <operation name="build" func="build" type="empty-sequence()">
    <param name="dir" type="directory" fct_dirExists="true"/>
    <param name="name" type="xs:NCName?"/>
    <param name="explain" type="xs:string?"/>
    <param name="namespace" type="xs:string?"/>    
    <param name="upgrade" type="xs:boolean" default="true"/>
    <param name="flavor" type="xs:string*"
        fct_pattern="basex\d\d|saxon(he|pe|ee)\d\d|xq(10|30)[fse]*"/>
  </operation>  
  <operation name="dcat" func="getDocumentCat" provider="_rcat.mod.xq">
    <param name="dcat" type="dcat" required="true"/>
    <param name="echo" type="xs:boolean" default="false"/>
  </operation>
  <operation name="docs" func="getDocuments" provider="_rcat.mod.xq">
    <param name="docs" type="docDFD" required="true"/>
    <param name="echo" type="xs:boolean" default="false"/>
  </operation>
  <operationsDoc/>
</service>;

declare variable $req as element() := tt:loadRequest($request, $toolScheme);

(:~
 : Executes operation '_help'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation__help($request as element())
        as node() {
    tt:_help($request, $toolScheme)        
};


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

    
(:~
 : Executes operation 'counts'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation_counts($request as element())
        as node() {
    i:getCounts($request)        
};
     
(:~
 : Executes operation 'items'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation_items($request as element())
        as node() {
    i:getItemReport($request)        
};
     
(:~
 : Executes operation 'proto'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation_add($request as element())
        as node()* {
    let $result := i:addModule($request)
    let $errors := $result/descendant-or-self::*:error    
    return
        if ($errors) then tt:_getErrorReport($errors, ()) else $result  
};
     
(:~
 : Executes operation 'new'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation_new($request as element())
        as node() {
    let $result := i:new($request)
    return
        if ($result/self::ztt:errors) then 
            tt:_getErrorReport($result, 'Annotation errors', 'module', ()) 
        else $result
};
     
(:~
 : Executes operation 'build'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation_build($request as element())
        as element()? {
    let $errors := i:build($request)
    return
        if ($errors) then tt:_getErrorReport($errors, 'Annotation errors', 'module', ()) else ()
};

(:
(:~
 : Executes operation 'dcat'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation_dcat($request as element())
        as node() {
    tt:getDocumentCat($request)        
};
     
(:~
 : Executes operation 'docs'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation_docs($request as element())
        as node() {
    tt:getDocuments($request)        
};
:)

(:~
 : Executes an operation.
 :
 : @param req the operation request
 : @return the result of the operation
 :)
declare function m:execOperation($req as element())
      as item()* {
    if ($req/self::ztt:errors) then tt:_getErrorReport($req, 'Invalid call', 'code', ()) else
    if ($req/@storeq eq 'true') then m:execOperation__storeq($req) else
    
    let $opName := tt:getOperationName($req) 
    let $result :=    
        if ($opName eq '_help') then m:execOperation__help($req)
        else if ($opName eq 'counts') then m:execOperation_counts($req)
        else if ($opName eq 'items') then m:execOperation_items($req)
        else if ($opName eq 'add') then m:execOperation_add($req)
        else if ($opName eq 'new') then m:execOperation_new($req)    
        else if ($opName eq 'build') then m:execOperation_build($req)    
        else
        tt:createError('UNKNOWN_OPERATION', concat('No such operation: ', $opName), 
            <error op='{$opName}'/>)    
     let $errors := tt:extractErrors($result)
     return
         if ($errors) then tt:_getErrorReport($errors, 'System error', 'code', ())     
         else $result
};

m:execOperation($req)
    