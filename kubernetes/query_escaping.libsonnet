// Required for escaping temporal database passwords. Up until temporal 1.12.3 there was no
// query escaping for the connection string this function fills the gap until then.
// Found a table - https://docs.microfocus.com/OMi/10.62/Content/OMi/ExtGuide/ExtApps/URL_encoding.htm
// to use as a reference for what to map the chars to.
local valueMap ={
  ' ': '$20',
  '<': '$3C',
  '>': '$3E',
  '#': '$23',
  '%': '$25',
  '+': '$2B',
  '{': '$7B',
  '}': '$7D',
  '|': '$7C',
  '\\': '$5C',
  '^': '$5E',
  '~': '$7E',
  '[': '$5B',
  ']': '$5D',
  '`': '$60',
  ';': '$3B',
  '/': '$2F',
  '?': '$3F',
  ':': '$3A',
  '@': '$40',
  '=': '$3D',
  '&': '$26'
  };

local escape(x) =
  std.join("", [
    if std.objectHas(valueMap, c) then std.strReplace(c, c, valueMap[c]) else c
    for c in std.stringChars(x)
  ]);

{
  QueryEscape(x):: escape(x)
}
