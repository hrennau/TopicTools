(: 
 : ===================================================================================
 : builder.xqm - creates or re-builds a topic tool
 :
 : @version 20150126-1 
 : ===================================================================================
 :)

(:~@operations
   <operations>
        <operation name="new" func="new" type="empty-sequence()">
            <param name="dir" type="directory" dirExists="false"/>
            <param name="name" type="xs:NCName"/>
            <param name="explain" type="xs:string?"/>           
            <param name="module" type="xs:NCName?"/>
            <param name="ops" type="xs:NCName*"/>
            <param name="flavor" type="xs:string*" 
                fct_pattern="basex\d\d|saxon(he|pe|ee)\d\d|xq(10|30)[fse]*" default="basex79"/>
        </operation>
        <operation name="build" func="new" type="empty-sequence()">
            <param name="dir" type="directory" dirExists="false"/>
            <param name="name" type="xs:NCName"/>
            <param name="explain" type="xs:string?"/>
            <param name="upgrade" type="xs:boolean" default="true"/>
                fct_pattern="basex\d\d|saxon(he|pe|ee)\d\d|xq(10|30)[fse]*" default="basex79"/>           
        </operation>
    </operations>   
:)


module namespace f="http://www.ttools.org/ttools/xquery-functions";

import module namespace tt="http://www.ttools.org/xquery-functions" at
    "tt/_constants.xqm",
    "tt/_request.xqm",
    "tt/_request_setters.xqm",    
    "tt/_reportAssistent.xqm",
    "tt/_nameFilter.xqm";
    
import module namespace i="http://www.ttools.org/ttools/xquery-functions" at
    "builder_main.xqm",
    "builder_extensions.xqm",
    "toolSchemeParser.xqm",
    "ttoolsConstants.xqm",
    "util.xqm";
    
declare namespace z="http://www.ttools.org/ttools/structure";
declare namespace ztt="http://www.ttools.org/structure";
declare namespace soap="http://schemas.xmlsoap.org/soap/envelope/";

(:~
 : Creates a new topic tool.
 :
 : @param request the operation request
 : @return no return value, side effect is the installation / an update
 :    of the topic tool application.
 :) 
declare function f:new($request as element())
        as node(){
    let $dir as xs:string := tt:getParam($request, 'dir')
(:    
    let $dir := 
        let $base := file:current-dir()
        return
            resolve-uri($dir, $base)
:)            
    let $ttDir as xs:string := concat($dir, '/tt')
    let $nameParam := tt:getParam($request, 'name')
    let $toolName as xs:NCName := i:getToolName($dir, $nameParam)                
    let $mod as xs:NCName? := tt:getParam($request, 'mod')
    let $ops as xs:string* := tt:getParam($request, 'ops')
    let $flavor as xs:string := i:getToolFlavor($request, ())
    let $namespace as element(namespace) := i:getToolNamespace($request, $toolName, ())
    let $features := f:featuresFromFlavor($flavor)
    
    let $requestBuild := tt:setParam($request, 'upgrade', true(), 'xs:boolean')
    let $requestBuild := $namespace/@func/tt:setParam($requestBuild, 'namespaceFunc', ., 'xs:string')    
    let $requestBuild := $namespace/@error/tt:setParam($requestBuild, 'namespaceError', ., 'xs:string')    
    let $requestBuild := $namespace/@struct/tt:setParam($requestBuild, 'namespaceStruct', ., 'xs:string')
    
    let $ttoolsUri := replace(replace(tt:static-base-uri(), '^file:/+(.:)?', ''), '^(.*)/.*', '$1/ttools.xq')
    
    let $dirInfo := replace(replace(replace(replace($dir, '^file:/+', ''), '^.:', ''), '\\', '/'), '/$', '')
    let $toolUri := concat($dirInfo, '/', $toolName, '.xq')
    let $toolIdent :=
        if (ends-with($dirInfo, concat('/', $toolName))) then concat('dir=', $dirInfo)
        else concat('name=', $toolName, ', dir=', $dirInfo)     
    let $result := (
        file:create-dir($dir),
        file:create-dir($ttDir),

        let $result_build := f:build($requestBuild) 
        return
            if ($result_build/self::ztt:errors) then $result_build
            else if ($mod and exists($ops)) then (
                let $requestExtend:= tt:setParam($requestBuild, 'upgrade', false(), 'xs:boolean')        
                let $moduleText := i:writeModule($toolName, $namespace, $mod, $ops, $features)
                return (
                    f:deploy($dir, $mod, $moduleText),
                    f:build($requestExtend)
                )
            ) else (),
        
        <_>        
===============================================================

Topic tool created:  {$toolName}
Tool directory:      {$dirInfo}

The tool can already be called. Example:
   basex -b "request=?" {$toolUri}

Use operation 'add' for adding module prototypes. Example:
   basex -b "request=add?{$toolIdent}, mod=fooMod, ops=fooOp barOp foobarOp" {$ttoolsUri}  
===============================================================
        </_>/text()
    )
    let $errors := $result[. instance of element(ztt:errors)]
    return
        if ($errors) then $errors else $result
        
};

