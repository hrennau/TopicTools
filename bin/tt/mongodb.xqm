(:~
 : This is a wrapper for the MongoDB driver implementation in Java.
 :
 : @author BaseX Team 2005-15, BSD License
 : @author Christian Gruen
 :)
module namespace mongodb = "http://expath.org/ns/mongodb";

import module namespace m = "java:org.expath.ns.mongodb.MongoDB";

(:~
 : Creates a new MongoDB client for the specified URL.
 : Example: {@code mongodb://root:root@localhost}.
 : @param  $uri connection URI
 : @return client id
 :)
declare function mongodb:connect($uri as xs:string) as xs:string {
  m:connect($uri)
};

(:~
 : Returns all client ids.
 : @return collections
 :)
declare function mongodb:list-client-ids() as xs:string* {
  m:list-client-ids()
};

(:~
 : Returns the names of all databases.
 : @param  $id client id
 : @return databases
 :)
declare function mongodb:list-databases($id as xs:string) as xs:string* {
  m:list-databases($id)
};

(:~
 : Returns the names of all collections of a database.
 : @param  $id client id
 : @param  $database database
 : @return collections
 :)
declare function mongodb:list-collections($id as xs:string, $database as xs:string)
    as xs:string* {
  m:list-collections($id, $database)
};

(:~
 : Finds documents.
 : @param  $id client id
 : @param  $database database
 : @param  $collection collection
 : @return documents
 :)
declare function mongodb:find($id as xs:string, $database as xs:string,
    $collection as xs:string) as map(*)* {
  m:find($id, $database, $collection)
};

(:~
 : Finds documents.
 : @param  $id client id
 : @param  $database database
 : @param  $collection collection
 : @param  $query query
 : @return documents
 :)
declare function mongodb:find($id as xs:string, $database as xs:string,
    $collection as xs:string, $query as item()) as map(*)* {
  m:find($id, $database, $collection, $query)
};

(:~
 : Finds documents.
 : @param  $id client id
 : @param  $database database
 : @param  $collection collection
 : @param  $query query
 : @param  $fields fields to return
 : @return documents
 :)
declare function mongodb:find($id as xs:string, $database as xs:string,
    $collection as xs:string, $query as item(), $fields as map(*)) as map(*)* {
  m:find($id, $database, $collection, $query, $fields)
};

(:~
 : Finds and modifies documents.
 : @param  $id client id
 : @param  $database database
 : @param  $collection collection
 : @param  $query query
 : @param  $update update operation
 : @return old document, if found
 :)
declare function mongodb:find-and-modify($id as xs:string, $database as xs:string,
    $collection as xs:string, $query as map(*), $update as map(*)) as map(*)? {
  m:find-and-modify($id, $database, $collection, $query, $update)
};

(:~
 : Finds and modifies documents.
 : @param  $id client id
 : @param  $database database
 : @param  $collection collection
 : @param  $query query
 : @param  $update update operation
 : @param  $options options
 : @return old document, if found
 :)
declare function mongodb:find-and-modify($id as xs:string, $database as xs:string,
    $collection as xs:string, $query as map(*), $update as map(*), $options as map(*))
    as map(*)? {
  m:find-and-modify($id, $database, $collection, $query, $update, $options)
};

(:~
 : Finds and removed documents.
 : @param  $id client id
 : @param  $database database
 : @param  $collection collection
 : @param  $query query
 : @return old document, if found
 :)
declare function mongodb:find-and-remove($id as xs:string, $database as xs:string,
    $collection as xs:string, $query as map(*)) as map(*)? {
  m:find-and-remove($id, $database, $collection, $query)
};

(:~
 : Finds a single document.
 : @param  $id client id
 : @param  $database database
 : @param  $collection collection
 : @return document, if found
 :)
declare function mongodb:find-one($id as xs:string, $database as xs:string,
    $collection as xs:string) as map(*)? {
  m:find-one($id, $database, $collection)
};

(:~
 : Finds a single document.
 : @param  $id client id
 : @param  $database database
 : @param  $collection collection
 : @param  $query query
 : @return document, if found
 :)
declare function mongodb:find-one($id as xs:string, $database as xs:string,
    $collection as xs:string, $query as map(*)) as map(*)? {
  m:find-one($id, $database, $collection, $query)
};

(:~
 : Finds a single document.
 : @param  $id client id
 : @param  $database database
 : @param  $collection collection
 : @param  $query query
 : @param  $options options
 : @return document, if found
 :)
declare function mongodb:find-one($id as xs:string, $database as xs:string,
    $collection as xs:string, $query as map(*), $options as map(*)) as map(*)? {
  m:find-one($id, $database, $collection, $query, $options)
};

(:~
 : Count documents.
 : @param  $id client id
 : @param  $database database
 : @param  $collection collection
 : @return number of documents
 :)
declare function mongodb:count($id as xs:string, $database as xs:string,
    $collection as xs:string) as xs:integer {
  m:count($id, $database, $collection)
};

(:~
 : Counts documents.
 : @param  $id client id
 : @param  $database database
 : @param  $collection collection
 : @param  $query query
 : @return number of results
 :)
declare function mongodb:count($id as xs:string, $database as xs:string,
    $collection as xs:string, $query as map(*)) as xs:integer {
  m:count($id, $database, $collection, $query)
};

(:~
 : Inserts new documents into a collection.
 : @param  $id client id
 : @param  $database database
 : @param  $collection collection
 : @param  $documents documents
 :)
declare function mongodb:insert($id as xs:string, $database as xs:string,
    $collection as xs:string, $documents as map(*)*) as empty-sequence() {
  m:insert($id, $database, $collection, $documents)
};

(:~
 : Aggregates documents.
 : @param  $id client id
 : @param  $database database
 : @param  $collection collection
 : @param  $pipeline pipeline
 : @return result
 :)
declare function mongodb:aggregate($id as xs:string, $database as xs:string,
    $collection as xs:string, $pipeline as map(*)*) as map(*)* {
  m:aggregate($id, $database, $collection, $pipeline)
};

(:~
 : Saves a document.
 : @param  $id client id
 : @param  $database database
 : @param  $collection collection
 : @param  $document document
 :)
declare function mongodb:save($id as xs:string, $database as xs:string,
    $collection as xs:string, $document as map(*)) as empty-sequence() {
  m:save($id, $database, $collection, $document)
};

(:~
 : Updates documents.
 : @param  $id client id
 : @param  $database database
 : @param  $collection collection
 : @param  $query selection criteria
 : @param  $update update operation
 :)
declare function mongodb:update($id as xs:string, $database as xs:string,
    $collection as xs:string, $query as map(*), $update as map(*))
    as empty-sequence() {
  m:update($id, $database, $collection, $query, $update)
};

(:~
 : Updates documents.
 : @param  $id client id
 : @param  $database database
 : @param  $collection collection
 : @param  $query selection criteria
 : @param  $update update operation
 : @param  $options options
 :)
declare function mongodb:update($id as xs:string, $database as xs:string,
    $collection as xs:string, $query as map(*), $update as map(*),
    $options as map(*)) as empty-sequence() {
  m:update($id, $database, $collection, $query, $update, $options)
};

(:~
 : Removes documents.
 : @param  $id client id
 : @param  $database database
 : @param  $collection collection
 : @param  $query query
 :)
declare function mongodb:remove($id as xs:string, $database as xs:string,
    $collection as xs:string, $query as map(*)) as empty-sequence() {
  m:remove($id, $database, $collection, $query)
};

(:~
 : Grouping query.
 : @param  $id client id
 : @param  $database database
 : @param  $collection collection
 : @param  $fields fields to group by
 : @param  $reduce reduce
 : @param  $initial initial
 : @return results
 :)
declare function mongodb:group($id as xs:string, $database as xs:string,
    $collection as xs:string, $fields as map(*), $reduce as xs:string, $initial as map(*))
    as map(*)* {
  m:group($id, $database, $collection, $fields, $reduce, $initial)
};

(:~
 : Grouping query.
 : @param  $id client id
 : @param  $database database
 : @param  $collection collection
 : @param  $fields fields to group by
 : @param  $reduce reduce
 : @param  $initial initial
 : @param  $options options
 : @return results
 :)
declare function mongodb:group($id as xs:string, $database as xs:string,
    $collection as xs:string, $fields as map(*), $reduce as xs:string, $initial as map(*),
    $options as map(*)) as map(*)* {
  m:group($id, $database, $collection, $fields, $reduce, $initial, $options)
};

(:~
 : Evaluates a map-reduce query.
 : @param  $id client id
 : @param  $database database
 : @param  $collection collection
 : @param  $map map function
 : @param  $reduce reduce function
 : @return results
 :)
declare function mongodb:map-reduce($id as xs:string, $database as xs:string,
    $collection as xs:string, $map as xs:string, $reduce as xs:string) as map(*)* {
  m:map-reduce($id, $database, $collection, $map, $reduce)
};

(:~
 : Evaluates a map-reduce query.
 : @param  $id client id
 : @param  $database database
 : @param  $collection collection
 : @param  $map map function
 : @param  $reduce reduce function
 : @param  $options options
 : @return results
 :)
declare function mongodb:map-reduce($id as xs:string, $database as xs:string,
    $collection as xs:string, $map as xs:string, $reduce as xs:string,
    $options as map(*)) as map(*)* {
  m:map-reduce($id, $database, $collection, $map, $reduce, $options)
};

(:~
 : Evaluates a server-side script.
 : @param  $id client id
 : @param  $database database
 : @param  $code code
 : @return result
 :)
declare function mongodb:eval($id as xs:string, $database as xs:string,
    $code as xs:string) as item()* {
  m:eval($id, $database, $code)
};

(:~
 : Evaluates a server-side script.
 : @param  $id client id
 : @param  $database database
 : @param  $code code
 : @param  $args arguments
 : @return result
 :)
declare function mongodb:eval($id as xs:string, $database as xs:string,
    $code as xs:string, $args as item()*) as item()* {
  m:eval($id, $database, $code, $args)
};

(:~
 : Evaluates a server command.
 : @param  $id client id
 : @param  $database database
 : @param  $command command
 : @return result
 :)
declare function mongodb:command($id as xs:string, $database as xs:string,
    $command as map(*)) as map(*) {
  m:command($id, $database, $command)
};

(:~
 : Drops a database.
 : @param  $id client id
 : @param  $database database
 :)
declare function mongodb:drop-database($id as xs:string, $database as xs:string)
    as empty-sequence() {
  m:drop-database($id, $database)
};

(:~
 : Drops a collection.
 : @param  $id client id
 : @param  $database database
 : @param  $collection collection
 :)
declare function mongodb:drop-collection($id as xs:string, $database as xs:string,
    $collection as xs:string) {
  m:drop-collection($id, $database, $collection)
};

(:~
 : Closes a client connection.
 : @param  $id client id
 :)
declare function mongodb:close($id as xs:string) as empty-sequence() {
  m:close($id)
};
