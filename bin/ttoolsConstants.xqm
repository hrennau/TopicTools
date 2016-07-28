(: ttoolsConstants.xqm - provides constants used by topic tool 'ttools'
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
                <module>_constants.xqm</module>  
                <module>_csvParser.xqm</module>                
                <module>_docs.xqm</module>     
                <module feature="basex">_foxpath.xqm</module>                
                <module feature="basex">_foxpath-functions.xqm</module>                
                <module feature="basex">_foxpath-parser.xqm</module>                
                <module feature="basex">_foxpath-util.xqm</module>                
                <module feature="basex">_foxpath-processorDependent.xqm</module>                
                <module feature="basex">_foxpath-resourceTreeTypeDependent.xqm</module>                
                <module>_help.xqm</module>                
                <module>_log.xqm</module>                
                <module>_nameFilter.xqm</module>            
                <module>_nameFilter_parser.xqm</module>                
                <module>_namespaceTools.xqm</module>               
                <module>_reportAssistent.xqm</module>                
                <module>_errorAssistent.xqm</module>
                <module>_pcollection.xqm</module>                
                <module feature="sql">_pcollection_sql.xqm</module>
                <module feature="mongo">_pcollection_mongo.xqm</module>                
                <module>_pcollection_utils.xqm</module>                
                <module>_pcollection_xml.xqm</module>           
                <module>_pfilter.xqm</module>                
                <module>_pfilter_parser.xqm</module> 
                <module feature="basex" source="_processorSpecific.xqm">_processorSpecific.xqm</module>                
                <module feature="| saxonpe saxonee" source="_processorSpecific_saxonpe.xqm">_processorSpecific.xqm</module>                
                <module feature="saxonhe" source="_processorSpecific_saxonhe.xqm">_processorSpecific.xqm</module>                
                <module feature="~basex ~saxonhe ~saxonpe ~saxonee" source="_processorSpecific_unknown.xqm">_processorSpecific.xqm</module>                
                <module>_rcat.xqm</module>                
                <module>_request.xqm</module>
                <module>_request_facets.xqm</module>                
                <module>_request_getters.xqm</module>                
                <module>_request_parser.xqm</module>                
                <module>_request_setters.xqm</module>
                <module>_request_valueParser.xqm</module>                
                <module>_resourceAccess.xqm</module>                
                <module feature="sql">_sqlExecutor.xqm</module>                
                <module feature="sql">_sqlWriter.xqm</module>  
                <module feature="mongo">_mongoExecutor.xqm</module>                
                <module feature="mongo">mongodb.xqm</module>                
                <module>_stringTools.xqm</module>               
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