(:~
 : Rebuilds a topic tool.
 :
 : @params request request message
 : @return no return value, but contents of tool directory have been updated
 :)
declare function f:build($request as element())
        as element()? {       
    let $dir as xs:string := 
        let $value := tt:getParam($request, 'dir')
        let $value := resolve-uri($value, tt:static-base-uri())
        return replace($value, '\\', '/')
    let $toolName as xs:NCName := 
        let $nameParam as xs:NCName? := tt:getParam($request, 'name')
        return i:getToolName($dir, $nameParam)    
    let $settings := i:getToolSettings($dir, $toolName)
    let $flavor as xs:string := i:getToolFlavor($request, $settings)
    let $namespace as element(namespace) := i:getToolNamespace($request, $toolName, $settings)
    let $upgrade as xs:boolean := tt:getParam($request, 'upgrade')    
    let $explain as xs:string? := tt:getParam($request, 'explain')
    let $features := f:featuresFromFlavor($flavor)
    return (
        if (not($upgrade)) then () else f:copyFramework($dir, $toolName, $features),       
        let $toolScheme := i:getToolScheme($dir, $toolName, $features)   
        return
            if ($toolScheme/self::ztt:errors) then $toolScheme else (
                (: generate & deploy the topic tool entry module and the extensions module :)
                let $topicTool := f:makeMainModule($toolScheme, $explain, $namespace)               
                let $extensionsModule := f:makeExtensionsModule($toolScheme, $namespace)    
                return
                    f:deploy($dir, $toolName, $namespace, $flavor, $topicTool, $extensionsModule)
            )                    
    )
};

(:~
 : Checks the application directory.
 :)
declare function f:checkDir($dir as xs:string, $install as xs:boolean)
        as xs:string {
    let $useDir := 
        let $staticBaseUri := tt:static-base-uri()
        return    
            resolve-uri($dir, $staticBaseUri) 
    return
        if (not($install or file:exists($useDir))) then
            let $dispDir := replace($useDir, '^file:/', '') return
                error(QName((), 'INVALID_ARG'), concat('Application directory ',
                $useDir, ' does not exist, and install flag is not set.&#xA;',
                '              Use install flag (install) if you wish to create a ',
                'new topic tool application;&#xA;',
                '              otherwise, correct the, $dir argument.'))
        else
            $useDir
};    

(:~
 : Installs an xquery topic tool application.
 : (a) creates the directory, if not already existing
 : (b) copies files into the directory (modules and examples)
 :
 : @param dir the application directory
 : @param toolName the topic tool name
 : @param features the features of the current tool flavor 
 : @return empty sequence
 :)
