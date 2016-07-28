xquery version "3.0";
(:
 :***************************************************************************
 :
 : processorSpecific.xqm - processor specific extension functions
 :
 : Edition for processor: Saxon
 :
 :***************************************************************************
 :)
 
module namespace f="http://www.ttools.org/xquery-functions";
import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "_constants.xqm";

declare namespace z="http://www.ttools.org/structure";
declare namespace saxon="http://saxon.sf.net/";

(:
 : ============================================================================
 :
 :     p r i v a t e    f u n c t i o n s
 :
 : ============================================================================
 :)

(:~
 : Executes an XQuery expression.
 :
 : @param query an XQuery expression
 : @param ctxt an item to be used as context item
 : @return the result of evaluating the expression
 :) 
declare function f:evaluate($query as xs:string, $context as item()?)
        as item()* {
    error(QName($tt:URI_ERROR, 'INVALID_CALL'), 
        'With SaxonHE, this function should never be called, as the ',
        'SaxonHE processor allows only for a dummy implementation.')        
};
