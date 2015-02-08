(:
 : -------------------------------------------------------------------------
 :
 : cmd.mod.xq - Document me!
 :
 : -------------------------------------------------------------------------
 :)
 
(:~@operations
   <operations>
      <operation name="createDb" type="node()?" func="createDb">     
         <param name="conn" type="xs:string{3}" sep="WS" default="localhost root admin"/>
         <param name="db" type="xs:string"/>         
         <param name="ifNotExists" type="xs:boolean?" default="true"/>
         <param name="charset" type="xs:string?"/>         
         <param name="collation" type="xs:string?"/>         
      </operation> 
      <operation name="dropDb" type="node()?" func="dropDb">     
         <param name="conn" type="xs:string{3}" sep="WS" default="localhost root admin"/>
         <param name="db" type="xs:string"/>         
      </operation> 
      <operation name="dbs" type="node()" func="showDbs">     
         <param name="conn" type="xs:string{3}" sep="WS" default="localhost root admin"/>
      </operation>
      <operation name="tables" type="node()" func="showTables">     
         <param name="conn" type="xs:string{3}" sep="WS" default="localhost root admin"/>
         <param name="db" type="xs:string"/>         
      </operation>
      <operation name="cols" type="node()" func="showColumns">     
         <param name="conn" type="xs:string{3}" sep="WS" default="localhost root admin"/>
         <param name="db" type="xs:string"/>         
         <param name="tables" type="nameFilter*" sep="SC"/>
         <param name="cols" type="nameFilter*" sep="SC"/>         
         <param name="dtypes" type="nameFilter*" sep="SC"/>         
      </operation>
      <operation name="createTable" type="node()" func="createTable">     
         <param name="conn" type="xs:string{3}" sep="WS" default="localhost root admin"/>
         <param name="db" type="xs:string"/>   
         <param name="table" type="xs:string"/>         
         <param name="primaryKey" type="xs:string?"/>         
         <param name="col" type="xs:string*"/>         
      </operation>
      <operation name="dropTable" type="node()" func="dropTable">     
         <param name="conn" type="xs:string{3}" sep="WS" default="localhost root admin"/>
         <param name="db" type="xs:string"/>         
         <param name="table" type="xs:string"/>
      </operation>
      <operation name="select" type="node()" func="select">     
         <param name="conn" type="xs:string{3}" sep="WS" default="localhost root admin"/>
         <param name="db" type="xs:string"/>   
         <param name="table" type="xs:string+" sep="SC"/>         
         <param name="wcols" type="xs:string*"/>         
         <param name="scols" type="xs:string*"/>         
      </operation>
      <operation name="insert" type="node()" func="insert">     
         <param name="conn" type="xs:string{3}" sep="WS" default="localhost root admin"/>
         <param name="db" type="xs:string"/>         
         <param name="table" type="xs:string"/>         
         <param name="colValues" type="xs:string"/>         
      </operation>
    </operations>  
:)  

module namespace f="http://www.ttools.org/sql/ns/xquery-functions";
import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "_request.mod.xq",
    "_reportAssistent.mod.xq",
    "_errorAssistent.mod.xq",    
    "_nameFilter.mod.xq";

import module namespace i="http://www.ttools.org/sql/ns/xquery-functions" at 
    "sqlExecutor.mod.xq";

declare namespace z="http://www.ttools.org/sql/ns/xquery-functions";

(:~
 : Document me!
 :
 : @param request the operation request
 : @return a report describing ...
 :) 
declare function f:createDb($request as element())
        as element()? {
        
    let $connData := tt:getParams($request, 'conn')
    let $db := tt:getParams($request, 'db') 
    let $ifNotExists := tt:getParams($request, 'ifNotExists')    
    let $charset := tt:getParams($request, 'charset')
    let $collation := tt:getParams($request, 'collation')
    
    let $cmd := 
        <createDb name="{$db}">{
            if (not($ifNotExists eq true())) then () else attribute ifNotExists {true()},        
            if (not($charset)) then () else attribute charset {$charset},
            if (not($collation)) then () else attribute collation {$collation}            
        }</createDb>
    return
        try {
            let $conn := i:connect($connData[1], $connData[2], $connData[3])    
            let $retCreateDb := i:sqlCreateDb($conn, $cmd)
            return
                element {node-name($cmd)} {
                    $cmd/@*,
                    attribute success {true()},
                    $cmd/node()
                }                    
        } catch * {
            tt:createError('SQL_ERROR', $err:description, ())
        }
};        
 
(:~
 : Document me!
 :
 : @param request the operation request
 : @return a report describing ...
 :) 
declare function f:dropDb($request as element())
        as element()? {
    let $connData := tt:getParams($request, 'conn')
    let $db := tt:getParams($request, 'db') 
    
    let $cmd := <dropDb name="{$db}"/>
    return
        try {    
            let $conn := i:connect($connData[1], $connData[2], $connData[3])    
            let $retDropDb := i:sqlDropDb($conn, $cmd)            
            return
                element {node-name($cmd)} {
                    $cmd/@*,
                    attribute success {true()},
                    $cmd/node()
                }                    
        } catch * {
            tt:createError('SQL_ERROR', $err:description, ())        
        }        
};        
 
(:~
 : Document me!
 :
 : @param request the operation request
 : @return a report describing ...
 :) 
declare function f:showDbs($request as element())
        as element() {
        let $connData := tt:getParams($request, 'conn')
        let $conn := i:connect($connData[1], $connData[2], $connData[3])    
        let $dbs := i:sqlShowDatabases($conn)
        return
            $dbs
};        

(:~
 : Document me!
 :
 : @param request the operation request
 : @return a report describing ...
 :) 