declare function f:copyFramework($dir as xs:string, $toolName as xs:string, $features as xs:string*)
         as empty-sequence() {       
    let $useDir := resolve-uri($dir, tt:static-base-uri()) 
    let $useDirTt := concat($useDir, '/tt')
    return (

    (: create the directory, if not yet existent :)
    if (file:exists($useDir)) then () else file:create-dir($useDir)
    ,       
    (: copy modules :)
    for $module in $i:cfg//modules/module
    let $sourceModule := ($module/@source, $module)[1]/string()
    let $sourceModule := string-join(($i:cfg/ttSubDir, $sourceModule), '/')
    let $rawText := unparsed-text($sourceModule)
    let $text := f:filterTextByFeatures($rawText, $features)
    let $target := string-join(($useDirTt, $module), '/')
    let $matchesFeature := f:copyFramework_matchesFeature($features, $module/@feature)
    where $matchesFeature
    return
        file:write($target, $text, $i:serParamsText)
    ,        
    for $module in $i:cfg//examples/example
    let $rawText := unparsed-text($module)
    let $text := f:filterTextByFeatures($rawText, $features)
    let $text := replace($text, 'www.ttools.org/ttools/', concat('www.ttools.org/', $toolName, '/')) 
    let $target := string-join(($useDirTt, $module), '/')
    return
        file:write($target, $text, $i:serParamsText)
    )        
};

(:~
 : Helper function of `copyFramework`, determining if the actual features match the 
 : feature requirement.
 :
 : @param features the actual features
 : @param requirement the requirement on the presence and/or absence of features
 : @return true if the actual features match the requirements, false otherwise
 :)
declare function f:copyFramework_matchesFeature($features as xs:string*, $requirement as xs:string?)
        as xs:boolean {
    let $req := normalize-space($requirement) return
    
    let $parts := tokenize(
        replace($req, '^\s*(\|)?\s*(.+)$', '$1###$2'), '###')
    let $mode := if ($parts[1] eq '|') then 'or' else 'and'
    let $items :=
        for $s in tokenize($parts[2], ' ') return
            if (starts-with($s, '~')) then <item text="{substring($s, 2)}" sign="-"/>
            else <item text="{$s}"/>
    return
        if ($mode eq 'or') then
            some $item in $items satisfies
                if ($item/@sign eq '-') then not($item/@text = $features)
                else $item/@text = $features
        else
            every $item in $items satisfies
                if ($item/@sign eq '-') then not($item/@text = $features)
                else $item/@text = $features
};

(:~
 : Deploys the topic tool and its extensions module.
 : 
 : @param dir the tool directory
 : @param toolName the tool name
 : @param namespace of the functions implementing the tool operations
 : @param flavor the tool flavor
 : @param topicTool text of the tool main module
 : @param extensionsModule text of the extensions module, which is the 
 :    generated module calling tool-provided framework extensions
 : @return empty sequence
 :)
declare function f:deploy($dir as xs:string, 
                          $toolName as xs:string, 
                          $namespace as element(namespace),
                          $flavor as xs:string,                          
                          $topicTool as xs:string, 
                          $extensionsModule as xs:string)
        as empty-sequence() {
        
    (: write main module :)
    let $topicToolURI := i:getTopicToolURI($dir, $toolName)            
    return            
        file:write($topicToolURI, $topicTool, $i:serParamsText),
        
    (: write extensions module :)
    let $extensionsURI := i:getExtensionsModuleURI($dir, $toolName)            
    return            
        file:write($extensionsURI, $extensionsModule, $i:serParamsText),
        
    (: write settings file :)
    let $settingsURI := i:getToolSettingsURI($dir, $toolName)            
    let $newSettings :=
        <toolSettings toolName="{$toolName}">{
            $namespace,
            <flavor>{$flavor}</flavor>
        }</toolSettings>
    return
        file:write($settingsURI, $newSettings, $i:serParamsXml)           
};

        