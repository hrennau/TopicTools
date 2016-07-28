(:
 : ============================================================================
 : prototypeWrite.xqm - functions for creating a module prototype
 :
 : @version 20150126-1 
 : ============================================================================
 :)

(:
 :*****************************************************************************
 :
 :     i n t e r f a c e
 :
 :*****************************************************************************
 :)

(:~@operations
    <operations>
        <operation name="add" func="addModule" type="empty-sequence()">
            <param name="dir" type="directory"/>
            <param name="name" type="xs:NCName?"/>          
            <param name="mod" type="xs:NCName"/>
            <param name="ops" type="xs:NCName+"/>            
            <param name="flavor" type="xs:string*" values="xq10, xq10f, xq30, xq30f" default="xq30f"/>           
        </operation>
    </operations>   
:)

module namespace f="http://www.ttools.org/ttools/xquery-functions";
import module namespace tt="http://www.ttools.org/xquery-functions" at
    "tt/_constants.xqm",
    "tt/_request.xqm",
    "tt/_reportAssistent.xqm",
    "tt/_nameFilter.xqm";
    
import module namespace i="http://www.ttools.org/ttools/xquery-functions" at    
    "ttoolsConstants.xqm",
    "util.xqm";

declare namespace z="http://www.ttools.org/ttools/structure";
declare namespace soap="http://schemas.xmlsoap.org/soap/envelope/";

(:~
 : Installs or updates a topic tool application.
 :
 : @param request the operation request
 : @return no return value, side effect is the installation / an update
 :    of the topic tool application.
 :) 
declare function f:addModule($request as element())
        as node()* {
    let $dir as xs:string := tt:getParam($request, 'dir')    
    let $useDir := resolve-uri($dir, static-base-uri())
    let $mod as xs:NCName := tt:getParam($request, 'mod')
    let $useMod := concat($useDir, '/', $mod)
    return
        (: check that module does not already exist :)
        if (file:exists($useMod)) then
            <z:error type="INVALID_PARAMETER_VALUE" paramName="mod" itemValue="{$mod}" 
                msg="{concat('Module ''', $mod, ''' already exists')}"/> 
        
        else
        
    let $name as xs:NCName := 
        let $nameParam as xs:NCName? := tt:getParam($request, 'name')
        return i:getToolName($dir, $nameParam)         
    let $settings := i:getToolSettings($dir, $name)    
    let $flavor as xs:string := trace( i:getToolFlavor($request, $settings) , 'FLAVOR: ') 
    let $namespace as element(namespace) := i:getToolNamespace($request, $name, $settings)                    
    let $features as xs:string* := f:featuresFromFlavor($flavor)
        


    let $ops as xs:string+ := tt:getParam($request, 'ops')       
    let $moduleText := f:writeModule($name, $namespace, $mod, $ops, $features)
    
    let $ttoolsUri := replace(replace(static-base-uri(), '^file:/+(.:)?', ''), '^(.*)/.*', '$1/ttools.xq')    
    let $moduleFname := concat($mod, '.xqm')    
    let $toolUri as xs:string := 
        let $raw := concat($dir, $name, '.xq')   
        return
            replace(replace(replace($raw, '^file:/+', ''), '^.:', ''), '\\', '/')    
    let $dirInfo := replace(replace(replace(replace($dir, '^file:/+', ''), '^.:', ''), '\\', '/'), '/$', '')
    
    return (
        f:deploy($dir, $mod, $moduleText),
        
        let $requestBuild := tt:setParam((), 'dir', $dir, 'directory')
        let $requestBuild:= tt:setParam($requestBuild, 'name', $name, 'xs:NCName')        
        let $requestBuild:= tt:setParam($requestBuild, 'upgrade', 'false', 'xs:boolean')        
        return       
            f:build($requestBuild)
        ,
        <_>        
===============================================================
XQuery module created: {$moduleFname}
Operations:            {$ops}

Directory:             {$dirInfo}
Topic tool:            {$name}
           
The new operations are available. Example:

   basex -b "request={$ops[1]}?doc=doc1.xml doc2.xml doc3.xml" {$toolUri}
   
To implement them, edit these functions: {$ops}    
===============================================================
        </_>/text()
    )        
};

(:~
 : Writes the prototype of an application module.
 :)
declare function f:writeModule($ttname as xs:string,
                               $namespace as element(namespace),
                               $moduleName as xs:string, 
                               $ops as xs:string+, 
                               $features as xs:string*)
        as xs:string {
    let $rawText :=  
    
    <TEXT>        
(:
 : -------------------------------------------------------------------------
 :
 : {$moduleName}.xqm - Document me!
 :
 : -------------------------------------------------------------------------
 :)
 
(:~@operations
   &lt;operations>{
      for $op in $ops return
      <NESTED-TEXT>
      &lt;operation name="{$op}" type="node()" func="{$op}">     
         &lt;param name="doc" type="docURI*" sep="WS" pgroup="input"/>
(:#file#:)         
         &lt;param name="docs" type="docDFD*" sep="SC" pgroup="input"/>
         &lt;param name="dox" type="docFOX*" sep="SC" pgroup="input"/>        
(:##:)         
         &lt;param name="dcat" type="docCAT*" sep="WS" pgroup="input"/>
         &lt;param name="fdocs" type="docSEARCH*" sep="SC" pgroup="input"/>         
         &lt;pgroup name="input" minOccurs="1"/>         
      &lt;/operation>
      </NESTED-TEXT>/replace(., '\s+$', '', 's') }
    &lt;/operations>  
:)  

module namespace f="{$namespace/@func/string()}";
import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "tt/_request.xqm",
    "tt/_reportAssistent.xqm",
    "tt/_errorAssistent.xqm",
    "tt/_log.xqm",
    "tt/_nameFilter.xqm",
    "tt/_pcollection.xqm";    
    
declare namespace z="{$namespace/@struct/string()}";
{
for $op in $ops return
<NESTED-TEXT>
(:~
 : Document me!
 :
 : @param request the operation request
 : @return a report describing ...
 :) 
declare function f:{$op}($request as element())
        as element() {{
(:#file#:)        
    let $docs := tt:getParams($request, 'doc docs dox dcat fdocs')    
(:#file-#:)        
    let $docs := tt:getParams($request, 'doc dcat fdocs')
(:##:)
    return
        &lt;z:{$op} countDocs="{{count($docs)}}">{{
           ()
        }}&lt;/z:{$op}>
}};        
</NESTED-TEXT>/string()
}

</TEXT>/replace(., '^\s+', '', 's')   

    return
        f:filterTextByFeatures($rawText, $features)
};    

(:~
 : Deploys the topic tool and its extensions module.
 :)
declare function f:deploy($dir as xs:string, 
                          $moduleName as xs:string,
                          $moduleText as xs:string)
        as element(z:error)? {

    let $useDir := trace( replace(replace(resolve-uri($dir, static-base-uri()), '\\', '/'), '([^/])$', '$1/') , 'USEDIR: ')
    let $moduleURI := string-join(($useDir, concat($moduleName, '.xqm')), '')            
    return   
        if (file:exists($moduleURI)) then
                <z:error  
                     type="INVALID_PARAMETER_TYPE" subType="TYPE_ERROR" paramName="module" itemType="xs:NCName" 
                     itemValue="{$moduleName}" facet="fileExists" facetValue="false" 
                     msg="{concat('Parameter ''', 'module', ''': file ', $moduleURI, ''' already exists.')}"/>
        else        
            file:write($moduleURI, $moduleText, $i:serParamsText)        
};
