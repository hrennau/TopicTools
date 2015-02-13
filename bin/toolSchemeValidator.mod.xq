(: toolSchemeValidator.mod.xq - parses a directory and constructs a tool scheme
 :
 : @version 20140826-1
 :
 : Rules:
 :
 : The names of operations MUST be unique - the @name attribute on one
 :    <operation> element MUST NOT be identical to the @name on another 
 :    <operation> element.
 : The names of type definitions MUST be unique - the @name attribute on one
 :    <type> element MUST NOT be identical to the @name on another 
 :    <type> element.
 : The names of facet definitions MUST be unique - the @name attribute on one
 :    <facet> element MUST NOT be identical to the @name on another 
 :    <facet> element.
 : The names of operation parameters MUST be unique - the @name attribute on
 :    one <param> element MUST NOT be identical to the @name on another
 :    <param> element within the same <operation> element.
 : The names of operation parameter groups MUST be unique - the @name attribute on 
 :    one <pgroup> element MUST NOT be identical to the @name on another 
 :    <pgroup> element within the same <operation> element.
 
 : <operation> elements MUST NOT have other children than <param>, <pgroup>. 
 : <operation> elements MUST NOT have other attributes than @name, @type, @func, @mod. 
 : <param> elements MUST NOT have other attributes than @name, @type, @pgroup, @sep, @default.
 : <pgroup> elements MUST NOT have other attributes than @name, @minOccurs, @maxOccurs.
 
 : <operation> elements MUST have a @name attribute which is an NCName.
 : <param> elements MUST have a @name which is an NCName.
 : <pgroup> elements MUST have a @name which is an NCName.
 
 : <param> elements MUST have a @type attribute which consists of a valid type name,
 :    optionally followed by a valid cardinality constraint; the range of valid
 :    type names comprises the builtin types of XQuery (excepting xs:QName,
 :    xs:NOTATION), the ttools-defined types and user-defined types, defined 
 :    by @type annotations; a cardinality constraint is either one of the
 :    characters ?, *, +, or one of the patterns {i}, {i,j}, {i,}, {,j}.
 : In the type `nameFilterMap(...)`, where ... represents the name of the map 
 :    value type, the map valueType must be a builtin type.
 : A facet - represented by a @fct_... attribute on a <param> element, where ...
 :    is the name of the facet kind - MUST have a valid facet kind; valid facet 
 :    kinds comprise the ttools-defined facets, as well as user-defined facets, 
 :    defined by @facet annotations.
 : A facet MUST have one of the facet kinds which are compatible with the type
 :    of the <param> element in question.
 : A facet MUST have a facet value which meets the constraints imposed by the
 :    facet kind and which may depend on the type of the <param> element in question.
 i A parameter value item separator - represented by a @sep attribute on a <param>
 :    element - MUST have a value which is either WS or ; (semicolon).
 : The assignment of a parameter to a parameter group - represented by a @pgroup 
 :    attribute on a <param> element - MUST have a value matching the name of a 
 :    parameter group in scope for that parameter; the names of parameter groups 
 :    in scope of a parameter are given by the @name attributes on the <pgroup> 
 :    siblings of the <param> element in question.
 
 : A @minOccurs attribute on a <pgroup> element must have a value which is an
 :    integer number greater or equal zero.
 : A @maxOccurs attribute on a <pgroup> element must have a value which is a
 :    positive integer number.
 : 
 : ===================================================================================
 :)

module namespace f="http://www.ttools.org/ttools/xquery-functions";

import module namespace tt="http://www.ttools.org/xquery-functions" at
    "tt/_constants.mod.xq",
    "tt/_errorAssistent.mod.xq",
    "tt/_nameFilter.mod.xq";
    
import module namespace i="http://www.ttools.org/ttools/xquery-functions" at
    "builder_main.mod.xq",
    "builder_extensions.mod.xq",
    "util.mod.xq";
    
declare namespace z="http://www.ttools.org/ttools/structure";
declare namespace zz="http://www.ttools.org/structure";

