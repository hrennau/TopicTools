(: ttoolsConstants.mod.xq - provides constants used by topic tool 'ttools'
 :
 : @version 20140124-1 first version 
 : ===================================================================================
 :)

module namespace c="http://www.ttools.org/ttools/xquery-functions";

declare variable $c:cfg :=
    <cfg>
        <ttSubDir>tt</ttSubDir>
        <install>
            <modules>
                <module>_constants.mod.xq</module>  
                <module>_csvParser.mod.xq</module>                
                <module>_docs.mod.xq</module>                
                <module>_help.mod.xq</module>                
                <module>_log.mod.xq</module>                
                <module>_nameFilter.mod.xq</module>            
                <module>_nameFilter_parser.mod.xq</module>                
                <module>_namespaceTools.mod.xq</module>               
                <module>_reportAssistent.mod.xq</module>                
                <module>_errorAssistent.mod.xq</module>
                <module>_pcollection.mod.xq</module>                
                <module feature="sql">_pcollection_sql.mod.xq</module>
                <module>_pcollection_utils.mod.xq</module>                
                <module>_pcollection_xml.mod.xq</module>           
                <module>_pfilter.mod.xq</module>                
                <module>_pfilter_parser.mod.xq</module> 
                <module feature="basex" source="_processorSpecific.mod.xq">_processorSpecific.mod.xq</module>                
                <module feature="| saxonpe saxonee" source="_processorSpecific_saxonpe.mod.xq">_processorSpecific.mod.xq</module>                
                <module feature="saxonhe" source="_processorSpecific_saxonhe.mod.xq">_processorSpecific.mod.xq</module>                
                <module feature="~basex ~saxonhe ~saxonpe ~saxonee" source="_processorSpecific_unknown.mod.xq">_processorSpecific.mod.xq</module>                
                <module>_rcat.mod.xq</module>                
                <module>_request.mod.xq</module>
                <module>_request_facets.mod.xq</module>                
                <module>_request_getters.mod.xq</module>                
                <module>_request_parser.mod.xq</module>                
                <module>_request_setters.mod.xq</module>
                <module>_request_valueParser.mod.xq</module>                
                <module>_resourceAccess.mod.xq</module>                
                <module feature="sql">_sqlExecutor.mod.xq</module>                
                <module feature="sql">_sqlWriter.mod.xq</module>                
                <module>_stringTools.mod.xq</module>               
            </modules>
            <examples>

            </examples>
        </install>
    </cfg>;

declare variable $c:serParamsText :=        
        <output:serialization-parameters>
            <output:method value='text'/>
        </output:serialization-parameters>;

declare variable $c:serParamsXml :=        
        <output:serialization-parameters>
            <output:method value='xml'/>
            <output:indent value='yes'/>            
        </output:serialization-parameters>;