declare function f:showTables($request as element())
        as element() {
        let $connData := tt:getParams($request, 'conn')
        let $db := tt:getParams($request, 'db')        
        let $conn := i:connect($connData[1], $connData[2], $connData[3])    
        let $tables := i:sqlInfoTables($conn, $db)
        return
            $tables
};        

(:~
 : Document me!
 :
 : @param request the operation request
 : @return a report describing ...
 :) 
declare function f:showColumns($request as element())
        as element() {
        let $connData := tt:getParams($request, 'conn')
        let $db := tt:getParams($request, 'db')
        let $tables as element(nameFilter)* := tt:getParams($request, 'tables')
        let $columns as element(nameFilter)* := tt:getParams($request, 'cols')        
        let $dtypes as element(nameFilter)* := tt:getParams($request, 'dtypes')
        
        let $conn := i:connect($connData[1], $connData[2], $connData[3])    
        let $cols := i:sqlInfoColumns($conn, $db, $tables, $columns, $dtypes)
        return
            $cols
};        

(:~
 : Document me!
 :
 : @param request the operation request
 : @return a report describing ...
 :) 
declare function f:createTable($request as element())
        as element() {
        let $connData := tt:getParams($request, 'conn')
        let $db := tt:getParams($request, 'db')
        let $table := tt:getParams($request, 'table')        
        
        let $cmd :=
            <createTable name="{$table}" db="{$db}">{
                <col name="pkey" type="int unsigned" pkey="true" auto="true"/>,
                <col name="uri" type="VARCHAR(200)" unique="true"/>,
                <col name="time" type="VARCHAR(1000)"/>,                
                <col name="sc_id" type="VARCHAR(1000)"/>,
                <col name="booking_kind" type="VARCHAR(1000)"/>,                
                ()
            }</createTable>
                
        let $conn := i:connect($connData[1], $connData[2], $connData[3])    
        let $retCreateTable := i:sqlCreateTable($conn, $db, $cmd)
        return
            $retCreateTable
};        

(:~
 : Document me!
 :
 : @param request the operation request
 : @return a report describing ...
 :) 
declare function f:dropTable($request as element())
        as element() {
        let $connData := tt:getParams($request, 'conn')
        let $db := tt:getParams($request, 'db')
        let $table := tt:getParams($request, 'table')        
        let $cmd :=
            <dropTable db="{$db}" table="{$table}"/>
                
        let $conn := i:connect($connData[1], $connData[2], $connData[3])    
        let $retDropTable := i:execDropTable($conn, $db, $cmd)
        return
            $retDropTable
};        

(:~
 : Document me!
 :
 : @param request the operation request
 : @return a report describing ...
 :) 
declare function f:insert($request as element())
        as element() {
        let $connData := tt:getParams($request, 'conn')
        let $db := tt:getParams($request, 'db')
        let $table := tt:getParams($request, 'table')        
        let $colValues := tt:getParams($request, 'colValues')
        let $cols := tt:getTextMap($colValues, 'col', 'name', 'value')
        let $cmd :=
            <insert db="{$db}" table="{$table}">{
                $cols
            }</insert>
                
        let $conn := i:connect($connData[1], $connData[2], $connData[3])    
        let $retCreateTable := i:execInsert($conn, $db, $cmd)
        return
            $retCreateTable
};        

(:~
 : Document me!
 :
 : @param request the operation request
 : @return a report describing ...
 :) 
declare function f:select($request as element())
        as element() {
        let $connData := tt:getParams($request, 'conn')
        let $db := tt:getParams($request, 'db')
        let $scols := 
            let $pvalue := tt:getParams($request, 'scols')
            return
                if (empty($pvalue)) then '*' else
                    string-join($pvalue, ',')
        let $table := tt:getParams($request, 'table')    
        let $tableClause :=
            <tables>{
                for $t at $pos in $table
                let $fields := tt:getTextFields($t)
                let $tnameInfo := tokenize($fields[1], '\s+')
                let $tname := $tnameInfo[1]
                let $alias := ($tnameInfo[2], concat('t', $pos))[1]
                let $join := $fields[2]
                return
                    <table name="{$tname}" alias="{$alias}">{
                        if (empty($join)) then () else (
                            attribute join {$join},

                            let $onItems := $fields[position() gt 2]
                            let $onConcat := string-join($onItems, '%')
                            return                            
                                <on>{
                                    (: shortcut - if the 'on' fields consists only of a single NCName,
                                       this is interpreted as shorthand for t1.$on = t$pos.$on
                                    :)
                                    if (matches($onConcat, '^\i\c*$')) then
                                        <col name="{concat('t1.', $onConcat)}" 
                                             op="=" 
                                             value="{concat('t', $pos, '.', $onConcat)}"/>
                                    else
                                        tt:getTextNameOpValueTriples(
                                            $onConcat, '= ~ > <', 'col', 'name', 'op', 'value')
                                }</on>
                        )                        
                    }</table>
            }</tables>                    
                
        let $wcols := tt:getParams($request, 'wcols')
        let $cols := 
            if (not($wcols)) then () else
                tt:getTextNameOpValueTriples($wcols, '= ~ > <', 'col', 'name', 'op', 'value')
        let $whereClause := 
            if (empty($cols)) then () else
                <where>{
                    $cols
                }</where>
        let $select :=
            <select db="{$db}" cols="{$scols}">{
                $tableClause,
                $whereClause
            }</select>
                
        let $conn := i:connect($connData[1], $connData[2], $connData[3])    
        let $retSelect := i:execSelect($conn, $db, $select)
        return
            $retSelect
};        