declare variable $f:childNames_operation := tokenize(normalize-space('
    param
    pgroup
'), ' ');    

declare variable $f:childNames_type := ();

declare variable $f:childNames_facet := ();

declare variable $f:attNames_operation := tokenize(normalize-space('
    name
    type
    func
    mod
    namespace
'), ' ');    

declare variable $f:attNames_type := tokenize(normalize-space('
    name
    itemType
    func
    mod
    namespace
'), ' ');    

declare variable $f:attNames_facet := tokenize(normalize-space('
    name
    typeClasses
    types
    func
    mod
    namespace
'), ' ');    

declare variable $f:attNames_param := tokenize(normalize-space('
    name
    type
    pgroup
    sep
    default
'), ' ');    

declare variable $f:attNames_pgroup := tokenize(normalize-space('
    name
    minOccurs
    maxOccurs
'), ' ');    

declare variable $f:typeClasses := tokenize(normalize-space('
    numeric
    time
    file
    element
    document-node
'), ' ');

declare variable $f:builtinTypesDict :=
    <types>
        <type name="xs:string" class="string" reqFeature="" />
        <type name="xs:normalizedString" class="string" reqFeature=""/>        
        <type name="xs:token" class="string" reqFeature=""/>        
        <type name="xs:language" class="string" reqFeature=""/>        
        <type name="xs:NMTOKEN" class="string" reqFeature=""/>        
        <type name="xs:Name" class="string" reqFeature=""/>        
        <type name="xs:NCName" class="string" reqFeature=""/>        
        <type name="xs:ID" class="string" reqFeature=""/>
        <type name="xs:IDREF" class="string" reqFeature=""/>
        <type name="xs:dateTime" class="time" reqFeature=""/>        
        <type name="xs:date" class="time" reqFeature=""/>        
        <type name="xs:time" class="time" reqFeature=""/>        
        <type name="xs:duration" class="duration" reqFeature=""/>        
        <type name="xs:yearMonthDuration" class="duration" reqFeature=""/>        
        <type name="xs:dayTimeDuration" class="duration" reqFeature=""/>        
        <type name="xs:float" class="numeric" reqFeature=""/>        
        <type name="xs:double" class="numeric" reqFeature=""/>
        <type name="xs:decimal" class="numeric" reqFeature=""/>
        <type name="xs:integer" class="numeric" reqFeature=""/>        
        <type name="xs:nonPositiveInteger" class="numeric" reqFeature=""/>        
        <type name="xs:negativeInteger" class="numeric" reqFeature=""/>        
        <type name="xs:long" class="numeric" reqFeature=""/>        
        <type name="xs:int" class="numeric" reqFeature=""/>
        <type name="xs:short" class="numeric" reqFeature=""/>
        <type name="xs:byte" class="numeric" reqFeature=""/>        
        <type name="xs:nonNegativeInteger" class="numeric" reqFeature=""/>        
        <type name="xs:unsignedLong" class="numeric" reqFeature=""/>        
        <type name="xs:unsignedShort" class="numeric" reqFeature=""/>        
        <type name="xs:unsignedByte" class="numeric" reqFeature=""/>        
        <type name="xs:positiveInteger" class="numeric" reqFeature=""/>        
        <type name="xs:gYearMonth" class="time" reqFeature=""/>        
        <type name="xs:gYear" class="time" reqFeature=""/>        
        <type name="xs:gMonthDay" class="time" reqFeature=""/>        
        <type name="xs:gDay" class="time" reqFeature=""/>        
        <type name="xs:gMonth" class="time" reqFeature=""/>        
        <type name="xs:boolean" class="boolean" reqFeature=""/>        
        <type name="xs:base64Binary" class="binary" reqFeature=""/>        
        <type name="xs:hexBinary" class="binary" reqFeature=""/>        
        <type name="xs:anyURI" class="string" reqFeature=""/>        
        <type name="xs:QName" class="qname" reqFeature=""/>        
    </types>;

declare variable $f:predefinedTypesDict :=
    <types>
        <type name="nameFilter" reqFeature=""/>
        <type name="nameFilterMap" reqFeature=""/>        
        <type name="pathFilter" reqFeature=""/>        
        <type name="docFLX" reqFeature="file"/>        
        <type name="docURI" reqFeature=""/>        
        <type name="docSEARCH" reqFeature=""/>        
        <type name="textURI" reqFeature="xq30ge"/>        
        <type name="xtextURI" reqFeature="xq30ge"/>        
        <type name="csvURI" reqFeature="xq30ge"/>        
        <type name="linesURI" reqFeature="xq30ge"/>        
        <type name="docDFD" reqFeature="file"/>        
        <type name="textDFD" reqFeature="file xq30ge"/>        
        <type name="xtextDFD" reqFeature="file xq30ge"/>        
        <type name="csvDFD" reqFeature="file xq30ge"/>
        <type name="linesDFD" reqFeature="file xq30ge"/>
        <type name="docCAT" reqFeature=""/>        
        <type name="dfd" reqFeature="file"/>        
        <type name="directory" reqFeature="file"/>        
    </types>;

declare variable $f:systemFacetsDict := 
    <facets>
        <facet name="values" typeClasses="" facetValueConstraint="item-castable"/>
        <facet name="pattern" typeClasses="" facetValueConstraint=""/>        
        <facet name="length" typeClasses="" facetValueConstraint="numeric"/>       
        <facet name="minLength" typeClasses="" facetValueConstraint="numeric"/>        
        <facet name="maxLength" typeClasses="" facetValueConstraint="numeric"/>     
        <facet name="min" typeClasses="numeric time" facetValueConstraint="castable"/>        
        <facet name="minEx" typeClasses="numeric time" facetValueConstraint="castable"/>        
        <facet name="max" typeClasses="numeric time" facetValueConstraint="castable"/>        
        <facet name="maxEx" typeClasses="numeric time" facetValueConstraint="castable"/>        
        <facet name="fileExists" reqFeature="file" facetValueConstraint="boolean"/>        
        <facet name="dirExists" reqFeature="file" facetValueConstraint="boolean"/>     
        <facet name="rootElem" types="docURI" facetValueConstraint="~(Q\{{.*\}})?(\i|\*)(\c|\*)*"/>    
<!--        
        <facet name="rootName" types="docURI" facetValueConstraint="~(\i|\*)(\c|\*)*"/>        
        <facet name="rootNamespace" types="docURI" facetValueConstraint="\S+"/>   
-->        
    </facets>;

declare variable $f:builtinTypes := $f:builtinTypesDict/*;
declare variable $f:predefinedTypes := $f:predefinedTypesDict/*;
declare variable $f:systemTypes := ($f:builtinTypes, $f:predefinedTypes);
declare variable $f:systemFacets := $f:systemFacetsDict/*;

(:~
 : Validates a tool scheme.
 :
 : @param toolScheme the tool scheme
 : @param features the features of the current tool flavor 
 : @return error elements describing validation error, or the empty sequence
 :    if the tool scheme is valid
 :)
declare function f:validateToolScheme($toolScheme as element(), $features as xs:string*)
      as element()* {
    let $operations := $toolScheme/operations/operation   
    let $userTypes := $toolScheme/types/type
    let $userFacets := $toolScheme/facets/facet   
   
    let $acceptedSystemTypes :=
        $f:systemTypes[empty(tokenize(@reqFeature, '\s+')[not(. = $features)])]
    let $acceptedSystemFacets :=
        $f:systemFacets[empty(tokenize(@reqFeature, '\s+')[not(. = $features)])]

    let $errors_uniqueness := f:validateToolScheme_uniqueness($operations, $userTypes, $userFacets)
    let $errors_operation := 
        f:validateToolScheme_operation($operations, $userTypes, $userFacets, 
                                       $acceptedSystemTypes, $acceptedSystemFacets)
    let $errors_type := 
        f:validateToolScheme_types($userTypes, $userFacets, 
                                   $acceptedSystemTypes, $acceptedSystemFacets)
                                   
    let $errors_facet := 
        f:validateToolScheme_facets($userTypes, $userFacets, 
                                    $acceptedSystemTypes, $acceptedSystemFacets)
                                   
    return (
        $errors_uniqueness,
        $errors_operation,
        $errors_type,
        $errors_facet
    )        
};

declare function f:validateToolScheme_uniqueness($operations as element(operation)*,
                                                 $userTypes as element(type)*,
                                                 $userFacets as element(facet)*)
        as element()* {
        
    (: check: uniqueness of operation names 
       ==================================== :)
        let $names := $operations/@name
        let $namesDV := distinct-values($names)
        return
            if (count($names) eq count($namesDV)) then () else            
                let $nonUniqueNames :=
                    for $n in $namesDV
                    where count($names[. eq $n]) gt 1
                    return $n
                for $name in $nonUniqueNames
                let $comps := $operations[@name eq $name]
                return
                    f:componentUniquenessError($comps)
        ,            
    (: check: uniqueness of type names 
       =============================== :)
        let $names := $userTypes/@name
        let $namesDV := distinct-values($names)
        return
            if (count($names) eq count($namesDV)) then () else            
                let $nonUniqueNames :=
                    for $n in $namesDV
                    where count($names[. eq $n]) gt 1
                    return $n
                for $name in $nonUniqueNames
                let $comps := $userTypes[@name eq $name]
                return
                    f:componentUniquenessError($comps)
        ,            
    (: check: uniqueness of facet names 
       ================================ :)
        let $names := $userFacets/@name
        let $namesDV := distinct-values($names)
        return
            if (count($names) eq count($namesDV)) then () else            
                let $nonUniqueNames :=
                    for $n in $namesDV
                    where count($names[. eq $n]) gt 1
                    return $n
                for $name in $nonUniqueNames
                let $comps := $userFacets[@name eq $name]
                return
                    f:componentUniquenessError($comps)
        ,            
        ()        
};

(:~
 : Validates the operations of a tool scheme.
 :
 : @param operations the operation elements of the tool scheme
 : @param userTypes the type definitions of the tool scheme
 : @param userFacets the facet definitions of the tool scheme 
 : @param acceptedSystemTypes the system types which are accepted, given the current features
 : @param acceptedSystemFacets the system facets which are accepted, given the current features 
 : @return error elements describing validation error, or the empty sequence
 :    if no errors are detected
 :)
declare function f:validateToolScheme_operation($operations as element(operation)*,
                                                $userTypes as element(type)*,
                                                $userFacets as element(facet)*,
                                                $acceptedSystemTypes as element(type)*,
                                                $acceptedSystemFacets as element(facet)*)
        as element()* {
    let $acceptedTypes := ($acceptedSystemTypes, $userTypes)
    let $acceptedTypeNames := $acceptedTypes/@name/string()  
    let $builtinTypeNames := $f:builtinTypes/@name/string()

    let $acceptedFacets := ($acceptedSystemFacets, $userFacets)
    let $acceptedFacetNames := $acceptedFacets/@name/string()    
    
    let $atts_pgroup := tokenize('name members minOccurs maxOccurs', '\s+')
    for $op in $operations
    let $name := $op/@name/string()
    let $pgroups := distinct-values($op/pgroup/@name)
    let $errors := (

        (: ########################
           check operation elem ...
           ######################## :)
           
        (: check operation/@name 
           ===================== :)
            (: ... exists :)           
        if (not($name)) then f:operationValidityError($op, 'missing operation name (@name)')
            (: ... is NCName :)        
        else if (not($name castable as xs:NCName)) then 
            f:operationValidityError($op, concat("operation name '", $name, "' not a valid xs:NCName"))
        else (),   
        
        (: check operation child names 
           =========================== :)        
        let $childNames := distinct-values($op/*/name())
        let $unexpected := 
            for $c in $childNames[not(. = $f:childNames_operation)]
            order by lower-case($c)
            return concat("'", $c, "'")
        return
            if (empty($unexpected)) then () else
                let $txt := 
                    if (count($unexpected) eq 1) then concat('element ', $unexpected)
                    else concat('elements (', string-join($unexpected, ', '), ')')
                return
                    f:operationValidityError($op, concat("operation element has unexpected child ", 
                        $txt, " - only 'param' and 'pgroup' children allowed."))
        ,    

        (: check operation attribute names 
           =============================== :)
        let $atts := $op/@*/name(.)
        let $unexpected := 
            string-join(
                for $a in $atts[not(. = $f:attNames_operation)] 
                order by $a 
                return $a
                , ', ')
        return
            if (not($unexpected)) then () else
                f:operationValidityError($op, 
                     concat("unexpected attributes (", $unexpected, ")")),

        (: check: parameter names must be unique 
           ===================================== :)
        let $names := $op/param/@name
        let $namesDV := distinct-values($names)
        return
            if (count($names) eq count($namesDV)) then () else
            
            let $nonUniqueNames :=
                for $n in $namesDV
                where count($names[. eq $n]) gt 1
                return $n
            for $name in $nonUniqueNames
            return
                f:operationValidityError($op, concat("parameter name '", $name, "' not unique"))
        ,            

        (: check: parameter group names must be unique 
           =========================================== :)
        let $names := $op/pgroup/@name
        let $namesDV := distinct-values($names)
        return
            if (count($names) eq count($namesDV)) then () else
            
            let $nonUniqueNames :=
                for $n in $namesDV
                where count($names[. eq $n]) gt 1
                return $n
            for $name in $nonUniqueNames
            let $param := $op/param[@name eq $name][1]
            return
                f:operationValidityError($op, concat("parameter group name '", $name, "' not unique"))
        ,            

        (: ####################
           check parameters ... 
           #################### :)
        for $param at $pnr in $op/param return (
        let $name := $param/@name
        let $type := $param/@type/replace(., '\s', '')    
        let $sep := $param/@sep
        let $pgroup := $param/@pgroup/replace(., '\s', '')
        let $facets := $param/@*[starts-with(name(.), 'fct_')]

        (: examples: 
            nameFilterMap(xs:integer)? 
                => typename=nameFilerMap
                => typeNameSuffix=xs:integer
                => typeCard=?                
            xs:dateTime* 
                => typename=xs:dateTime
                => typeNameSuffix=
                => typeCard=*
        :)                     
                     
        let $typeName :=
            if (not($type)) then () else
                replace($type, '^(\i\c*)(\((.*)\))?(.*)$', '$1')
        let $typeNameSuffix :=
            if (not($type)) then () else
                replace($type, '^(\i\c*)(\((.*)\))?(.*)$', '$3')
        let $typeCard :=               
            if (not($type)) then () else
                replace($type, '^(\i\c*)(\((.*)\))?(.*)$', '$4')            

        let $typeModel := $acceptedTypes[@name eq $typeName]                
        let $typeClass := $typeModel/@class                
        let $typeFacets := $typeModel/@facets/tokenize(., '\s+')
        
        let $itemTypeName := ($typeModel/@itemType/string(), $typeName)[1]
        let $itemTypeModel :=
            if ($itemTypeName eq $typeName) then $typeModel 
            else $acceptedTypes[@name eq $itemTypeName]
        let $itemTypeClass :=
            if ($itemTypeName eq $typeName) then $typeClass 
            else $itemTypeModel/@class/string()
        
        return (        
            (: check param/@name 
               ================= :)
            (: ... exists :)
            if (not($name)) then f:parameterValidityError($op, $param, 'missing parameter name (@name)')
            (: ... is NCName :)            
            else if (not($name castable as xs:NCName)) then 
                f:parameterValidityError($op, $param, concat("parameter name '", $name, "' not a valid xs:NCName"))
            else (),
        
            (: check param/@type 
               ================= :)
            (: ... exists :)            
            if (not($type)) then f:parameterValidityError($op, $param, 'missing parameter type (@type)')
            (: ... is a known type :)
            else if (not($typeName = $acceptedTypeNames)) then                        
                f:parameterValidityError($op, $param, 
                    concat("parameter type name '", $typeName, "' not a valid type"))
            else (),
            
            if ($typeNameSuffix) then
                if (not($typeName eq 'nameFilterMap')) then
                    f:parameterValidityError($op, $param, concat("type '", $typeName, "' must not have a value type suffix '",
                        "(", $typeNameSuffix, ")'"))
                else if ($typeNameSuffix = $builtinTypeNames) then () else
                    f:parameterValidityError($op, $param, concat("type '", $typeName, "' with invalid value type '", 
                        $typeNameSuffix, "' - value type must be a builtin type"))
            else (),
            
            (: ... NCName is followed by nothing or by a valid cardinality (?,*,+,{n},{n,},{,n},{n,m} :)                
            if ($typeCard and not(matches($typeCard, '^(\?|\*|\+|\{\d+\}|\{\d+,\}|\{,\d+\}|\{\d+,\d+\})$'))) then
                f:parameterValidityError($op, $param, concat("parameter type spec '", $type, "' has invalid cardinality: '", $typeCard, "'"))
            else (),
            
            (: check param/@facet 
               ================== :)
            for $facet in $param/@*[starts-with(local-name(.), 'fct_')]            
            let $facetName := substring-after(local-name($facet), 'fct_')
            let $facetModel := $acceptedFacets[@name eq $facetName] 
            let $facetValueConstraints := $facetModel/tokenize(@facetValueConstraint, '\s+')
            return (
                (: ... facet kind is a known facet kind :)
                if (not($facetName = $acceptedFacetNames)) then                        
                    f:facetValidityError($op, $param, concat("facet kind '", $facetName, 
                        "' not a valid facet kind"))
                else (),
            
                (: ... facet kind compatible with parameter type ... :)
                let $reqTypeClasses := $facetModel/@typeClasses/tokenize(., '\s+')
                let $reqClasses := $facetModel/@types/tokenize(., '\s+')                
                let $supportedFacets := $typeModel/@facets/tokenize(., '\s+')
                return
                    if ($supportedFacets = $facetName) then ()
                    else if ($reqTypeClasses = $itemTypeClass) then ()
                    else if ($reqClasses = $itemTypeName) then ()
                    else if (empty(($reqClasses, $reqTypeClasses))) then ()
                    else
                       f:facetValidityError($op, $param, concat("facet kind '", $facetName, 
                           "' cannot be used for type '", $typeName, "'")),
                            
                (: ... facet value compatible with facet kind specific constraints ... :)                
                for $fvc in $facetValueConstraints
                return
                    (: facet value must be numeric :)
                    if ($fvc eq 'numeric') then
                        if ($facet castable as xs:long) then () else
                            f:facetValidityError($op, $param, concat("facet kind '", $facetName, 
                                "' must have a numeric value, but value is '", $facet, "'"))
                    (: facet value must be castable to parameter type :)
                    else if ($fvc eq 'castable') then
                        if (tt:itemsCastable($facet, $itemTypeName)) then () else
                            f:facetValidityError($op, $param, concat("facet kind '", $facetName, 
                                "' must have a value which is castable to '", $itemTypeName,
                                "', but value is '", $facet, "'"))
                    (: facet values items (comma-separated) must be castable to parameter type :)
                    else if ($fvc eq 'item-castable') then
                        let $items := tokenize($facet, ',\s+') return
                            if (every $item in $items satisfies
                                    tt:itemsCastable($item, $itemTypeName)) then () else
                                f:facetValidityError($op, $param, concat("facet kind '", $facetName, 
                                    "' must have item values which are castable to '", $itemTypeName,
                                    "', but value is '", $facet, "'"))
                    (: facet value must be boolean :)
                    else if ($fvc eq 'boolean') then
                        if ($facet castable as xs:boolean) then () else
                            f:facetValidityError($op, $param, concat("facet kind '", $facetName, 
                                "' must have a boolean value, but value is '", $facet, "'"))                        
                    (: facet value must match regex :)
                    else if (starts-with($fvc, '~')) then
                        let $regex := concat('^', replace($fvc, '^~', ''), '$')
                        return
                            if (matches($facet, $regex, 'x')) then () else
                            f:facetValidityError($op, $param, concat("facet kind '", $facetName, 
                                "' has value '", $facet, "', which does not match this regex: ", $regex))                        
                    else ()                        
            ),
            
            (: check param/@sep 
               ================ :)
            (: ... must be one of 'WS', 'SC' or ';' :)            
            if ($sep and not(replace($sep, '\s', '') = ('WS', 'SC'))) then 
                f:parameterValidityError($op, $param, concat("parameter item separator must be 'WS' or 'SC' - found '", $sep, "'"))
            else (),

            (: check param/@pgroup 
               =================== :)
            (: ... must match the name of a pgroup defined for this operation :)            
            if ($pgroup and not($pgroup = $pgroups)) then 
                f:parameterValidityError($op, $param, 
                    concat("referenced parameter group '", $pgroup, "' not defined",
                        if (empty($pgroups)) then () else concat(" (defined pgroups: ", string-join($pgroups, ', '), ")")))
            else (),            

            (: check unexpected attributes on `param´ 
               ====================================== :)
            let $atts := $param/@*/name(.)
            let $unexpected := 
                string-join(
                    for $a in $atts[not(. = $f:attNames_param)][not(starts-with(., 'fct_'))] 
                    order by $a 
                    return $a
                    , ', ')
            return
                if (not($unexpected)) then () else
                    f:parameterValidityError($op, $param, 
                        concat("unexpected attributes (", $unexpected, ")")),
                    
            ()
        )
        )
        ,
        for $pgroup in $op/pgroup
        let $name := $pgroup/@name
        return (
            (: check pgroup/@name 
               ================== :)
            (: ... exists :)           
            if (not($name)) then f:pgroupValidityError($op, $pgroup, 'missing pgroup name (@name)')
            (: ... is NCName :)        
            else if (not($name castable as xs:NCName)) then 
                f:pgroupValidityError($op, $pgroup, concat("pgroup name '", $name, "' not a valid xs:NCName"))
            else (),   
        
            if (not($pgroup/@minOccurs)) then ()
            else if ($pgroup/@minOccurs castable as xs:nonNegativeInteger) then ()
            else
                f:pgroupValidityError($op, $pgroup, 
                    concat("minOccurs constraint ('", $pgroup/@minOccurs, "') not a number greater/equal 0"))                    
            ,            
            if (not($pgroup/@maxOccurs)) then ()
            else if ($pgroup/@maxOccurs castable as xs:positiveInteger) then ()
            else
                f:pgroupValidityError($op, $pgroup, 
                    concat("maxOccurs constraint ('", $pgroup/@maxOccurs, "') not a positive number"))                    
            ,            
                    
            (: check unexpected attributes on `pgroup` 
               ======================================= :)
            let $atts := $pgroup/@*/name(.)
            let $unexpected := 
                string-join(
                    for $a in $atts[not(. = $f:attNames_pgroup)] 
                    order by $a 
                    return $a
                    , ', ')
            return
                if (not($unexpected)) then () else
                    f:pgroupValidityError($op, $pgroup, 
                         concat("unexpected attributes (", $unexpected, ")"))                    
        )
    )
    return
        $errors
};

(:~
 : Validates the type definitions of a tool scheme.
 :
 : @param userTypes the type definitions of the tool scheme
 : @param userFacets the facet definitions of the tool scheme 
 : @param acceptedSystemTypes the system types which are accepted, given the current features
 : @param acceptedSystemFacets the system facets which are accepted, given the current features 
 : @return error elements describing validation error, or the empty sequence
 :    if no errors are detected
 :)
declare function f:validateToolScheme_types($userTypes as element(type)*,
                                            $userFacets as element(facet)*,
                                            $acceptedSystemTypes as element(type)*,
                                            $acceptedSystemFacets as element(facet)*)
        as element()* {
    let $acceptedTypes := ($acceptedSystemTypes, $userTypes)
    let $acceptedTypeNames := $acceptedTypes/@name/string()  
    let $builtinTypeNames := $f:builtinTypes/@name/string()

    let $acceptedFacets := ($acceptedSystemFacets, $userFacets)
    let $acceptedFacetNames := $acceptedFacets/@name/string()

    let $errors :=
        for $type in $userTypes
        let $name := $type/@name
        let $itemType := $type/@itemType        
        return (
        
        (: check type/@name 
           ================ :)
            (: ... exists :)           
        if (not($name)) then f:typeValidityError($type, 'missing type name (@name)')
            (: ... is NCName :)        
        else if (not($name castable as xs:NCName)) then 
            f:typeValidityError($type, concat("type name '", $name, "' not a valid xs:NCName"))
        else (),   

        (: check type/@itemType 
           ==================== :)
            (: ... exists :)           
        if (not($itemType)) then f:typeValidityError($type, 'missing item type name (@itemType)')
            (: ... is built-in type :)        
        else if ($itemType = $builtinTypeNames) then () 
        else 
            let $isTypeNodeType := f:isTypeNameNodeTypeName($itemType)
            return
                if ($isTypeNodeType eq 'yes') then ()
                else
                    let $msg :=
                        if ($isTypeNodeType eq 'no') then
                            concat("itemType name '", $itemType, "' not a valid type name")
                        else
                            concat("itemType name '", $itemType, "' contains invalid element name")
                    return                            
                        f:typeValidityError($type, $msg)
        ,   
        

        (: check type child names 
           ====================== :)        
        let $childNames := distinct-values($type/*/name())
        let $unexpected := 
            for $c in $childNames[not(. = $f:childNames_type)]
            order by lower-case($c)
            return concat("'", $c, "'")
        return
            if (empty($unexpected)) then () else
                let $txt := 
                    if (count($unexpected) eq 1) then concat('element ', $unexpected, ')')
                    else concat('elements (', string-join($unexpected, ', '), ')')
                return
                    f:typeValidityError($type, concat("type element has unexpected child ", 
                        $txt, "."))
        ,    

        (: check type attribute names 
           ========================== :)
        let $atts := $type/@*/name(.)
        let $unexpected := 
            string-join(
                for $a in $atts[not(. = $f:attNames_type)] 
                order by $a 
                return $a
                , ', ')
        return
            if (not($unexpected)) then () else
                f:typeValidityError($type, concat("unexpected attributes (", $unexpected, ")"))
        
        )
    return
        $errors
};

(:~
 : Validates the facet definitions of a tool scheme.
 :
 : @param userTypes the type definitions of the tool scheme
 : @param userFacets the facet definitions of the tool scheme 
 : @param acceptedSystemTypes the system types which are accepted, given the current features
 : @param acceptedSystemFacets the system facets which are accepted, given the current features 
 : @return error elements describing validation error, or the empty sequence
 :    if no errors are detected
 :)
declare function f:validateToolScheme_facets($userTypes as element(type)*,
                                             $userFacets as element(facet)*,
                                             $acceptedSystemTypes as element(type)*,
                                             $acceptedSystemFacets as element(facet)*)
        as element()* {
    let $acceptedTypes := ($acceptedSystemTypes, $userTypes)
    let $acceptedTypeNames := $acceptedTypes/@name/string()  
    let $builtinTypeNames := $f:builtinTypes/@name/string()

    let $acceptedFacets := ($acceptedSystemFacets, $userFacets)
    let $acceptedFacetNames := $acceptedFacets/@name/string()

    let $errors :=
        for $facet in $userFacets
        let $name := $facet/@name
        let $typeClasses := $facet/@typeClasses        
        let $types := $facet/@types        
        return (
        
        (: check type/@name 
           ================ :)
            (: ... exists :)           
        if (not($name)) then f:facetDefinitionValidityError($facet, 'missing facet name (@name)')
            (: ... is NCName :)        
        else if (not($name castable as xs:NCName)) then 
            f:facetDefinitionValidityError(
                $facet, concat("type name '", $name, "' not a valid xs:NCName"))
        else (),   

        (: check type/@reqTypeClass, type/@reqType 
           ======================================= :)
            (: ... exists :)           
        if (not($typeClasses) and not($types)) then 
            f:facetDefinitionValidityError(
                $facet, concat('facet must have either @typeClasses or @types attribute ',
                'which constrains the types to which this facet is applicable'))
        
            (: ... reqTypeClass is valid type class :)        
        else ( 
            if (not($typeClasses)) then () else
                let $unexpectedTypeClasses := tokenize($typeClasses, '\s+')[not(. = $f:typeClasses)]
                let $unexpectedTypeClassesInfo :=
                    string-join(for $t in $unexpectedTypeClasses return concat("'", $t, "'"), ', ')
                return
                    if (empty($unexpectedTypeClasses)) then () else
                        f:facetDefinitionValidityError(
                            $facet, concat("@typeClasses '", $typeClasses, "' contains invalid type class(es): ",
                            $unexpectedTypeClassesInfo,                           
                            "; valid classes are: ", string-join($f:typeClasses, ', ')))
            ,
            if (not($types)) then () else
                let $unexpectedTypes := tokenize($types, '\s+')
                    [not(. = $acceptedTypeNames) and not(f:isTypeNameNodeTypeName(.) eq 'yes')]
                let $unexpectedTypeInfo :=
                    string-join(for $t in $unexpectedTypes return concat("'", $t, "'"), ', ')
                return
                    if (empty($unexpectedTypes)) then () else
                        f:facetDefinitionValidityError(
                            $facet, concat("@types '", $types, "' contains invalid type name(s): ",
                            $unexpectedTypeInfo))
        )        
        ,   
        

        (: check type child names 
           ====================== :)        
        let $childNames := distinct-values($facet/*/name())
        let $unexpected := 
            for $c in $childNames[not(. = $f:childNames_facet)]
            order by lower-case($c)
            return concat("'", $c, "'")
        return
            if (empty($unexpected)) then () else
                let $txt := 
                    if (count($unexpected) eq 1) then concat('element ', $unexpected, ')')
                    else concat('elements (', string-join($unexpected, ', '), ')')
                return
                    f:facetDefinitionValidityError($facet, concat("facet element has unexpected child ", 
                        $txt, "."))
        ,    

        (: check type attribute names 
           ========================== :)
        let $atts := $facet/@*/name(.)
        let $unexpected := 
            string-join(
                for $a in $atts[not(. = $f:attNames_facet)] 
                order by $a 
                return $a
                , ', ')
        return
            if (not($unexpected)) then () else
                f:facetDefinitionValidityError($facet, concat("unexpected attributes (", $unexpected, ")"))
        
        )
    return
        $errors
};

(:~
 : Reports a component name which is not unique (non-unique operation,
 : type definition or facet definition).
 :
 : @param components the components sharing a name
 : @return an error element
 :)
declare function f:componentUniquenessError($components as element()+)
        as element(zz:error) {
    let $modules := distinct-values($components/@mod)
    let $module1 := $modules[1]
    let $name := $components[1]/@name
    let $kind := $components[1]/local-name(.)
    let $kindInfo := concat(upper-case(substring($kind, 1, 1)), substring($kind, 2))
    let $furtherModulesInfo :=
        if (count($modules) eq 1) then () else
            let $furtherModules :=
                if (count($modules) eq 1) then () else
                string-join(
                    for $m in subsequence($modules, 2) 
                    order by $m 
                    return concat("'", $m, "'"), ', ')
            return
                concat("; further occurrences in these modules: ", $furtherModules)
    let $message := concat($kindInfo, " name not unique: '", $name, "'", $furtherModulesInfo)
    return        
        <zz:error code="ANNOTATION_ERROR" module="{$module1}" msg="{$message}"/> 
};

declare function f:operationValidityError(
                                    $op as element(operation),
                                    $msg as xs:string)
        as element(zz:error) {
    let $module := $op/@mod
    let $name := $op/@name
    let $ident := 
        if (string($name)) then concat("Operation '", $name, "'") else "Operation [missing name]"
    let $message := concat($ident, ": ", $msg)
    return        
        <zz:error code="ANNOTATION_ERROR" module="{$module}" msg="{$message}"/> 
};

declare function f:typeValidityError($type as element(type),
                                     $msg as xs:string)
        as element(zz:error) {
    let $module := $type/@mod
    let $name := $type/@name
    let $ident := 
        if (string($name)) then concat("Type '", $name, "'") else "Type [missing name]"
    let $message := concat($ident, ": ", $msg)
    return        
        <zz:error code="ANNOTATION_ERROR" module="{$module}" msg="{$message}"/> 
};

declare function f:facetDefinitionValidityError($facet as element(facet),
                                                $msg as xs:string)
        as element(zz:error) {
    let $module := $facet/@mod
    let $name := $facet/@name
    let $ident := 
        if (string($name)) then concat("Facet '", $name, "'") else "Facet [missing name]"
    let $message := concat($ident, ": ", $msg)
    return        
        <zz:error code="ANNOTATION_ERROR" module="{$module}" msg="{$message}"/> 
};

(:~
 : Creates an annotation eror, kind `parameter validity`.
 :
 : NOTE: the additional parameter $op is added because of a
 : BaseX bug - the `operation` element should be accessible by
 : the expression: 
 :    $param/ancestor::operation
 : however, the ancestor axis is empty. The parameter will be
 : removed when the bug has been fixed.
 :
 : @param op the operation element
 : @param param the parameter element
 : @msg the message
 : @return an error element of type ANNOTATION_ERROR, specifying the module
 :    and containing an augmented error message
 :)
declare function f:parameterValidityError(
                                    $op as element(operation),
                                    $param as element(param),
                                    $msg as xs:string)
        as element(zz:error) {
(:        
    let $op := trace( $param/ancestor::operation , 
          concat('ANC=', string-join($param/ancestor-or-self::*/name(.), '~'), 
                 '; ATT=', string-join($param/@*/name(.), '~'),          
          ' - OPERATION: '))
:)          
    let $module := $op/@mod
    let $opName := $op/@name
    let $opIdent :=
        if ($opName) then concat("Operation '", $opName, "'")
        else "Operation '?'"    
    let $name := $param/@name/string()
    let $paramIdent :=
        if ($name) then concat("parameter '", $name, "'")
        else concat("parameter #", 1 + count($param/preceding-sibling::param))
    let $ident := concat($opIdent, ', ', $paramIdent)
    let $message := concat($ident, ": ", $msg)
    return        
        <zz:error code="ANNOTATION_ERROR" module="{$module}" msg="{$message}"/> 
};

(:~
 : Creates an annotation eror, kind `pgroup validity`.
 :
 : NOTE: the additional parameter $op is added because of a
 : BaseX bug - the `operation` element should be accessible by
 : the expression: 
 :    $param/ancestor::operation
 : however, the ancestor axis is empty. The parameter will be
 : removed when the bug has been fixed.
 :
 : @param op the operation element
 : @param param the parameter element
 : @msg the message
 : @return an error element of type ANNOTATION_ERROR, specifying the module
 :    and containing an augmented error message
 :)
declare function f:pgroupValidityError(
                         $op as element(operation),
                         $pgroup as element(pgroup),                         
                         $msg as xs:string)
        as element(zz:error) {
    let $module := $op/@mod
    let $opName := $op/@name
    let $opIdent :=
        if ($opName) then concat("Operation '", $opName, "'")
        else "Operation '?'"    
    let $name := $pgroup/@name/string()
    let $pgroupIdent :=
        if ($name) then concat("pgroup '", $name, "'")
        else concat("pgroup #", 1 + count($pgroup/preceding-sibling::pgroup))
    let $ident := concat($opIdent, ', ', $pgroupIdent)
    let $message := concat($ident, ": ", $msg)
    return        
        <zz:error code="ANNOTATION_ERROR" module="{$module}" msg="{$message}"/> 
};

(:~
 : Creates an annotation eror, kind `facet validity`.
 :
 : NOTE: the additional parameter $op is added because of a
 : BaseX bug - the `operation` element should be accessible by
 : the expression: 
 :    $param/ancestor::operation
 : however, the ancestor axis is empty. The parameter will be
 : removed when the bug has been fixed.
 :
 : @param op the operation element
 : @param param the parameter element
 : @msg the message
 : @return an error element of type ANNOTATION_ERROR, specifying the module
 :    and containing an augmented error message
 :)
declare function f:facetValidityError(
                                    $op as element(operation),
                                    $param as element(param),
                                    $msg as xs:string)
        as element(zz:error) {
(:        
    let $op := trace( $param/ancestor::operation , 
          concat('ANC=', string-join($param/ancestor-or-self::*/name(.), '~'), 
                 '; ATT=', string-join($param/@*/name(.), '~'),          
          ' - OPERATION: '))
:)          
    let $module := $op/@mod
    let $opName := $op/@name
    let $opIdent :=
        if ($opName) then concat("Operation '", $opName, "'")
        else "Operation '?'"    
    let $name := $param/@name/string()
    let $paramIdent :=
        if ($name) then concat("parameter '", $name, "'")
        else concat("parameter #", 1 + count($param/preceding-sibling::param))
    let $ident := concat($opIdent, ', ', $paramIdent)
    let $message := concat($ident, ": ", $msg)
    return        
        <zz:error code="ANNOTATION_ERROR" module="{$module}" msg="{$message}"/> 
};

(:~
 : Checks whether a type name is a valid node type name. Returns 'yes' or 'no',
 : or 'error' if the type name is a node type name containing an invalid
 : element name.
 :
 : Examples:
 :    element(), document-node(), element(foo), document-node(bar) - 'yes'
 :    xs:string - 'no'
 :    element(foo#), document-node(bar+) - 'error'
 :
 : @param name the name to be checked
 : @return one of 'yes', 'no' or 'error'
 :)
declare function f:isTypeNameNodeTypeName($name)
        as xs:string {
    if (not(matches($name, '^(element|document-node)\(.*\)$'))) then 'no'
    else
        
    let $elemName := replace($name, '^(document-node|element)\((.*)\)$', '$2')
    let $elemName := replace($elemName, '.+:', '')
    return
        if (not($elemName) or $elemName castable as xs:NCName) then 'yes' 
        else 'error'
};

declare function f:isValueCastable($value as xs:untypedAtomic, $typeName as xs:string)
        as xs:boolean? {
        let $t :=
    <types>
        <type name="xs:string" class="string" reqFeature="" />
        <type name="xs:normalizedString" class="string" reqFeature=""/>        
        <type name="xs:token" class="string" reqFeature=""/>        
        <type name="xs:language" class="string" reqFeature=""/>        
        <type name="xs:NMTOKEN" class="string" reqFeature=""/>        
        <type name="xs:Name" class="string" reqFeature=""/>        
        <type name="xs:NCName" class="string" reqFeature=""/>        
        <type name="xs:ID" class="string" reqFeature=""/>
        <type name="xs:IDREF" class="string" reqFeature=""/>
        <type name="xs:dateTime" class="time" reqFeature=""/>        
        <type name="xs:date" class="time" reqFeature=""/>        
        <type name="xs:time" class="time" reqFeature=""/>        
        <type name="xs:duration" class="duration" reqFeature=""/>        
        <type name="xs:yearMonthDuration" class="duration" reqFeature=""/>        
        <type name="xs:dayTimeDuration" class="duration" reqFeature=""/>        
        <type name="xs:float" class="numeric" reqFeature=""/>        
        <type name="xs:double" class="numeric" reqFeature=""/>
        <type name="xs:decimal" class="numeric" reqFeature=""/>
        <type name="xs:integer" class="numeric" reqFeature=""/>        
        <type name="xs:nonPositiveInteger" class="numeric" reqFeature=""/>        
        <type name="xs:negativeInteger" class="numeric" reqFeature=""/>        
        <type name="xs:long" class="numeric" reqFeature=""/>        
        <type name="xs:int" class="numeric" reqFeature=""/>
        <type name="xs:short" class="numeric" reqFeature=""/>
        <type name="xs:byte" class="numeric" reqFeature=""/>        
        <type name="xs:nonNegativeInteger" class="numeric" reqFeature=""/>        
        <type name="xs:unsignedLong" class="numeric" reqFeature=""/>        
        <type name="xs:unsignedShort" class="numeric" reqFeature=""/>        
        <type name="xs:unsignedByte" class="numeric" reqFeature=""/>        
        <type name="xs:positiveInteger" class="numeric" reqFeature=""/>        
        <type name="xs:gYearMonth" class="time" reqFeature=""/>        
        <type name="xs:gYear" class="time" reqFeature=""/>        
        <type name="xs:gMonthDay" class="time" reqFeature=""/>        
        <type name="xs:gDay" class="time" reqFeature=""/>        
        <type name="xs:gMonth" class="time" reqFeature=""/>        
        <type name="xs:boolean" class="boolean" reqFeature=""/>        
        <type name="xs:base64Binary" class="binary" reqFeature=""/>        
        <type name="xs:hexBinary" class="binary" reqFeature=""/>        
        <type name="xs:anyURI" class="string" reqFeature=""/>        
        <type name="xs:QName" class="qname" reqFeature=""/>        
    </types>
    return    
    if ($typeName eq 'xs:string') then $value castable as xs:string        
    else if ($typeName eq 'xs:normalizedString') then $value castable as xs:normalizedString    
    else if ($typeName eq 'xs:token') then $value castable as xs:token    
    else if ($typeName eq 'xs:language') then $value castable as xs:language    
    else if ($typeName eq 'xs:NMTOKEN') then $value castable as xs:NMTOKEN    
    else if ($typeName eq 'xs:Name') then $value castable as xs:Name    
    else if ($typeName eq 'xs:NCName') then $value castable as xs:NCName    
    else if ($typeName eq 'xs:ID') then $value castable as xs:ID    
    else if ($typeName eq 'xs:IDREF') then $value castable as xs:IDREF    
    else if ($typeName eq 'xs:dateTime') then $value castable as xs:dateTime    
    else if ($typeName eq 'xs:date') then $value castable as xs:date    
    else if ($typeName eq 'xs:time') then $value castable as xs:time
    else if ($typeName eq 'xs:duration') then $value castable as xs:duration    
(:    
    if ($typeName eq 'xs:integer') then $value castable as xs:integer
    else if ($typeName eq 'xs:boolean') then $value castable as xs:boolean
:)    
    else ()
};        