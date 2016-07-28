module namespace f="http://www.ttools.org/xquery-functions";
import module namespace i="http://www.ttools.org/xquery-functions" at 
    "_foxpath-processorDependent.xqm",
    "_foxpath-util.xqm";

declare function f:childUriCollection($uri as xs:string, $name as xs:string?) {
    file:list($uri, false(), $name)           
    ! replace(., '\\', '/')
    ! replace(., '/$', '')
};

declare function f:descendantUriCollection($uri as xs:string, $name as xs:string?) {
    file:list($uri, true(), $name)           
    ! replace(., '\\', '/')
    ! replace(., '/$', '')
};
