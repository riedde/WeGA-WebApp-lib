xquery version "3.0" encoding "UTF-8";

(:~
 : XQuery module for manipulating strings
~:)
module namespace str="http://xquery.weber-gesamtausgabe.de/modules/str";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace mei="http://www.music-encoding.org/ns/mei";

import module namespace functx="http://www.functx.com";

(:~
 : Normalizes a given string
 : In addition to fn:normalize-space() this function treats non-breaking-spaces etc. as whitespace 
 :
 : @author Peter Stadler
 : @param $string the string to normalize
 : @return xs:string
 :)
declare function str:normalize-space($string as xs:string?) as xs:string {
    normalize-unicode(
        normalize-space(
            replace(
                (: diverse Control Codes entsorgen, siehe https://en.wikipedia.org/wiki/List_of_Unicode_characters :)
                replace($string, '&#27;|&#127;|&#128;', ' '),
                (: diversen Whitespace entsorgen, siehe https://en.wikipedia.org/wiki/Whitespace_character :)
                '&#160;|&#8194;|&#8195;|&#8201;', ' '
            )
        )
    )
};

(:~
 : Joins path elements with a forward slash
 : In addition to string-join this function also takes care of double slashes
 :
 : @author Peter Stadler
 : @param $segs the path elements to join
 : @return the joined path as xs:string, the empty string when $segs was the empty sequence
 :)
declare function str:join-path-elements($segs as xs:string*) as xs:string {
    replace(replace(string-join($segs, '/'), '/+' , '/'), '\s+', '_')
};

(:~ 
 : Print forename surname by simply checking for a comma and reversing the tokens at this point
 :
 : @param $name the name as a simple string
 : @author Peter Stadler
 : @return xs:string
 :)
declare function str:printFornameSurname($name as xs:string?) as xs:string? {
    let $clearName := str:normalize-space($name)
    return
        if(functx:number-of-matches($clearName, ',') eq 1)
        then normalize-space(string-join(reverse(tokenize($clearName, ',')), ' '))
        else $clearName
};

(:~ 
 : Print forename surname from a TEI persName element
 : In contrast to str:printFornameSurname() this function checks the appearance of forenames, i.e.
 : <persName type="reg"><forename>Eugen</forename> <forename>Friedrich</forename> <forename>Heinrich</forename>, <roleName>Herzog</roleName> <nameLink>von</nameLink> Württemberg</persName>
 : is turned into "Eugen Friedrich Heinrich, Herzog von Württemberg" rather than "Herzog von Württemberg Eugen Friedrich Heinrich"
 :
 : @param $name a tei persName element
 : @author Peter Stadler
 : @return xs:string
 :)
declare function str:printFornameSurnameFromTEIpersName($persName as element(tei:persName)?) as xs:string? {
    if(($persName/element()[1])[self::tei:forename]) then str:normalize-space($persName)
    else str:printFornameSurname(string($persName))
};

(:~ 
 : Surround a string with typographic double quotes
 :
 : @param $str the string to enquote
 : @param $lang the language switch (en|de)
 : @author Peter Stadler
 : @return a single string if the input was a single string, a sequence of strings if the input was a sequence (where the quotes are then the first and the last item) 
 :)
declare function str:enquote($str as xs:string*, $lang as xs:string) as xs:string* {
    if(count($str) = 1) then 
        switch ($lang)
        case 'de' return concat('&#x201E;', $str, '&#x201C;')
        case 'en' return concat('&#x201C;', $str, '&#x201D;')
        default return concat('&quot;', $str, '&quot;')
    else if(count($str) gt 1) then 
        switch ($lang)
        case 'de' return ('&#x201E;', $str, '&#x201C;')
        case 'en' return ('&#x201C;', $str, '&#x201D;')
        default return ('&quot;', $str, '&quot;')
    else ()
};

(:~ 
 : Surround a string with typographic single quotes
 :
 : @param $str the string to enquote
 : @param $lang the language switch (en|de)
 : @author Peter Stadler
 : @return a single string if the input was a single string, a sequence of strings if the input was a sequence (where the quotes are then the first and the last item) 
 :)
declare function str:enquote-single($str as xs:string*, $lang as xs:string) as xs:string* {
    if(count($str) = 1) then 
        switch ($lang)
        case 'de' return concat('&#x201A;', $str, '&#x2018;')
        case 'en' return concat('&#x2018;', $str, '&#x2019;')
        default return concat('&#x0027;', $str, '&#x0027;')
    else if(count($str) gt 1) then 
        switch ($lang)
        case 'de' return ('&#x201A;', $str, '&#x2018;')
        case 'en' return ('&#x2018;', $str, '&#x2019;')
        default return ('&#x0027;', $str, '&#x0027;')
    else ()
};

(:~
 : Print teaser text of max length while truncating at word border
 :
 : @author Peter Stadler
 : @param $string the string to truncate
 : @param $maxLength the max length of the returned string as xs:int
 : @return xs:string 
:)
declare function str:shorten-text($string as xs:string, $maxLength as xs:int) as xs:string {
    let $delimiterRegex := '[\s\.,!\?\+-;]' 
    let $maxString := substring(normalize-space($string),1,$maxLength)
    return 
        if(string-length($maxString) lt $maxLength) then $maxString 
        else concat(functx:substring-before-last-match($maxString, $delimiterRegex), ' …')
};

(:~
 : A simple shortcut to str:shorten-text() for creating teaser texts from TEI documents
 :
 : @author Peter Stadler
 : @param $nodes the TEI nodes that make up the text to be truncated
 : @param $maxLength the max length of the returned string as xs:int
 : @return xs:string 
~:)
declare function str:shorten-TEI($nodes as node()*, $maxLength as xs:int, $lang as xs:string) as xs:string {
    let $strings := $nodes ! string-join(str:txtFromTEI(., $lang), '')
    return
        str:shorten-text(string-join($strings, ' '), $maxLength)
};

(:~
 : Creates a simple text version of a TEI document (or fragment)
 : by resolving choices, substitutions and removing notes
 : (used for e.g. wordOfTheDay and several titles)
 :
 : @param $nodes the nodes to transform
~:)
declare function str:txtFromTEI($nodes as node()*, $lang as xs:string) as xs:string* {
    for $node in $nodes
    return
        typeswitch($node)
        case element(tei:forename) return 
        	if($node/@cert) then ($node/child::node() ! str:txtFromTEI(., $lang), '(?)') 
        	else $node/child::node() ! str:txtFromTEI(., $lang)
        case element(tei:del) return ()
        case element(tei:subst) return $node/child::element() ! str:txtFromTEI(., $lang)
        case element(tei:note) return ()
        case element(tei:lb) return 
            if($node[@type='inWord']) then ()
            else '&#10;'
        case element(tei:pb) return 
            if($node[@type='inWord']) then ()
            else ' '
        case element(tei:q) return str:enquote(($node/child::node() ! str:txtFromTEI(., $lang)), $lang)
        case element(tei:quote) return 
            if($node[@rend='double-quotes']) then str:enquote(($node/child::node() ! str:txtFromTEI(., $lang)), $lang)
            else str:enquote-single(($node/child::node() ! str:txtFromTEI(., $lang)), $lang)
        case element(tei:supplied) return ('[', $node/child::node() ! str:txtFromTEI(., $lang), ']') 
        case text() return replace($node, '\n+', ' ')
        case document-node() return $node/child::node() ! str:txtFromTEI(., $lang) 
        case processing-instruction() return ()
        case comment() return ()
        default return $node/child::node() ! str:txtFromTEI(., $lang)
};

(:~ 
 : Sanitize user input
 : cf. http://www.balisage.net/Proceedings/vol7/html/Vlist02/BalisageVol7-Vlist02.html
 :
 : @author Peter Stadler
 : @return xs:string
 :)
declare function str:sanitize($str as xs:string) as xs:string {
(: Das wird wohl intern schon berücksichtigt?! Jedenfalls bringt die doppelte(?) Kodierung hier nur Probleme    :)
   (:if(contains($str, '&amp;')) then str:sanitize(replace($str, '&amp;', '&amp;amp;'))
   else if(contains($str, '''')) then str:sanitize(replace($str, '''', '&amp;apos;'))
   else if(contains($str, '""')) then str:sanitize(replace($str, '""', '&amp;quot;'))
   else if(contains($str, '<')) then str:sanitize(replace($str, '<', '&amp;lt;'))
   else if(contains($str, '{')) then str:sanitize(replace($str, '{', '{{'))
   else if(contains($str, '}')) then str:sanitize(replace($str, '}', '}}'))
   else :)$str
};

declare function str:list($items as xs:string*, $lang as xs:string, $maxLength as xs:int, $get-language as function() as xs:string) as xs:string? {
    let $count := count($items)
    return
        if($count le 2) then string-join($items, ', ')
        else string-join(subsequence($items, 1, $count -1), ', ') || ' ' || $get-language('and', $lang) || ' ' || $items[$count]
};
