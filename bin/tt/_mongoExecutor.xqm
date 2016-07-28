(:
 :***************************************************************************
 :
 : mongoExecutor.xqm - functions for executing MongoDB commands
 :
 :***************************************************************************
 :)
 
module namespace f="http://www.ttools.org/xquery-functions";

(: import module namespace mongodb="http://expath.org/ns/mongodb" at "/projects/infospace/mongodb/mongodb.xqm"; :)
import module namespace mongodb="http://expath.org/ns/mongodb" at "mongodb.xqm";

import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "_request.xqm",
    "_reportAssistent.xqm",
    "_errorAssistent.xqm",    
    "_nameFilter.xqm",
    "_sqlWriter.xqm";
    
declare namespace z="http://www.ttools.org/structure";

(:
 : ============================================================================
 :
 :     p u b l i c    f u n c t i o n s
 :
 : ============================================================================
 :)

(:~
 : Creates a connection to server $server.
 :
 : @param server the server name (e.g. 'localhost')
 : @return the connection handle
 :)
declare function f:mongoConnect($server as xs:string)
        as xs:string {
    let $uri := concat('mongodb://', $server)
    return mongodb:connect($uri)
       
};

(:~
 : Creates a new collection. If the collection already exists,
 : the existence is reported.
 :
 : @param cid MongoDB client id
 : @param db the database name
 : @param collection the collection name
 : @return a report describing the operation result
 :) 
declare function f:createCollection($conn as xs:string, 
                                    $db as xs:string, 
                                    $collection as xs:string)
        as element(z:createCollection) { 
    let $collections := mongodb:list-collections($conn, $db)    
    return
        if ($collections = $collection) then 
            let $size := mongodb:count($conn, $db, $collection)
            return
                <z:createCollection db="{$db}" collection="{$collection}" collectionSize="{$size}" alreadyExists="true"/> else
        
        let $r_insert := mongodb:insert($conn, $db, $collection, map{"INITIALIZED" : "true"})
        let $r_remove := mongodb:remove($conn, $db, $collection, map{})
        let $size := mongodb:count($conn, $db, $collection)
        return
            <z:createCollection db="{$db}" collection="{$collection}" collectionSize="{$size}"/>
};

(:~
 : Creates a database.
 :
 : @param conn the connection handle
 : @return nothing
 :)
declare function f:mongoCreateDb($conn as xs:string, $db as xs:string)
        as empty-sequence() {
    error()
};

(:~
 : Deletes a database.
 :
 : @param conn the connection handle
 : @return nothing
 :)
declare function f:mongoDropDb($conn as xs:string, $db as xs:string)
        as empty-sequence() {
    error()
};

(:~
 : Returns a 'dbs' element reporting the accessible databases.
 :
 : @param conn the connection handle
 : @return a report of the accessible databases
 :)
declare function f:mongoShowDatabases($conn as xs:string)
        as element() {
    error()
};
