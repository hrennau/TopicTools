(:~ 
 : _extensions.xqm - generated functions invoking application specific extensions.
 :
 : @version 20140402-1 first version 
 : ===================================================================================
 :)

module namespace m="http://www.ttools.org/xquery-functions";


declare namespace z="http://www.ttools.org/structure";

declare variable $m:NON_STANDARD_TYPES := '';

(:
 : ============================================================================
 :
 :     o p e r a t i o n s
 :
 : ============================================================================
 :)

(:~
 : Parses a request string into a data type item. The function delegates the
 : parsing to the appropriate function identified by pseudo annotations.
 : 
 : @param paramName the parameter name
 : @param itemType the item type
 : @param itemText a string providing a single parameter item
 : @return the parsed item, or an z:errors element
 :)
declare function m:parseNonStandardItemType($paramName as xs:string, $itemType as xs:string, $itemText as xs:string)       
        as item() {       

    <z:error type="UNKNOWN_ITEMTYPE" paramName="{$paramName}" itemType="{$itemType}" 
        itemValue="{$itemText}"                       
        msg="{concat('Parameter ''', $paramName, ''' has unknown item type: ', $itemType)}"/>
};

declare function m:adaptItemTypeOfNonStandardItemType($itemType as xs:string)
        as xs:string {
    $itemType
};

declare function m:checkNonStandardFacets($itemText as xs:string, $typedItem as item(), $paramConfig as element())       
        as element()* {
    ()        
};
